"""Проверяет отказы сравнения по принятой карте и реальному выводу прототипа."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.qa.performance.decor_batching import verify as geometry


class PairVerificationTest(unittest.TestCase):
    anchors: tuple[geometry.Point, ...]

    @classmethod
    def setUpClass(cls) -> None:
        cls.anchors = geometry.flowers()

    def test_actual_prototype_and_phase_counts(self) -> None:
        geometry.check_control(geometry.read(geometry.CONTROL), self.anchors)
        result = geometry.verify(geometry.replay(self.anchors), self.anchors)["phases"]
        full = result["full_refresh"]["full_rebuild"]
        self.assertEqual(full["one_batch"], {"groups": 1, "submitted": 14, "visible": 14})
        self.assertEqual(full["spatial_batches"], {"groups": 10, "submitted": 14, "visible": 14})
        local = result["local_refresh"]
        self.assertEqual(
            local["flower_crossing_cell"]["spatial_batches"],
            {"groups": 1, "submitted": 3, "visible": 1},
        )
        self.assertEqual(local["empty_patch"]["spatial_batches"]["submitted"], 0)
        warm = result["warm_route"]["home_view"]["spatial_batches"]
        self.assertEqual(warm, {"groups": 0, "submitted": 0, "visible": 4})

    def test_different_window_framebuffer_camera_or_zoom(self) -> None:
        differences = (
            ("window", [1280, 720], "window differs"),
            ("framebuffer", [2304, 1296], "framebuffer differs"),
            ("camera", [648, 478], "camera differs"),
            ("zoom_percent", 100, "zoom differs"),
        )
        for key, value, message in differences:
            with self.subTest(field=key), self.assertRaisesRegex(ValueError, message):
                pairs = geometry.replay(self.anchors)
                pairs["village_square_view"]["spatial_batches"][key] = value
                geometry.verify(pairs, self.anchors)

    def test_paired_equal_but_wrong_repaint_is_rejected(self) -> None:
        pairs = geometry.replay(self.anchors)
        for record in pairs["flower_crossing_cell"].values():
            record["repaint"] = [480, 528, 24, 72]
        with self.assertRaisesRegex(ValueError, "repaint region differs"):
            geometry.verify(pairs, self.anchors)

    def test_refresh_phases_cannot_be_swapped(self) -> None:
        pairs = geometry.replay(self.anchors)
        pairs["full_rebuild"]["one_batch"]["phase"] = "local_refresh"
        with self.assertRaisesRegex(ValueError, "refresh phase differs"):
            geometry.verify(pairs, self.anchors)

    def test_warm_route_cannot_count_batches_from_cache_refresh(self) -> None:
        pairs = geometry.replay(self.anchors)
        pairs["home_view"]["spatial_batches"]["batches"] = [[[192, 600]]]
        with self.assertRaisesRegex(ValueError, "submitted anchors differ"):
            geometry.verify(pairs, self.anchors)

    def test_duplicate_anchor_inside_or_across_batches(self) -> None:
        for across in (False, True):
            with (
                self.subTest(across=across),
                self.assertRaisesRegex(ValueError, "duplicate .*anchor"),
            ):
                pairs = geometry.replay(self.anchors)
                batches = pairs["flower_crossing_cell"]["spatial_batches"]["batches"]
                if across:
                    batches.append([batches[0][0]])
                else:
                    batches[0].append(batches[0][0])
                geometry.verify(pairs, self.anchors)

    def test_missing_or_displaced_boundary_anchor(self) -> None:
        for replacement in (None, [505, 576]):
            with (
                self.subTest(replacement=replacement),
                self.assertRaisesRegex(ValueError, "submitted anchors differ"),
            ):
                pairs = geometry.replay(self.anchors)
                batch = pairs["flower_crossing_cell"]["spatial_batches"]["batches"][0]
                batch.remove([504, 576])
                if replacement is not None:
                    batch.append(replacement)
                geometry.verify(pairs, self.anchors)

    def test_missing_visible_anchor_in_all_variants(self) -> None:
        pairs = geometry.replay(self.anchors)
        for record in pairs["flower_crossing_cell"].values():
            record["visible"].clear()
        with self.assertRaisesRegex(ValueError, "visible anchors differ"):
            geometry.verify(pairs, self.anchors)

    def test_same_instances_in_wrong_batches(self) -> None:
        pairs = geometry.replay(self.anchors)
        batches = pairs["full_rebuild"]["spatial_batches"]["batches"]
        batches[0].extend(batches.pop())
        with self.assertRaisesRegex(ValueError, "batch membership differs"):
            geometry.verify(pairs, self.anchors)

    def test_corrupted_real_prototype_counts(self) -> None:
        control = geometry.read(geometry.CONTROL)
        control["branches"]["flower_crossing_cell"]["spatial_batches"]["submitted"] = 2
        with self.assertRaisesRegex(ValueError, "prototype control differs"):
            geometry.check_control(control, self.anchors)

    def test_incomplete_variant_or_case(self) -> None:
        pairs = geometry.replay(self.anchors)
        del pairs["north_view"]["one_batch"]
        with self.assertRaisesRegex(ValueError, "variant matrix differs"):
            geometry.verify(pairs, self.anchors)
        del pairs["north_view"]
        with self.assertRaisesRegex(ValueError, "case matrix differs"):
            geometry.verify(pairs, self.anchors)

    def test_cli_rejects_a_pair_from_different_windows(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            pair_file = Path(directory) / "pairs.json"
            pairs = geometry.replay(self.anchors)
            pairs["home_view"]["one_batch"]["window"] = [1280, 720]
            pair_file.write_text(json.dumps(pairs))
            proc = subprocess.run(
                [
                    sys.executable,
                    "tools/run.py",
                    "qa.performance.decor_batching.verify",
                    "--pairs",
                    str(pair_file),
                ],
                cwd=geometry.ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("window differs", proc.stderr)


if __name__ == "__main__":
    unittest.main()
