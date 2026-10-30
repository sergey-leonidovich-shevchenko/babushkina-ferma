"""Настоящие Git/linked-worktree проверки явной границы исторического исходника."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from .git import git_environment
from .history import read_git_blob


class HistoryTests(unittest.TestCase):
    def setUp(self):
        """Создаёт принадлежащий тесту репозиторий с пробелами и бинарным содержимым."""
        self.temporary = tempfile.TemporaryDirectory(prefix='history real Git ')
        self.parent = Path(self.temporary.name)
        self.root = self.parent / 'project with spaces'
        self.root.mkdir()
        self.git('init', '-q', '--initial-branch=main')
        for key, value in [('user.name', 'History fixture'), ('user.email', 'history@example.invalid'),
                           ('commit.gpgsign', 'false'), ('core.hooksPath', str(self.parent / 'no hooks'))]:
            self.git('config', key, value)
        self.relative = 'tools/source.gd'
        self.raw = b'original source\x00\xff\n'
        self.path = self.root / self.relative
        self.path.parent.mkdir()
        self.path.write_bytes(self.raw)
        (self.root / 'empty').touch()
        self.git('add', '.')
        self.git('commit', '-qm', 'fixed original')
        self.commit = self.git('rev-parse', 'HEAD').decode().strip()
        self.digest = hashlib.sha256(self.raw).hexdigest()
        self.addCleanup(self.temporary.cleanup)

    def git(self, *arguments, root=None):
        """Все fixture-команды изолированы от окружения реального hook/checkout."""
        return subprocess.run(['git', '-C', str(root or self.root), *arguments],
                              env=git_environment(), capture_output=True, check=True).stdout

    def read(self, **overrides):
        """Вызывает production reader с одним явно изменяемым входом."""
        arguments = dict(root=self.root, relative=self.relative, commit=self.commit, expected=self.digest)
        arguments.update(overrides)
        return read_git_blob(**arguments)

    def test_exact_binary_blob(self):
        """Git blob возвращается без декодирования, фильтрации или изменения переводов строк."""
        self.assertEqual(self.read(), self.raw)

    def test_current_edit_delete_and_move_do_not_resign_history(self):
        """Редактирование и настоящий git mv текущего файла не меняют старый proof."""
        self.path.write_bytes(b'new current implementation')
        self.assertEqual(self.read(), self.raw)
        self.git('mv', self.relative, 'tools/renamed.gd')
        self.assertEqual(self.read(), self.raw)
        (self.root / 'tools/renamed.gd').unlink()
        self.assertEqual(self.read(), self.raw)

    def test_invalid_pin_parameters(self):
        """Traversal, неоднозначные пути, короткие refs и неправильный SHA отклоняются."""
        mutations = [('relative', value) for value in ['', '/tmp/source', '../source', 'tools//source.gd',
                     'tools/./source.gd', 'tools/../source.gd', 'tools\\source.gd', ':source',
                     'tools/*', '.git/config', 'tools/\x00source', 'tools/\nsource', 7]]
        mutations += [('commit', value) for value in ['HEAD', self.commit[:12], 'F' * 40, None]]
        mutations += [('expected', value) for value in ['abcd', 'A' * 64, None]]
        for key, value in mutations:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                self.read(**{key: value})

    def test_current_bytes_cannot_replace_wrong_historical_sha(self):
        """Даже совпадающий с ожидаемым рабочий файл не заменяет другой Git blob."""
        self.path.write_bytes(b'different file matching an attacker claim')
        with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
            self.read(expected=hashlib.sha256(self.path.read_bytes()).hexdigest())

    def test_unavailable_commit_has_no_live_fallback(self):
        """Правильные текущие байты не позволяют пройти без закреплённого commit."""
        with self.assertRaises(ValueError):
            self.read(commit='0' * 40)

    def test_missing_git_path_has_no_live_fallback(self):
        """Новый untracked файл с правильными байтами не становится прошлым исходником."""
        (self.root / 'tools/current-only.gd').write_bytes(self.raw)
        with self.assertRaisesRegex(ValueError, 'missing'):
            self.read(relative='tools/current-only.gd')

    def test_parent_repository_cannot_be_borrowed(self):
        """Вложенная папка без собственного .git не заимствует историю родителя."""
        child = self.root / 'nested project'
        child.mkdir()
        with self.assertRaises(ValueError):
            self.read(root=child)

    def test_stored_symlink_is_not_a_source_blob(self):
        """Даже верный SHA текста symlink не превращает его в обычный исходник."""
        link = self.root / 'tools/archived-link'
        link.symlink_to('source.gd')
        self.git('add', '.')
        self.git('commit', '-qm', 'symlink fixture')
        link.unlink()
        with self.assertRaisesRegex(ValueError, 'regular file'):
            self.read(relative='tools/archived-link', commit=self.git('rev-parse', 'HEAD').decode().strip(),
                      expected=hashlib.sha256(b'source.gd').hexdigest())

    def test_live_symlink_does_not_cross_checkout_boundary(self):
        """Рабочая symlink не позволяет обращаться к внешнему файлу как к собственному source."""
        outside = self.parent / 'outside source'
        outside.write_bytes(self.raw)
        self.path.unlink()
        self.path.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.read()
        self.assertEqual(outside.read_bytes(), self.raw)

    def test_bare_repository_is_not_a_checkout(self):
        """Bare clone не выдаётся за исходный рабочий проект."""
        bare = self.parent / 'bare repository'
        self.git('clone', '-q', '--bare', str(self.root), str(bare))
        with self.assertRaises(ValueError):
            self.read(root=bare)

    def test_real_linked_worktree_with_spaces(self):
        """Настоящий worktree с .git-файлом читает собственный закреплённый commit."""
        checkout = self.parent / 'linked checkout with spaces'
        self.git('worktree', 'add', '-q', '--detach', str(checkout), self.commit)
        self.assertTrue((checkout / '.git').is_file())
        self.assertEqual(self.read(root=checkout), self.raw)

    def test_hostile_git_environment_and_parent_state_unchanged(self):
        """Чужие worktree/index/config не выбирают источник и остаются побайтно прежними."""
        foreign = self.parent / 'foreign checkout'
        self.git('clone', '-q', str(self.root), str(foreign))
        paths = [self.root / '.git/config', self.root / '.git/index',
                 foreign / '.git/config', foreign / '.git/index']
        before = {p: p.read_bytes() for p in paths}
        hostile = {'GIT_DIR': str(foreign / '.git'), 'GIT_WORK_TREE': str(foreign),
                   'GIT_INDEX_FILE': str(foreign / '.git/alternate-index'),
                   'GIT_CONFIG_COUNT': '1', 'GIT_CONFIG_KEY_0': 'core.bare', 'GIT_CONFIG_VALUE_0': 'true'}
        with patch.dict(os.environ, hostile):
            environment = dict(os.environ)
            self.assertEqual(self.read(), self.raw)
            self.assertEqual(dict(os.environ), environment)
        self.assertEqual({p: p.read_bytes() for p in paths}, before)
        self.assertFalse((foreign / '.git/alternate-index').exists())

    def test_git_directory_symlink_is_rejected(self):
        """Подложенная .git symlink не становится самостоятельным checkout."""
        child = self.parent / 'fake checkout'
        child.mkdir()
        (child / '.git').symlink_to(self.root / '.git', target_is_directory=True)
        with self.assertRaises(ValueError):
            self.read(root=child)

    def test_unregistered_git_file_cannot_borrow_another_checkout(self):
        """Поддельный .git-файл не заменяет зарегистрированный linked worktree."""
        child = self.parent / 'fake Git file checkout'
        child.mkdir()
        (child / '.git').write_text('gitdir: ' + str(self.root / '.git') + '\n')
        with self.assertRaises(ValueError):
            self.read(root=child)

    def test_source_parent_symlink_is_rejected(self):
        """Граница проверяется и для родителя исходника, а не только его последнего имени."""
        self.path.parent.rename(self.root / 'original tools')
        (self.root / 'tools').symlink_to(self.root / 'original tools', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.read()

    def test_noncommit_object_is_rejected(self):
        """Полный blob ID синтаксически похож на commit, но не проходит чтение дерева."""
        blob = self.git('rev-parse', self.commit + ':' + self.relative).decode().strip()
        with self.assertRaises(ValueError):
            self.read(commit=blob)

    def test_empty_file_is_valid(self):
        """Пустой обычный файл имеет проверяемый SHA и не считается отсутствующим."""
        self.assertEqual(self.read(relative='empty', expected=hashlib.sha256(b'').hexdigest()), b'')

    def test_replace_ref_cannot_change_pinned_commit(self):
        """Локальный replace ref не подменяет байты полного исходного commit."""
        self.path.write_bytes(b'replacement implementation')
        self.git('add', '.')
        self.git('commit', '-qm', 'replacement fixture')
        replacement = self.git('rev-parse', 'HEAD').decode().strip()
        self.git('replace', self.commit, replacement)
        self.assertEqual(self.read(), self.raw)
        with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
            self.read(expected=hashlib.sha256(self.path.read_bytes()).hexdigest())

    def test_unicode_and_spaces_in_canonical_path(self):
        """Нормальное имя с кириллицей и пробелами читается без Git quoting потерь."""
        relative = 'tools/исходник с пробелом.gd'
        (self.root / relative).write_bytes(self.raw)
        self.git('add', '.')
        self.git('commit', '-qm', 'unicode fixture')
        self.assertEqual(self.read(relative=relative, commit=self.git('rev-parse', 'HEAD').decode().strip()), self.raw)

    def test_actual_bare_config_is_rejected_without_repairing_it(self):
        """Reader не исправляет конфигурацию репозитория скрытой записью."""
        self.git('config', 'core.bare', 'true')
        config = self.root / '.git/config'
        before = config.read_bytes()
        with self.assertRaises(ValueError):
            self.read()
        self.assertEqual(config.read_bytes(), before)

    def test_other_cwd_does_not_choose_repository(self):
        """Смена cwd не влияет на явно переданный checkout."""
        previous = Path.cwd()
        try:
            os.chdir(self.parent)
            self.assertEqual(self.read(), self.raw)
        finally:
            os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
