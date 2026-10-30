"""Проверяет настоящий Git index и pre-commit без запуска Game и без изменения чужих данных."""

from __future__ import annotations

import contextlib
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.common.git import git_environment
from tools.common.paths import project_root
from tools.quality.index import matching_sources
from tools.quality.selection import BASELINE, baseline, selected

ROOT = project_root(__file__)


class IndexTests(unittest.TestCase):
    """Создаёт отдельный репозиторий с пробелами и проверяет сырые staged/working байты."""

    def setUp(self) -> None:
        """Готовит настоящий index и собственный коммит, отключая унаследованные Git overrides."""
        self.temporary = tempfile.TemporaryDirectory(prefix="farm quality index ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.env = git_environment()
        self.env["PYTHONDONTWRITEBYTECODE"] = "1"
        self.env["PATH"] = str(Path(sys.executable).parent) + os.pathsep + self.env["PATH"]
        self.git("init", "-q")
        self.git("config", "user.name", "Quality index test")
        self.git("config", "user.email", "quality@example.invalid")
        self.git("config", "core.hooksPath", ".githooks")
        self.source = self.root / "probe.py"
        self.source.write_text("value: int = 3\n")
        self.git("add", "probe.py")
        self.git("commit", "-qm", "owned fixture")

    def git(self, *arguments: str) -> bytes:
        """Вызывает реальный Git только внутри собственного временного репозитория."""
        return subprocess.check_output(
            ["git", "-C", str(self.root), *arguments], env=self.env, stderr=subprocess.PIPE
        )

    def state(self) -> dict[str, bytes]:
        """Сохраняет config/index, рабочие данные и HEAD для точного сравнения после отказа."""
        names = [name for name in self.root.rglob("*") if name.is_file()]
        return {
            path.relative_to(self.root).as_posix(): path.read_bytes()
            for path in names
            if not path.relative_to(self.root).as_posix().startswith(".git/objects/")
        }

    def guard(self) -> list[str]:
        """Передаёт намеренный index, сохраняя исходное окружение процесса тестов."""
        with patch.dict(os.environ, self.env, clear=True):
            before = dict(os.environ)
            try:
                return matching_sources(self.root)
            finally:
                self.assertEqual(dict(os.environ), before)

    def install_hook(self) -> None:
        """Копирует настоящий gate/hook/bump; после bump останавливает тест до Game."""
        names = [
            "tools/run.py",
            "tools/__init__.py",
            "tools/bump_version.py",
            "tools/planning/__init__.py",
            "tools/planning/bump_version.py",
            "tools/common/__init__.py",
            "tools/common/paths.py",
            "tools/common/git.py",
            "tools/common/launch.py",
            "tools/quality/__init__.py",
            "tools/quality/check.py",
            "tools/quality/index.py",
            "tools/quality/selection.py",
            "tools/quality/process.py",
            "tools/quality/godot.py",
            "tools/quality/requirements.txt",
            BASELINE,
            "pyproject.toml",
            ".gdlintrc",
            ".githooks/pre-commit",
            "VERSION",
            "project.godot",
            "Бабушкина ферма.app/Contents/Info.plist",
        ]
        for name in names:
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, destination)
        boundary = self.root / "tools/check_architecture.sh"
        boundary.write_text("#!/bin/zsh\nprint 'QUALITY TEST BOUNDARY: after real bump'\nexit 23\n")
        boundary.chmod(0o755)
        self.git("add", ".")
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "install actual gate")

    def commit_hook(self) -> subprocess.CompletedProcess[str]:
        """Выполняет настоящий hook на настоящем index, останавливаясь перед Game."""
        return subprocess.run(
            [str(self.root / ".githooks/pre-commit")],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=90,
            check=False,
        )

    ## Сценарий: ошибочный staged-файл скрыт исправленной рабочей копией.
    ## Исходное состояние: настоящий index содержит ошибку типов; cwd содержит корректный Python.
    ## Ожидаемый результат: явный отказ до линтера; файлы, index и config побайтно прежние.
    def test_bad_index_good_working_is_rejected_and_preserved(self) -> None:
        self.source.write_text('value: int = "wrong"\n')
        self.git("add", "probe.py")
        self.source.write_text("value: int = 3\n")
        before = self.state()
        with self.assertRaisesRegex(ValueError, "staged and working.*differ"):
            self.guard()
        self.assertEqual(self.state(), before)

    ## Сценарий: исправление действительно добавлено в index.
    ## Исходное состояние: staged и рабочие байты одинакового корректного нового файла совпадают.
    ## Ожидаемый результат: файл включён в последующую проверку, данные и metadata не меняются.
    def test_matching_index_is_selected_without_mutation(self) -> None:
        self.source.write_text("value: int = 4\n")
        self.git("add", "probe.py")
        before = self.state()
        self.assertIn("probe.py", self.guard())
        self.assertEqual(self.state(), before)

    ## Сценарий: законный отдельный index имеет свой новый скрытый исходник вне обычных корней.
    ## Исходное состояние: основной index прежний; альтернативный содержит ignored-файл с пробелами.
    ## Ожидаемый результат: отказ при разных байтах, затем новый путь проверяется; основной index прежний.
    def test_alternate_index_and_ignored_new_path_are_honored(self) -> None:
        standard = (self.root / ".git/index").read_bytes()
        alternate = self.root / ".git/alternate index"
        alternate.write_bytes(standard)
        self.env["GIT_INDEX_FILE"] = str(alternate)
        (self.root / ".gitignore").write_text("extra/\n")
        extra = self.root / "extra/new source.py"
        extra.parent.mkdir()
        extra.write_text('value: int = "wrong"\n')
        self.git("add", "-f", "extra/new source.py")
        extra.write_text("value: int = 3\n")
        before = self.state()
        with self.assertRaisesRegex(ValueError, "extra/new source.py"):
            self.guard()
        self.assertEqual(self.state(), before)
        self.git("add", "-f", "extra/new source.py")
        self.assertIn("extra/new source.py", self.guard())
        self.assertIn("extra/new source.py", selected(self.root, {}, self.guard()))
        self.assertEqual((self.root / ".git/index").read_bytes(), standard)

    ## Сценарий: staged-удаление, переименование и несовпавшие правила качества.
    ## Исходное состояние: удалённый файл оставлен в cwd, затем удалён полностью; новое имя staged.
    ## Ожидаемый результат: оставшиеся байты и иные правила отклонены; полное удаление/rename разрешены.
    def test_deletion_rename_and_policy_bytes(self) -> None:
        self.git("rm", "--cached", "probe.py")
        with self.assertRaisesRegex(ValueError, "probe.py"):
            self.guard()
        self.source.unlink()
        self.assertEqual(self.guard(), [])
        renamed = self.root / "renamed.py"
        renamed.write_text("value: int = 3\n")
        self.git("add", "renamed.py")
        self.assertEqual(self.guard(), ["renamed.py"])
        policy = self.root / "pyproject.toml"
        policy.write_text("[tool.mypy]\n")
        with self.assertRaisesRegex(ValueError, "pyproject.toml"):
            self.guard()
        self.git("add", "pyproject.toml")
        self.assertEqual(self.guard(), ["renamed.py"])

    ## Сценарий: настоящий hook проверяет staged-ошибку, скрытую исправленным новым файлом.
    ## Исходное состояние: gate/hook и bump настоящие; исходник в index ошибочен, cwd исправлен.
    ## Ожидаемый результат: commit отклонён до bump; версия/index/config/рабочие файлы прежние.
    def test_actual_hook_rejects_partial_staging_before_bump(self) -> None:
        self.install_hook()
        self.source.write_text('value: int = "wrong"\n')
        self.git("add", "probe.py")
        self.source.write_text("value: int = 3\n")
        before = self.state()
        result = self.commit_hook()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("QUALITY INDEX: staged and working", result.stderr)
        self.assertNotIn("QUALITY TEST BOUNDARY", result.stdout)
        self.assertEqual(self.state(), before)

    ## Сценарий: baseline скрывает restored legacy cwd при ошибочном staged legacy blob.
    ## Исходное состояние: настоящий baseline исключает paths.py в cwd, но index содержит его ошибку.
    ## Ожидаемый результат: hook всё равно отклоняет legacy-файл до bump без изменения данных.
    def test_actual_hook_rejects_partial_legacy_before_baseline_filter(self) -> None:
        self.install_hook()
        name = "tools/common/paths.py"
        legacy = self.root / name
        good = legacy.read_bytes()
        self.assertNotIn(name, selected(self.root, baseline(self.root)))
        legacy.write_bytes(good + b'\nbroken: int = "wrong"\n')
        self.git("add", name)
        legacy.write_bytes(good)
        self.assertNotIn(name, selected(self.root, baseline(self.root)))
        before = self.state()
        result = self.commit_hook()
        self.assertIn("QUALITY INDEX: staged and working", result.stderr)
        self.assertIn(name, result.stderr)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("QUALITY TEST BOUNDARY", result.stdout)
        self.assertEqual(self.state(), before)

    ## Сценарий: тот же настоящий hook работает с законным альтернативным index.
    ## Исходное состояние: alternate содержит ошибку, затем исправление; основной index не используется.
    ## Ожидаемый результат: ошибка остановлена до bump; исправление проходит gate и реальный bump.
    def test_actual_hook_alternate_index_bad_then_good(self) -> None:
        self.install_hook()
        index = self.root / ".git/index"
        standard = index.read_bytes()
        alternate = self.root / ".git/alternate index"
        alternate.write_bytes(standard)
        self.env["GIT_INDEX_FILE"] = str(alternate)
        self.source.write_text('value: int = "wrong"\n')
        self.git("add", "probe.py")
        self.source.write_text("value: int = 3\n")
        before = self.state()
        bad = self.commit_hook()
        self.assertIn("QUALITY INDEX: staged and working", bad.stderr)
        self.assertNotEqual(bad.returncode, 0)
        self.assertEqual(self.state(), before)
        self.git("add", "probe.py")
        version = (self.root / "VERSION").read_bytes()
        good = self.commit_hook()
        self.assertIn("QUALITY: 0 failed steps", good.stdout, good.stderr)
        self.assertIn("QUALITY TEST BOUNDARY: after real bump", good.stdout)
        self.assertNotEqual((self.root / "VERSION").read_bytes(), version)
        self.assertEqual(self.git("show", ":VERSION"), (self.root / "VERSION").read_bytes())
        self.assertEqual(index.read_bytes(), standard)

    ## Сценарий: сам git commit вызывает установленный hook на частично добавленном файле.
    ## Исходное состояние: Git может обновить служебный cache index до входа в hook.
    ## Ожидаемый результат: commit отвергнут; staged blobs, HEAD, версия и рабочие байты прежние.
    def test_real_git_commit_rejects_bad_staged_blob(self) -> None:
        self.install_hook()
        self.source.write_text('value: int = "wrong"\n')
        self.git("add", "probe.py")
        self.source.write_text("value: int = 3\n")
        staged = self.git("ls-files", "--stage", "-z")
        before = self.state()
        result = subprocess.run(
            ["git", "-C", str(self.root), "commit", "--allow-empty", "-m", "hook control"],
            cwd=self.root.parent,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=90,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("QUALITY INDEX: staged and working", result.stderr)
        self.assertNotIn("QUALITY TEST BOUNDARY", result.stdout + result.stderr)
        self.assertEqual(self.git("ls-files", "--stage", "-z"), staged)
        after = self.state()
        before.pop(".git/index")
        after.pop(".git/index")
        self.assertEqual(after, before)

    ## Сценарий: полностью исправленный staged-файл проходит настоящий hook до следующего gate.
    ## Исходное состояние: новая версия исходника совпадает с index, bump выполняется штатным кодом.
    ## Ожидаемый результат: Ruff/mypy проходят, версия повышена/staged; Game не запускается.
    def test_actual_hook_matching_staged_source_passes_quality(self) -> None:
        self.install_hook()
        self.source.write_text("value: int = 4\n")
        self.git("add", "probe.py")
        version = (self.root / "VERSION").read_bytes()
        result = self.commit_hook()
        self.assertIn("QUALITY: 0 failed steps", result.stdout, result.stderr)
        self.assertIn("QUALITY TEST BOUNDARY: after real bump", result.stdout)
        self.assertNotEqual((self.root / "VERSION").read_bytes(), version)
        self.assertEqual(self.git("show", ":VERSION"), (self.root / "VERSION").read_bytes())

    ## Сценарий: относительный законный index сохраняется при чужих Git directory/config overrides.
    ## Исходное состояние: есть свой alternate и посторонний репозиторий с отдельными metadata.
    ## Ожидаемый результат: читается свой alternate; обе metadata и окружение побайтно прежние.
    def test_relative_alternate_ignores_other_git_overrides(self) -> None:
        alternate = self.root / ".git/relative index"
        alternate.write_bytes((self.root / ".git/index").read_bytes())
        foreign = self.root / "foreign"
        subprocess.run(["git", "init", "-q", str(foreign)], env=self.env, check=True)
        self.env.update(
            GIT_INDEX_FILE=".git/relative index",
            GIT_DIR=str(foreign / ".git"),
            GIT_WORK_TREE=str(foreign),
            GIT_CONFIG_COUNT="1",
            GIT_CONFIG_KEY_0="core.bare",
            GIT_CONFIG_VALUE_0="true",
        )
        before = self.state()
        with contextlib.chdir(self.root):
            self.assertIn("probe.py", self.guard())
        self.assertEqual(self.state(), before)

    ## Сценарий: запрещено совмещать исправление рабочей копии и staged-режим hook.
    ## Исходное состояние: публичный launcher получает fix --staged на собственном репозитории.
    ## Ожидаемый результат: argparse отказывает до исправлений, версия/index/исходники не меняются.
    def test_staged_fix_is_rejected_without_mutation(self) -> None:
        self.install_hook()
        before = self.state()
        result = subprocess.run(
            [sys.executable, str(self.root / "tools/run.py"), "quality.check", "fix", "--staged"],
            cwd=self.root.parent,
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("--staged is read-only", result.stderr)
        self.assertEqual(self.state(), before)


if __name__ == "__main__":
    unittest.main()
