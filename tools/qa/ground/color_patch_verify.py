#!/usr/bin/env python3
"""Verify VGROUND-002 native pairs, road coverage and frozen source provenance."""

from __future__ import annotations

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
from tools.qa.performance.perf_contract_collect import command, sha, write
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
LEGACY_LOCATIONS = [name for name in LOCATIONS if name != "overworld"]


def load(path: Path) -> dict[str, Any]:
    """Read one JSON witness without mutating archived evidence."""
    return cast(dict[str, Any], json.loads(path.read_text()))


def provenance(folder: Path, expected_head: str | None = None) -> dict[str, Any]:
    """Bind exact CI inputs to Git blobs while retaining an explicit local preflight mode."""
    source = load(folder / "source.json")
    require(source["complete"] and source["task"] == "VGROUND-002", "incomplete collection")
    require(isinstance(source.get("head_commit"), str), "head commit is missing")
    head_commit = cast(str, source["head_commit"])
    require(head_commit == source["base_commit"], "head/base commit differs")
    require(
        source.get("head_tree") == command(["git", "rev-parse", f"{head_commit}^{{tree}}"]),
        "head tree differs",
    )
    if expected_head is not None:
        require(head_commit == expected_head, "evidence belongs to another head")
        require(source.get("exact_head"), "expected-head verification requires exact evidence")
        require(source.get("expected_head") == expected_head, "collector expected another head")
    require(
        set(source["sources"]) == set(SOURCES)
        and set(source["base_sources"]) == set(SOURCES)
        and set(source.get("head_sources", {})) == set(SOURCES),
        "source coverage",
    )
    for name, digest in source["sources"].items():
        require(sha(folder / "inputs" / name) == digest, "archived input changed: " + name)
        historical = historical_result(ROOT, head_commit, name)
        blob_digest = (
            hashlib.sha256(historical.stdout).hexdigest() if historical.returncode == 0 else None
        )
        require(blob_digest == source["base_sources"][name], "historical base differs: " + name)
        require(blob_digest == source["head_sources"][name], "head blob differs: " + name)
        if source.get("exact_head") or name not in OVERLAY:
            require(blob_digest == digest, "input differs from declared Git blob: " + name)
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


def virtual_display_is_x11(capture: dict[str, Any]) -> bool:
    """Accept Godot's canonical ``X11`` spelling without accepting another backend."""
    return not capture.get("virtual_display") or str(capture.get("display", "")).casefold() == "x11"


def verify(folder: Path, expected_head: str | None = None) -> dict[str, Any]:
    """Reject mismatched camera/state pairs, invisible fields and incomplete native proof."""
    source = provenance(folder, expected_head)
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
        require(virtual_display_is_x11(capture), "virtual-display proof must come from X11")
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
        expected.update(
            {
                mode + "-" + name
                for name in LEGACY_LOCATIONS
                for mode in ["legacy-cached", "legacy-direct"]
            }
        )
        require(set(rows) == expected and len(rows) == 30, "pair and legacy-path coverage")
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
            if pair.startswith("biome-village_"):
                require(
                    difference["bbox"] is None and difference["max"] == 0,
                    "separate village map changed with overworld patch toggle: " + pair,
                )
            else:
                require(
                    difference["bbox"] is not None
                    and difference["max"] >= 8
                    and difference["mean"] >= 0.45,
                    "colour field is not visibly present: " + pair,
                )
            differences[pair] = difference
        legacy_paths = {}
        for location in LEGACY_LOCATIONS:
            cached_id = "legacy-cached-" + location
            direct_id = "legacy-direct-" + location
            cached, direct = rows[cached_id], rows[direct_id]
            require(
                not cached["direct"] and direct["direct"], "legacy path labels differ: " + location
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
                require(cached[key] == direct[key], "legacy paths changed " + key + ": " + location)
            for row_id in [cached_id, direct_id]:
                with Image.open(path / f"{row_id}.png") as image:
                    require(list(image.size) == capture["window"], "legacy PNG size differs")
                draws = json.loads(gzip.decompress((path / f"{row_id}-draws.json.gz").read_bytes()))
                require(len(draws) == 4, "legacy path must retain four complete draw traces")
                validate_draws(draws)
            difference = image_difference(path / f"{cached_id}.png", path / f"{direct_id}.png")
            require(
                difference["bbox"] is None and difference["max"] == 0,
                "cached and direct legacy village rendering differ: " + location,
            )
            legacy_paths[location] = difference
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
            "legacy_paths": len(LEGACY_LOCATIONS),
            "png_count": 33,
            "differences": differences,
            "legacy_differences": legacy_paths,
            "biome_means": means,
        }
    print("COLOR PATCH EVIDENCE: 66 native PNG, 240 complete draw snapshots; no FPS claim")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=REPORT / "native")
    parser.add_argument("--expected-head")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    summary = verify(args.output.resolve(), args.expected_head)
    if args.write:
        write(REPORT / "summary.json", summary)
