"""Verify native VSHORE-006 pairs, downstream motion and the camera video."""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
from collections.abc import Callable, Iterable
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any

from PIL import Image, ImageChops

from tools.common.git import git_environment
from tools.common.history import read_git_blob
from tools.common.paths import project_root
from tools.qa.world.water_chunk_seam import digest, require
from tools.qa.world.water_surface import (
    SIZE,
    WITNESSES,
    difference,
    encode,
    pixels,
    project,
    verify_video,
    water_mask,
)

ROOT = project_root(__file__)
REPORTS = ROOT / "docs/reports/visual-overhaul"
CAMERAS = {"upper": [288, 18], "lower": [700, 540], "pond": [1368, 618]}
START = 1.25
LATER = START + 20 / 3
SOURCES = {
    "assets/game/locations/overworld/modular/riverbed_material_v1.png",
    "assets/game/locations/overworld/modular/water_material_v1.png",
    "main.tscn",
    "scripts/game_core.gd",
    "scripts/presentation/post_motion_frame.gd",
    "scripts/presentation/underwater_bottom.gd",
    "scripts/presentation/village_ground_clock.gd",
    "scripts/presentation/village_ground_layer.gd",
    "scripts/presentation/village_river_flow.gd",
    "scripts/presentation/village_water_surface.gd",
    "scripts/presentation/village_water_surface.gdshader",
    "scripts/presentation/visual_reference_mode.gd",
    "scripts/systems/village_terrain_renderer.gd",
    "scripts/systems/water_layout_data.gd",
    "scripts/systems/water_map_registry.gd",
    "scripts/systems/water_topology.gd",
    "scripts/world_background.gd",
    "tools/qa/camera/visual_camera_points.gd",
    "tools/qa/world/river_flow_capture.gd",
}
CHECKS = {
    "direct_hidden",
    "directed_default",
    "low_keeps_flow",
    "normal_fine",
    "pause",
    "reduced_motion_static",
    "reference_static",
    "resume",
    "save_equal",
    "split_visible",
    "uniform_only",
    "unsplit_hidden",
}
Point = tuple[int, int]
PixelMap = Callable[[Point], Point]


def verify_base(base: str, commit: str | None) -> None:
    """Check that the capture base is an actual ancestor of the selected source tree."""
    require(
        isinstance(base, str) and re.fullmatch(r"[0-9a-f]{40}", base) is not None,
        "capture base must be a Git commit",
    )
    require(
        commit is None or re.fullmatch(r"[0-9a-f]{40}", commit) is not None, "invalid source commit"
    )
    git = ["git", "--no-replace-objects", "-C", str(ROOT)]
    environment = git_environment()
    kind = subprocess.run(
        [*git, "cat-file", "-t", base], env=environment, capture_output=True, check=False
    )
    require(
        kind.returncode == 0 and kind.stdout == b"commit\n", "capture base must be a Git commit"
    )
    ancestry = subprocess.run(
        [*git, "merge-base", "--is-ancestor", base, commit or "HEAD"],
        env=environment,
        capture_output=True,
        check=False,
    )
    require(ancestry.returncode == 0, "capture base is not an ancestor of the source tree")


def verify_capture(capture: dict[str, Any], commit: str | None) -> None:
    """Check runtime context, source provenance and the camera sequence before reading pixels."""
    require(capture["task"] == "VSHORE-006" and capture["display"] != "headless", "native capture")
    require(capture["renderer"] == "gl_compatibility" and capture["size"] == list(SIZE), "renderer")
    require(capture["checks"] == dict.fromkeys(CHECKS, True), "runtime checks")
    require(
        capture["atlas"]
        == {
            "size": [314, 98],
            "bytes": 123088,
            "bounds": [-56, 232, 2512, 784],
        },
        "shared atlas",
    )
    require(
        len(capture["river_cells"]) == 494
        and len(capture["pond_cells"]) == 56
        and len(capture["bridges"]) == 2,
        "canonical water and bridge coverage",
    )
    require(set(capture["sources"]) == SOURCES, "capture must name the exact source paths")
    verify_base(capture["base"], commit)
    for path, sha in capture["sources"].items():
        source = (ROOT / path).resolve()
        require(source.is_relative_to(ROOT), "capture source outside the project")
        if commit:
            read_git_blob(ROOT, path, commit, sha)
        else:
            require(digest(source) == sha, f"source changed: {path}")
    motion = capture["motion"]
    require(len(motion) == len({row["png"] for row in motion}) == 120, "motion coverage")
    for index, row in enumerate(motion):
        local = index % 60
        camera = CAMERAS["lower"] if index < 60 else [268 + 204 * local / 59, 72 + 22 * local / 59]
        require(
            all(
                math.isclose(a, b, abs_tol=0.001)
                for a, b in zip(row["camera"], camera, strict=True)
            )
            and row["scale"] == 1.2
            and math.isclose(row["seconds"], START + local / 30)
            and row["file"] == f"frames/{index:04d}.png",
            f"motion settings: {index}",
        )


def picture(folder: Path, row: dict[str, Any], name: str) -> Image.Image:
    """Use the established native PNG path, hash and size verifier."""
    return pixels(folder, {**row, "sha256": row["png"]}, name)


def projection(row: dict[str, Any]) -> dict[str, Any]:
    """Adapt the common report metadata to the existing world projection verifier."""
    return {"camera": row["camera"], "zoom": row["scale"]}


def delta_stats(delta: Image.Image) -> tuple[int, int]:
    """Return the changed pixel count and greatest channel difference in a grayscale delta."""
    histogram = delta.histogram()
    return sum(histogram[1:]), max(level for level, frequency in enumerate(histogram) if frequency)


def compare_pairs(
    capture: dict[str, Any], images: dict[str, Image.Image]
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Prove the three native pairs only changed river RGB, including near the bridges."""
    rows = capture["captures"]
    pairs = {}
    metrics = {}
    for case, camera in CAMERAS.items():
        before, after = rows[f"{case}-before"], rows[f"{case}-after"]
        require(
            all(
                before[key] == after[key]
                for key in ("camera", "scale", "location", "owner", "seconds", "quality")
            )
            and before["camera"] == camera
            and before["scale"] == 1.2
            and before["seconds"] == START
            and before["location"] == "overworld"
            and before["quality"] == "normal"
            and before["directed"] is False
            and after["directed"] is True,
            f"equal comparison settings: {case}",
        )
        view = projection(before)
        delta = difference(images[f"{case}-before"], images[f"{case}-after"])
        count, maximum = delta_stats(delta)
        require(count > 1000 and 0 < maximum <= 26, f"visible and restrained ripple: {case}")
        dry_and_pond = ImageChops.invert(water_mask(capture["river_cells"], view))
        require(
            ImageChops.multiply(delta, dry_and_pond).getbbox() is None, f"non-river pixels: {case}"
        )
        for x, y, w, h in capture["bridges"]:
            deck = (x + w / 4, y + h / 4, w / 2, h / 2)
            require(delta.crop(project(deck, view)).getbbox() is None, f"bridge deck: {case}")
        pairs[case] = {"camera": camera, "other_pixels_equal": True}
        metrics[case] = {"river_pixels_changed": count, "max_rgb_delta": maximum}
    return pairs, metrics


def measure_drift(
    frames: tuple[Image.Image, Image.Image, Image.Image],
    samples: Iterable[Point],
    candidates: dict[str, PixelMap],
) -> dict[str, Any]:
    """Compare the blue signal after removing the stationary bottom and surface colors."""
    before, later, static = (image.getchannel("B").tobytes() for image in frames)
    sums = dict.fromkeys(candidates, 0.0)
    count = 0
    for x, y in samples:
        source = y * SIZE[0] + x
        destinations = [target((x, y)) for target in candidates.values()]
        positions = [dy * SIZE[0] + dx for dx, dy in destinations]
        if static[source] < 70 or any(static[position] < 70 for position in positions):
            continue
        reference = before[source] / static[source]
        for label, position in zip(candidates, positions, strict=True):
            sums[label] += (reference - later[position] / static[position]) ** 2
        count += 1
    require(count > 650, "visible water samples")
    errors = {label: round(value / count, 8) for label, value in sums.items()}
    forward = errors["downstream"]
    require(
        all(forward * 1.4 < value for label, value in errors.items() if label != "downstream"),
        f"the measured pattern does not move downstream: {errors}",
    )
    return {"samples": count, "mean_squared_error": errors}


def straight_drift(
    frames: tuple[Image.Image, Image.Image, Image.Image],
    row: dict[str, Any],
    rect: tuple[float, ...],
    axis: Point,
) -> dict[str, Any]:
    """Verify that downstream translation wins over reverse, crosswise and stationary controls."""
    dx, dy = axis[0] * 12, axis[1] * 12
    x0, y0, x1, y1 = project(rect, projection(row))
    return measure_drift(
        frames,
        ((x, y) for y in range(y0, y1) for x in range(x0, x1)),
        {
            "downstream": lambda pt: (pt[0] + dx, pt[1] + dy),
            "upstream": lambda pt: (pt[0] - dx, pt[1] - dy),
            "cross_first": lambda pt: (pt[0] + dy, pt[1] + dx),
            "cross_second": lambda pt: (pt[0] - dy, pt[1] - dx),
            "stationary": lambda pt: pt,
        },
    )


def bend_drift(
    frames: tuple[Image.Image, Image.Image, Image.Image],
    row: dict[str, Any],
    origin: Point,
    incoming: Point,
    outgoing: Point,
) -> dict[str, Any]:
    """Test advected pixels in each visible quarter-turn against reverse and held controls."""
    ox, oy = origin
    camera_x, camera_y = row["camera"]
    scale = row["scale"]
    dx, dy = incoming
    ex, ey = outgoing
    rotation = (dx * ey - dy * ex) * 10 / 48
    x0, y0, x1, y1 = project((ox - 70, oy - 70, 140, 140), projection(row))

    def radial(point: Point) -> tuple[float, float]:
        x, y = point
        return (x + 0.5) / scale + camera_x - ox, (y + 0.5) / scale + camera_y - oy

    def visible() -> Iterable[Point]:
        for y in range(max(1, y0), min(SIZE[1] - 2, y1)):
            for x in range(max(1, x0), min(SIZE[0] - 2, x1)):
                px, py = radial((x, y))
                u, v = px * dx + py * dy, -px * ex - py * ey
                if 37 <= math.hypot(px, py) <= 57 and 0.38 < math.atan2(u, v) < 1.12:
                    yield x, y

    def rotated(angle: float) -> PixelMap:
        c, s = math.cos(angle), math.sin(angle)

        def pixel(point: Point) -> Point:
            px, py = radial(point)
            return (
                round((ox + px * c - py * s - camera_x) * scale - 0.5),
                round((oy + px * s + py * c - camera_y) * scale - 0.5),
            )

        return pixel

    return measure_drift(
        frames,
        visible(),
        {
            "downstream": rotated(rotation),
            "upstream": rotated(-rotation),
            "stationary": lambda pt: pt,
        },
    )


def verify_motion(capture: dict[str, Any], images: dict[str, Image.Image]) -> dict[str, Any]:
    """Quantify real image transport on straight segments, around bends and across the camera seam."""
    rows = capture["captures"]

    def frames(case: str, first: str, second: str) -> tuple[Image.Image, Image.Image, Image.Image]:
        require(
            rows[f"{case}-{first}"]["seconds"] == START
            and math.isclose(rows[f"{case}-{second}"]["seconds"], LATER)
            and all(
                rows[f"{case}-{item}"]["camera"] == CAMERAS[case]
                for item in (first, second, "static")
            ),
            f"fixed motion setup: {case}",
        )
        return images[f"{case}-{first}"], images[f"{case}-{second}"], images[f"{case}-static"]

    upper = frames("upper", "after", "later")
    lower = frames("lower", "after", "later")
    a, b = rows["upper-after"], rows["lower-after"]
    drift = {
        "upper_right": straight_drift(upper, a, (330, 268, 143, 42), (1, 0)),
        "lower_down": straight_drift(lower, b, (1013, 652, 39, 128), (0, 1)),
        "lower_right": straight_drift(lower, b, (1110, 941, 145, 37), (1, 0)),
        "low_profile_right": straight_drift(
            frames("upper", "low", "low-later"), a, (330, 268, 143, 42), (1, 0)
        ),
        "first_bend": bend_drift(upper, a, (528, 336), (1, 0), (0, 1)),
        "second_bend": bend_drift(upper, a, (624, 408), (0, 1), (1, 0)),
        "third_bend": bend_drift(upper, a, (984, 504), (1, 0), (0, 1)),
        "fourth_bend": bend_drift(lower, b, (1080, 912), (0, 1), (1, 0)),
    }
    require(difference(upper[0], images["upper-wrapped"]).getbbox() is None, "full phase wrap")
    shifted = images["upper-shifted"]
    patch = difference(upper[0].crop((48, 270, 335, 360)), shifted.crop((0, 270, 287, 360)))
    count, maximum = delta_stats(patch)
    require(maximum <= 1 and count <= 100, "fixed world patch across camera shift")
    return {
        "drift": drift,
        "phase_wrap_equal": True,
        "camera_patch": {
            "pixels": patch.width * patch.height,
            "changed": count,
            "max_rgb_delta": maximum,
        },
    }


def main() -> None:
    """Verify retained native evidence or package it from one fresh raw capture."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder", type=Path, default=REPORTS / "vshore-006/native")
    parser.add_argument("--commit")
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--raw", type=Path, help="publish only the verified MP4 from all raw PNGs")
    output.add_argument(
        "--write-comparison", action="store_true", help="publish the comparison manifest"
    )
    arguments = parser.parse_args()
    folder = arguments.folder.resolve()
    manifest = folder / "capture.json"
    capture = json.loads(manifest.read_text())
    verify_capture(capture, arguments.commit)
    rows = capture["captures"]
    expected = {f"{case}-{profile}" for case in CAMERAS for profile in ("before", "after")}
    expected |= {
        f"{case}-{profile}" for case in ("upper", "lower") for profile in ("static", "later")
    }
    expected |= {"upper-low", "upper-low-later", "upper-wrapped", "upper-shifted"}
    require(set(rows) == expected, "still coverage")
    images = {key: picture(folder, rows[key], f"{key}.png") for key in sorted(expected)}
    frozen_before = REPORTS / "vshore-005/native/seam-normal.png"
    require(
        rows["upper-before"]["png"] == digest(frozen_before),
        "the control is not the accepted VSHORE-005 frame",
    )
    pairs, comparison = compare_pairs(capture, images)
    motion = verify_motion(capture, images)
    results = {"same_camera": comparison, **motion, "atlas_bytes": capture["atlas"]["bytes"]}
    comparison_manifest = {
        "capture_sha256": digest(manifest),
        "captures": {key: rows[key] for key in sorted(rows) if key.endswith(("-before", "-after"))},
        "pairs": pairs,
    }
    video = folder / "camera-pan.mp4"
    witnesses = [{**row, "sha256": row["png"]} for row in capture["motion"]]
    require(witnesses[0]["png"] == rows["lower-after"]["png"], "fixed shot differs from its still")
    for index in WITNESSES:
        picture(folder, capture["motion"][index], f"frames/{index:04d}.png")
    verified = folder / "comparison.json"
    if arguments.raw:
        encode(arguments.raw.resolve(), video, witnesses)
    else:
        verify_video(video, folder, witnesses)
        if arguments.write_comparison:
            require(not verified.exists(), "comparison manifest already exists")
            with TemporaryDirectory(dir=folder) as temporary:
                staged = Path(temporary) / verified.name
                staged.write_text(
                    json.dumps(comparison_manifest, indent=2, ensure_ascii=False) + "\n"
                )
                verified.hardlink_to(staged)
        else:
            require(json.loads(verified.read_text()) == comparison_manifest, "verified comparison")
    print(json.dumps(results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
