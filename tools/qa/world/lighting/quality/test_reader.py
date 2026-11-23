"""Проверяет reader на копиях настоящего полного Actions-пакета VLIGHT-010."""

from __future__ import annotations

import copy
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path

from PIL import Image

from tools.common.git import git_environment
from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality import gallery, metrics, output_guard, regressions, retained
from tools.qa.world.lighting.quality.evidence import Evidence
from tools.qa.world.lighting.quality.verify import verify

REPORT = c.ROOT / "docs/reports/visual-overhaul/vlight-010/native-ci-01"
HEAD = "93df8ef619d27b86994d8e190023a6f3b744135a"
ARCHIVE_SHA = "a8206c84afd1e48f9a2fc54b12f133c7b51917c4bd0f44148303776d8f4d2c11"


class ReaderTests(unittest.TestCase):
    """Пересчитанный SHA повреждённой копии не подменяет семантическую проверку."""

    archive: Path

    @classmethod
    def setUpClass(cls) -> None:
        """Один оригинальный ZIP восстанавливается побайтно в принадлежащем тесту temp."""
        stack = ExitStack()
        cls.addClassCleanup(stack.close)
        cls.archive = stack.enter_context(retained.materialize(REPORT / "archive.json"))
        if hashlib.sha256(cls.archive.read_bytes()).hexdigest() != ARCHIVE_SHA:
            raise ValueError("retained bytes differ from original GitHub Actions artifact")

    def test_original_native_and_published_gallery(self) -> None:
        """Полная матрица и каждая native-вставка читаются без нормализации изображений."""
        result = verify(self.archive, HEAD)
        self.assertEqual(result["native_png"], 270)
        self.assertEqual(result["runs"], 4)
        self.assertTrue(result["default_standard_equal"])
        self.assertFalse(result["hardware_fps_acceptance"])
        gallery.check(self.archive, REPORT / "figures")
        metrics.check(self.archive, REPORT)
        store = Evidence(self.archive)
        for room in ("street", "home"):
            self.assertEqual(
                (REPORT / (room + "-low.png")).read_bytes(),
                store.read(f"candidate/1280/{room}-night-low.png"),
            )

    def test_full_copied_real_regressions(self) -> None:
        """Девятнадцать повреждений и парный опыт старых функций используют реальный пакет."""
        with tempfile.TemporaryDirectory(prefix="farm lighting regressions ") as temporary:
            report = Path(temporary).resolve() / "results.json"
            regressions.run(self.archive, HEAD, report, False)
            result = json.loads(report.read_bytes())
            self.assertEqual(len(result["results"]), 20)
            self.assertTrue(result["all_negative_rejected"])
            self.assertTrue(result["original_unchanged"])
            pair = next(row for row in result["results"] if row["case"] == "off is actual standard")
            self.assertTrue(pair["old_functions_accepted"])
            self.assertTrue(pair["new_rejected"])

    def test_resigned_gallery_pixel_change(self) -> None:
        """Один изменённый native-пиксель отклоняется даже при новом SHA выходного PNG."""
        with tempfile.TemporaryDirectory(prefix="farm lighting gallery copy ") as temporary:
            root = Path(temporary).resolve()
            for path in (REPORT / "figures").iterdir():
                shutil.copyfile(path, root / path.name)
            manifest = json.loads((root / "gallery.json").read_bytes())
            figure = "comparison.png"
            placement = manifest["figures"][figure]["placements"][0]
            x, y, _, _ = placement["at"]
            with Image.open(root / figure) as original:
                image = original.convert("RGBA")
            image.putpixel((x, y), (255, 0, 255, 255))
            image.save(root / figure)
            manifest["outputs"][figure] = c.digest((root / figure).read_bytes())
            (root / "gallery.json").write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "gallery changed native pixels"):
                gallery.check(self.archive, root)

    def test_retained_part_damage_is_rejected(self) -> None:
        """Проверка частей замечает подмену до открытия ZIP и сохраняет настоящие файлы."""
        with tempfile.TemporaryDirectory(prefix="farm lighting damaged part ") as temporary:
            root = Path(temporary).resolve()
            manifest = json.loads((REPORT / "archive.json").read_bytes())
            (root / "archive.json").write_text(json.dumps(manifest))
            first = manifest["parts"][0]["name"]
            shutil.copyfile(REPORT / first, root / first)
            with (root / first).open("r+b") as stream:
                first_byte = stream.read(1)[0]
                stream.seek(0)
                stream.write(bytes([first_byte ^ 1]))
            with self.assertRaisesRegex(ValueError, "archive part SHA differs"):
                with retained.materialize(root / "archive.json"):
                    self.fail("damaged original archive was accepted")

    def test_published_samples_and_median_tamper(self) -> None:
        """Подписанная правка CSV или медианы не заменяет настоящие сырые observations."""
        with tempfile.TemporaryDirectory(prefix="farm lighting metric copy ") as temporary:
            root = Path(temporary).resolve()
            for name in ("samples.csv", "metrics.json"):
                shutil.copyfile(REPORT / name, root / name)
            raw = (root / "samples.csv").read_bytes()
            altered = raw.replace(b",standard,0,0,", b",standard,0,9,", 1)
            self.assertNotEqual(raw, altered)
            (root / "samples.csv").write_bytes(altered)
            record = json.loads((root / "metrics.json").read_bytes())
            record["sample_csv_sha256"] = c.digest(altered)
            (root / "metrics.json").write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, "raw published samples differ"):
                metrics.check(self.archive, root)
            (root / "samples.csv").write_bytes(raw)
            record["sample_csv_sha256"] = c.digest(raw)
            record["groups"]["candidate"]["1152"]["low"]["median_draw_ms"] += 1
            (root / "metrics.json").write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, "published metrics differ"):
                metrics.check(self.archive, root)

    def test_actual_derived_cli_refuses_existing_output(self) -> None:
        """Оба настоящих producer из чужой cwd с пробелами сохраняют прежние результаты."""
        with tempfile.TemporaryDirectory(prefix="farm derived CLI refusal ") as temporary:
            root = Path(temporary).resolve()
            foreign = root / "foreign working directory"
            foreign.mkdir()
            for command in ("gallery", "metrics"):
                folder = root / ("existing " + command)
                folder.mkdir()
                originals = (
                    list((REPORT / "figures").iterdir())
                    if command == "gallery"
                    else [REPORT / "samples.csv", REPORT / "metrics.json"]
                )
                for path in originals:
                    shutil.copyfile(path, folder / path.name)

                def snapshot(location: Path = folder) -> dict[str, tuple[int, int, str]]:
                    return {
                        path.name: (
                            path.stat().st_mode,
                            path.stat().st_mtime_ns,
                            c.digest(path.read_bytes()),
                        )
                        for path in location.iterdir()
                    }

                before = snapshot()
                result = subprocess.run(
                    [
                        sys.executable,
                        str(c.ROOT / "tools/run.py"),
                        "qa.world.lighting.quality." + command,
                        "--native",
                        str(self.archive),
                        "--output",
                        str(folder),
                    ],
                    cwd=foreign,
                    env=git_environment(),
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=30,
                )
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("fresh external output with existing parent required", result.stderr)
                self.assertFalse(result.stdout)
                self.assertEqual(before, snapshot())

    def test_retained_manifest_rejects_foreign_paths(self) -> None:
        """Absolute/traversal имена не дают reader доступа за пределами набора частей."""
        original = json.loads((REPORT / "archive.json").read_bytes())
        for name in ("../foreign", "/", "/foreign", "a\\b", "./part"):
            with self.subTest(name=name):
                with tempfile.TemporaryDirectory(
                    prefix="farm lighting unsafe manifest "
                ) as temporary:
                    record = copy.deepcopy(original)
                    record["parts"][0]["name"] = name
                    manifest = Path(temporary).resolve() / "archive.json"
                    manifest.write_text(json.dumps(record))
                    with self.assertRaisesRegex(ValueError, "unsafe retained archive part"):
                        with retained.materialize(manifest):
                            self.fail("unsafe original archive path was accepted")

    @unittest.skipUnless(sys.platform == "linux", "actual Linux early CLI guard runs in CI")
    def test_actual_linux_cli_refuses_existing_packet(self) -> None:
        """Настоящий CLI отказывает до engine; это early guard, не имитация нативного успеха."""
        result = output_guard.run(self.archive, HEAD)
        self.assertEqual(result["exit_code"], 2)
        self.assertFalse(result["real_engine_invoked"])
        self.assertTrue(result["original_archive_unchanged"])
        print("LIGHT QUALITY EARLY CLI GUARD: " + json.dumps(result, sort_keys=True), flush=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
