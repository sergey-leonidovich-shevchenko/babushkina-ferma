"""Keep the native river proof tied to its exact source set and Git ancestry."""

from __future__ import annotations

import hashlib
import json
import subprocess
import unittest

from tools.common.git import git_environment
from tools.qa.world.river_flow import REPORTS, ROOT, verify_capture

REPORT = REPORTS / "vshore-006/native/capture.json"
IMPLEMENTATION = "c874df4892fce54a81b4e21e39595e749898a526"
OTHER_BASE = "b89624d7729066280709fb65c8baafa566c8e91a"


class RiverFlowProvenanceTests(unittest.TestCase):
    """Take each mutated copy from the actual native capture."""

    def test_native_sources_and_base_are_verified(self) -> None:
        """The captured source set matches the exact published implementation."""
        verify_capture(json.loads(REPORT.read_text()), IMPLEMENTATION)

    def test_substituted_real_git_blob_is_rejected(self) -> None:
        """Nineteen valid blobs still fail when an actual capture dependency is missing."""
        capture = json.loads(REPORT.read_text())
        replacement = "scripts/systems/presentation_pose_system.gd"
        blob = subprocess.check_output(
            [
                "git",
                "--no-replace-objects",
                "-C",
                str(ROOT),
                "show",
                f"{IMPLEMENTATION}:{replacement}",
            ],
            env=git_environment(),
        )
        del capture["sources"]["scripts/presentation/village_ground_clock.gd"]
        capture["sources"][replacement] = hashlib.sha256(blob).hexdigest()
        with self.assertRaisesRegex(ValueError, "exact source paths"):
            verify_capture(capture, IMPLEMENTATION)

    def test_missing_commit_is_rejected(self) -> None:
        """A syntactically valid SHA must name a commit object in the project."""
        capture = json.loads(REPORT.read_text())
        capture["base"] = "a" * 40
        with self.assertRaisesRegex(ValueError, "base must be a Git commit"):
            verify_capture(capture, IMPLEMENTATION)

    def test_real_unrelated_base_is_rejected(self) -> None:
        """A real merge on main cannot be the base of an earlier implementation."""
        capture = json.loads(REPORT.read_text())
        capture["base"] = OTHER_BASE
        with self.assertRaisesRegex(ValueError, "base is not an ancestor"):
            verify_capture(capture, IMPLEMENTATION)


if __name__ == "__main__":
    unittest.main()
