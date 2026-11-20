"""Проверяет реальные Git/экспортные границы и отказ producer до запуска движка."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison import contract, exports, provenance
from tools.qa.world.lighting.comparison.publish import publish
from tools.qa.world.lighting.comparison.verify import REPORT


class ContractTests(unittest.TestCase):
    """Использует принятую production-историю и настоящий source manifest новой серии."""

    def test_real_overlays(self) -> None:
        for name, (old, new) in contract.OVERLAYS.items():
            with self.subTest(name=name):
                raw = shared.git("show", contract.BASE + ":" + name)
                changed = contract.instrument(name, raw)
                self.assertNotEqual(raw, changed)
                self.assertEqual(changed.replace(new.encode(), old.encode()), raw)

    def test_owner_change_is_refused(self) -> None:
        for name, (old, _new) in contract.OVERLAYS.items():
            raw = shared.git("show", contract.BASE + ":" + name)
            for damaged in [raw.replace(old.encode(), b""), raw + old.encode()]:
                with self.subTest(name=name), self.assertRaises(ValueError):
                    contract.instrument(name, damaged)

    def test_unknown_overlay_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            contract.instrument(
                "scripts/game.gd", shared.git("show", contract.BASE + ":scripts/game.gd")
            )

    def test_export_inventory_matches_real_git(self) -> None:
        stored = json.loads((REPORT / "exported-blobs.json").read_bytes())
        self.assertEqual(stored, exports.expected_blobs())
        self.assertGreater(len(stored), 1000)
        name = "main.tscn"
        self.assertEqual(
            stored[name], exports.blob_id(shared.git("show", contract.BASE + ":" + name))
        )

    def test_signed_wrong_export_inventory(self) -> None:
        document = json.loads((REPORT / "source.json").read_bytes())
        # Подмена карты и её hash вместе всё равно отклоняется сверкой с настоящим Git.
        with tempfile.TemporaryDirectory(prefix="lantern source ") as folder:
            root = Path(folder)
            import shutil

            for name in ["inputs", "overlays"]:
                shutil.copytree(REPORT / name, root / name)
            changed = json.loads((REPORT / "exported-blobs.json").read_bytes())
            changed["main.tscn"] = "0" * 40
            raw = json.dumps(changed).encode()
            (root / "exported-blobs.json").write_bytes(raw)
            document["exported_blobs_sha256"] = shared.digest(raw)
            with self.assertRaisesRegex(ValueError, "production blob inventory"):
                provenance.check(root, document, False)

    def test_existing_output_cli_has_no_engine_side_effect(self) -> None:
        with tempfile.TemporaryDirectory(prefix="lantern refusal ") as folder:
            folder = str(Path(folder).resolve())
            sentinel = Path(folder) / "sentinel"
            sentinel.write_text("retain")
            result = subprocess.run(
                [
                    sys.executable,
                    str(contract.ROOT / "tools/run.py"),
                    "qa.world.lighting.comparison.collect",
                    "--output",
                    folder,
                ],
                cwd=folder,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("fresh external output", result.stderr)
            self.assertEqual(sentinel.read_text(), "retain")
            self.assertEqual([p.name for p in Path(folder).iterdir()], ["sentinel"])

    def test_existing_publication_is_untouched(self) -> None:
        source = (REPORT / "source.json").read_bytes()
        with self.assertRaisesRegex(ValueError, "fresh native publication"):
            publish(Path("/not/a/capture"), REPORT)
        self.assertEqual((REPORT / "source.json").read_bytes(), source)


if __name__ == "__main__":
    unittest.main()
