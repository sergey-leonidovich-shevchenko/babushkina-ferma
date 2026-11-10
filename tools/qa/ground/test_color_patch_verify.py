#!/usr/bin/env python3
"""Exact-head provenance regressions for VGROUND-002 workflow artifacts."""

import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.qa.ground import color_patch_verify as verifier
from tools.qa.performance.perf_contract_collect import command, sha
from tools.qa.world.source_inputs import historical_result

SOURCE = "project.godot"


class ColorPatchExactHead(unittest.TestCase):
    """Self-consistent manifests cannot replace the Git blobs of the reviewed head."""

    def test_workflow_uploads_hidden_archived_sources(self) -> None:
        """The evidence archive must retain ``inputs/.github`` from the source envelope."""
        workflow = (verifier.ROOT / ".github/workflows/vground-002.yml").read_text()
        self.assertIn("include-hidden-files: true", workflow)

    def evidence(self, parent: str) -> tuple[Path, str]:
        folder = Path(parent) / "evidence"
        target = folder / "inputs" / SOURCE
        target.parent.mkdir(parents=True)
        head = command(["git", "rev-parse", "HEAD"])
        blob = historical_result(verifier.ROOT, head, SOURCE)
        self.assertEqual(blob.returncode, 0)
        target.write_bytes(blob.stdout)
        digest = hashlib.sha256(blob.stdout).hexdigest()
        source = {
            "task": "VGROUND-002",
            "base_commit": head,
            "head_commit": head,
            "head_tree": command(["git", "rev-parse", "HEAD^{tree}"]),
            "expected_head": head,
            "exact_head": True,
            "complete": True,
            "sources": {SOURCE: digest},
            "base_sources": {SOURCE: digest},
            "head_sources": {SOURCE: digest},
            "artifacts": {},
        }
        (folder / "source.json").write_text(json.dumps(source))
        return folder, head

    def verify_one_source(self, folder: Path, expected_head: str) -> dict:
        with (
            patch.object(verifier, "SOURCES", [SOURCE]),
            patch.object(verifier, "OVERLAY", {SOURCE}),
        ):
            return verifier.provenance(folder, expected_head)

    def test_exact_head_accepts_its_git_blob(self) -> None:
        with tempfile.TemporaryDirectory() as parent:
            folder, head = self.evidence(parent)
            self.assertEqual(self.verify_one_source(folder, head)["head_commit"], head)

    def test_repacked_input_and_recalculated_manifest_digest_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as parent:
            folder, head = self.evidence(parent)
            target = folder / "inputs" / SOURCE
            target.write_bytes(target.read_bytes() + b"\nrepacked")
            source = json.loads((folder / "source.json").read_text())
            source["sources"][SOURCE] = sha(target)
            (folder / "source.json").write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError, "declared Git blob"):
                self.verify_one_source(folder, head)

    def test_evidence_claimed_for_another_expected_head_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as parent:
            folder, _head = self.evidence(parent)
            with self.assertRaisesRegex(ValueError, "another head"):
                self.verify_one_source(folder, "0" * 40)

    def test_virtual_display_requires_x11_but_accepts_godot_spelling(self) -> None:
        self.assertTrue(
            verifier.virtual_display_is_x11({"virtual_display": True, "display": "X11"})
        )
        self.assertTrue(
            verifier.virtual_display_is_x11({"virtual_display": True, "display": "x11"})
        )
        self.assertFalse(
            verifier.virtual_display_is_x11({"virtual_display": True, "display": "Wayland"})
        )
        self.assertFalse(
            verifier.virtual_display_is_x11({"virtual_display": True, "display": "headless"})
        )


if __name__ == "__main__":
    unittest.main()
