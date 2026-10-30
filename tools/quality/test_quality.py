"""Проверяет реальные отказы выбора файлов, формата, lint, типов и анализатора Godot."""

from __future__ import annotations

import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.assets.migration import migration_fixture as fixture
from tools.common.git import git_environment
from tools.common.paths import project_root
from tools.quality.check import tools
from tools.quality.fixture_validation import validate
from tools.quality.godot import IGNORE, analyze_project, configuration, mirror
from tools.quality.selection import BASELINE, baseline, discover, selected, sha

ROOT = project_root(__file__)


class SelectionTests(unittest.TestCase):
    """Проверяет настоящий index и вложенные файлы, скрытые правилами Git ignore."""

    def setUp(self) -> None:
        """Создаёт собственный временный Git-проект для каждого сценария."""
        self.temporary = tempfile.TemporaryDirectory(prefix="farm quality selection ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        subprocess.run(["git", "init", "-q", str(self.root)], env=git_environment(), check=True)
        (self.root / "tools/quality/nested").mkdir(parents=True)
        self.source = self.root / "tools/quality/nested/new.py"
        self.source.write_text("value: int = 3\n")

    ## Сценарий: найти скрытый новый файл и проверять целиком изменённый старый.
    ## Исходное состояние: Git ignore скрывает tools, а baseline знает прежние байты одного файла.
    ## Ожидаемый результат: новый файл найден; изменение одного байта снимает исключение со всего файла.
    def test_ignored_nested_file_and_full_changed_legacy_are_selected(self) -> None:
        (self.root / ".gitignore").write_text("tools/\n")
        self.assertIn("tools/quality/nested/new.py", discover(self.root))
        legacy = {"tools/quality/nested/new.py": sha(self.source)}
        self.assertEqual(selected(self.root, legacy), [])
        self.source.write_text(self.source.read_text() + "broken: int = 'wrong'\n")
        self.assertEqual(selected(self.root, legacy), ["tools/quality/nested/new.py"])

    ## Сценарий: читать собственный index при чужих переменных Git.
    ## Исходное состояние: есть отдельный чужой репозиторий и один свой staged-файл.
    ## Ожидаемый результат: выбран свой исходник; чужой config и окружение не изменились.
    def test_index_and_untracked_sources_ignore_foreign_git_variables(self) -> None:
        other = self.root / "foreign"
        subprocess.run(["git", "init", "-q", str(other)], env=git_environment(), check=True)
        (self.root / "tracked.py").write_text("n: int = 1\n")
        subprocess.run(
            ["git", "-C", str(self.root), "add", "tracked.py"],
            env=git_environment(),
            check=True,
        )
        config = (other / ".git/config").read_bytes()
        overrides = {"GIT_DIR": str(other / ".git"), "GIT_WORK_TREE": str(other)}
        with patch.dict(os.environ, overrides):
            before = dict(os.environ)
            self.assertIn("tracked.py", selected(self.root, {}))
            self.assertEqual(dict(os.environ), before)
        self.assertEqual((other / ".git/config").read_bytes(), config)

    ## Сценарий: сохранить исторический отчёт и включить новый вложенный исходник.
    ## Исходное состояние: временный проект содержит frozen proof и новый инструмент.
    ## Ожидаемый результат: proof исключён из форматирования; новый инструмент выбран.
    def test_frozen_report_is_not_formatted_but_new_source_is_checked(self) -> None:
        report = self.root / "docs/reports/old"
        report.mkdir(parents=True)
        (report / "proof.py").write_text("frozen   =   1\n")
        self.assertNotIn("docs/reports/old/proof.py", discover(self.root))
        self.assertIn("tools/quality/nested/new.py", selected(self.root, {}))

    ## Сценарий: отклонить подмену baseline и ссылку вместо исходника.
    ## Исходное состояние: скопирован точный baseline, затем изменены его байты и создан symlink.
    ## Ожидаемый результат: оба нарушения дают явный отказ без принятия чужого файла.
    def test_baseline_extension_and_file_symlinks_are_rejected(self) -> None:
        destination = self.root / BASELINE
        destination.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / BASELINE, destination)
        self.assertTrue(baseline(self.root))
        destination.write_text(destination.read_text() + "\n")
        with self.assertRaisesRegex(ValueError, "baseline differs"):
            baseline(self.root)
        self.source.unlink()
        self.source.symlink_to(self.root / "missing.py")
        with self.assertRaisesRegex(ValueError, "regular file"):
            selected(self.root, {})

    ## Сценарий: отклонить ссылку вместо каталога исходников.
    ## Исходное состояние: вложенный пакет ссылается на другой существующий каталог.
    ## Ожидаемый результат: обход прекращается с понятной ошибкой.
    def test_external_directory_symlink_is_rejected(self) -> None:
        (self.root / "foreign").mkdir()
        (self.root / "tools/quality/linked").symlink_to(
            self.root / "foreign", target_is_directory=True
        )
        with self.assertRaisesRegex(ValueError, "directory must not be a symlink"):
            discover(self.root)

    ## Сценарий: защитить checkout и непустую цель при прямом вызове helper.
    ## Исходное состояние: есть свой тестовый checkout, архив VERSION и чужая папка с sentinel.
    ## Ожидаемый результат: запись отклонена; пустая внешняя копия с ресурсом VERSION работает.
    def test_semantic_helpers_cannot_write_to_checkout_or_existing_directory(self) -> None:
        before = self.source.read_bytes()
        with self.assertRaisesRegex(ValueError, "empty external directory"):
            mirror(self.root, self.root, ["tools/quality/nested/new.py"], {})
        with self.assertRaisesRegex(ValueError, "isolated copy"):
            configuration(self.root)
        self.assertFalse((self.root / "override.cfg").exists())
        self.assertEqual(self.source.read_bytes(), before)
        archive = self.root / "source archive"
        archive.mkdir()
        (archive / "VERSION").write_text("source archive\n")
        with self.assertRaisesRegex(ValueError, "isolated copy"):
            configuration(archive)
        self.assertFalse((archive / "override.cfg").exists())
        with tempfile.TemporaryDirectory(prefix="farm existing semantic destination ") as t:
            external = Path(t)
            (external / "sentinel").write_bytes(b"preserve")
            with self.assertRaisesRegex(ValueError, "empty external directory"):
                mirror(self.root, external, [], {})
            self.assertEqual((external / "sentinel").read_bytes(), b"preserve")
        (self.root / "VERSION").write_text("preserved version resource\n")
        (self.root / "project.godot").write_text("config_version=5\n")
        (self.root / "scripts").mkdir()
        (self.root / "scripts/probe.gd").write_text(
            'extends RefCounted\nconst VERSION_PATH: String = "res://VERSION"\n'
        )
        with tempfile.TemporaryDirectory(prefix="farm owned versioned mirror ") as t:
            external = Path(t)
            mirror(self.root, external, ["scripts/probe.gd"], {})
            self.assertEqual(
                (external / "VERSION").read_bytes(), (self.root / "VERSION").read_bytes()
            )
            self.assertTrue((external / "override.cfg").is_file())


class ToolTests(unittest.TestCase):
    """Запускает установленные инструменты и настоящий Godot на своих одноразовых исходниках."""

    ## Сценарий: отклонить настоящие ошибки формата, lint и типов Python.
    ## Исходное состояние: три временных исходника содержат разные нарушения.
    ## Ожидаемый результат: check не меняет файлы; корректный файл после явного fix проходит.
    def test_python_format_lint_and_type_errors_fail_and_fixed_file_passes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="farm quality Python ") as temporary:
            root = Path(temporary)
            shutil.copyfile(ROOT / "pyproject.toml", root / "pyproject.toml")
            path = root / "probe.py"
            cases = (
                "value:int=1\n",
                "import os\n\nvalue: int = 1\n",
                'value: int = "wrong"\n',
            )
            for source in cases:
                with self.subTest(source=source):
                    path.write_text(source)
                    before = path.read_bytes()
                    self.assertGreater(tools(root, ["probe.py"]), 0)
                    self.assertEqual(path.read_bytes(), before)
            path.write_text("value:int=1\n")
            self.assertEqual(tools(root, ["probe.py"], fix=True), 0)
            self.assertEqual(tools(root, ["probe.py"]), 0)

    ## Сценарий: проверить формат и имена настоящими GDScript-инструментами.
    ## Исходное состояние: временный файл не отформатирован, затем задано плохое имя функции.
    ## Ожидаемый результат: gdformat исправляет свой файл, а gdlint отклоняет плохое имя.
    def test_gdformat_and_gdlint_real_negative_controls(self) -> None:
        executable = Path(sys.executable).parent
        with tempfile.TemporaryDirectory(prefix="farm quality GD style ") as temporary:
            path = Path(temporary) / "probe.gd"
            path.write_text("extends RefCounted\nfunc value()->int:return 3\n")
            checks = (
                (["gdformat", "--check"], 1),
                (["gdformat"], 0),
                (["gdformat", "--check"], 0),
            )
            for arguments, expected in checks:
                result = subprocess.run(
                    [str(executable / arguments[0]), *arguments[1:], str(path)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
            path.write_text("extends RefCounted\n\n\nfunc BAD_NAME() -> int:\n\treturn 3\n")
            result = subprocess.run(
                [str(executable / "gdlint"), str(path)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    ## Сценарий: поймать реальные ошибки Godot и изолировать статическую инициализацию.
    ## Исходное состояние: есть корректный файл, три ошибки и запись из статического метода.
    ## Ожидаемый результат: ошибки отклонены; статический файл остаётся в temp, игровая инициализация не вызвана.
    def test_real_godot_semantics_strict_warnings_and_static_initializer_isolation(self) -> None:
        engine = os.environ.get("FARM_GODOT_BIN")
        self.assertIsNotNone(
            engine, "FARM_GODOT_BIN is required; semantic tests cannot silently skip"
        )
        assert engine is not None
        cases = {
            "good": "func value(x: int) -> int:\n\treturn x\n",
            "semantic": 'func value() -> int:\n\treturn "wrong"\n',
            "untyped": "func value(x) -> int:\n\treturn int(x)\n",
            "unsafe": "func value(x: Variant) -> void:\n\tx.nonexistent()\n",
        }
        for name, body in cases.items():
            with (
                self.subTest(case=name),
                tempfile.TemporaryDirectory(prefix="farm quality Godot ") as t,
            ):
                root = Path(t)
                (root / "project.godot").write_text("config_version=5\n")
                (root / "base.gd").write_text(
                    IGNORE + "extends SceneTree\nfunc old(x):\n\treturn x\n"
                )
                source = 'extends "res://base.gd"\n\n' + body
                (root / "probe.gd").write_text(source)
                with contextlib.redirect_stdout(io.StringIO()):
                    result = analyze_project(root, ["probe.gd"], engine)
                self.assertEqual(result == 0, name == "good")
                self.assertEqual((root / "probe.gd").read_text(), source)
        with tempfile.TemporaryDirectory(prefix="farm quality static ") as t:
            root = Path(t)
            (root / "project.godot").write_text("config_version=5\n")
            (root / "probe.gd").write_text(
                "extends SceneTree\n\nstatic func _static_init() -> void:\n"
                '\tFileAccess.open("res://static-proof", FileAccess.WRITE).store_string("ran")\n'
                '\nfunc _initialize() -> void:\n\tFileAccess.open("res://runtime-proof", FileAccess.WRITE)\n'
            )
            self.assertEqual(analyze_project(root, ["probe.gd"], engine), 0)
            self.assertTrue((root / "static-proof").exists())
            self.assertFalse((root / "runtime-proof").exists())

    ## Сценарий: не допустить выход ресурса за границы временного mirror.
    ## Исходное состояние: передан путь с переходом к родительскому каталогу.
    ## Ожидаемый результат: копирование отклонено до записи файлов.
    def test_mirror_rejects_absolute_or_traversal_resource_names(self) -> None:
        with tempfile.TemporaryDirectory(prefix="farm quality mirror ") as t:
            with self.assertRaisesRegex(ValueError, "non-canonical"):
                mirror(ROOT, Path(t), ["../foreign.gd"], {})

    ## Сценарий: обнаружить сломанный namespace и URI результата настоящего генератора.
    ## Исходное состояние: create создал внешний проект, затем изменены коллектор и путь черновика.
    ## Ожидаемый результат: целый проект проходит, каждая отдельная порча отклоняется.
    def test_real_producer_namespace_and_resource_regressions_are_detected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="farm quality actual producer ") as t:
            target = Path(t) / "new project"
            fixture.create(ROOT, target)
            self.assertTrue(validate(target, ROOT))
            capture = target / "tools/migration_capture.gd"
            capture.rename(target / "tools/stale_capture.gd")
            with self.assertRaisesRegex(ValueError, "namespace differs"):
                validate(target, ROOT)
            (target / "tools/stale_capture.gd").rename(capture)
            draft = json.loads((target / "saved-draft.json").read_text())
            draft["objects"][0]["asset_path"] = "res://stale-path.png"
            (target / "saved-draft.json").write_text(json.dumps(draft))
            with self.assertRaisesRegex(ValueError, "URIs differ"):
                validate(target, ROOT)


if __name__ == "__main__":
    unittest.main()
