"""Настоящие Git/файловые контроли границ producer/reader; не синтетическая native-приёмка."""

from __future__ import annotations

import os
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.qa.world.weather import collect
from tools.qa.world.weather import contract as c
from tools.qa.world.weather.verify import Evidence


class ContractTests(unittest.TestCase):
    """Проверяет закреплённую базу, полноту QA и реальные отказы до запуска движка."""

    def test_baseline_is_real_accepted_runtime_with_old_clock(self) -> None:
        """Историческая база содержит настоящий дефект и полный игровой art, а не parser fixture."""
        self.assertEqual(c.git("rev-parse", c.BASE).decode().strip(), c.BASE)
        raw = c.git("show", c.BASE + ":scripts/systems/atmosphere_renderer.gd")
        self.assertEqual(raw.count(b"Time.get_ticks_msec()"), 3)
        blobs = c.blobs(c.BASE)
        self.assertIn("main.tscn", blobs)
        self.assertEqual(sum(path.startswith("assets/game/") for path in blobs), 2936)
        self.assertNotIn("scripts/presentation/weather_visual_clock.gd", blobs)

    def test_all_actual_qa_script_references_are_recorded(self) -> None:
        """Каждая реально прочитанная QA-зависимость входит в замороженный input closure."""
        self.assertEqual(len(c.INPUTS), len(set(c.INPUTS)))
        for name in c.INPUTS:
            self.assertTrue((c.ROOT / name).is_file(), name)
            if name.endswith(".gd"):
                for target in re.findall(r'res://([^"\s]+)', (c.ROOT / name).read_text()):
                    if target.startswith("tools/"):
                        self.assertIn(target, c.INPUTS, (name, target))

    def test_artifact_contract_requires_every_frame_and_real_log(self) -> None:
        """Реестр не принимает потерю паузы, второго viewport или физического окна."""
        files = c.artifacts()
        self.assertEqual(sum(name.endswith(".png") for name in files), 160)
        for variant in ("baseline", "candidate"):
            for width in c.WIDTHS:
                self.assertIn(f"{variant}/{width}/rain-pause-b.png", files)
                self.assertIn(f"{variant}/{width}/twin-1-1.png", files)
                self.assertIn(f"{variant}/{width}.launch.json", files)

    def test_local_game_capture_refuses_before_output_or_engine(self) -> None:
        """Нативный producer реально отказывает Mac даже при заданном DISPLAY."""
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "unused"
            with (
                patch.object(collect.sys, "platform", "darwin"),
                patch.dict(os.environ, {"DISPLAY": ":99"}),
            ):
                with self.assertRaisesRegex(ValueError, "remote Linux X11"):
                    collect.collect(target)
            self.assertFalse(target.exists())

    def test_reader_accepts_an_ordinary_local_file(self) -> None:
        """Простой положительный файловый контроль не объявляется нативным изображением."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "ordinary.json").write_text('{"value": 7}')
            self.assertEqual(Evidence(root).document("ordinary.json"), {"value": 7})

    def test_reader_refuses_absolute_parent_and_symlink(self) -> None:
        """Настоящие symlink/traversal не могут подменить файл сохранённого evidence."""
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            root = parent / "evidence"
            root.mkdir()
            outside = parent / "foreign.json"
            outside.write_text("{}")
            (root / "linked.json").symlink_to(outside)
            reader = Evidence(root)
            for name in ("../foreign.json", str(outside), "linked.json"):
                with self.assertRaisesRegex(ValueError, "unsafe|escaped|symlink"):
                    reader.read(name)


if __name__ == "__main__":
    unittest.main()
