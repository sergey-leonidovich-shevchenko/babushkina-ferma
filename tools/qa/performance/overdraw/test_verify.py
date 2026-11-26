"""Контроли измерителя, счётчиков наложения и сравнения видимых пикселей."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from tools.qa.performance.overdraw import contract as c
from tools.qa.performance.overdraw.verify import (
    SIZE,
    area,
    check_calibration,
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


if __name__ == "__main__":
    unittest.main()
