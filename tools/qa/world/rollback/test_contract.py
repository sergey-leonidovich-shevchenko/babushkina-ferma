"""Отрицательные контроли Git-экспорта и запрета подменять native локальным/headless запуском."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.qa.world.rollback import collect
from tools.qa.world.rollback import contract as c


class ContractTests(unittest.TestCase):
    """Читает настоящую принятую базу, а запускающий CLI проверяет до возможного engine side effect."""

    def test_real_baseline_and_full_input_matrix(self) -> None:
        """База принадлежит реальной истории и содержит весь runtime, art и проектные уровни."""
        inventory = c.blobs(c.BASE)
        self.assertGreater(len(inventory), 3000)
        self.assertIn("scripts/world_background.gd", inventory)
        self.assertIn("level_designs/README.md", inventory)
        self.assertNotIn("scripts/presentation/visual_version.gd", inventory)
        self.assertEqual(len(c.FRAME_IDS), 34)
        self.assertEqual(len(c.INPUTS), len(set(c.INPUTS)))
        self.assertIn("tools/qa/world/weather/verify.py", c.INPUTS)
        for name in c.INPUTS:
            self.assertTrue((c.ROOT / name).is_file(), name)

    def test_no_mac_native_bypass(self) -> None:
        """Даже при DISPLAY локальный Mac отвергается до Git-экспорта и запуска движка."""
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "capture"
            with (
                patch.object(collect.sys, "platform", "darwin"),
                patch.dict(collect.os.environ, {"DISPLAY": ":1"}),
                patch.object(collect, "execute") as engine,
            ):
                with self.assertRaisesRegex(ValueError, "remote Linux X11"):
                    collect.collect(output)
                engine.assert_not_called()
                self.assertFalse(output.exists())

    def test_executed_data_and_other_assets_reject_tampering(self) -> None:
        """Настоящие Git-слот и ресурс вне assets/game проверяются тем же guard, что и exporter."""
        inventory = c.blobs(c.BASE)
        for name in ("tests/fixtures/saves/v1-core.json", "assets/title_art_rpg.png"):
            with self.subTest(input=name):
                self.assertTrue(
                    name in inventory, "executed input missing from Git inventory: " + name
                )
                original = (c.ROOT / name).read_bytes()
                raw = c.git("show", c.BASE + ":" + name)
                with tempfile.TemporaryDirectory() as folder:
                    project = Path(folder)
                    target = project / name
                    target.parent.mkdir(parents=True)
                    target.write_bytes(raw)
                    c.check_export(project, {name: inventory[name]})
                    target.write_bytes(raw + b"\n")
                    with self.assertRaisesRegex(ValueError, "export changed production"):
                        c.check_export(project, {name: inventory[name]})
                self.assertEqual((c.ROOT / name).read_bytes(), original)

    def test_no_headless_as_native(self) -> None:
        """Отсутствие оконного сервера не заменяется headless картинкой или синтетическим PNG."""
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "capture"
            with (
                patch.object(collect.sys, "platform", "linux"),
                patch.dict(collect.os.environ, {}, clear=True),
                patch.object(collect, "execute") as engine,
            ):
                with self.assertRaisesRegex(ValueError, "remote Linux X11"):
                    collect.collect(output)
                engine.assert_not_called()
                self.assertFalse(output.exists())

    def test_dirty_inputs_are_rejected(self) -> None:
        """Повреждённый рабочий overlay не используется вместо exact committed input closure."""
        with patch.object(c, "git", side_effect=[b"a" * 40, b" M scripts/world_background.gd\n"]):
            with self.assertRaisesRegex(ValueError, "clean committed"):
                c.export_inputs()


if __name__ == "__main__":
    unittest.main()
