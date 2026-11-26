"""Контроли измерителя, счётчиков наложения и сравнения видимых пикселей."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from tools.qa.performance.overdraw import contract as c
from tools.qa.performance.overdraw.verify import (
    CONTACT_WIND_SIZE,
    SIZE,
    area,
    check_calibration,
    check_camera,
    check_contact,
    check_readiness,
    contact_composite,
    equal_frame,
    no_growth,
    water_stays_under_decks,
)


class CoverageTest(unittest.TestCase):
    def test_full_matrix(self) -> None:
        self.assertEqual(len(c.schedule()), 8)
        evidence = c.expected_files()
        self.assertIn("long-cycle/trimmed/frames.csv.gz", evidence)
        self.assertIn("views/dense-grass-baseline-wind.png", evidence)
        self.assertNotIn("views/still-bridge-trimmed-wind.png", evidence)
        self.assertIn("views/grass-contact-trimmed-composite.png", evidence)
        self.assertIn("views/grass-contact-baseline-wind-color.png", evidence)

    def test_counter_counts_layers_and_unique_pixels(self) -> None:
        band = Image.new("L", (6, 4), 0)
        band.putpixel((1, 1), 2)
        band.putpixel((2, 1), 1)
        self.assertEqual(area(band), {"fragments": 3, "covered_pixels": 2, "maximum_layers": 2})
        band.putpixel((3, 1), 255)
        with self.assertRaisesRegex(ValueError, "saturated"):
            area(band)

    def test_equal_area_can_hide_an_expansion(self) -> None:
        original = Image.new("L", (4, 3), 0)
        original.putpixel((0, 0), 1)
        shifted = Image.new("L", (4, 3), 0)
        shifted.putpixel((1, 0), 1)
        self.assertEqual(area(original), area(shifted))
        with self.assertRaisesRegex(ValueError, "added coverage"):
            no_growth(original, shifted)

    def test_comparison_detects_visible_color_under_constant_alpha(self) -> None:
        original = Image.new("RGBA", (4, 3), (0, 0, 0, 255))
        different = original.copy()
        equal_frame(original, different, "bridge")
        different.putpixel((1, 0), (0, 2, 0, 255))
        with self.assertRaisesRegex(ValueError, "visible pixels changed"):
            equal_frame(original, different, "bridge")
        different.putpixel((1, 0), (0, 0, 0, 254))
        with self.assertRaisesRegex(ValueError, "visible pixels changed"):
            equal_frame(original, different, "contact composite")

    def test_water_can_disappear_only_inside_proven_deck(self) -> None:
        original = Image.new("L", SIZE)
        original.putpixel((560, 300), 1)
        original.putpixel((20, 70), 1)
        trimmed = original.copy()
        trimmed.putpixel((560, 300), 0)
        water_stays_under_decks(original, trimmed, [384.0, 186.0], 1.2)
        trimmed.putpixel((20, 70), 0)
        with self.assertRaisesRegex(ValueError, "outside an opaque deck"):
            water_stays_under_decks(original, trimmed, [384.0, 186.0], 1.2)

    def test_calibration_detects_wrong_overlap_in_individual_channel(self) -> None:
        band = Image.new("L", SIZE)
        draw = ImageDraw.Draw(band)
        draw.rectangle((0, 0, 31, 31), fill=1)
        draw.rectangle((16, 16, 47, 47), fill=1)
        draw.rectangle((16, 16, 31, 31), fill=2)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "known.png"
            Image.merge("RGB", (band, band, band)).save(path)
            check_calibration(path)
            wrong = band.copy()
            wrong.putpixel((20, 20), 1)
            Image.merge("RGB", (band, wrong, band)).save(path)
            with self.assertRaisesRegex(ValueError, "differs in G"):
                check_calibration(path)

    def test_contact_requires_both_axes_and_the_smaller_raster_target(self) -> None:
        contact = {"scale": 1, "frame": True, "bends": [[6, [-1.25, 0.75]]]}
        row = {"case": c.CONTACT, "zoom": 1.0, "wind_rows": 1, "contact": contact}
        check_contact(row)
        contact["bends"] = [[6, [-1.25, 0]]]
        with self.assertRaisesRegex(ValueError, "both axes"):
            check_contact(row)
        contact["bends"] = [[6, [-1.25, 0.75]]]
        contact["scale"] = 2
        with self.assertRaisesRegex(ValueError, "wind scale"):
            check_contact(row)

    def test_static_view_keeps_the_fixture_effect_phase(self) -> None:
        row = {
            "case": "still-bridge",
            "quality": "static",
            "zoom": 1.0,
            "live_seconds": 0.0,
            "effect_seconds": 0.0,
            "state": {
                "player": [864.0, 456.0],
                "camera": [288.0, 132.0],
                "day": 31,
                "minutes": 780.0,
                "facing": [0, 1],
                "location": "overworld",
                "seed": 20261015,
                "walkable": "walkable",
                "weather": "rain",
            },
        }
        check_camera(row)
        row["effect_seconds"] = 0.25
        with self.assertRaisesRegex(ValueError, "fixed view does not match"):
            check_camera(row)

    def test_contact_keeps_native_atlas_and_composited_alpha(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            image = Image.new("RGBA", CONTACT_WIND_SIZE)
            image.putpixel((5, 5), (1, 2, 3, 76))
            composite = Image.new("RGBA", SIZE)
            composite.putpixel((10, 10), (2, 3, 4, 69))
            for name in c.VARIANTS:
                image.save(folder / f"{c.CONTACT}-{name}-wind-color.png")
                composite.save(folder / f"{c.CONTACT}-{name}-composite.png")
            contact_composite(folder)
            image.putpixel((5, 5), (1, 2, 3, 77))
            image.save(folder / f"{c.CONTACT}-trimmed-wind-color.png")
            with self.assertRaisesRegex(ValueError, "native wind texture changed"):
                contact_composite(folder)
            image.save(folder / f"{c.CONTACT}-baseline-wind-color.png")
            composite.putpixel((10, 10), (2, 3, 4, 70))
            composite.save(folder / f"{c.CONTACT}-trimmed-composite.png")
            with self.assertRaisesRegex(ValueError, "contact composite"):
                contact_composite(folder)

    def test_window_requires_bounded_stable_native_draws(self) -> None:
        ready = {
            "ready": True,
            "focus": True,
            "visible": True,
            "ground_ready": True,
            "ground_split": True,
            "water_visible": True,
            "host_size": list(SIZE),
            "window_size": list(SIZE),
            "framebuffer": list(SIZE),
            "window_mode": 0,
            "terrain_requests": 1,
            "stable_draws": 8,
            "callbacks": 13,
            "elapsed_ms": 582,
        }
        check_readiness({"case": "west-bridge", "readiness": ready})
        for key, value in (
            ("focus", False),
            ("ground_ready", False),
            ("framebuffer", [1144, 648]),
            ("stable_draws", 7),
            ("callbacks", 0),
            ("elapsed_ms", 8000),
        ):
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "window did not settle"):
                check_readiness({"case": "west-bridge", "readiness": ready | {key: value}})


if __name__ == "__main__":
    unittest.main()
