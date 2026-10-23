#!/usr/bin/env python3
"""Портит копии предложения и реальных PNG, не подключая контракт к старому игровому suite."""

import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image
from item_export_contract import ROOT, MANIFEST, read, validate, resource_errors


class ContractProposalTests(unittest.TestCase):
    """Все повреждения выполняются вне рабочих ресурсов и прежних архивов."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="farm-export-proposal-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.data = read(ROOT / MANIFEST)
        self.path = self.folder / "manifest.json"

    def errors(self):
        self.path.write_text(json.dumps(self.data))
        return validate(ROOT, self.path)

    def test_real_two_platform_evidence(self):
        """Все 386 предметов и 275 исходных файлов подтверждаются настоящими двумя капсулами."""
        self.assertEqual(self.errors(), [])

    def test_missing_item(self):
        self.data["entries"].pop("bread")
        self.assertTrue(any("coverage" in e for e in self.errors()))

    def test_extra_one_byte_variant_is_not_allowed(self):
        """Неизвестный целый вывод запрещён, даже если он похож на разрешённый по одному байту."""
        self.data["entries"]["compost"]["derived_rgba_sha256"].append("0" * 64)
        self.assertTrue(any("finite" in e for e in self.errors()))

    def test_source_fingerprint_cannot_be_rewritten(self):
        self.data["entries"]["compost"]["source_rgba_sha256"] = "0" * 64
        self.assertTrue(any("finite" in e for e in self.errors()))

    def test_actual_reference_cannot_be_replaced_by_known_linux_export(self):
        """Известный вывод resize не становится разрешением заменить настоящий игровой PNG."""
        entry = self.data["entries"]["compost"]
        folder = self.folder / "assets/game/items/ui/preview"
        folder.mkdir(parents=True)
        source = (
            ROOT
            / "docs/reports/visual-overhaul/vfoliage-006/ci-repro/linux-x64/preview/compost-resized.png"
        )
        (folder / "compost.png").write_bytes(source.read_bytes())
        self.assertTrue(resource_errors(self.folder, "compost", entry))

    def test_actual_one_byte_rgba_corruption(self):
        """Один невидимый RGB-байт в новом PNG отклоняется по настоящему ресурсу."""
        folder = self.folder / "assets/game/items/ui/preview"
        folder.mkdir(parents=True)
        with Image.open(ROOT / "assets/game/items/ui/preview/compost.png") as source:
            image = source.copy()
        pixel = image.getpixel((0, 0))
        image.putpixel((0, 0), (pixel[0] ^ 1, *pixel[1:]))
        image.save(folder / "compost.png")
        self.assertTrue(
            resource_errors(self.folder, "compost", self.data["entries"]["compost"])
        )

    def test_changed_evidence_hash(self):
        self.data["evidence"][next(iter(self.data["evidence"]))] = "0" * 64
        self.assertTrue(any("evidence file" in e for e in self.errors()))

    def test_missing_evidence_platform(self):
        self.data["evidence"].pop(next(iter(self.data["evidence"])))
        self.assertTrue(self.errors())

    def test_engine_and_fitter(self):
        for field in ["engine_hash", "fitter_sha256"]:
            with self.subTest(field=field):
                saved = self.data[field]
                self.data[field] = "0" * len(saved)
                self.assertTrue(any("engine/fitter" in e for e in self.errors()))
                self.data[field] = saved

    def test_output_geometry(self):
        self.data["padding"] = 7
        self.assertTrue(any("geometry" in e for e in self.errors()))

    def test_physical_source_coverage(self):
        self.data["physical_source_files"].pop(
            next(iter(self.data["physical_source_files"]))
        )
        self.assertTrue(any("physical source coverage" in e for e in self.errors()))

    def test_actual_source_file_hash(self):
        self.data["physical_source_files"][
            next(iter(self.data["physical_source_files"]))
        ] = ("0" * 64)
        self.assertTrue(any("source file differs" in e for e in self.errors()))

    def test_png_serialization_is_not_rgba_identity(self):
        entry = self.data["entries"]["compost"]
        entry["preview_rgba_sha256"] = entry["preview_file_sha256"]
        self.assertTrue(any("actual preview" in e for e in self.errors()))

    def test_cannot_claim_approval(self):
        self.data["purpose"] = "accepted"
        self.assertTrue(any("proposal engine" in e for e in self.errors()))


if __name__ == "__main__":
    unittest.main()
