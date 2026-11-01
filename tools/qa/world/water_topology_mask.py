#!/usr/bin/env python3
"""Verify the VSHORE-003 topology-owned water mask and its native evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path
from typing import Any

from imageio_ffmpeg import count_frames_and_secs, read_frames  # type: ignore[import-untyped]
from PIL import Image, ImageChops, ImageStat

from tools.common.git import git_environment
from tools.common.history import read_git_blob
from tools.common.paths import project_root

ROOT = project_root(__file__)
REPORT = Path("docs/reports/visual-overhaul/vshore-003")
TASK = "VSHORE-003"
PAIR_NAMES = ("bridge-west", "river-turn", "pond", "chunk-boundary")
WITNESS_FRAMES = (0, 36, 71)
VIDEO_FILES = {"camera-pan.mp4", "camera-pan.json", "camera-pan.decoded.png"}
SOURCE_FILES = {
    "scripts/systems/water_layout_data.gd",
    "scripts/systems/water_topology.gd",
    "scripts/systems/water_map_registry.gd",
    "scripts/systems/village_terrain_renderer.gd",
    "scripts/systems/water_visual_system.gd",
}
CAPTURE_SOURCES = {
    "res://assets/game/locations/overworld/modular/riverbed_material_v1.png",
    "res://assets/game/locations/overworld/modular/water_material_v1.png",
    "res://scripts/presentation/underwater_bottom.gd",
    "res://scripts/systems/village_terrain_renderer.gd",
    "res://scripts/systems/water_layout_data.gd",
    "res://scripts/systems/water_map_registry.gd",
    "res://scripts/systems/water_topology.gd",
    "res://scripts/systems/water_visual_system.gd",
    "res://tools/qa/world/water_topology_mask_board.gd",
    "res://tools/qa/world/water_topology_mask_capture.gd",
}
WATER_SOURCES = {
    "tests/suites/water_topology_suite.gd",
    "tests/suites/water_navigation_suite.gd",
    "tests/suites/water_fishing_suite.gd",
    "tests/suites/water_visual_suite.gd",
    "scripts/presentation/underwater_bottom.gd",
    "scripts/systems/village_terrain_renderer.gd",
    "scripts/systems/water_visual_system.gd",
    "scripts/systems/water_map_registry.gd",
    "scripts/systems/water_topology.gd",
}
EXPECTED_TOPOLOGY = {
    "revision": 5,
    "cells": 550,
    "regions": 2,
    "polygons": 1,
    "shore_spans": 20,
    "visual_builds": 1,
    "repeated_reads": 120,
    "rebuilds_during_repeated_reads": 0,
    "bridge_surface": [True, True],
    "chunk_boundary_surface": [True, True],
}


def digest(path: Path) -> str:
    """Hash exact artifact bytes."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict[str, Any]:
    """Read one required JSON object."""
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"JSON object required: {path}")
    return value


def require(condition: bool, message: str) -> None:
    """Reject incomplete evidence with an addressable message."""
    if not condition:
        raise ValueError(message)


def local(root: Path, folder: Path, value: str) -> Path:
    """Resolve a report-relative path without allowing project escape."""
    require(isinstance(value, str) and not Path(value).is_absolute(), "absolute artifact path")
    path = (folder / value).resolve()
    require(path.is_relative_to(root.resolve()), "artifact path escapes project")
    return path


def tracked(root: Path, paths: list[Path]) -> bool:
    """Distinguish committed evidence from workstation-only files."""
    relative = [str(path.resolve().relative_to(root.resolve())) for path in paths]
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", "--", *relative],
        cwd=root,
        capture_output=True,
        check=False,
        env=git_environment(),
    )
    return result.returncode == 0


def historical_bytes(root: Path, commit: str, name: str, expected: str) -> bytes:
    """Read one full-hex-pinned regular blob without accepting Git options."""
    history_root = root if (root / ".git").exists() else ROOT
    require(bool(re.fullmatch(r"[0-9a-f]{40}", commit)), "implementation commit")
    try:
        return read_git_blob(history_root, name, commit, expected)
    except ValueError as error:
        raise ValueError(f"historical source unavailable: {name}") from error


def historical(root: Path, commit: str, name: str, expected: str) -> bool:
    """Bind one manifest row to exact Git bytes."""
    try:
        historical_bytes(root, commit, name, expected)
    except ValueError:
        return False
    return True


def changed_pixels(first: Path, second: Path) -> int:
    """Count actual RGBA differences in a same-camera pair."""
    with Image.open(first) as before, Image.open(second) as after:
        require(before.size == after.size == (1152, 648), "native frame dimensions")
        difference = ImageChops.difference(before.convert("RGBA"), after.convert("RGBA"))
        mask = ImageChops.lighter(
            ImageChops.lighter(difference.getchannel("R"), difference.getchannel("G")),
            ImageChops.lighter(difference.getchannel("B"), difference.getchannel("A")),
        )
        return sum(mask.histogram()[1:])


def verify_sources(root: Path, folder: Path, profile: dict[str, Any]) -> None:
    """Bind canonical plan, topology and consumers to the implementation commit."""
    source = read(folder / "source.json")
    commit = profile["implementation_commit"]
    require(source.get("task") == TASK, "source task")
    require(source.get("implementation_commit") == commit, "source implementation commit")
    require(
        source.get("canonical_plan") == "scripts/systems/water_layout_data.gd", "canonical plan"
    )
    files = source.get("files")
    if not isinstance(files, dict) or set(files) != SOURCE_FILES:
        raise ValueError("source file coverage")
    historical_files: dict[str, bytes] = {}
    for name, expected in files.items():
        try:
            historical_files[name] = historical_bytes(root, commit, name, expected)
        except ValueError as error:
            raise ValueError(f"source SHA: {name}") from error

    topology = historical_files["scripts/systems/water_topology.gd"].decode()
    registry = historical_files["scripts/systems/water_map_registry.gd"].decode()
    renderer = historical_files["scripts/systems/village_terrain_renderer.gd"].decode()
    visual = historical_files["scripts/systems/water_visual_system.gd"].decode()
    require("Geometry2D.merge_polygons" in topology, "surface polygons are not merged")
    require(
        "_visual_revision" in topology and "visual_builds" in topology, "revision cache missing"
    )
    require("func visual(location: String)" in registry, "registry visual API missing")
    require("WaterMapRegistry.visual" in renderer, "renderer bypasses registry")
    require("MapData.river_polygon" not in renderer, "renderer keeps a separate river mask")
    require(
        "WaterMapRegistry.geometry" in visual and "WaterMapRegistry.has_surface" in visual,
        "ambient water bypasses registry",
    )


def verify_static_frames(root: Path, native: Path, capture: dict[str, Any]) -> None:
    """Verify four same-camera diagnostic/runtime pairs."""
    expected_ids = {
        *(f"{name}-topology" for name in PAIR_NAMES),
        *(f"{name}-runtime" for name in PAIR_NAMES),
    }
    frames = capture.get("frames")
    if not isinstance(frames, list) or len(frames) != 8:
        raise ValueError("static coverage")
    by_id = {row.get("id"): row for row in frames}
    require(set(by_id) == expected_ids and len(by_id) == len(frames), "static frame IDs")
    for row in frames:
        path = local(root, native, row["file"])
        require(path.is_file() and digest(path) == row["sha256"], f"static frame SHA: {row['id']}")
        require(row.get("repeat_equal") is True, f"unstable readback: {row['id']}")
        with Image.open(path) as image:
            require(image.size == (1152, 648), f"static frame size: {row['id']}")
    for name in PAIR_NAMES:
        topology = by_id[f"{name}-topology"]
        runtime = by_id[f"{name}-runtime"]
        require(topology["camera"] == runtime["camera"], f"same-camera pair: {name}")
        require(
            changed_pixels(native / topology["file"], native / runtime["file"]) > 20_000,
            f"diagnostic/runtime distinction: {name}",
        )


def verify_motion(root: Path, native: Path, capture: dict[str, Any]) -> None:
    """Verify a real moving-camera sequence and three committed witnesses."""
    motion = capture.get("motion")
    if not isinstance(motion, list) or len(motion) != 72:
        raise ValueError("motion coverage")
    require(len({row.get("sha256") for row in motion}) == len(motion), "repeated motion frames")
    start = (288.0, 18.0)
    finish = (1368.0, 618.0)
    for index, row in enumerate(motion):
        require(row.get("frame") == index, "motion frame order")
        require(row.get("file") == f"frames/{index:04d}.png", "motion frame path")
        phase = index / (len(motion) - 1)
        expected = [start[axis] + (finish[axis] - start[axis]) * phase for axis in range(2)]
        require(
            all(
                math.isclose(row["camera"][axis], expected[axis], abs_tol=0.002)
                for axis in range(2)
            ),
            "motion camera trajectory",
        )
    for index in WITNESS_FRAMES:
        witness = native / f"motion-{index:03d}.png"
        require(
            witness.is_file() and digest(witness) == motion[index]["sha256"], "motion witness SHA"
        )
        with Image.open(witness) as image:
            require(image.size == (1152, 648), "motion witness dimensions")


def _decoder_process(reader: Any, seen: set[int] | None = None) -> Any:
    """Find imageio-ffmpeg's process through an optional observing generator."""
    visited = seen if seen is not None else set()
    if id(reader) in visited:
        return None
    visited.add(id(reader))
    frame = getattr(reader, "gi_frame", None)
    if frame is None:
        return None
    process = frame.f_locals.get("process")
    if process is not None:
        return process
    for value in frame.f_locals.values():
        if getattr(value, "gi_frame", None) is not None:
            process = _decoder_process(value, visited)
            if process is not None:
                return process
    return None


def _close_decoder(reader: Any) -> None:
    """Close the decoder and imageio's pipes even when ffmpeg already exited."""
    process = _decoder_process(reader)
    try:
        reader.close()
    finally:
        if process is not None:
            for pipe_name in ("stdin", "stdout"):
                pipe = getattr(process, pipe_name, None)
                if pipe is not None and not pipe.closed:
                    pipe.close()
            try:
                process.wait(timeout=2.0)
            except subprocess.TimeoutExpired:  # pragma: no cover - imageio enforces a timeout
                process.kill()
                process.wait(timeout=2.0)


def verify_video(root: Path, native: Path, capture: dict[str, Any]) -> None:
    """Decode the current H.264 bytes and bind their real motion to three witnesses."""
    video = read(native / "video-proof.json")
    motion = capture["motion"]
    chain = hashlib.sha256("\n".join(row["sha256"] for row in motion).encode()).hexdigest()
    require(video.get("task") == TASK, "video task")
    require(video.get("capture_sha256") == digest(native / "capture.json"), "video capture SHA")
    require(video.get("frame_chain_sha256") == chain, "video frame chain")
    files = video.get("files")
    if not isinstance(files, dict) or set(files) != VIDEO_FILES:
        raise ValueError("video file coverage")
    for name, expected in files.items():
        path = local(root, native, name)
        require(path.is_file() and digest(path) == expected, f"video SHA: {name}")
    encoded = read(native / "camera-pan.json")
    expected = {"width": 1152, "height": 648, "frames": 72, "fps": 30}
    require(
        all(encoded.get(key) == value for key, value in expected.items()), "encoded video metadata"
    )
    require(math.isclose(encoded.get("duration", 0), 2.4, abs_tol=0.001), "encoded video duration")

    reader = None
    signatures: set[bytes] = set()
    minimum_change = math.inf
    maximum_change = 0.0
    previous_frame: Image.Image | None = None
    witness_frames: dict[int, Image.Image] = {}
    try:
        actual_frames, actual_duration = count_frames_and_secs(str(native / "camera-pan.mp4"))
        require(actual_frames == 72, "encoded video frame count")
        require(
            math.isclose(actual_duration, 2.4, abs_tol=0.01),
            "encoded video stream duration",
        )
        reader = read_frames(str(native / "camera-pan.mp4"), pix_fmt="rgb24")
        stream = next(reader)
        require(stream.get("codec") == "h264", "encoded video codec")
        require(tuple(stream.get("size", ())) == (1152, 648), "encoded video stream dimensions")
        require(math.isclose(float(stream.get("fps", 0)), 30.0, abs_tol=0.01), "encoded video fps")
        require(
            math.isclose(float(stream.get("duration", 0)), 2.4, abs_tol=0.01),
            "encoded video stream duration",
        )
        for index in range(72):
            frame_bytes = next(reader)
            require(len(frame_bytes) == 1152 * 648 * 3, "encoded video frame bytes")
            frame = Image.frombytes("RGB", (1152, 648), frame_bytes)
            signatures.add(hashlib.sha256(frame.resize((64, 36)).tobytes()).digest())
            if previous_frame is not None:
                change = (
                    sum(ImageStat.Stat(ImageChops.difference(previous_frame, frame)).mean) / 3.0
                )
                minimum_change = min(minimum_change, change)
                maximum_change = max(maximum_change, change)
            if index in WITNESS_FRAMES:
                witness_frames[index] = frame
            previous_frame = frame
    except (OSError, RuntimeError, StopIteration) as error:
        raise ValueError("encoded video stream cannot be decoded") from error
    finally:
        if reader is not None:
            _close_decoder(reader)
    require(len(signatures) == 72, "frozen video sequence")
    require(minimum_change > 2.0, "frozen video sequence")
    require(maximum_change / minimum_change < 2.5, "discontinuous video sequence")
    for index in WITNESS_FRAMES:
        with Image.open(native / f"motion-{index:03d}.png") as witness:
            difference = ImageChops.difference(witness_frames[index], witness.convert("RGB"))
            require(max(ImageStat.Stat(difference).mean) < 5.0, "decoded motion witness mismatch")
    with Image.open(native / "camera-pan.decoded.png") as decoded:
        require(decoded.size == (1152, 648), "decoded video frame dimensions")
        difference = ImageChops.difference(decoded.convert("RGB"), witness_frames[0])
        require(max(ImageStat.Stat(difference).mean) < 5.0, "decoded first frame mismatch")


def verify_native(root: Path, folder: Path, profile: dict[str, Any]) -> None:
    """Verify the native classification, topology metrics, frames and clean engine log."""
    native = folder / "native"
    capture = read(native / "capture.json")
    require(capture.get("task") == TASK, "capture task")
    require(capture.get("kind") == "native-water-topology-mask-study", "capture kind")
    require(
        capture.get("display_server") == "macOS" and bool(capture.get("adapter")), "native display"
    )
    require(capture.get("runtime_integration") is True, "runtime integration missing")
    require(capture.get("native_gameplay") is False, "capture mislabelled as gameplay")
    require(capture.get("performance_eligible") is False, "capture mislabelled as FPS evidence")
    require(capture.get("fixed_clock_video") is True, "fixed clock classification")
    for key in ("target", "field", "zoom"):
        require(capture.get(key) == profile[key], f"native {key}")
    require(capture.get("topology") == EXPECTED_TOPOLOGY, "topology metrics")

    sources = capture.get("sources")
    if not isinstance(sources, dict) or set(sources) != CAPTURE_SOURCES:
        raise ValueError("capture source coverage")
    commit = profile["implementation_commit"]
    for name, expected in sources.items():
        require(name.startswith("res://"), "capture source URI")
        require(
            historical(root, commit, name.removeprefix("res://"), expected),
            f"capture source SHA: {name}",
        )

    verify_static_frames(root, native, capture)
    verify_motion(root, native, capture)
    verify_video(root, native, capture)
    engine = (native / "engine.log").read_text()
    require(
        "WATER TOPOLOGY CAPTURE: 8 static frames and 72 camera frames; not FPS" in engine,
        "capture completion",
    )
    require(
        not any(marker in engine for marker in ("ERROR:", "SCRIPT ERROR", "Parse Error", "FAIL:")),
        "native engine error",
    )


def verify_water_review(root: Path, folder: Path, profile: dict[str, Any]) -> None:
    """Bind all 871 WATER assertions to the exact runner, sources and clean log."""
    review = read(folder / "water-review.json")
    commit = profile["implementation_commit"]
    require(review.get("task") == TASK, "WATER review task")
    require(review.get("implementation_commit") == commit, "WATER implementation commit")
    require(review.get("passed") == 871 and review.get("failed") == 0, "WATER result")
    runner = "tools/qa/world/water_topology_mask_review.gd"
    require(historical(root, commit, runner, review.get("runner_sha256", "")), "WATER runner SHA")
    sources = review.get("sources")
    if not isinstance(sources, dict) or set(sources) != WATER_SOURCES:
        raise ValueError("WATER source coverage")
    for name, expected in sources.items():
        require(historical(root, commit, name, expected), f"WATER source SHA: {name}")
    log = folder / "water-review.log"
    require(review.get("log_sha256") == digest(log), "WATER log SHA")
    text = log.read_text()
    require("WATER TOPOLOGY MASK: 871 passed, 0 failed" in text, "WATER completion")
    require(
        not any(marker in text for marker in ("ERROR:", "SCRIPT ERROR", "Parse Error", "FAIL:")),
        "WATER engine error",
    )


def verify(root: Path = ROOT, *, require_tracked: bool = True) -> dict[str, Any]:
    """Verify the complete VSHORE-003 packet without regenerating artifacts."""
    folder = root / REPORT
    profile = read(folder / "profile.json")
    require(profile.get("task") == TASK, "profile task")
    require(profile.get("status") == "review_candidate", "profile status")
    commit = profile.get("implementation_commit")
    require(
        isinstance(commit, str) and bool(re.fullmatch(r"[0-9a-f]{40}", commit)),
        "implementation commit",
    )
    require(profile.get("runtime_integration") is True, "runtime profile")
    require(profile.get("physical_authority") is True, "topology authority")
    require(profile.get("performance_eligible") is False, "performance claim")
    require(profile.get("native_static_frames") == 8, "profile static coverage")
    require(profile.get("native_motion_frames") == 72, "profile motion coverage")
    verify_sources(root, folder, profile)
    verify_native(root, folder, profile)
    verify_water_review(root, folder, profile)
    if require_tracked:
        required = [path for path in folder.rglob("*") if path.is_file()]
        required.extend(
            [
                root / "tools/qa/world/water_topology_mask.py",
                root / "tools/qa/world/test_water_topology_mask.py",
                root / "wiki/articles/water-topology-mask.md",
            ]
        )
        require(tracked(root, required), "critical VSHORE-003 evidence is not in Git index")
    return {
        "task": TASK,
        "native_static_frames": 8,
        "native_motion_frames": 72,
        "topology_cells": 550,
        "surface_polygons": 1,
        "rebuilds_during_repeated_reads": 0,
        "performance_eligible": False,
    }


def main() -> None:
    """Expose a read-only CLI; capture remains an explicit native action."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-untracked", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(verify(require_tracked=not args.allow_untracked), ensure_ascii=False, indent=2)
    )


if __name__ == "__main__":
    main()
