#!/usr/bin/env python3
"""Negative VSHORE-002 checks mutate only disposable evidence copies."""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any

from tools.qa.world import underwater_bottom as bottom


class UnderwaterBottomTests(unittest.TestCase):
    """Exercise provenance, native classification, cameras, motion and video."""

    def setUp(self) -> None:
        """Copy the packet and every source named by its native manifest."""
        self.temporary = tempfile.TemporaryDirectory(prefix="farm-underwater-bottom-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.folder = self.root / bottom.REPORT
        shutil.copytree(bottom.ROOT / bottom.REPORT, self.folder)
        capture = bottom.read(self.folder / "native/capture.json")
        for uri in capture["sources"]:
            relative = Path(uri.removeprefix("res://"))
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(bottom.ROOT / relative, target)
        source = bottom.read(self.folder / "source.json")
        for name in source["files"]:
            original = (bottom.ROOT / bottom.REPORT / name).resolve()
            target = self.root / original.relative_to(bottom.ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                shutil.copyfile(original, target)
        review = bottom.read(self.folder / "water-review.json")
        review_sources = [*review["sources"], "tools/qa/world/underwater_bottom_review.gd"]
        for name in review_sources:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                shutil.copyfile(bottom.ROOT / name, target)
        runtime = self.root / "assets/game/locations/overworld/modular/riverbed_material_v1.png"
        shutil.copyfile(
            bottom.ROOT / "assets/game/locations/overworld/modular/riverbed_material_v1.png.import",
            runtime.with_suffix(runtime.suffix + ".import"),
        )
        region = Path("scripts/presentation/village_region_terrain.gd")
        (self.root / region).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(bottom.ROOT / region, self.root / region)

    def change(self, relative: str, edit: Callable[[dict[str, Any]], None]) -> None:
        """Apply one semantic mutation to JSON in the temporary copy."""
        path = self.folder / relative
        data = bottom.read(path)
        edit(data)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

    def rejected(self, message: str) -> None:
        """Require an addressable rejection rather than any generic exception."""
        with self.assertRaisesRegex(ValueError, message):
            bottom.verify(self.root, require_tracked=False)

    def test_complete_packet(self) -> None:
        """The unchanged packet proves runtime integration without physics or FPS claims."""
        result = bottom.verify(self.root, require_tracked=False)
        self.assertEqual(result["native_static_frames"], 11)
        self.assertEqual(result["native_motion_frames"], 90)
        self.assertFalse(result["physical_authority"])
        self.assertFalse(result["performance_eligible"])

    def test_runtime_image_replacement_is_rejected(self) -> None:
        """A visually similar but byte-different runtime file cannot replace the selected master."""
        runtime = self.root / "assets/game/locations/overworld/modular/riverbed_material_v1.png"
        runtime.write_bytes(runtime.read_bytes() + b"changed")
        self.rejected("source SHA")

    def test_headless_or_fps_relabel_is_rejected(self) -> None:
        """A headless frame or fixed-clock video cannot be promoted to native FPS evidence."""
        self.change(
            "native/capture.json",
            lambda data: data.update(display_server="headless", performance_eligible=True),
        )
        self.rejected("native display")

    def test_mismatched_pair_camera_is_rejected(self) -> None:
        """Before/after evidence must use the exact same camera coordinates."""

        def edit(data: dict[str, Any]) -> None:
            next(row for row in data["frames"] if row["id"] == "pond-after")["camera"][0] += 1

        self.change("native/capture.json", edit)
        self.rejected("same-camera pair")

    def test_frozen_motion_is_rejected(self) -> None:
        """Ninety repeated signatures cannot masquerade as a camera seam review."""

        def edit(data: dict[str, Any]) -> None:
            for row in data["motion"]:
                row["sha256"] = data["motion"][0]["sha256"]

        self.change("native/capture.json", edit)
        self.rejected("repeated motion frames")

    def test_wrong_video_metadata_is_rejected(self) -> None:
        """The encoded dimensions and duration are checked independently of the MP4 name."""
        self.change("native/camera-pan.json", lambda data: data.update(width=640, duration=1))
        self.rejected("video SHA")

    def test_resigned_video_metadata_still_fails_semantics(self) -> None:
        """Re-signing a bad local JSON cannot turn a one-second file into accepted evidence."""
        self.change("native/camera-pan.json", lambda data: data.update(duration=1))
        proof_path = self.folder / "native/video-proof.json"
        proof = bottom.read(proof_path)
        proof["files"]["camera-pan.json"] = bottom.digest(self.folder / "native/camera-pan.json")
        proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")
        self.rejected("encoded video metadata")

    def test_engine_error_is_rejected(self) -> None:
        """A completed manifest does not hide a native parse or driver error."""
        path = self.folder / "native/engine.log"
        path.write_text(path.read_text() + "ERROR: simulated failure\n")
        self.rejected("native engine error")

    def test_water_log_error_is_rejected(self) -> None:
        """A re-signed assertion log still cannot contain a hidden engine failure."""
        log_path = self.folder / "water-review.log"
        log_path.write_text(log_path.read_text() + "ERROR: simulated WATER failure\n")
        review_path = self.folder / "water-review.json"
        review = bottom.read(review_path)
        review["log_sha256"] = bottom.digest(log_path)
        review_path.write_text(json.dumps(review, ensure_ascii=False, indent=2) + "\n")
        self.rejected("WATER engine error")

    def test_capture_source_mutation_is_rejected(self) -> None:
        """The retained mesh implementation stays bound to the code used for capture."""
        path = self.root / "scripts/presentation/underwater_bottom.gd"
        path.write_text(path.read_text() + "\n# changed after capture\n")
        self.rejected("capture source SHA")

    def test_empty_capture_sources_are_rejected(self) -> None:
        """A packet cannot drop every runtime source and remain reviewable."""
        self.change("native/capture.json", lambda data: data.update(sources={}))
        self.rejected("capture source coverage")

    def test_missing_capture_source_is_rejected(self) -> None:
        """Dropping only the retained renderer is also incomplete source coverage."""

        def edit(data: dict[str, Any]) -> None:
            data["sources"].pop("res://scripts/presentation/underwater_bottom.gd")

        self.change("native/capture.json", edit)
        self.rejected("capture source coverage")

    def test_empty_video_files_are_rejected(self) -> None:
        """The proof must name the MP4, decoded frame and encoded metadata explicitly."""
        self.change("native/video-proof.json", lambda data: data.update(files={}))
        self.rejected("video file coverage")

    def test_missing_video_file_is_rejected(self) -> None:
        """A decoded preview and metadata cannot stand in for the required MP4."""

        def edit(data: dict[str, Any]) -> None:
            data["files"].pop("camera-pan.mp4")

        self.change("native/video-proof.json", edit)
        self.rejected("video file coverage")

    def test_empty_water_sources_are_rejected(self) -> None:
        """A passing assertion count cannot replace the exact WATER source set."""
        self.change("water-review.json", lambda data: data.update(sources={}))
        self.rejected("WATER source coverage")

    def test_missing_water_source_is_rejected(self) -> None:
        """Every suite contributing to the WATER count remains named and hashed."""

        def edit(data: dict[str, Any]) -> None:
            data["sources"].pop("tests/suites/water_visual_suite.gd")

        self.change("water-review.json", edit)
        self.rejected("WATER source coverage")

    def test_separate_river_map_integration_is_rejected(self) -> None:
        """VSHORE-002 stays on the first overworld instead of changing village_river."""
        path = self.root / "scripts/presentation/village_region_terrain.gd"
        path.write_text(path.read_text() + "\ndraw_underwater_rect(canvas, Data.WATER\n")
        self.rejected("underwater bottom escaped first overworld")


if __name__ == "__main__":
    unittest.main()
