"""Check the restore CLI against the unchanged VPERF-006 evidence bundle."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
CAPTURE = HERE.parent / "native-ci-01"


class RestoreReceiptTest(unittest.TestCase):
    def test_wrong_blob_count_is_rejected_before_creating_output(self) -> None:
        receipt = json.loads((CAPTURE / "archive.json").read_bytes())
        receipt["bundle"]["unique_blobs"] += 1
        with tempfile.TemporaryDirectory() as directory:
            scratch = Path(directory)
            wrong_receipt = scratch / "archive.json"
            wrong_receipt.write_text(json.dumps(receipt))
            output = scratch / "files"
            process = subprocess.run(
                [
                    sys.executable,
                    str(HERE / "restore.py"),
                    "--bundle",
                    str(CAPTURE / "evidence.bundle.zip"),
                    "--receipt",
                    str(wrong_receipt),
                    "--output",
                    str(output),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(process.returncode, 2, process.stderr)
            self.assertIn("capture blob count differs from the checked-in receipt", process.stderr)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
