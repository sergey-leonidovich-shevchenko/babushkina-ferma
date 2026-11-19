"""Проверяет реальные Git-исходники, границы инструментации и новые внешние пути."""

from __future__ import annotations

import ast
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from tools.qa.world.shadows.contract import (
    MESH_FILES,
    ROOT,
    RUNTIME,
    SOURCES,
    fresh_output,
    git,
    head,
    instrument,
)


class ContactContractTests(unittest.TestCase):
    """Повреждения ограничены копиями настоящих функций, рабочие исходники не меняются."""

    def test_all_real_owners_are_instrumented_once(self) -> None:
        """Прибор вставляется во все семь владельцев, остальные байты сохраняются."""
        for name in SOURCES:
            with self.subTest(name=name):
                source = git("show", "HEAD:" + name)
                result = instrument(name, source)
                self.assertNotEqual(source, result)
                self.assertEqual(
                    result.count(b'preload("res://tools/qa/world/shadows/contact_probe.gd")'), 1
                )

    def test_lamp_glow_is_not_a_shadow(self) -> None:
        """В настоящем фонаре два mesh-вызова: световой обязан остаться побайтно прежним."""
        name = "scripts/presentation/village_lamp_visual.gd"
        source = git("show", "HEAD:" + name)
        marker = b"static func draw_glow("
        original_glow = source[source.index(marker) :]
        result = instrument(name, source)
        self.assertEqual(original_glow, result[result.index(marker) :])
        self.assertIn(b"canvas.draw_mesh(", original_glow)

    def test_missing_ambiguous_and_unknown_owners_fail(self) -> None:
        """Изменённый контракт реальной функции не проходит по совпадению имени файла."""
        name = MESH_FILES[0]
        source = git("show", "HEAD:" + name)
        for broken in (
            source.replace(b"canvas.draw_mesh(", b"canvas.draw_circle("),
            source.replace(
                b"\tcanvas.draw_mesh(", b"\tcanvas.draw_mesh(null)\n\tcanvas.draw_mesh("
            ),
        ):
            with self.subTest(broken=broken[-40:]), self.assertRaises(ValueError):
                instrument(name, broken)
        with self.assertRaises(ValueError):
            instrument("scripts/future_shadow.gd", source)

    def test_fresh_external_path_and_existing_targets(self) -> None:
        """Настоящий новый каталог создаётся один раз; файл и прежний вывод не заменяются."""
        with tempfile.TemporaryDirectory(prefix="shadow path ") as temporary:
            root = Path(temporary).resolve()
            output = root / "new frames"
            self.assertEqual(fresh_output(output), output)
            (output / "keep").write_bytes(b"unchanged")
            with self.assertRaises(ValueError):
                fresh_output(output)
            self.assertEqual((output / "keep").read_bytes(), b"unchanged")
            file = root / "file"
            file.write_bytes(b"keep")
            with self.assertRaises(ValueError):
                fresh_output(file)
            self.assertEqual(file.read_bytes(), b"keep")
            with self.assertRaises(ValueError):
                fresh_output(root / "missing" / "output")

    def test_symlink_and_project_targets_fail(self) -> None:
        """Ссылка в родительском пути не обходит запрет и не создаёт настоящую цель."""
        with tempfile.TemporaryDirectory(prefix="shadow link ") as temporary:
            root = Path(temporary).resolve()
            actual = root / "actual"
            actual.mkdir()
            link = root / "linked"
            link.symlink_to(actual, target_is_directory=True)
            with self.assertRaises(ValueError):
                fresh_output(link / "frames")
            self.assertFalse((actual / "frames").exists())
        with self.assertRaises(ValueError):
            fresh_output(ROOT / "shadow-test-must-not-exist")
        self.assertFalse((ROOT / "shadow-test-must-not-exist").exists())

    def test_working_candidate_guard_uses_real_git_and_rejects_unrelated_production(self) -> None:
        """В своей Git-копии разрешены два runtime-входа; ассеты, сцена и project не обходят guard."""
        originals = {name: git("show", "HEAD:" + name) for name in RUNTIME}
        with tempfile.TemporaryDirectory(prefix="shadow candidate Git ") as temporary:
            repo = Path(temporary).resolve()
            files = {
                **originals,
                "assets/game/fixture.txt": b"fixture",
                "main.tscn": b"scene",
                "project.godot": b"project",
            }
            for name, raw in files.items():
                target = repo / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(repo),
                    "-c",
                    "user.name=QA",
                    "-c",
                    "user.email=qa@example.test",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "commit",
                    "-qm",
                    "isolated fixture",
                ],
                check=True,
            )
            commit = subprocess.check_output(
                ["git", "-C", str(repo), "rev-parse", "HEAD"], text=True
            ).strip()
            index = (repo / ".git/index").read_bytes()
            config = (repo / ".git/config").read_bytes()
            with (
                patch("tools.qa.world.shadows.contract.ROOT", repo),
                patch.dict(
                    os.environ,
                    {
                        "GIT_DIR": str(repo / "unrelated-git"),
                        "GIT_WORK_TREE": str(repo / "unrelated-tree"),
                    },
                ),
            ):
                self.assertEqual(head(), commit)
                name = RUNTIME[0]
                (repo / name).write_bytes(files[name] + b"\n# candidate change\n")
                with self.assertRaisesRegex(ValueError, "production must match"):
                    head()
                self.assertEqual(head(True), commit)
                (repo / name).write_bytes(files[name])
                for name in ("assets/game/fixture.txt", "main.tscn", "project.godot"):
                    with self.subTest(name=name):
                        (repo / name).write_bytes(files[name] + b" changed")
                        with self.assertRaisesRegex(ValueError, "production must match"):
                            head(True)
                        (repo / name).write_bytes(files[name])
            self.assertEqual((repo / ".git/index").read_bytes(), index)
            self.assertEqual((repo / ".git/config").read_bytes(), config)

    def test_traversal_cannot_enter_project_but_external_alias_is_normalized(self) -> None:
        """Прежняя функция воспроизводит обход только в своей временной папке; новая отказывает."""
        frozen = (
            ROOT
            / "docs/reports/visual-overhaul/vshadow-010/native/inputs/tools/qa/world/shadows/contract.py"
        )
        tree = ast.parse(frozen.read_text())
        function = next(
            node
            for node in tree.body
            if isinstance(node, ast.FunctionDef) and node.name == "fresh_output"
        )
        with tempfile.TemporaryDirectory(prefix="shadow traversal ") as temporary:
            parent = Path(temporary).resolve()
            project, outside = parent / "project", parent / "outside"
            project.mkdir()
            outside.mkdir()
            alias = outside / ".." / "project" / "must-not-exist"
            namespace: dict[str, Any] = {"Path": Path, "ROOT": project}
            exec(
                compile(ast.Module(body=[function], type_ignores=[]), str(frozen), "exec"),
                namespace,
            )
            previous = namespace["fresh_output"](alias)
            self.assertEqual(previous.resolve(), project / "must-not-exist")
            self.assertTrue(previous.is_dir())
            previous.rmdir()
            with patch("tools.qa.world.shadows.contract.ROOT", project):
                with self.assertRaisesRegex(ValueError, "fresh external output"):
                    fresh_output(alias)
                valid_alias = outside / ".." / "external frames"
                self.assertEqual(fresh_output(valid_alias), parent / "external frames")
            self.assertFalse((project / "must-not-exist").exists())


if __name__ == "__main__":
    unittest.main()
