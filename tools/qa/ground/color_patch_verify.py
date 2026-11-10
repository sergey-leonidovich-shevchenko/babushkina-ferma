#!/usr/bin/env python3
"""Verify VGROUND-002 native pairs, road coverage and frozen source provenance."""

if not __package__:
    from tools.common.launch import prepare_imports
    from tools.common.paths import project_root

    prepare_imports(project_root(__file__))

import argparse
import gzip
import hashlib
import json
from pathlib import Path
from typing import Any, cast

from PIL import Image, ImageChops, ImageStat

from tools.qa.ground.color_patch_collect import OVERLAY, ROOT, SOURCES
from tools.qa.performance.perf_contract_collect import sha, write
from tools.qa.world.render_order import require, validate_draws
from tools.qa.world.source_inputs import historical_result

REPORT = ROOT / "docs/reports/visual-overhaul/vground-002"
LOCATIONS = [
    "overworld",
    "village_market",
    "village_garden",
    "village_river",
    "village_workyard",
    "village_orchard",
]
PAIRS = ["spring", "summer", "autumn", "winter"] + ["biome-" + name for name in LOCATIONS]


def load(path: Path) -> dict[str, Any]:
    """Read one JSON witness without mutating archived evidence."""
    return cast(dict[str, Any], json.loads(path.read_text()))


def provenance(folder: Path) -> dict[str, Any]:
    """Bind every input to the base commit and the explicit task overlay."""
    source = load(folder / "source.json")
    require(source["complete"] and source["task"] == "VGROUND-002", "incomplete collection")
    require(
        set(source["sources"]) == set(SOURCES) and set(source["base_sources"]) == set(SOURCES),
        "source coverage",
    )
    for name, digest in source["sources"].items():
        require(sha(folder / "inputs" / name) == digest, "archived input changed: " + name)
        historical = historical_result(ROOT, source["base_commit"], name)
        base_digest = (
            hashlib.sha256(historical.stdout).hexdigest() if historical.returncode == 0 else None
        )
        require(base_digest == source["base_sources"][name], "historical base differs: " + name)
        if name not in OVERLAY:
            require(base_digest == digest, "unreviewed dependency changed: " + name)
    actual = {
        str(path.relative_to(folder))
        for path in folder.rglob("*")
        if path.is_file() and path.name != "source.json" and "inputs" not in path.parts
    }
    require(actual == set(source["artifacts"]), "artifact coverage differs")
    for name, digest in source["artifacts"].items():
        require(
            not Path(name).is_absolute() and ".." not in Path(name).parts, "unsafe artifact path"
        )
        require(sha(folder / name) == digest, "artifact changed: " + name)
    return source


def image_difference(first: Path, second: Path) -> dict[str, Any]:
    """Measure decoded pixels independently from PNG compression and metadata."""
    with Image.open(first) as left, Image.open(second) as right:
        diff = ImageChops.difference(left.convert("RGB"), right.convert("RGB"))
        extrema = cast(tuple[tuple[int, int], tuple[int, int], tuple[int, int]], diff.getextrema())
        bbox = diff.getbbox()
        return {
            "mean": sum(ImageStat.Stat(diff).mean) / 3,
            "max": max(channel[1] for channel in extrema),
            "bbox": list(bbox) if bbox is not None else None,
        }


def biome_means(path: Path) -> list[list[float]]:
    """Read the six equally sized biome cells away from their QA borders."""
    with Image.open(path) as image:
        image = image.convert("RGB")
        width, height = image.size
        result = []
        for row in range(2):
            for column in range(3):
                box = (
                    column * width // 3 + 8,
                    row * height // 2 + 8,
                    (column + 1) * width // 3 - 8,
                    (row + 1) * height // 2 - 8,
                )
                result.append(ImageStat.Stat(image.crop(box)).mean)
        return result


def verify(folder: Path) -> dict[str, Any]:
    """Reject mismatched camera/state pairs, invisible fields and incomplete native proof."""
    source = provenance(folder)
    result = {
        "task": "VGROUND-002",
        "base_commit": source["base_commit"],
        "windows": {},
        "performance_eligible": False,
        "gpu_time_ms": None,
    }
    for width in [1152, 1280]:
        path = folder / str(width)
        capture = load(path / "capture.json")
        require(load(path / "environment.json")["exit_code"] == 0, "native process failed")
        require(
            capture["task"] == "VGROUND-002"
            and not capture["errors"]
            and capture["display"] != "headless",
            "invalid native capture",
        )
        require(
            not capture.get("virtual_display") or capture["display"] == "x11",
            "virtual-display proof must come from X11",
        )
        require(
            capture["simulation_frozen"]
            and not capture["performance_eligible"]
            and capture["gpu_time_ms"] is None,
            "unsupported performance claim",
        )
        require(capture["window"] == [width, round(width * 9 / 16)], "wrong physical window")
        require(
            set(capture["road_shapes"]) == {"straight", "t", "turn", "dead_end", "corner"},
            "road-shape coverage",
        )
        require(
            set(capture["biomes"]) == set(LOCATIONS) and len(set(capture["biomes"].values())) == 6,
            "biome coverage",
        )
        rows = {row["id"]: row for row in capture["rows"]}
        expected = {pair + suffix for pair in PAIRS for suffix in ["-before", "-after"]}
        require(set(rows) == expected and len(rows) == 20, "pair coverage")
        differences = {}
        for pair in PAIRS:
            before, after = rows[pair + "-before"], rows[pair + "-after"]
            require(
                not before["patches"] and after["patches"], "pair did not toggle patches: " + pair
            )
            for key in [
                "camera",
                "player",
                "location",
                "season",
                "weather",
                "snapshot",
                "physical",
                "zoom",
            ]:
                require(before[key] == after[key], "pair changed " + key + ": " + pair)
            focus_valid = capture.get("virtual_display") or (before["focused"] and after["focused"])
            require(
                focus_valid and before["physical"] == capture["window"],
                "focus or host size differs",
            )
            for suffix in ["before", "after"]:
                image_path = path / f"{pair}-{suffix}.png"
                with Image.open(image_path) as image:
                    require(list(image.size) == capture["window"], "PNG size differs")
                draws = json.loads(
                    gzip.decompress((path / f"{pair}-{suffix}-draws.json.gz").read_bytes())
                )
                require(len(draws) == 4, "static state must retain four complete draw traces")
                validate_draws(draws)
            difference = image_difference(path / f"{pair}-before.png", path / f"{pair}-after.png")
            require(
                difference["bbox"] is not None
                and difference["max"] >= 8
                and difference["mean"] >= 0.45,
                "colour field is not visibly present: " + pair,
            )
            differences[pair] = difference
        for board, target in [
            ("biomes-spring", [1152, 648]),
            ("road-shapes-spring", [1152, 1152]),
            ("road-shapes-winter", [1152, 1152]),
        ]:
            with Image.open(path / f"{board}.png") as image:
                require(list(image.size) == target, "board size differs: " + board)
                require(
                    sum(ImageStat.Stat(image.convert("RGB")).var) > 100,
                    "board is visually empty: " + board,
                )
        means = biome_means(path / "biomes-spring.png")
        rounded = {tuple(round(value, 2) for value in row) for row in means}
        require(len(rounded) == 6, "biome palette cells are not distinct")
        result["windows"][str(width)] = {
            "pairs": len(PAIRS),
            "png_count": 23,
            "differences": differences,
            "biome_means": means,
        }
    print("COLOR PATCH EVIDENCE: 46 native PNG, 160 complete draw snapshots; no FPS claim")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=REPORT / "native")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    summary = verify(args.output.resolve())
    if args.write:
        write(REPORT / "summary.json", summary)
