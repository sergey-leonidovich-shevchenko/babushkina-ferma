#!/usr/bin/env python3
"""Verify the VSHORE-004 seam-safe chunk contract and native evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path
from typing import Any

from imageio_ffmpeg import count_frames_and_secs, read_frames, write_frames  # type: ignore[import-untyped]
from PIL import Image, ImageChops, ImageStat

from tools.common.git import git_environment
from tools.common.history import read_git_blob
from tools.common.paths import project_root

ROOT = project_root(__file__)
REPORT = Path("docs/reports/visual-overhaul/vshore-004")
TASK = "VSHORE-004"
CAMERAS = ("seam-center", "seam-east")
MODES = ("global", "chunk-safe", "isolated-negative")
WITNESS_FRAMES = (0, 30, 59)
VIDEO_FILES = {"camera-pan.mp4", "camera-pan.json", "camera-pan.decoded.png"}
SOURCE_FILES = {
    "scripts/systems/water_map_registry.gd",
    "scripts/systems/water_topology.gd",
    "scripts/systems/water_visual_system.gd",
}
CAPTURE_SOURCES = {
    "res://assets/game/tiles/editor/water/water_clear.png",
    "res://scripts/systems/village_terrain_renderer.gd",
    "res://scripts/systems/water_layout_data.gd",
    "res://scripts/systems/water_map_registry.gd",
    "res://scripts/systems/water_topology.gd",
    "res://scripts/systems/water_visual_system.gd",
    "res://tools/qa/world/water_chunk_seam_board.gd",
    "res://tools/qa/world/water_chunk_seam_capture.gd",
}
WATER_SOURCES = {
    "scripts/systems/water_map_registry.gd",
    "scripts/systems/water_topology.gd",
    "scripts/systems/water_visual_system.gd",
    "tests/suites/water_fishing_suite.gd",
    "tests/suites/water_chunk_seam_suite.gd",
    "tests/suites/water_navigation_suite.gd",
    "tests/suites/water_topology_suite.gd",
    "tests/suites/water_visual_suite.gd",
}
EXPECTED_CHUNKS = {
    "left_cells": 64,
    "right_cells": 48,
    "left_halo": 4,
    "right_halo": 8,
    "left_east_filled": 4,
    "right_west_filled": 4,
    "visual_builds": 9,
    "repeated_reads": 240,
    "rebuilds_during_repeated_reads": 0,
    "internal_shore_edges": 0,
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
    """Resolve one report-relative path without allowing project escape."""
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


def changed_pixels(first: Path, second: Path) -> tuple[int, tuple[int, int, int, int] | None]:
    """Count RGB differences without the unchanged alpha channel hiding their bbox."""
    with Image.open(first) as before, Image.open(second) as after:
        require(before.size == after.size == (1152, 648), "native frame dimensions")
        difference = ImageChops.difference(before.convert("RGB"), after.convert("RGB"))
        mask = ImageChops.lighter(
            ImageChops.lighter(difference.getchannel("R"), difference.getchannel("G")),
            difference.getchannel("B"),
        )
        return sum(mask.histogram()[1:]), mask.getbbox()


def verify_sources(root: Path, folder: Path, profile: dict[str, Any]) -> None:
    """Bind the public chunk, registry and renderer contracts to one implementation commit."""
    source = read(folder / "source.json")
    commit = profile["implementation_commit"]
    require(source.get("task") == TASK, "source task")
    require(source.get("implementation_commit") == commit, "source implementation commit")
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
    visual = historical_files["scripts/systems/water_visual_system.gd"].decode()
    require("func _chunk_visual_snapshot" in topology, "chunk visual snapshot missing")
    require(
        '"halo": halo' in topology and '"filled_edges": filled_edges' in topology,
        "halo contract missing",
    )
    require("_chunk_visual_cache.erase(key)" in topology, "local invalidation missing")
    require("func visual_chunk" in registry, "registry chunk API missing")
    require("func draw_chunk_module" in visual, "chunk visual consumer missing")


def verify_static_frames(root: Path, native: Path, capture: dict[str, Any]) -> None:
    """Require exact global/chunk equality and a visible, localized broken control."""
    expected_ids = {f"{camera}-{mode}" for camera in CAMERAS for mode in MODES}
    frames = capture.get("frames")
    if not isinstance(frames, list) or len(frames) != 6:
        raise ValueError("static coverage")
    by_id = {row.get("id"): row for row in frames}
    require(set(by_id) == expected_ids and len(by_id) == len(frames), "static frame IDs")
    for row in frames:
        path = local(root, native, row["file"])
        require(path.is_file() and digest(path) == row["sha256"], f"static frame SHA: {row['id']}")
        require(row.get("repeat_equal") is True, f"unstable readback: {row['id']}")
        with Image.open(path) as image:
            require(image.size == (1152, 648), f"static frame size: {row['id']}")
    for camera in CAMERAS:
        global_row = by_id[f"{camera}-global"]
        safe_row = by_id[f"{camera}-chunk-safe"]
        broken_row = by_id[f"{camera}-isolated-negative"]
        require(
            global_row["camera"] == safe_row["camera"] == broken_row["camera"],
            f"same-camera trio: {camera}",
        )
        global_path = native / global_row["file"]
        safe_path = native / safe_row["file"]
        broken_path = native / broken_row["file"]
        require(
            global_path.read_bytes() == safe_path.read_bytes(), f"chunk/global mismatch: {camera}"
        )
        changed, bounds = changed_pixels(global_path, broken_path)
        require(changed > 10_000 and bounds is not None, f"negative control missing: {camera}")
        if bounds is None:  # pragma: no cover - require above keeps the task-specific message
            raise ValueError(f"negative control missing: {camera}")
        width = bounds[2] - bounds[0]
        height = bounds[3] - bounds[1]
        require(width <= 128 and height <= 192, f"negative control is not seam-local: {camera}")


def verify_motion(root: Path, native: Path, capture: dict[str, Any]) -> None:
    """Verify continuous camera motion whose every saved frame matched the global plan."""
    motion = capture.get("motion")
    if not isinstance(motion, list) or len(motion) != 60:
        raise ValueError("motion coverage")
    require(len({row.get("sha256") for row in motion}) == len(motion), "repeated motion frames")
    start = (96.0, 90.0)
    finish = (288.0, 90.0)
    for index, row in enumerate(motion):
        require(row.get("frame") == index, "motion frame order")
        require(row.get("file") == f"frames/{index:04d}.png", "motion frame path")
        require(row.get("global_equal") is True, "motion global comparison")
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
    """Decode current H.264 bytes and bind real motion to the captured PNG sequence."""
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
    metadata = read(native / "camera-pan.json")
    expected = {"width": 1152, "height": 648, "frames": 60, "fps": 30}
    require(all(metadata.get(key) == value for key, value in expected.items()), "encoded metadata")
    require(math.isclose(metadata.get("duration", 0), 2.0, abs_tol=0.001), "encoded duration")
    try:
        actual_frames, actual_duration = count_frames_and_secs(str(native / "camera-pan.mp4"))
    except (OSError, RuntimeError) as error:
        raise ValueError("encoded stream cannot be decoded") from error
    require(actual_frames == 60, "encoded frame count")
    require(math.isclose(actual_duration, 2.0, abs_tol=0.01), "encoded stream duration")
    reader = None
    signatures: set[bytes] = set()
    witnesses: dict[int, Image.Image] = {}
    try:
        reader = read_frames(str(native / "camera-pan.mp4"), pix_fmt="rgb24")
        stream = next(reader)
        require(stream.get("codec") == "h264", "encoded codec")
        require(tuple(stream.get("size", ())) == (1152, 648), "encoded stream dimensions")
        require(math.isclose(float(stream.get("fps", 0)), 30.0, abs_tol=0.01), "encoded fps")
        for index in range(60):
            payload = next(reader)
            require(len(payload) == 1152 * 648 * 3, "encoded frame bytes")
            frame = Image.frombytes("RGB", (1152, 648), payload)
            signatures.add(hashlib.sha256(frame.resize((64, 36)).tobytes()).digest())
            if index in WITNESS_FRAMES:
                witnesses[index] = frame
    except (OSError, RuntimeError, StopIteration) as error:
        raise ValueError("encoded stream cannot be decoded") from error
    finally:
        if reader is not None:
            _close_decoder(reader)
    require(len(signatures) == 60, "frozen video sequence")
    for index in WITNESS_FRAMES:
        with Image.open(native / f"motion-{index:03d}.png") as witness:
            difference = ImageChops.difference(witnesses[index], witness.convert("RGB"))
            require(max(ImageStat.Stat(difference).mean) < 5.0, "decoded witness mismatch")
    with Image.open(native / "camera-pan.decoded.png") as decoded:
        difference = ImageChops.difference(decoded.convert("RGB"), witnesses[0])
        require(max(ImageStat.Stat(difference).mean) < 5.0, "decoded first frame mismatch")


def verify_native(root: Path, folder: Path, profile: dict[str, Any]) -> None:
    """Verify classification, metrics, same-camera frames, motion and clean native log."""
    native = folder / "native"
    capture = read(native / "capture.json")
    require(capture.get("task") == TASK, "capture task")
    require(capture.get("kind") == "native-water-chunk-seam-study", "capture kind")
    require(
        capture.get("display_server") == "macOS" and bool(capture.get("adapter")), "native display"
    )
    require(capture.get("runtime_integration") is True, "runtime integration missing")
    require(capture.get("native_gameplay") is False, "capture mislabelled as gameplay")
    require(capture.get("performance_eligible") is False, "capture mislabelled as FPS evidence")
    require(capture.get("fixed_clock_video") is True, "fixed clock classification")
    for key in ("target", "field", "zoom", "seam_world_x"):
        require(capture.get(key) == profile[key], f"native {key}")
    require(capture.get("chunks") == EXPECTED_CHUNKS, "chunk metrics")
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
        "WATER CHUNK SEAM CAPTURE: 6 static frames and 60 camera frames; not FPS" in engine,
        "capture completion",
    )
    require(
        not any(marker in engine for marker in ("ERROR:", "SCRIPT ERROR", "Parse Error", "FAIL:")),
        "native engine error",
    )


def verify_water_review(root: Path, folder: Path, profile: dict[str, Any]) -> None:
    """Bind all WATER assertions to the exact runner, sources and clean log."""
    review = read(folder / "water-review.json")
    commit = profile["implementation_commit"]
    require(review.get("task") == TASK, "WATER review task")
    require(review.get("implementation_commit") == commit, "WATER implementation commit")
    require(review.get("passed") == 892 and review.get("failed") == 0, "WATER result")
    runner = "tools/qa/world/water_chunk_seam_review.gd"
    require(historical(root, commit, runner, review.get("runner_sha256", "")), "WATER runner SHA")
    sources = review.get("sources")
    if not isinstance(sources, dict) or set(sources) != WATER_SOURCES:
        raise ValueError("WATER source coverage")
    for name, expected in sources.items():
        require(historical(root, commit, name, expected), f"WATER source SHA: {name}")
    log = folder / "water-review.log"
    require(review.get("log_sha256") == digest(log), "WATER log SHA")
    text = log.read_text()
    require("WATER CHUNK SEAM: 892 passed, 0 failed" in text, "WATER completion")
    require(
        not any(marker in text for marker in ("ERROR:", "SCRIPT ERROR", "Parse Error", "FAIL:")),
        "WATER engine error",
    )


def verify(root: Path = ROOT, *, require_tracked: bool = True) -> dict[str, Any]:
    """Verify the complete VSHORE-004 packet without regenerating artifacts."""
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
    require(profile.get("native_static_frames") == 6, "profile static coverage")
    require(profile.get("native_motion_frames") == 60, "profile motion coverage")
    verify_sources(root, folder, profile)
    verify_native(root, folder, profile)
    verify_water_review(root, folder, profile)
    if require_tracked:
        required = [path for path in folder.rglob("*") if path.is_file()]
        required.extend(
            [
                root / "tools/qa/world/water_chunk_seam.py",
                root / "tools/qa/world/test_water_chunk_seam.py",
                root / "wiki/articles/water-chunk-seams.md",
            ]
        )
        require(tracked(root, required), "critical VSHORE-004 evidence is not in Git index")
    return {
        "task": TASK,
        "native_static_frames": 6,
        "native_motion_frames": 60,
        "same_camera_pixel_equal": True,
        "internal_shore_edges": 0,
        "rebuilds_during_repeated_reads": 0,
        "performance_eligible": False,
    }


def encode_native(native: Path) -> None:
    """Create a review H.264 from an already completed, immutable PNG sequence."""
    capture = read(native / "capture.json")
    require(
        capture.get("task") == TASK and len(capture.get("motion", [])) == 60, "capture required"
    )
    movie = native / "camera-pan.mp4"
    metadata_path = native / "camera-pan.json"
    decoded_path = native / "camera-pan.decoded.png"
    proof_path = native / "video-proof.json"
    require(
        not any(path.exists() for path in (movie, metadata_path, decoded_path, proof_path)),
        "video output exists",
    )
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
        for row in capture["motion"]:
            with Image.open(native / row["file"]) as image:
                writer.send(image.convert("RGB").tobytes())
    finally:
        writer.close()
    frames, duration = count_frames_and_secs(str(movie))
    metadata_path.write_text(
        json.dumps(
            {"width": 1152, "height": 648, "frames": frames, "fps": 30, "duration": duration},
            ensure_ascii=False,
            indent=2,
        )
        + "\n"
    )
    reader = read_frames(str(movie), pix_fmt="rgb24")
    try:
        stream = next(reader)
        require(tuple(stream.get("size", ())) == (1152, 648), "encoded stream dimensions")
        Image.frombytes("RGB", (1152, 648), next(reader)).save(decoded_path)
    finally:
        _close_decoder(reader)
    chain = hashlib.sha256(
        "\n".join(row["sha256"] for row in capture["motion"]).encode()
    ).hexdigest()
    proof = {
        "schema": 1,
        "task": TASK,
        "capture_sha256": digest(native / "capture.json"),
        "frame_chain_sha256": chain,
        "files": {name: digest(native / name) for name in sorted(VIDEO_FILES)},
    }
    proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")


def main() -> None:
    """Expose read-only verification and an explicit one-time video assembly action."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-untracked", action="store_true")
    parser.add_argument("--encode-native", type=Path)
    args = parser.parse_args()
    if args.encode_native is not None:
        encode_native(args.encode_native.resolve())
        return
    print(
        json.dumps(verify(require_tracked=not args.allow_untracked), ensure_ascii=False, indent=2)
    )


if __name__ == "__main__":
    main()
