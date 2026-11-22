"""Проверяет сохранение ZIP по частям и отказы на настоящем неизменённом первом CI."""

from __future__ import annotations

import copy
import io
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from typing import Any

from tools.qa.world.rollback import contract as c
from tools.qa.world.rollback.archive import archive_input
from tools.qa.world.rollback.verify import check_run, compare_gameplay, verify
from tools.qa.world.weather.archive import unpack
from tools.qa.world.weather.verify import Evidence


class ArchivePartsTests(unittest.TestCase):
    """Маленький unit ZIP проверяет только байты/границы частей, не нативную игру."""

    def setUp(self) -> None:
        """Все изменения идут в свою новую временную папку."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, "w") as archive:
            archive.writestr("unit.txt", "explicit synthetic parser fixture")
        self.raw = stream.getvalue()
        split = len(self.raw) // 2
        self.manifest: dict[str, Any] = {
            "schema": 1,
            "format": "zip-parts-v1",
            "task": "VCOMPAT-010",
            "bytes": len(self.raw),
            "sha256": c.digest(self.raw),
            "parts": [],
        }
        for index, raw in enumerate((self.raw[:split], self.raw[split:]), 1):
            name = f"artifact.zip.{index:03}"
            (self.root / name).write_bytes(raw)
            self.manifest["parts"].append(
                {"file": name, "bytes": len(raw), "sha256": c.digest(raw)}
            )
        self.path = self.root / "parts.json"

    def read(self) -> bytes:
        """Собирает тем же reader, который открывает frozen evidence из Git."""
        self.path.write_text(json.dumps(self.manifest))
        with archive_input(self.path) as archive:
            result = archive.read_bytes()
        self.assertFalse(archive.exists())
        return result

    def test_exact_original_bytes(self) -> None:
        """Части восстанавливают исходный ZIP без новой упаковки."""
        self.assertEqual(self.read(), self.raw)

    def test_changed_part(self) -> None:
        """Изменённая копия части не принимается по одному полному SHA."""
        (self.root / "artifact.zip.001").write_bytes(b"bad")
        with self.assertRaisesRegex(ValueError, "part bytes"):
            self.read()

    def test_wrong_complete_digest(self) -> None:
        """Верные части требуют также SHA всего исходного архива."""
        self.manifest["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "original ZIP"):
            self.read()

    def test_reordered_or_escaped_part(self) -> None:
        """Порядок и путь проверяются до чтения за пределами evidence."""
        original = copy.deepcopy(self.manifest["parts"])
        for name in ("artifact.zip.002", "../artifact.zip.001"):
            with self.subTest(path=name):
                self.manifest["parts"] = copy.deepcopy(original)
                self.manifest["parts"][0]["file"] = name
                with self.assertRaisesRegex(ValueError, "order/path"):
                    self.read()

    def test_symlink_part(self) -> None:
        """Даже совпавшие байты не разрешают подменять часть symlink."""
        path = self.root / "artifact.zip.001"
        raw = path.read_bytes()
        path.unlink()
        target = self.root / "other"
        target.write_bytes(raw)
        path.symlink_to(target)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.read()

    def test_missing_part(self) -> None:
        """Отсутствие части не заменяется неполным архивом."""
        (self.root / "artifact.zip.002").unlink()
        with self.assertRaises(FileNotFoundError):
            self.read()


class OriginalNativeSeedTests(unittest.TestCase):
    """Исходный ZIP CI1 остаётся failure, все проверки читают только временную распаковку."""

    PARTS = c.ROOT / "docs/reports/visual-overhaul/vcompat-010/failures/ci-01/parts.json"
    HEAD = "ae7485b343a374f04c460b09c9353d822f771e76"

    def test_all_four_actual_series_require_the_fixed_seed(self) -> None:
        """Первоначальный, cold-start и twin world получают один строгий seed guard."""
        with archive_input(self.PARTS) as archive, unpack(archive) as folder:
            store = Evidence(folder)
            for width in c.WIDTHS:
                for variant in ("baseline", "candidate"):
                    with self.subTest(width=width, variant=variant):
                        with self.assertRaisesRegex(ValueError, "fixed world seed"):
                            check_run(store, f"{variant}/{width}/", variant == "candidate", width)

    def test_identical_actual_pixels_do_not_prove_identical_gameplay(self) -> None:
        """1152 home-on совпал целиком, но разные настоящие RNG/containers всё равно отвергаются."""
        with archive_input(self.PARTS) as archive, unpack(archive) as folder:
            store = Evidence(folder)
            pixels = []
            for variant in ("baseline", "candidate"):
                prefix = f"{variant}/1152/"
                rows = store.document(prefix + "capture.json")["frames"]
                row = next(row for row in rows if row["id"] == "home-on")
                pixels.append(store.image(prefix, row, (1152, 648)))
            self.assertEqual(pixels[0], pixels[1])
            for width in c.WIDTHS:
                with self.assertRaisesRegex(ValueError, "baseline/candidate gameplay differs"):
                    compare_gameplay(store, width)

    def test_full_reader_rejects_original_failure_without_a_waiver(self) -> None:
        """Настоящие Git-входы и SHA проверяются тем же публичным verifier до seed-отказа."""
        with archive_input(self.PARTS) as archive, unpack(archive) as folder:
            with self.assertRaisesRegex(ValueError, "fixed world seed"):
                verify(folder, self.HEAD)


if __name__ == "__main__":
    unittest.main()
