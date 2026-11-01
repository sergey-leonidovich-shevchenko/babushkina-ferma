#!/usr/bin/env python3
"""Negative VSHORE-004 checks mutate only disposable evidence copies."""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any

from tools.qa.world import water_chunk_seam as seam


class WaterChunkSeamTests(unittest.TestCase):
    """Exercise provenance, chunk metrics, same-camera frames, motion and review logs."""

    def setUp(self) -> None:
        """Copy the complete evidence packet into an isolated temporary root."""
        self.temporary = tempfile.TemporaryDirectory(prefix="farm-water-chunk-seam-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.folder = self.root / seam.REPORT
        shutil.copytree(seam.ROOT / seam.REPORT, self.folder)

    def change(self, relative: str, edit: Callable[[dict[str, Any]], None]) -> None:
        """Apply one semantic mutation to JSON in the temporary copy."""
        path = self.folder / relative
        data = seam.read(path)
        edit(data)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

    def rejected(self, message: str) -> None:
        """Require an addressable rejection instead of a generic exception."""
        with self.assertRaisesRegex(ValueError, message):
            seam.verify(self.root, require_tracked=False)

    def resign_capture(self) -> None:
        """Update only the capture digest so a semantic forgery reaches its own check."""
        proof_path = self.folder / "native/video-proof.json"
        proof = seam.read(proof_path)
        proof["capture_sha256"] = seam.digest(self.folder / "native/capture.json")
        proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")

    def resign_movie(self) -> None:
        """Update only the movie digest, reproducing a semantically forged proof."""
        proof_path = self.folder / "native/video-proof.json"
        proof = seam.read(proof_path)
        proof["files"]["camera-pan.mp4"] = seam.digest(self.folder / "native/camera-pan.mp4")
        proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")

    def test_complete_packet(self) -> None:
        """The unchanged packet proves pixel equality, a visible control and cached reads."""
        result = seam.verify(self.root, require_tracked=False)
        self.assertEqual(result["native_static_frames"], 6)
        self.assertEqual(result["native_motion_frames"], 60)
        self.assertTrue(result["same_camera_pixel_equal"])
        self.assertEqual(result["internal_shore_edges"], 0)

    def test_empty_source_manifest_is_rejected(self) -> None:
        """Native frames cannot replace implementation provenance."""
        self.change("source.json", lambda data: data.update(files={}))
        self.rejected("source file coverage")

    def test_wrong_source_hash_is_rejected(self) -> None:
        """A later or invented topology cannot impersonate the captured implementation."""

        def edit(data: dict[str, Any]) -> None:
            data["files"]["scripts/systems/water_topology.gd"] = "0" * 64

        self.change("source.json", edit)
        self.rejected("source SHA")

    def test_headless_or_fps_relabel_is_rejected(self) -> None:
        """The fixed-clock QA window cannot become gameplay or performance evidence."""
        self.change(
            "native/capture.json",
            lambda data: data.update(display_server="headless", performance_eligible=True),
        )
        self.resign_capture()
        self.rejected("native display")

    def test_internal_shore_metric_is_rejected(self) -> None:
        """A false edge cannot hide behind otherwise valid chunk counts."""

        def edit(data: dict[str, Any]) -> None:
            data["chunks"]["internal_shore_edges"] = 1

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("chunk metrics")

    def test_cache_rebuild_is_rejected(self) -> None:
        """Repeated reads must not manufacture a frame-time rebuild."""

        def edit(data: dict[str, Any]) -> None:
            data["chunks"]["rebuilds_during_repeated_reads"] = 240

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("chunk metrics")

    def test_mismatched_trio_camera_is_rejected(self) -> None:
        """Global, seam-safe and broken images must use the same camera."""

        def edit(data: dict[str, Any]) -> None:
            next(row for row in data["frames"] if row["id"] == "seam-center-chunk-safe")["camera"][
                0
            ] += 1

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("same-camera trio")

    def test_resigned_mismatched_safe_frame_is_rejected(self) -> None:
        """A re-signed PNG cannot make the safe render differ from the global plan."""
        native = self.folder / "native"
        shutil.copyfile(
            native / "seam-center-isolated-negative.png", native / "seam-center-chunk-safe.png"
        )

        def edit(data: dict[str, Any]) -> None:
            row = next(row for row in data["frames"] if row["id"] == "seam-center-chunk-safe")
            row["sha256"] = seam.digest(native / row["file"])

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("chunk/global mismatch")

    def test_resigned_missing_negative_control_is_rejected(self) -> None:
        """Pixel equality is meaningful only beside a visibly broken isolated control."""
        native = self.folder / "native"
        shutil.copyfile(
            native / "seam-center-global.png", native / "seam-center-isolated-negative.png"
        )

        def edit(data: dict[str, Any]) -> None:
            row = next(
                row for row in data["frames"] if row["id"] == "seam-center-isolated-negative"
            )
            row["sha256"] = seam.digest(native / row["file"])

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("negative control missing")

    def test_frozen_motion_manifest_is_rejected(self) -> None:
        """Repeated frame signatures cannot masquerade as camera movement."""

        def edit(data: dict[str, Any]) -> None:
            for row in data["motion"]:
                row["sha256"] = data["motion"][0]["sha256"]

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("repeated motion frames")

    def test_wrong_motion_trajectory_is_rejected(self) -> None:
        """Ordered filenames do not replace the recorded camera trajectory."""

        def edit(data: dict[str, Any]) -> None:
            data["motion"][30]["camera"][0] += 4

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("motion camera trajectory")

    def test_missing_saved_motion_frame_is_rejected(self) -> None:
        """The manifest and video cannot replace any committed source PNG."""
        (self.folder / "native/frames/0017.png").unlink()
        self.rejected("motion frame SHA: 17")

    def test_resigned_motion_frame_is_rejected(self) -> None:
        """Changing a saved frame and its manifest still breaks the video-bound capture."""
        native = self.folder / "native"
        shutil.copyfile(native / "frames/0018.png", native / "frames/0017.png")

        def edit(data: dict[str, Any]) -> None:
            data["motion"][17]["sha256"] = seam.digest(native / "frames/0017.png")

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("repeated motion frames")

    def test_motion_without_canvas_camera_is_rejected(self) -> None:
        """Camera metadata must agree with the CanvasItem transform used by the capture."""

        def edit(data: dict[str, Any]) -> None:
            data["motion"][12]["board_position"][0] += 8

        self.change("native/capture.json", edit)
        self.resign_capture()
        self.rejected("motion board transform")

    def test_empty_capture_sources_are_rejected(self) -> None:
        """Native PNGs without renderer inputs are incomplete evidence."""
        self.change("native/capture.json", lambda data: data.update(sources={}))
        self.resign_capture()
        self.rejected("capture source coverage")

    def test_wrong_video_metadata_is_rejected(self) -> None:
        """A re-signed one-second label cannot pass as the 60-frame review."""
        self.change("native/camera-pan.json", lambda data: data.update(duration=1))
        proof_path = self.folder / "native/video-proof.json"
        proof = seam.read(proof_path)
        proof["files"]["camera-pan.json"] = seam.digest(self.folder / "native/camera-pan.json")
        proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")
        self.rejected("encoded duration")

    def test_resigned_plain_text_movie_is_rejected(self) -> None:
        """A matching SHA cannot turn arbitrary bytes into an H.264 stream."""
        movie = self.folder / "native/camera-pan.mp4"
        movie.write_bytes(b"This is plain text, not an MPEG-4 video.\n")
        self.resign_movie()
        self.rejected("encoded stream")

    def test_commit_option_is_rejected_without_writing(self) -> None:
        """A 40-character Git option is rejected before it can overwrite another file."""
        outside = tempfile.TemporaryDirectory(prefix="p35", dir="/tmp")
        self.addCleanup(outside.cleanup)
        name = next(iter(seam.read(self.folder / "source.json")["files"]))
        prefix = "--output=" + str(Path(outside.name) / "p")
        self.assertLess(len(prefix), 40)
        commit = prefix + "x" * (40 - len(prefix))
        target = Path(commit.removeprefix("--output=") + ":" + name)
        target.parent.mkdir(parents=True, exist_ok=True)
        sentinel = b"owned temporary sentinel\n"
        target.write_bytes(sentinel)
        for relative in ("profile.json", "source.json"):
            path = self.folder / relative
            data = seam.read(path)
            data["implementation_commit"] = commit
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        self.rejected("implementation commit")
        self.assertEqual(target.read_bytes(), sentinel)

    def test_engine_error_is_rejected(self) -> None:
        """A complete manifest cannot hide a native parse or driver error."""
        path = self.folder / "native/engine.log"
        path.write_text(path.read_text() + "ERROR: simulated failure\n")
        self.rejected("native engine error")

    def test_empty_water_sources_are_rejected(self) -> None:
        """An assertion count cannot replace exact WATER source coverage."""
        self.change("water-review.json", lambda data: data.update(sources={}))
        self.rejected("WATER source coverage")

    def test_water_log_error_is_rejected(self) -> None:
        """A re-signed assertion log still cannot contain a hidden failure."""
        log = self.folder / "water-review.log"
        log.write_text(log.read_text() + "ERROR: simulated WATER failure\n")
        review_path = self.folder / "water-review.json"
        review = seam.read(review_path)
        review["log_sha256"] = seam.digest(log)
        review_path.write_text(json.dumps(review, ensure_ascii=False, indent=2) + "\n")
        self.rejected("WATER engine error")


if __name__ == "__main__":
    unittest.main()
