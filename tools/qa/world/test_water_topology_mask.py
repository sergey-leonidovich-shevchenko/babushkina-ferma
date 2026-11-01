#!/usr/bin/env python3
"""Negative VSHORE-003 checks mutate only disposable evidence copies."""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any

from tools.qa.world import water_topology_mask as mask


class WaterTopologyMaskTests(unittest.TestCase):
    """Exercise provenance, native classification, topology, cameras and video."""

    def setUp(self) -> None:
        """Copy the complete evidence packet into an isolated temporary root."""
        self.temporary = tempfile.TemporaryDirectory(prefix="farm-water-topology-mask-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.folder = self.root / mask.REPORT
        shutil.copytree(mask.ROOT / mask.REPORT, self.folder)

    def change(self, relative: str, edit: Callable[[dict[str, Any]], None]) -> None:
        """Apply one semantic mutation to JSON in the temporary copy."""
        path = self.folder / relative
        data = mask.read(path)
        edit(data)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

    def rejected(self, message: str) -> None:
        """Require an addressable rejection instead of a generic exception."""
        with self.assertRaisesRegex(ValueError, message):
            mask.verify(self.root, require_tracked=False)

    def test_complete_packet(self) -> None:
        """The unchanged packet proves one cached topology-owned visual mask."""
        result = mask.verify(self.root, require_tracked=False)
        self.assertEqual(result["native_static_frames"], 8)
        self.assertEqual(result["native_motion_frames"], 72)
        self.assertEqual(result["rebuilds_during_repeated_reads"], 0)
        self.assertFalse(result["performance_eligible"])

    def test_empty_source_manifest_is_rejected(self) -> None:
        """A passing capture cannot replace canonical source provenance."""
        self.change("source.json", lambda data: data.update(files={}))
        self.rejected("source file coverage")

    def test_wrong_source_hash_is_rejected(self) -> None:
        """Re-signing a later topology as the implementation source is rejected."""

        def edit(data: dict[str, Any]) -> None:
            data["files"]["scripts/systems/water_topology.gd"] = "0" * 64

        self.change("source.json", edit)
        self.rejected("source SHA")

    def test_headless_or_fps_relabel_is_rejected(self) -> None:
        """A fixed-clock QA capture cannot become gameplay or FPS evidence."""
        self.change(
            "native/capture.json",
            lambda data: data.update(display_server="headless", performance_eligible=True),
        )
        self.rejected("native display")

    def test_bridge_surface_removal_is_rejected(self) -> None:
        """Both bridge decks must preserve their canonical water cells."""

        def edit(data: dict[str, Any]) -> None:
            data["topology"]["bridge_surface"] = [True, False]

        self.change("native/capture.json", edit)
        self.rejected("topology metrics")

    def test_cache_rebuild_is_rejected(self) -> None:
        """Repeated reads cannot hide an accidental per-read rebuild."""

        def edit(data: dict[str, Any]) -> None:
            data["topology"]["rebuilds_during_repeated_reads"] = 120

        self.change("native/capture.json", edit)
        self.rejected("topology metrics")

    def test_mismatched_pair_camera_is_rejected(self) -> None:
        """Diagnostic and production frames must use the same camera."""

        def edit(data: dict[str, Any]) -> None:
            next(row for row in data["frames"] if row["id"] == "pond-runtime")["camera"][0] += 1

        self.change("native/capture.json", edit)
        self.rejected("same-camera pair")

    def test_frozen_motion_is_rejected(self) -> None:
        """Repeated signatures cannot masquerade as a moving-camera review."""

        def edit(data: dict[str, Any]) -> None:
            for row in data["motion"]:
                row["sha256"] = data["motion"][0]["sha256"]

        self.change("native/capture.json", edit)
        self.rejected("repeated motion frames")

    def test_wrong_motion_trajectory_is_rejected(self) -> None:
        """Frame order alone cannot replace the recorded camera path."""

        def edit(data: dict[str, Any]) -> None:
            data["motion"][36]["camera"][1] += 4

        self.change("native/capture.json", edit)
        self.rejected("motion camera trajectory")

    def test_empty_capture_sources_are_rejected(self) -> None:
        """Native PNGs without their complete renderer inputs are incomplete."""
        self.change("native/capture.json", lambda data: data.update(sources={}))
        self.rejected("capture source coverage")

    def test_wrong_video_metadata_is_rejected(self) -> None:
        """A re-signed one-second file cannot pass as the 72-frame review."""
        self.change("native/camera-pan.json", lambda data: data.update(duration=1))
        proof_path = self.folder / "native/video-proof.json"
        proof = mask.read(proof_path)
        proof["files"]["camera-pan.json"] = mask.digest(self.folder / "native/camera-pan.json")
        proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")
        self.rejected("encoded video duration")

    def test_empty_video_files_are_rejected(self) -> None:
        """The MP4, metadata and decoded witness are all mandatory."""
        self.change("native/video-proof.json", lambda data: data.update(files={}))
        self.rejected("video file coverage")

    def test_engine_error_is_rejected(self) -> None:
        """A complete manifest cannot hide a native parse or driver error."""
        path = self.folder / "native/engine.log"
        path.write_text(path.read_text() + "ERROR: simulated failure\n")
        self.rejected("native engine error")

    def test_empty_water_sources_are_rejected(self) -> None:
        """An assertion count cannot replace the exact WATER source set."""
        self.change("water-review.json", lambda data: data.update(sources={}))
        self.rejected("WATER source coverage")

    def test_water_log_error_is_rejected(self) -> None:
        """A re-signed assertion log still cannot contain a hidden failure."""
        log = self.folder / "water-review.log"
        log.write_text(log.read_text() + "ERROR: simulated WATER failure\n")
        review_path = self.folder / "water-review.json"
        review = mask.read(review_path)
        review["log_sha256"] = mask.digest(log)
        review_path.write_text(json.dumps(review, ensure_ascii=False, indent=2) + "\n")
        self.rejected("WATER engine error")


if __name__ == "__main__":
    unittest.main()
