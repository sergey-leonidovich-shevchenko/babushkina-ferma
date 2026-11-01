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
from unittest.mock import patch

from imageio_ffmpeg import write_frames  # type: ignore[import-untyped]
from PIL import Image

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

    def resign_movie(self) -> None:
        """Update only the movie digest, reproducing a semantically forged proof."""
        proof_path = self.folder / "native/video-proof.json"
        proof = mask.read(proof_path)
        proof["files"]["camera-pan.mp4"] = mask.digest(self.folder / "native/camera-pan.mp4")
        proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")

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

    def test_resigned_plain_text_movie_is_rejected(self) -> None:
        """A matching SHA cannot turn arbitrary bytes into a decodable MP4 stream."""
        movie = self.folder / "native/camera-pan.mp4"
        movie.write_bytes(b"This is plain text, not an MPEG-4 video.\n")
        self.resign_movie()
        self.rejected("encoded video stream")

    def test_resigned_wrong_movie_is_rejected(self) -> None:
        """A valid H.264 video from another task cannot impersonate this 72-frame capture."""
        movie = self.folder / "native/camera-pan.mp4"
        shutil.copyfile(
            mask.ROOT / "docs/reports/visual-overhaul/vshore-002/native/camera-pan.mp4",
            movie,
        )
        self.resign_movie()
        self.rejected("encoded video (stream duration|frame count)")

    def test_resigned_frozen_movie_is_rejected(self) -> None:
        """A real 72-frame H.264 stream must still contain continuous camera movement."""
        movie = self.folder / "native/camera-pan.mp4"
        with Image.open(self.folder / "native/motion-000.png") as image:
            frame = image.convert("RGB").tobytes()
        writer = write_frames(
            str(movie),
            (1152, 648),
            fps=30,
            codec="libx264",
            macro_block_size=1,
            ffmpeg_log_level="error",
        )
        writer.send(None)
        try:
            for _index in range(72):
                writer.send(frame)
        finally:
            writer.close()
        self.resign_movie()
        self.rejected("frozen video sequence")

    def test_wrong_dimensions_are_rejected_before_payload_decode(self) -> None:
        """A wrongly sized stream is rejected before any decoded payload is retained."""
        movie = self.folder / "native/camera-pan.mp4"
        frame = Image.new("RGB", (64, 36), "#224466").tobytes()
        writer = write_frames(
            str(movie),
            (64, 36),
            fps=30,
            codec="libx264",
            macro_block_size=1,
            ffmpeg_log_level="error",
        )
        writer.send(None)
        try:
            for _index in range(72):
                writer.send(frame)
        finally:
            writer.close()
        self.resign_movie()

        payload_reads = 0
        real_read_frames = mask.read_frames

        def tracked_read_frames(*args: Any, **kwargs: Any) -> Any:
            reader = real_read_frames(*args, **kwargs)
            try:
                yield next(reader)
                nonlocal payload_reads
                for payload in reader:
                    payload_reads += 1
                    yield payload
            finally:
                reader.close()

        with patch.object(mask, "read_frames", tracked_read_frames):
            self.rejected("encoded video stream dimensions")
        self.assertEqual(payload_reads, 0)

    def test_commit_option_is_rejected_without_writing(self) -> None:
        """A 40-character Git option is rejected before it can overwrite an external file."""
        outside = tempfile.TemporaryDirectory(prefix="p35", dir="/tmp")
        self.addCleanup(outside.cleanup)
        name = next(iter(mask.read(self.folder / "source.json")["files"]))
        prefix = "--output=" + str(Path(outside.name) / "p")
        self.assertLess(len(prefix), 40)
        commit = prefix + "x" * (40 - len(prefix))
        target = Path(commit.removeprefix("--output=") + ":" + name)
        target.parent.mkdir(parents=True, exist_ok=True)
        sentinel = b"owned temporary sentinel\n"
        target.write_bytes(sentinel)
        for relative in ("profile.json", "source.json"):
            path = self.folder / relative
            data = mask.read(path)
            data["implementation_commit"] = commit
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        self.rejected("implementation commit")
        self.assertEqual(target.read_bytes(), sentinel)

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
