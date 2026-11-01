#!/usr/bin/env python3
"""Verify the VSHORE-003 topology-owned water mask and its native evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageStat

from tools.common.git import git_environment
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


def historical_bytes(root: Path, commit: str, name: str) -> bytes:
    """Read the exact implementation input from Git history."""
    history_root = root if (root / ".git").exists() else ROOT
    result = subprocess.run(
        ["git", "show", f"{commit}:{name}"],
        cwd=history_root,
        capture_output=True,
        check=False,
        env=git_environment(),
    )
    require(result.returncode == 0, f"historical source missing: {name}")
    return result.stdout


def historical(root: Path, commit: str, name: str, expected: str) -> bool:
    """Bind one manifest row to exact Git bytes."""
    return hashlib.sha256(historical_bytes(root, commit, name)).hexdigest() == expected


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
    for name, expected in files.items():
        require(historical(root, commit, name, expected), f"source SHA: {name}")

    topology = historical_bytes(root, commit, "scripts/systems/water_topology.gd").decode()
    registry = historical_bytes(root, commit, "scripts/systems/water_map_registry.gd").decode()
    renderer = historical_bytes(
        root, commit, "scripts/systems/village_terrain_renderer.gd"
    ).decode()
    visual = historical_bytes(root, commit, "scripts/systems/water_visual_system.gd").decode()
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


def verify_video(root: Path, native: Path, capture: dict[str, Any]) -> None:
    """Bind the H.264 file, metadata and decoded first frame to the sequence."""
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
    with (
        Image.open(native / "camera-pan.decoded.png") as decoded,
        Image.open(native / "motion-000.png") as source,
    ):
        require(decoded.size == source.size == (1152, 648), "decoded video frame dimensions")
        difference = ImageChops.difference(decoded.convert("RGB"), source.convert("RGB"))
        require(max(ImageStat.Stat(difference).mean) < 3.0, "decoded first frame mismatch")


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
    require(isinstance(commit, str) and len(commit) == 40, "implementation commit")
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
