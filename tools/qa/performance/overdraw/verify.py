"""Пересчитывает нативное покрытие и полную парную серию VPERF-004 без запуска игры."""

from __future__ import annotations

import argparse
import json
import math
import re
import statistics
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageDraw

from tools.qa.performance.overdraw import contract as c
from tools.qa.performance.pass_cost import contract as base
from tools.qa.performance.pass_cost.verify import deltas, inspect

SIZE = (1152, 648)
CONTACT_WIND_SIZE = (384, 192)
LAYERS = ("water_surface", "grass_composite", "water_bottom")
DECK_INTERIORS = ((822, 376, 906, 550), (1566, 880, 1650, 1054))


def png(path: Path, expected: tuple[int, int] | None = None) -> Image.Image:
    with Image.open(path) as image:
        base.require(
            image.format == "PNG" and (expected is None or image.size == expected),
            f"invalid PNG: {path.name}",
        )
        rgba: Image.Image = image.convert("RGBA")
        return rgba


def area(channel: Image.Image) -> dict[str, int]:
    histogram = channel.histogram()
    maximum = channel.getextrema()[1]
    if not isinstance(maximum, int) or maximum >= 255:
        raise ValueError("coverage counter saturated or not monochrome")
    return {
        "fragments": sum(value * count for value, count in enumerate(histogram)),
        "covered_pixels": channel.width * channel.height - histogram[0],
        "maximum_layers": maximum,
    }


def no_growth(original: Image.Image, trimmed: Image.Image) -> None:
    """Проверяет отсутствие нового покрытия по каждому пикселю каждого измеряемого слоя."""
    base.require(original.size == trimmed.size, "coverage target size changed")
    grown = ImageChops.subtract(trimmed, original)
    base.require(grown.getbbox() is None, "candidate added coverage instead of trimming it")


def water_stays_under_decks(
    original: Image.Image, trimmed: Image.Image, camera: list[float], zoom: float
) -> None:
    allowed = Image.new("L", SIZE)
    painter = ImageDraw.Draw(allowed)
    for left, top, right, bottom in DECK_INTERIORS:
        # A one-pixel guard covers inclusive versus exclusive framebuffer edges.
        painter.rectangle(
            (
                math.floor((left - camera[0]) * zoom) - 1,
                math.floor((top - camera[1]) * zoom) - 1,
                math.ceil((right - camera[0]) * zoom) + 1,
                math.ceil((bottom - camera[1]) * zoom) + 1,
            ),
            fill=255,
        )
    removed = ImageChops.subtract(original, trimmed)
    outside = ImageChops.subtract(removed, allowed)
    base.require(outside.getbbox() is None, "water coverage was removed outside an opaque deck")


def equal_frame(original: Image.Image, trimmed: Image.Image, view: str) -> dict[str, int]:
    difference = ImageChops.difference(original, trimmed)
    red, green, blue, alpha = difference.split()
    peak = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    histogram = peak.histogram()
    changed = peak.width * peak.height - histogram[0]
    base.require(
        alpha.getbbox() is None
        and sum(histogram[2:]) == 0
        and changed * 400 <= peak.width * peak.height,
        f"visible pixels changed: {view}",
    )
    return {"rgb_pixels_differing_by_one": changed, "alpha_pixels_changed": 0}


def check_camera(record: dict[str, Any]) -> None:
    player, day, minutes, profile, zoom, phase = c.VIEWS[record["case"]]
    field = (SIZE[0] / zoom, SIZE[1] / zoom)
    bounds = (2400, 1368)
    camera = [
        max(0.0, min(p - extent * 0.5, size - extent))
        for p, extent, size in zip(player, field, bounds, strict=True)
    ]
    state = record["state"]
    base.require(
        state["player"] == list(player)
        and math.dist(state["camera"], camera) < 0.002
        and state["day"] == day
        and state["minutes"] == minutes
        and state["facing"] == [0, 1]
        and state["location"] == "overworld"
        and state["seed"] == 20261015
        and state["walkable"] == "walkable"
        and state["weather"] == ("rain" if record["case"] == "still-bridge" else "clear")
        and record["quality"] == profile
        and record["zoom"] == zoom
        and record["live_seconds"] == record["effect_seconds"] == phase,
        f"fixed view does not match its contract: {record['case']}",
    )


def check_calibration(path: Path) -> None:
    calibration = png(path, SIZE)
    for band in ("R", "G", "B"):
        channel = calibration.getchannel(band)
        base.require(
            [channel.getpixel(point) for point in ((52, 52), (4, 4), (20, 20))] == [0, 1, 2]
            and area(channel) == {"fragments": 2048, "covered_pixels": 1792, "maximum_layers": 2},
            f"coverage calibration differs in {band}",
        )


def check_readiness(record: dict[str, Any]) -> None:
    observed = record["readiness"]
    base.require(
        all(
            observed[key] is True
            for key in (
                "ready",
                "focus",
                "visible",
                "ground_ready",
                "ground_split",
                "water_visible",
            )
        )
        and all(observed[key] == list(SIZE) for key in ("host_size", "window_size", "framebuffer"))
        and observed["window_mode"] == 0
        and observed["terrain_requests"] >= 1
        and observed["callbacks"] >= observed["stable_draws"] >= 8
        and 500 <= observed["elapsed_ms"] < 8000,
        f"native window did not settle: {record['case']}",
    )


def check_contact(record: dict[str, Any]) -> None:
    contact = record["contact"]
    bends = dict(contact["bends"])
    expected_scale = 0 if record["case"] == "still-bridge" else math.ceil(record["zoom"])
    base.require(
        contact["scale"] == expected_scale
        and len(bends) == len(contact["bends"]) == record["wind_rows"]
        and all(len(bend) == 2 and all(map(math.isfinite, bend)) for bend in bends.values()),
        "wind scale, row count or contact vectors do not match",
    )
    if record["case"] in c.CONTACTS:
        x, y = bends.get(6, (0, 0))
        base.require(
            contact["frame"] is True and x < -0.5 and y > 0.5,
            "the first grass in the actual compositor did not bend on both axes",
        )
    else:
        base.require(
            contact["frame"] is False and all(bend == [0, 0] for bend in bends.values()),
            "a wind-only capture acquired a contact field",
        )


def contact_composite(folder: Path, case: str) -> dict[str, int]:
    scale = math.ceil(c.VIEWS[case][4])
    atlas_size = (CONTACT_WIND_SIZE[0] * scale, CONTACT_WIND_SIZE[1] * scale)
    atlas = [png(folder / f"{case}-{name}-wind-color.png", atlas_size) for name in c.VARIANTS]
    base.require(
        all(image.getchannel("A").getbbox() is not None for image in atlas),
        f"native wind texture has no foliage: {case}",
    )
    if case == c.CONTACT:
        base.require(
            atlas[0].tobytes() == atlas[1].tobytes(),
            "1x native wind texture changed before composite",
        )
    original, trimmed = (png(folder / f"{case}-{name}-composite.png", SIZE) for name in c.VARIANTS)
    mask = original.getchannel("A").histogram()
    base.require(mask[0] > 0 and sum(mask[1:255]) > 0, "composite alpha was not exercised")
    return equal_frame(original, trimmed, f"contact composite ({case})")


def check_views(root: Path) -> dict[str, Any]:
    folder = root / "views"
    check_calibration(folder / "calibration.png")
    views = base.read(folder / "views.json")
    expected = [(case, trimmed) for case in c.CASES for trimmed in (False, True)]
    base.require(
        [(row["case"], row["trimmed"]) for row in views] == expected,
        "missing or reordered camera proof",
    )
    findings: dict[str, Any] = {}
    for initial, final in zip(views[::2], views[1::2], strict=True):
        case = initial["case"]
        check_camera(initial)
        check_camera(final)
        check_readiness(initial)
        check_readiness(final)
        check_contact(initial)
        check_contact(final)
        base.require(
            initial["display"] == final["display"] == "X11"
            and initial["framebuffer"] == final["framebuffer"] == list(SIZE)
            and initial["quality"] == final["quality"]
            and initial["zoom"] == final["zoom"]
            and initial["state"] == final["state"]
            and initial["state"]["physics_processing"] is False
            and initial["save"] == initial["final_save"] == final["save"] == final["final_save"]
            and re.fullmatch(r"[a-f0-9]{64}", initial["save"])
            and initial["deck_trim"] is False
            and final["deck_trim"] is True
            and initial["wind_rows"] == final["wind_rows"],
            f"camera, visual profile or game state differs: {case}",
        )
        base.require(
            initial["contact"] == final["contact"], f"contact changed inside the pair: {case}"
        )
        frame = [png(folder / f"{case}-{name}-frame.png", SIZE) for name in c.VARIANTS]
        visual = equal_frame(frame[0], frame[1], case)
        masks = [png(folder / f"{case}-{name}-world.png", SIZE) for name in c.VARIANTS]
        counts = {}
        for name, band in zip(LAYERS, ("R", "G", "B"), strict=True):
            original, trimmed = (mask.getchannel(band) for mask in masks)
            no_growth(original, trimmed)
            if name in ("water_surface", "water_bottom"):
                water_stays_under_decks(
                    original, trimmed, initial["state"]["camera"], initial["zoom"]
                )
            counts[name] = {"baseline": area(original), "trimmed": area(trimmed)}
        if case == "still-bridge":
            base.require(
                initial["wind_rows"] == 0, "reduced motion incorrectly allocated live grass"
            )
        else:
            base.require(initial["wind_rows"] > 0, "camera proof did not exercise live vegetation")
            original_wind, trimmed_wind = (
                png(folder / f"{case}-{name}-wind.png").getchannel("R") for name in c.VARIANTS
            )
            no_growth(original_wind, trimmed_wind)
            counts["grass_wind_target"] = {
                "baseline": area(original_wind),
                "trimmed": area(trimmed_wind),
            }
            if case == c.CONTACT:
                base.require(
                    original_wind.tobytes() == trimmed_wind.tobytes(), "1x wind geometry changed"
                )
            else:
                positive_delta(counts, "grass_wind_target", case)
        if "bridge" in case:
            positive_delta(counts, "water_surface", case)
            positive_delta(counts, "water_bottom", case)
        if case in ("dense-grass", *c.CONTACTS):
            positive_delta(counts, "grass_composite", case)
        findings[case] = {"camera": initial["state"]["camera"], "visual": visual, "layers": counts}
        if case in c.CONTACTS:
            findings[case]["contact"] = initial["contact"]
            findings[case]["contact_composite"] = contact_composite(folder, case)
    return findings


def positive_delta(counts: dict[str, Any], layer: str, case: str) -> None:
    result = counts[layer]
    base.require(
        result["baseline"]["fragments"] > result["trimmed"]["fragments"] > 0,
        f"no covered area saved: {case}/{layer}",
    )


def check_series(folder: Path, expected: str) -> dict[str, Any]:
    root = folder.resolve(strict=True)
    tree = base.tree(expected)
    source = base.read(base.ordinary_file(root, "source.json"))
    route = base.ROOT / base.ROUTE
    base.require(
        source["schema"] == 1
        and source["task"] == c.TASK
        and source["complete"] is True
        and source["head"] == expected
        and source["tree"] == tree
        and source["views"] == list(c.CASES)
        and source["schedule"] == [list(entry) for entry in c.schedule()]
        and re.fullmatch(r"[a-f0-9]{64}", source["engine_sha256"])
        and route.read_bytes() == base.git("show", expected + ":" + base.ROUTE)
        and source["route_sha256"] == base.digest(route),
        "evidence provenance or the exact route differs",
    )
    expected_files = c.expected_files()
    base.require(set(source["artifacts"]) == expected_files, "incomplete evidence file set")
    for name in expected_files:
        base.require(
            base.digest(base.ordinary_file(root, name)) == source["artifacts"][name],
            f"evidence bytes differ: {name}",
        )
    views = check_views(root)
    launch = base.read(root / "views-launch.json")
    base.require(
        launch["exit_code"] == 0
        and ("res://" + c.DIAGNOSTIC) in launch["command"]
        and launch["command"][-1] == "--profile=" + launch["profile"],
        "fixed camera launch does not match the producer",
    )
    version = (root / "engine-version.txt").read_text().strip()
    base.require(version.startswith("4.7.1.stable.official"), "unexpected Godot build")
    positions = base.read(route)
    results: dict[str, Any] = {}
    equipment: tuple[Any, ...] | None = None
    profiles = {launch["profile"]}
    processes: set[int] = set()
    last_end = 0.0
    for run, variant, seconds in c.schedule():
        data, metrics = inspect(
            root / run / variant, variant, seconds, positions, version, task=c.TASK
        )
        trimmed = variant == "trimmed"
        for state in (data["initial"], data["final"]):
            base.require(
                state["deck_trim"] is trimmed
                and state["foliage_trim"] is trimmed
                and state["foliage_types"] == (2 if trimmed else 0),
                "timings did not exercise the real optimization",
            )
        observed = (
            data["display"],
            data["adapter"],
            data["driver"],
            data["refresh_hz"],
            data["initial"]["vsync"],
        )
        if equipment is None:
            equipment = observed
        receipt = base.read(root / run / variant / "launch.json")
        base.require(
            equipment == observed
            and ("res://" + c.CAPTURE) in receipt["command"]
            and data["pid"] not in processes
            and data["profile"] not in profiles
            and last_end <= data["utc_started"] < data["utc_ended"],
            "native configuration, profile or process drifted",
        )
        processes.add(data["pid"])
        profiles.add(data["profile"])
        last_end = data["utc_ended"]
        results.setdefault(run, {})[variant] = metrics
    differences = {
        name: deltas(pair["baseline"], pair["trimmed"]) for name, pair in results.items()
    }
    return {
        "task": c.TASK,
        "head": expected,
        "tree": tree,
        "host": source["host"],
        "engine_sha256": source["engine_sha256"],
        "runner_id": source["runner_id"],
        "runner_attempt": source["runner_attempt"],
        "equipment": equipment,
        "gpu_time_ms": None,
        "hardware_fps_accepted": False,
        "views": views,
        "runs": results,
        "paired_deltas": differences,
        "short_median_p95_delta_ms": statistics.median(
            differences[name]["frame_interval_ms"]["p95"] for name, _ in base.RUNS[:3]
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-head", required=True)
    args = parser.parse_args()
    try:
        print(
            json.dumps(check_series(args.output, args.expected_head), ensure_ascii=False, indent=2)
        )
    except (ValueError, KeyError, TypeError, IndexError, OSError) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
