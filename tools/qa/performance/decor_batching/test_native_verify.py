"""Regression checks for fixed native receipts and the pixel acceptance rule."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from tools.qa.performance.decor_batching import native_contract as contract
from tools.qa.performance.decor_batching import native_verify as native


class RefreshTest(unittest.TestCase):
    def test_local_refresh_cannot_pass_as_full_rebuild(self) -> None:
        spec = next(
            case for case in contract.plan()["cases"] if case["id"] == "flower_crossing_cell"
        )
        samples: list[native.Data] = [
            {
                "previous_draw_usec": 1 + i * 15000,
                "requested_usec": 2 + i * 15000,
                "submitted_usec": 3 + i * 15000,
                "presented_usec": 10001 + i * 15000,
                "draw_calls": 31,
                "terrain_draw_calls": 5,
                "static_bytes": 2**22,
                "texture_bytes": 2**20,
                "before": {"revision": i, "requests": 1, "full_paints": 1, "local_paints": i},
                "after": {
                    "revision": i + 1,
                    "requests": 1,
                    "full_paints": 1,
                    "local_paints": i + 1,
                    "last_completed": spec["repaint"],
                },
            }
            for i in range(contract.REPETITIONS)
        ]
        report = native.refresh_summary(samples, spec)
        self.assertEqual(report["frame_interval_ms"]["p95"], 10)
        samples[0]["after"]["last_completed"] = [480, 528, 24, 72]
        with self.assertRaisesRegex(ValueError, "terrain revision"):
            native.refresh_summary(samples, spec)
        samples[0]["after"].update(
            last_completed=spec["repaint"], local_paints=0, full_paints=2, requests=2
        )
        with self.assertRaisesRegex(ValueError, "terrain revision"):
            native.refresh_summary(samples, spec)

    def test_rejects_unexpected_or_missing_raw_files(self) -> None:
        files = contract.expected_files()
        self.assertIn("long-cycle/spatial_batches/frames.csv.gz", files)
        self.assertIn("fixed/baseline/flower-order-wrong.png", files)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory).resolve()
            for name in files:
                file = output / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.touch()
            self.assertEqual(contract.inventory(output).keys(), files)
            (output / "long-cycle/spatial_batches/frames.csv.gz").unlink()
            with self.assertRaisesRegex(ValueError, "incomplete"):
                contract.inventory(output)

    def test_warm_route_keeps_refresh_events_separate(self) -> None:
        data = {
            "first_draw": {"draw_id": 10},
            "final_draw": {"draw_id": 13},
            "initial": {"decor_terrain": {"revision": 2}},
            "final": {"decor_terrain": {"revision": 3}},
        }
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            event = {"draw_id": 11, "revision": 3, "terrain_ready": True}
            with patch.object(
                native.warm,
                "csv_rows",
                return_value=[
                    (1, 90.0, 11),
                    (2, 50.0, 12),
                    (3, 18.0, 13),
                ],
            ):
                report = native.warm_cache_intervals(folder, data, [event])
                self.assertEqual(report["intervals_touching_terrain_events"], 2)
                self.assertEqual(report["settled_cache_frame_interval_ms"]["p95"], 18.0)
                with self.assertRaisesRegex(ValueError, "without a captured frame"):
                    native.warm_cache_intervals(folder, data, [])


class PixelTest(unittest.TestCase):
    def test_preserves_alpha_and_rejects_more_than_one_rgb_step(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            before = Path(directory) / "before.png"
            after = Path(directory) / "after.png"
            image = Image.new("RGBA", (20, 20), (30, 40, 60, 255))
            image.save(before)
            image.putpixel((10, 10), (31, 40, 60, 255))
            image.save(after)
            self.assertEqual(native.compare_png(before, after, (20, 20))["rgb_changed_pixels"], 1)
            for pixel in ((32, 40, 60, 255), (31, 40, 60, 254)):
                with self.subTest(pixel=pixel):
                    image.putpixel((10, 10), pixel)
                    image.save(after)
                    with self.assertRaisesRegex(ValueError, "visible mismatch"):
                        native.compare_png(before, after, (20, 20))

    def test_negative_control_must_change_pixels_on_the_hero(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            image = Image.new("RGBA", (1152, 648), (31, 32, 33, 255))
            image.save(folder / "flower-order-correct.png")
            state = {"negative_hero_body": [1103, 652, 50, 83], "negative_camera": [648, 466]}
            image.putpixel((4, 5), (255, 32, 33, 255))
            image.save(folder / "flower-order-wrong.png")
            with self.assertRaisesRegex(ValueError, "invisible on the hero"):
                native.check_negative(folder, state)
            image.putpixel((576, 300), (255, 32, 33, 255))
            image.save(folder / "flower-order-wrong.png")
            native.check_negative(folder, state)


if __name__ == "__main__":
    unittest.main()
