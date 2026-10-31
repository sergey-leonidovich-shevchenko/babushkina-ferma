#!/usr/bin/env python3
"""Verify VSHORE-002 art provenance, runtime ownership and native evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops

from tools.common.git import git_environment
from tools.common.paths import project_root

ROOT = project_root(__file__)
REPORT = Path("docs/reports/visual-overhaul/vshore-002")
PAIR_NAMES = ("bridge-west", "riverwalk", "pond", "river-seam")
EXTRA_NAMES = ("pond-bottom", "pond-winter", "pond-rain")
WITNESS_FRAMES = (0, 45, 89)


def digest(path: Path) -> str:
    """Hash exact artifact bytes."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict[str, Any]:
    """Read one JSON object without manufacturing missing evidence."""
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"JSON object required: {path}")
    return value


def require(condition: bool, message: str) -> None:
    """Reject incomplete or misleading evidence with an addressable error."""
    if not condition:
        raise ValueError(message)


def local(root: Path, folder: Path, value: str) -> Path:
    """Resolve a report-relative path while forbidding escape from the project."""
    require(isinstance(value, str) and not Path(value).is_absolute(), "absolute artifact path")
    path = (folder / value).resolve()
    require(path.is_relative_to(root.resolve()), "artifact path escapes project")
    return path


def tracked(root: Path, paths: list[Path]) -> bool:
    """Distinguish committed evidence from ignored files on one workstation."""
    relative = [str(path.resolve().relative_to(root.resolve())) for path in paths]
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", "--", *relative],
        cwd=root,
        capture_output=True,
        check=False,
        env=git_environment(),
    )
    return result.returncode == 0


def changed_pixels(first: Path, second: Path) -> int:
    """Count actual RGBA differences between a same-camera before/after pair."""
    with Image.open(first) as before, Image.open(second) as after:
        require(before.size == after.size == (1152, 648), "native frame dimensions")
        difference = ImageChops.difference(before.convert("RGBA"), after.convert("RGBA"))
        mask = ImageChops.lighter(
            ImageChops.lighter(difference.getchannel("R"), difference.getchannel("G")),
            ImageChops.lighter(difference.getchannel("B"), difference.getchannel("A")),
        )
        return sum(mask.histogram()[1:])


def verify_source(root: Path, folder: Path, profile: dict[str, Any]) -> None:
    """Bind the selected master, byte-exact runtime image and retained renderer."""
    source = read(folder / "source.json")
    require(source.get("task") == "VSHORE-002", "source task")
    require(source.get("selected") == "masters/riverbed-master-v1.png", "selected master")
    require(source.get("generator") == "built-in imagegen", "generator provenance")
    files = source.get("files")
    if not isinstance(files, dict) or len(files) != 3:
        raise ValueError("source file coverage")
    for name, expected in files.items():
        path = local(root, folder, name)
        require(path.is_file() and digest(path) == expected, f"source SHA: {name}")
    master = local(root, folder, source["selected"])
    runtime = local(root, folder, source["runtime"])
    require(master.read_bytes() == runtime.read_bytes(), "runtime is not a byte-exact master copy")
    with Image.open(runtime) as image:
        require(image.size == tuple(profile["source_size"]), "riverbed source dimensions")
    import_text = (runtime.with_suffix(runtime.suffix + ".import")).read_text()
    require("mipmaps/generate=true" in import_text, "riverbed mipmaps disabled")
    renderer = (root / "scripts/systems/village_terrain_renderer.gd").read_text()
    require("Geometry2D.merge_polygons" in renderer, "river and pond double-alpha overlap")
    require(
        renderer.find("draw_underwater_bottom") < renderer.find("draw_surface"),
        "bottom/surface order changed",
    )


def verify_native(root: Path, folder: Path, profile: dict[str, Any]) -> None:
    """Validate same-camera GPU frames, movement witnesses and the encoded video."""
    native = folder / "native"
    capture = read(native / "capture.json")
    require(capture.get("task") == "VSHORE-002", "capture task")
    require(capture.get("kind") == "native-runtime-water-study", "capture kind")
    require(
        capture.get("display_server") == "macOS" and bool(capture.get("adapter")),
        "native display",
    )
    require(capture.get("runtime_integration") is True, "runtime integration missing")
    require(capture.get("native_gameplay") is False, "capture mislabelled as gameplay")
    require(capture.get("performance_eligible") is False, "capture mislabelled as FPS evidence")
    require(capture.get("fixed_clock_video") is True, "fixed clock classification")
    require(capture.get("target") == profile["target"], "native target")
    require(capture.get("field") == profile["field"], "native field")
    require(capture.get("zoom") == profile["zoom"], "native zoom")
    require(capture.get("clipped_vertices") == profile["clipped_vertices"], "mesh vertex count")
    require(capture.get("texture_loads_inside_draw") == 0, "texture loads inside draw")
    require(
        capture.get("bottom_profile", {}).get("physical_authority") is False, "visual-only profile"
    )
    require(
        capture.get("bottom_profile", {}).get("sampling") == "mirrored_cells", "sampling profile"
    )

    sources = capture.get("sources")
    if not isinstance(sources, dict):
        raise ValueError("capture source coverage")
    for name, expected in sources.items():
        require(name.startswith("res://"), "capture source URI")
        path = (root / name.removeprefix("res://")).resolve()
        require(path.is_relative_to(root.resolve()), "capture source escapes project")
        require(path.is_file() and digest(path) == expected, f"capture source SHA: {name}")

    expected_ids = {
        *(f"{name}-{phase}" for name in PAIR_NAMES for phase in ("before", "after")),
        *EXTRA_NAMES,
    }
    frames = capture.get("frames")
    if not isinstance(frames, list) or len(frames) != profile["native_static_frames"]:
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
        before = by_id[f"{name}-before"]
        after = by_id[f"{name}-after"]
        require(before["camera"] == after["camera"], f"same-camera pair: {name}")
        difference = changed_pixels(native / before["file"], native / after["file"])
        require(difference > 20_000, f"bottom is not visibly integrated: {name}")

    motion = capture.get("motion")
    if not isinstance(motion, list) or len(motion) != profile["native_motion_frames"]:
        raise ValueError("motion coverage")
    require(len({row.get("sha256") for row in motion}) == len(motion), "repeated motion frames")
    start = (288.0, 18.0)
    finish = (1128.0, 690.0)
    for index, row in enumerate(motion):
        require(row.get("frame") == index, "motion frame order")
        phase = index / (len(motion) - 1)
        expected = [start[axis] + (finish[axis] - start[axis]) * phase for axis in range(2)]
        require(
            all(
                math.isclose(actual, target, abs_tol=0.001)
                for actual, target in zip(row["camera"], expected, strict=True)
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

    video = read(native / "video-proof.json")
    chain = hashlib.sha256("\n".join(row["sha256"] for row in motion).encode()).hexdigest()
    require(video.get("capture_sha256") == digest(native / "capture.json"), "video capture SHA")
    require(video.get("frame_chain_sha256") == chain, "video frame chain")
    video_files = video.get("files")
    if not isinstance(video_files, dict):
        raise ValueError("video file coverage")
    for name, expected in video_files.items():
        path = local(root, native, name)
        require(path.is_file() and digest(path) == expected, f"video SHA: {name}")
    encoded = read(native / "camera-pan.json")
    expected_video = {"width": 1152, "height": 648, "frames": 90, "fps": 30, "duration": 3}
    require(
        all(encoded.get(key) == value for key, value in expected_video.items()),
        "encoded video metadata",
    )
    with Image.open(native / "camera-pan.decoded.png") as decoded:
        require(decoded.size == (1152, 648), "decoded video frame dimensions")
    engine = (native / "engine.log").read_text()
    require(
        "UNDERWATER CAPTURE: 11 static frames and 90 camera frames; not FPS" in engine,
        "capture completion",
    )
    require(
        not any(marker in engine for marker in ("ERROR:", "SCRIPT ERROR", "Parse Error")),
        "native engine error",
    )


def verify_water_review(root: Path, folder: Path) -> None:
    """Bind all 853 WATER assertions to their runner, sources and clean log."""
    review = read(folder / "water-review.json")
    require(review.get("task") == "VSHORE-002", "WATER review task")
    require(review.get("passed") == 853 and review.get("failed") == 0, "WATER result")
    runner = root / "tools/qa/world/underwater_bottom_review.gd"
    require(review.get("runner_sha256") == digest(runner), "WATER runner SHA")
    sources = review.get("sources")
    if not isinstance(sources, dict):
        raise ValueError("WATER source coverage")
    for name, expected in sources.items():
        path = (root / name).resolve()
        require(path.is_relative_to(root.resolve()), "WATER source escapes project")
        require(path.is_file() and digest(path) == expected, f"WATER source SHA: {name}")
    log = folder / "water-review.log"
    require(review.get("log_sha256") == digest(log), "WATER log SHA")
    text = log.read_text()
    require("UNDERWATER BOTTOM: 853 passed, 0 failed" in text, "WATER completion")
    require(
        not any(marker in text for marker in ("ERROR:", "SCRIPT ERROR", "Parse Error", "FAIL:")),
        "WATER engine error",
    )


def verify(root: Path = ROOT, *, require_tracked: bool = True) -> dict[str, Any]:
    """Verify the complete VSHORE-002 packet without regenerating any artifact."""
    folder = root / REPORT
    profile = read(folder / "profile.json")
    require(profile.get("task") == "VSHORE-002", "profile task")
    require(profile.get("status") == "review_candidate", "profile status")
    require(profile.get("runtime_integration") is True, "runtime profile")
    require(profile.get("physical_authority") is False, "physical authority changed")
    require(profile.get("performance_eligible") is False, "performance claim")
    require(profile.get("world_cell") == [768, 768], "world cell")
    require(profile.get("sampling") == "mirrored_cells", "sampling")
    require(profile.get("draw_calls_per_geometry") == 1, "draw call profile")
    verify_source(root, folder, profile)
    verify_native(root, folder, profile)
    verify_water_review(root, folder)
    if require_tracked:
        required = [path for path in folder.rglob("*") if path.is_file()]
        required.extend(
            [
                root / "assets/game/locations/overworld/modular/riverbed_material_v1.png",
                root / "assets/game/locations/overworld/modular/riverbed_material_v1.png.import",
            ]
        )
        require(tracked(root, required), "critical VSHORE-002 evidence is not in Git index")
    return {
        "task": "VSHORE-002",
        "native_static_frames": profile["native_static_frames"],
        "native_motion_frames": profile["native_motion_frames"],
        "clipped_vertices": profile["clipped_vertices"],
        "physical_authority": False,
        "performance_eligible": False,
    }


def main() -> None:
    """Expose a read-only CLI; native capture remains an explicit separate action."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-untracked", action="store_true")
    args = parser.parse_args()
    result = verify(require_tracked=not args.allow_untracked)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
