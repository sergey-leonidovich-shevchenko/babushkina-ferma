"""Проверяет реальный guard tools, владельцев, UID и запуск документированных маршрутов."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.common.paths import project_root
from tools.quality.tool_layout import (
    DOMAIN_OWNERS,
    NAVIGATION_COMMANDS,
    REQUIRED_ROOT_UIDS,
    ROOT_PUBLIC,
    ROOT_UIDS,
    inspect_layout,
)

ROOT = project_root(__file__)


class ToolLayoutTests(unittest.TestCase):
    """Создаёт только disposable layout; настоящий checkout проверяется read-only."""

    def setUp(self) -> None:
        """Создаёт минимальный допустимый проект со всеми root exceptions и доменами."""
        self.temporary = tempfile.TemporaryDirectory(prefix="farm tool layout ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        tools = self.root / "tools"
        tools.mkdir()
        for name in ROOT_PUBLIC:
            path = tools / name
            if path.suffix == ".gd":
                path.write_text("extends RefCounted\n", encoding="utf-8")
            elif path.suffix == ".sh":
                path.write_text("#!/bin/zsh\n", encoding="utf-8")
            else:
                path.write_text("VALUE = 1\n", encoding="utf-8")
        for uid in ROOT_UIDS:
            (tools / uid).write_text("uid://fixture\n", encoding="utf-8")
        for domain in DOMAIN_OWNERS:
            (tools / domain).mkdir()
        readme = ["# Fixture"]
        readme.extend(f"`tools/{name}`" for name in ROOT_PUBLIC)
        readme.extend(f"| `{domain}` | owner |" for domain in DOMAIN_OWNERS)
        readme.extend(f"`{command}`" for command in NAVIGATION_COMMANDS)
        (tools / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8")

    ## Сценарий: проверить принятую main без записи файлов и без полного frozen snapshot.
    ## Исходное состояние: 11 root source, два root UID и семь владельческих доменов.
    ## Ожидаемый результат: ошибок нет; лимит и динамическое правило явно записаны.
    def test_current_checkout_has_documented_root_and_owned_domains(self) -> None:
        report = inspect_layout(ROOT)
        self.assertEqual(report["errors"], [])
        self.assertEqual(report["root"]["source_count"], len(ROOT_PUBLIC))
        self.assertGreaterEqual(report["root"]["uid_count"], len(REQUIRED_ROOT_UIDS))
        self.assertLessEqual(report["root"]["uid_count"], len(ROOT_UIDS))
        self.assertEqual({row["name"] for row in report["domains"]}, set(DOMAIN_OWNERS))
        self.assertFalse(report["policy"]["whole_repository_snapshot_pinned"])

    ## Сценарий: проверить layout сразу после чистого Git checkout до импорта Godot.
    ## Исходное состояние: локальный water UID ещё не создан, tracked sampler UID присутствует.
    ## Ожидаемый результат: guard принимает честный Git-срез и не требует generated sidecar.
    def test_clean_checkout_does_not_require_generated_root_uid(self) -> None:
        optional = next(uid for uid in ROOT_UIDS if uid not in REQUIRED_ROOT_UIDS)
        (self.root / "tools" / optional).unlink()
        report = inspect_layout(self.root)
        self.assertEqual(report["errors"], [])
        self.assertEqual(report["root"]["uid_count"], len(REQUIRED_ROOT_UIDS))

    ## Сценарий: добавить новый внутренний инструмент в правильный домен.
    ## Исходное состояние: допустимый fixture не содержит имени будущего nested-файла.
    ## Ожидаемый результат: guard принимает файл без расширения root allowlist.
    def test_new_nested_source_in_owned_domain_does_not_need_snapshot_update(self) -> None:
        path = self.root / "tools/qa/new_family/probe.py"
        path.parent.mkdir()
        path.write_text("VALUE = 2\n", encoding="utf-8")
        report = inspect_layout(self.root)
        self.assertEqual(report["errors"], [])
        qa = next(row for row in report["domains"] if row["name"] == "qa")
        self.assertIn("tools/qa/new_family/probe.py", qa["sources"])

    ## Сценарий: положить новый внутренний инструмент прямо в корень tools.
    ## Исходное состояние: корневой набор полностью документирован и ниже бюджета.
    ## Ожидаемый результат: неизвестный root source отклонён даже до достижения лимита30.
    def test_new_internal_root_tool_is_rejected(self) -> None:
        (self.root / "tools/internal_probe.py").write_text("VALUE = 3\n", encoding="utf-8")
        errors = inspect_layout(self.root)["errors"]
        self.assertTrue(any("internal_probe.py" in error for error in errors), errors)

    ## Сценарий: проверить отдельные границы бюджета и владельческого домена.
    ## Исходное состояние: неизвестный каталог и20 дополнительных root source.
    ## Ожидаемый результат: guard сообщает и владельца, и честное превышение11+20>30.
    def test_unknown_domain_and_root_budget_are_reported_separately(self) -> None:
        unknown = self.root / "tools/misc/probe.py"
        unknown.parent.mkdir()
        unknown.write_text("VALUE = 4\n", encoding="utf-8")
        for index in range(20):
            (self.root / f"tools/extra_{index}.py").write_text("VALUE = 5\n", encoding="utf-8")
        errors = inspect_layout(self.root)["errors"]
        self.assertTrue(any("нет владельческого домена" in error for error in errors), errors)
        self.assertTrue(any("31 исходников" in error for error in errors), errors)

    ## Сценарий: учитывать UID отдельно от исходников и требовать реальную пару.
    ## Исходное состояние: один root UID удалён, а nested UID создан без .gd.
    ## Ожидаемый результат: оба нарушения видны; UID не раздувает source budget.
    def test_uid_requires_source_and_does_not_hide_in_source_count(self) -> None:
        missing = next(iter(REQUIRED_ROOT_UIDS))
        (self.root / "tools" / missing).unlink()
        orphan = self.root / "tools/qa/orphan.gd.uid"
        orphan.write_text("uid://orphan\n", encoding="utf-8")
        report = inspect_layout(self.root)
        self.assertEqual(report["root"]["source_count"], len(ROOT_PUBLIC))
        self.assertTrue(any(missing in error for error in report["errors"]), report["errors"])
        self.assertTrue(
            any("orphan.gd.uid" in error for error in report["errors"]), report["errors"]
        )

    ## Сценарий: не разрешить исходнику или пакету выйти через symlink.
    ## Исходное состояние: допустимый домен содержит link на внешний Python и linked directory.
    ## Ожидаемый результат: оба пути отклонены, внешний файл не исполняется.
    def test_source_and_directory_symlinks_are_rejected(self) -> None:
        outside = self.root / "outside.py"
        outside.write_text("raise RuntimeError('must not run')\n", encoding="utf-8")
        (self.root / "tools/qa/escape.py").symlink_to(outside)
        foreign = self.root / "foreign"
        foreign.mkdir()
        (self.root / "tools/qa/linked").symlink_to(foreign, target_is_directory=True)
        errors = inspect_layout(self.root)["errors"]
        self.assertTrue(
            any("escape.py" in error and "symlink" in error for error in errors), errors
        )
        self.assertTrue(
            any("qa/linked" in error and "symlink" in error for error in errors), errors
        )

    ## Сценарий: закрыть чтение каталога с внутренним исходником.
    ## Исходное состояние: допустимый qa-домен содержит Python-файл, но его папка chmod000.
    ## Ожидаемый результат: inventory отказывает fail-closed, а не теряет путь молча.
    def test_unreadable_directory_is_rejected_instead_of_skipped(self) -> None:
        unreadable = self.root / "tools/qa/closed"
        unreadable.mkdir()
        (unreadable / "hidden.py").write_text("VALUE = 6\n", encoding="utf-8")
        unreadable.chmod(0)
        try:
            errors = inspect_layout(self.root)["errors"]
        finally:
            unreadable.chmod(0o700)
        self.assertTrue(
            any(
                "недоступен для полного обхода" in error and "qa/closed" in error
                for error in errors
            ),
            errors,
        )

    ## Сценарий: запустить три маршрута навигации из корня и чужой cwd.
    ## Исходное состояние: общий guard выполняется, foliage/atlas дают безопасный --help.
    ## Ожидаемый результат: один launcher находит свой проект в обеих cwd и возвращает0.
    def test_documented_routes_run_from_project_and_foreign_cwd(self) -> None:
        commands = (
            ("quality.tool_layout", "--json"),
            ("qa.foliage.foliage_root_verify", "--help"),
            ("assets.authoring.build_forest_tree_atlas", "--help"),
        )
        with tempfile.TemporaryDirectory(prefix="farm tool routes ") as temporary:
            for cwd in (ROOT, Path(temporary)):
                for command in commands:
                    with self.subTest(cwd=cwd, command=command):
                        launcher = "tools/run.py" if cwd == ROOT else str(ROOT / "tools/run.py")
                        result = subprocess.run(
                            [sys.executable, launcher, *command],
                            cwd=cwd,
                            capture_output=True,
                            text=True,
                            check=False,
                        )
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        if command[0] == "quality.tool_layout":
                            self.assertEqual(json.loads(result.stdout)["errors"], [])


if __name__ == "__main__":
    unittest.main()
