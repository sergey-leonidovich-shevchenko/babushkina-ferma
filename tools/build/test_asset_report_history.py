"""Проверяет настоящую Git-историю происхождения без замораживания текущих игровых ресурсов."""

from copy import deepcopy
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.assets.contracts.asset_report import working_reader
from tools.assets.contracts.asset_costs import origin
from tools.common.git import git_environment


def git(root, *arguments):
    """Меняет и читает только собственный временный Git, очищая унаследованный контекст."""
    return subprocess.check_output(["git", *arguments], cwd=root, env=git_environment(), stderr=subprocess.PIPE)


def repository(root, source):
    """Создаёт маленькую самостоятельную историю с одним генератором и одним текущим ресурсом."""
    (root / "tools").mkdir(parents=True)
    (root / "tools/generator.py").write_bytes(source)
    (root / "assets/game").mkdir(parents=True)
    (root / "assets/game/a.png").write_bytes(b"original live media")
    git(root, "init", "--template=", "-q")
    git(root, "add", ".")
    git(root, "-c", "user.name=Codex QA", "-c", "user.email=qa@example.invalid",
        "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture")
    return git(root, "rev-parse", "HEAD").decode().strip()


class HistoricalEvidenceTests(unittest.TestCase):
    """Отделяет неизменное свидетельство генерации от живых файлов и чужих worktree/index/config."""

    def setUp(self):
        """Готовит только собственный Git с пробелами в пути; cleanup действует и после отказа."""
        self.temporary = tempfile.TemporaryDirectory(prefix="asset evidence history ")
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.root = self.folder / "repository with spaces"
        self.original = b"# original generator\n"
        self.commit = repository(self.root, self.original)
        self.rules = {
            "rules": [{"id": "fixture", "paths": ["assets/game/a.png"],
                       "asset_sha256": {"assets/game/a.png": hashlib.sha256(b"original live media").hexdigest()},
                       "kind": "documented-fixture", "claim": "fixture", "license_status": "reference-only",
                       "evidence": ["tools/generator.py"]}],
            "evidence_history": {"tools/generator.py": {
                "commit": self.commit, "sha256": hashlib.sha256(self.original).hexdigest()}},
        }

    # Сценарий: генератор перемещён и его адресные строки изменены.
    # Исходное состояние: точная прежняя версия в самостоятельном Git.
    # Ожидаемый результат: возвращаются именно закреплённые байты, а не новый файл.
    def test_real_rename_preserves_original_evidence(self):
        (self.root / "tools/package").mkdir()
        git(self.root, "mv", "tools/generator.py", "tools/package/generator.py")
        (self.root / "tools/package/generator.py").write_bytes(b"# relocated generator\n")
        self.assertEqual(working_reader(self.root, self.rules)("tools/generator.py"), self.original)

    # Сценарий: текущий рисунок изменён при прежнем доказательстве генератора.
    # Исходное состояние: существующий reader и точное правило исходных байтов.
    # Ожидаемый результат: live-чтение видит изменение, а прежнее правило его отвергает.
    def test_media_remains_live_and_changed_bytes_fail(self):
        read = working_reader(self.root, self.rules)
        self.assertEqual(read("assets/game/a.png"), b"original live media")
        (self.root / "assets/game/a.png").write_bytes(b"changed live media")
        self.assertEqual(read("assets/game/a.png"), b"changed live media")
        with self.assertRaisesRegex(ValueError, "reviewed bytes"):
            origin("assets/game/a.png", read("assets/game/a.png"), self.rules, read)

    # Сценарий: указанный commit отсутствует, хотя текущий генератор доступен.
    # Исходное состояние: корректная форма полного SHA и намеренно несуществующая история.
    # Ожидаемый результат: текущий файл не подменяет недоступное свидетельство.
    def test_missing_history_has_no_live_fallback(self):
        rules = deepcopy(self.rules)
        rules["evidence_history"]["tools/generator.py"]["commit"] = "0" * 40
        with self.assertRaises(ValueError):
            working_reader(self.root, rules)("tools/generator.py")

    # Сценарий: commit существует, ожидаемая подпись неверна.
    # Исходное состояние: сохранённый настоящий исходник и чужой SHA256.
    # Ожидаемый результат: неподходящие байты отклоняются.
    def test_wrong_digest_fails(self):
        rules = deepcopy(self.rules)
        rules["evidence_history"]["tools/generator.py"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "SHA256"):
            working_reader(self.root, rules)("tools/generator.py")

    # Сценарий: metadata пытается закрепить медиа, внешний путь или неполный дескриптор.
    # Исходное состояние: реальные правила и девять отдельных повреждений.
    # Ожидаемый результат: каждый неверный якорь отвергается до чтения источников.
    def test_malformed_pins_fail(self):
        original = self.rules["evidence_history"]["tools/generator.py"]
        variants = [[], {"tools/generator.py": {"commit": "HEAD", "sha256": original["sha256"]}},
                    {"tools/generator.py": {"commit": self.commit, "sha256": "bad"}},
                    {"tools/generator.py": {**original, "extra": True}},
                    {"tools/../generator.py": original}, {"assets/game/a.png": original},
                    {"tools//generator.py": original}, {"tools/unknown.py": original},
                    {"tools/generator.py": {"commit": self.commit}}]
        for variant in variants:
            with self.subTest(variant=variant), self.assertRaises(ValueError):
                working_reader(self.root, {**self.rules, "evidence_history": variant})

    # Сценарий: старое имя стало symlink за границу проекта.
    # Исходное состояние: собственный внешний файл и существующая Git-история.
    # Ожидаемый результат: исходная защита ссылок сохраняется.
    def test_symlink_is_rejected(self):
        outside = self.folder / "outside.py"
        outside.write_bytes(self.original)
        (self.root / "tools/generator.py").unlink()
        (self.root / "tools/generator.py").symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "unsafe"):
            working_reader(self.root, self.rules)("tools/generator.py")

    # Сценарий: вложенная папка не имеет собственного Git.
    # Исходное состояние: доступная история родителя с тем же именем файла.
    # Ожидаемый результат: reader не заимствует репозиторий родителя.
    def test_parent_repository_is_not_borrowed(self):
        nested = self.root / "nested"
        nested.mkdir()
        with self.assertRaises(ValueError):
            working_reader(nested, self.rules)

    # Сценарий: унаследованы чужие Git directory/worktree/index/config overrides.
    # Исходное состояние: два реальных репозитория, другая текущая версия исходника и alternate index.
    # Ожидаемый результат: читается нужная история; чужие config/index и окружение прежние.
    def test_foreign_git_context_is_ignored(self):
        foreign = self.folder / "foreign repository"
        repository(foreign, b"# foreign generator\n")
        alternate = self.folder / "alternate index"
        shutil.copy2(foreign / ".git/index", alternate)
        (self.root / "tools/generator.py").write_bytes(b"# current differs\n")
        tracked = [self.root / ".git/config", self.root / ".git/index", foreign / ".git/config", foreign / ".git/index", alternate]
        before = {str(path): path.read_bytes() for path in tracked}
        environment = dict(os.environ)
        with patch.dict(os.environ, {"GIT_DIR": str(foreign / ".git"), "GIT_WORK_TREE": str(foreign),
                                     "GIT_INDEX_FILE": str(alternate), "GIT_CONFIG_COUNT": "1",
                                     "GIT_CONFIG_KEY_0": "core.bare", "GIT_CONFIG_VALUE_0": "true"}):
            self.assertEqual(working_reader(self.root, self.rules)("tools/generator.py"), self.original)
        self.assertEqual(dict(os.environ), environment)
        self.assertEqual({str(path): path.read_bytes() for path in tracked}, before)

    # Сценарий: вызывающий код меняет исходный dict уже после создания reader.
    # Исходное состояние: нормальный snapshot якорей и новая текущая версия файла.
    # Ожидаемый результат: привязка не меняется через общий mutable dict.
    def test_pin_snapshot_is_not_mutable(self):
        read = working_reader(self.root, self.rules)
        self.rules["evidence_history"]["tools/generator.py"]["commit"] = "0" * 40
        (self.root / "tools/generator.py").write_bytes(b"# current differs\n")
        self.assertEqual(read("tools/generator.py"), self.original)

    # Сценарий: обычное чтение не объявляет исторических якорей.
    # Исходное состояние: отдельная папка без .git и свой файл.
    # Ожидаемый результат: существующий Gitless-контракт live-чтения сохраняется.
    def test_live_only_reader_needs_no_git(self):
        folder = self.folder / "no git"
        folder.mkdir()
        (folder / "a.txt").write_bytes(b"live")
        self.assertEqual(working_reader(folder)("a.txt"), b"live")

    # Сценарий: старый генератор отсутствует и явного якоря нет.
    # Исходное состояние: файл удалён только в disposable fixture.
    # Ожидаемый результат: общий fallback не скрывает отсутствие источника.
    def test_missing_unpinned_input_is_not_hidden(self):
        (self.root / "tools/generator.py").unlink()
        with self.assertRaises(FileNotFoundError):
            working_reader(self.root)("tools/generator.py")


if __name__ == "__main__":
    unittest.main()
