"""Реальные Git-чтения performance не должны наследовать чужой проект/index/config."""
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import performance_gate as gate
from tools.qa.performance import perf_contract as contract
from tools.qa.performance import perf_contract_collect as collector
from tools.common.git import git_environment


class PerformanceContextTests(unittest.TestCase):
    """Проверяет настоящий Git и старую signed-серию без запуска игрового окна."""

    def repository(self, root, label):
        """Создаёт отдельный настоящий commit с различимым assets-деревом и без global config."""
        root.mkdir()
        subprocess.run(['git', 'init', '-q', str(root)], env=git_environment(), check=True)
        (root / 'assets').mkdir()
        (root / 'assets/item.txt').write_text(label)
        subprocess.run(['git', '-C', str(root), 'add', 'assets'], env=git_environment(), check=True)
        subprocess.run(['git', '-C', str(root), '-c', 'user.name=Performance QA',
            '-c', 'user.email=qa@example.invalid', 'commit', '-qm', label],
            env=git_environment(), check=True)
        return root

    def git(self, root, *arguments):
        """Читает ожидаемый commit/дерево отдельным чистым Git, не вызывая проверяемый helper."""
        return subprocess.check_output(['git', '-C', str(root), *arguments],
            env=git_environment()).decode().strip()

    @contextmanager
    def foreign_context(self, folder):
        """Сохраняет cwd, вызывающее окружение и точные index/config чужого репозитория."""
        before = {n: (folder / '.git' / n).read_bytes() for n in ['index', 'config']}
        previous = Path.cwd()
        try:
            os.chdir(folder)
            with patch.dict(os.environ, GIT_DIR=str(folder / '.git'),
                GIT_WORK_TREE=str(folder), GIT_INDEX_FILE=str(folder / '.git/index'),
                GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true'):
                environment = dict(os.environ)
                yield
                self.assertEqual(dict(os.environ), environment)
        finally:
            os.chdir(previous)
            for name, raw in before.items():
                self.assertEqual((folder / '.git' / name).read_bytes(), raw)

    def test_asset_state_and_revision_use_the_explicit_project(self):
        """Сценарий: asset/revision reader запущен из чужого Git.
        Исходное состояние: два разных commit, один tracked и один untracked asset у своего проекта.
        Ожидаемый результат: собственные tree/revision/байты и неизменный чужой index/config.
        """
        with tempfile.TemporaryDirectory(prefix='performance project git ') as directory:
            parent = Path(directory).resolve()
            project = self.repository(parent / 'own project', 'own')
            foreign = self.repository(parent / 'foreign project', 'foreign')
            tree, revision = self.git(project, 'rev-parse', 'HEAD:assets'), self.git(project, 'rev-parse', 'HEAD')
            (project / 'assets/item.txt').write_text('changed own')
            (project / 'assets/new.txt').write_text('untracked own')
            expected = {n: hashlib.sha256((project / n).read_bytes()).hexdigest()
                for n in ['assets/item.txt', 'assets/new.txt']}
            with self.foreign_context(foreign):
                self.assertEqual(gate.asset_state(project),
                    {'git_tree_sha1': tree, 'worktree_files': expected})
                self.assertEqual(gate.revision(project), revision)

    def test_archived_contract_provenance_uses_its_code_history(self):
        """Сценарий: старый настоящий native-пакет читается под чужими GIT переменными.
        Исходное состояние: полный старый архив и отдельный Git без его base commit.
        Ожидаемый результат: прежний source проверен в своём code checkout, чужие файлы неизменны.
        """
        folder = contract.REPORT / 'native'
        expected = json.loads((folder / 'source.json').read_text())
        with tempfile.TemporaryDirectory(prefix='performance history git ') as directory:
            foreign = self.repository(Path(directory).resolve() / 'foreign', 'no code history')
            with self.foreign_context(foreign):
                self.assertEqual(contract.provenance(folder, contract.SCHEDULE), expected)

    def test_collector_git_command_uses_own_source_checkout(self):
        """Сценарий: публичный collector helper получает git rev-parse из чужой cwd.
        Исходное состояние: настоящий код и посторонний Git с другим commit и bare override.
        Ожидаемый результат: commit кода, без изменения окружения и чужого index/config.
        """
        expected = self.git(collector.ROOT, 'rev-parse', 'HEAD')
        with tempfile.TemporaryDirectory(prefix='performance collector git ') as directory:
            foreign = self.repository(Path(directory).resolve() / 'foreign', 'wrong collector base')
            with self.foreign_context(foreign):
                self.assertEqual(collector.command(['git', 'rev-parse', 'HEAD']), expected)

    def test_public_performance_shell_help_uses_own_launcher(self):
        """Сценарий: публичный shell запущен из другого проекта с одноимённым ложным инструментом.
        Исходное состояние: foreign Git и собственный --help, который не запускает Godot.
        Ожидаемый результат: справка настоящего кода, а не исполнение одноимённого чужого файла.
        """
        with tempfile.TemporaryDirectory(prefix='performance shell context ') as directory:
            foreign = self.repository(Path(directory).resolve() / 'foreign', 'foreign shell')
            (foreign / 'tools').mkdir()
            (foreign / 'tools/performance_gate.py').write_text('print("FOREIGN_GATE_EXECUTED")\n')
            with self.foreign_context(foreign):
                result = subprocess.run(['zsh', str(gate.ROOT / 'tools/performance_gate.sh'), '--help'],
                    cwd=foreign, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn('FOREIGN_GATE_EXECUTED', result.stdout)
                self.assertIn('--output', result.stdout)
                self.assertIn('--godot', result.stdout)

    def test_public_smoke_shell_binds_own_project_with_fake_engine(self):
        """Сценарий: shell smoke получает только изолированный fake-engine свидетель.
        Исходное состояние: foreign Git/cwd, fake процесс сохраняет argv/cwd без запуска игры.
        Ожидаемый результат: свой проект и прежние180 кадров; это не нативный/FPS допуск.
        """
        with tempfile.TemporaryDirectory(prefix='smoke shell context ') as directory:
            parent = Path(directory).resolve()
            foreign = self.repository(parent / 'foreign', 'wrong smoke project')
            fake, witness = parent / 'fake Godot', parent / 'witness.json'
            fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\n'
                'Path(os.environ["FARM_SMOKE_WITNESS"]).write_text(json.dumps({"cwd":os.getcwd(),"argv":sys.argv[1:]}))\n'
                'print("isolated fake-engine witness only")\n')
            fake.chmod(0o755)
            with self.foreign_context(foreign):
                environment = dict(os.environ, FARM_GODOT_BIN=str(fake), FARM_SMOKE_WITNESS=str(witness))
                result = subprocess.run(['zsh', str(gate.ROOT / 'tools/smoke_test.sh')],
                    cwd=foreign, env=environment, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                data = json.loads(witness.read_text())
                self.assertEqual(Path(data['cwd']).resolve(), gate.ROOT.resolve())
                self.assertEqual(data['argv'], ['--headless', '--path', '.', '--quit-after', '180', '--', '--autoplay'])


if __name__ == '__main__':
    unittest.main()
