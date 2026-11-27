"""Recompute VPERF-006 comparisons from the complete raw X11 artifact."""

from __future__ import annotations

import argparse
import itertools
import json
import math
import re
import statistics
import subprocess
from pathlib import Path
from typing import Any, cast

from PIL import Image, ImageChops

from tools.qa.performance.decor_batching import native_contract as contract
from tools.qa.performance.decor_batching import verify as geometry
from tools.qa.performance.pass_cost import contract as c
from tools.qa.performance.pass_cost import verify as warm
from tools.qa.performance.perf_contract import distribution

Data = dict[str, Any]


def native_image(path: Path, size: tuple[int, int]) -> Image.Image:
    with Image.open(path) as image:
        c.require(image.size == size and image.format == "PNG", f"invalid image: {path}")
        return cast(Image.Image, image.convert("RGBA"))


def differences(reference: Image.Image, candidate: Image.Image) -> tuple[int, int, int]:
    """Return changed RGB pixels, maximum RGB code delta, and changed alpha pixels."""
    red, green, blue, alpha = ImageChops.difference(reference, candidate).split()
    rgb = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    histogram = rgb.histogram()
    extrema = rgb.getextrema()
    assert isinstance(extrema[1], int)
    return sum(histogram[1:]), extrema[1], sum(alpha.histogram()[1:])


def compare_png(first: Path, second: Path, size: tuple[int, int]) -> Data:
    changed, maximum, alpha = differences(native_image(first, size), native_image(second, size))
    c.require(
        alpha == 0 and maximum <= 1 and changed <= size[0] * size[1] // 400,
        f"visible mismatch {second}: RGB changed={changed}, max={maximum}, alpha changed={alpha}",
    )
    return {"rgb_changed_pixels": changed, "rgb_max_delta": maximum, "alpha_changed_pixels": alpha}


def check_negative(folder: Path, state: Data) -> None:
    correct = native_image(folder / "flower-order-correct.png", geometry.WINDOW)
    wrong = native_image(folder / "flower-order-wrong.png", geometry.WINDOW)
    x, y, width, height = state["negative_hero_body"]
    camera_x, camera_y = state["negative_camera"]
    c.require(
        math.dist((camera_x, camera_y), (648, 466)) < 0.001
        and geometry.intersects((x, y, width, height), geometry.footprint((1128, 720))),
        "negative control does not intersect the hero",
    )
    box = (
        math.floor((x - camera_x) * 1.2),
        math.floor((y - camera_y) * 1.2),
        math.ceil((x + width - camera_x) * 1.2),
        math.ceil((y + height - camera_y) * 1.2),
    )
    count, max_delta, _ = differences(correct.crop(box), wrong.crop(box))
    c.require(count > 0 and max_delta > 1, "bad depth order is invisible on the hero")


def check_state(state: Data, spec: Data) -> None:
    c.require(
        state["window"] == state["framebuffer"] == list(geometry.WINDOW)
        and state["player"] == spec["player"]
        and state["focus"] is True
        and state["zoom_percent"] == geometry.ZOOM_PERCENT
        and state["terrain_ready"] is True
        and state["day"] == spec.get("day", 1)
        and state["minutes"] == 780
        and state["seed"] == 20261015
        and state["light_standard"] is True
        and state["reduced_motion"] is True
        and state["reference_effects"] is False
        and state["physics_processing"] is False
        and state["vsync_requested"] == 1
        and state["preset"]["ground_split"] is True
        and state["preset"]["local_terrain_updates"] is True
        and state["preset"]["water_bottom_trim_decks"] is True
        and state["preset"]["water_surface_trim_decks"] is True
        and state["preset"]["window_mode"] == 0,
        f"unmatched fixed state: {spec['id']}",
    )
    expected_camera = [
        max(0, min(player - half, span))
        for player, half, span in zip(spec["player"], (480, 270), (1440, 828), strict=True)
    ]
    c.require(
        math.dist(state["camera"], spec.get("camera", expected_camera)) < 0.001,
        f"camera differs for {spec['id']}",
    )
    c.require(
        state["season"] == ("winter" if spec.get("day") == 22 else "spring"), "season differs"
    )
    if "prop" in spec:
        c.require(
            state["prop_anchor"] == spec["anchor"]
            and state["prop_front"] is spec["front"]
            and geometry.intersects(tuple(state["sprite"]), tuple(state["hero_body"])),
            f"depth overlap or ground anchor is missing: {spec['id']}",
        )
    if spec["id"] == "winter":
        c.require(state["winter_batches"] == [], "winter did not hide the flower batches")


def refresh_summary(samples: list[Data], spec: Data) -> Data:
    phase = spec["phase"]
    full = phase == "full_refresh"
    local = phase == "local_refresh"
    is_refresh = full or local
    c.require(len(samples) == contract.REPETITIONS, "fixed repetitions incomplete")
    previous = 0
    for sample in samples:
        before, after = sample["before"], sample["after"]
        start, request, submit, end = (
            sample[field]
            for field in (
                "previous_draw_usec",
                "requested_usec",
                "submitted_usec",
                "presented_usec",
            )
        )
        c.require(previous < start <= request <= submit < end, "fixed frame timestamps differ")
        c.require(
            after["full_paints"] - before["full_paints"] == int(full)
            and after["local_paints"] - before["local_paints"] == int(local)
            and after["requests"] - before["requests"] == int(full)
            and after["revision"] - before["revision"] == int(is_refresh)
            and after["last_completed"]
            == (spec["repaint"] if is_refresh else before["last_completed"]),
            f"incorrect terrain revision: {spec['id']}",
        )
        c.require(
            sample["draw_calls"] > 0
            and sample["static_bytes"] > 0
            and sample["texture_bytes"] >= 0
            and (
                sample["terrain_draw_calls"] >= 0
                if is_refresh
                else sample["terrain_draw_calls"] is None
            ),
            "invalid render counters or stale terrain counter",
        )
        previous = end
    metrics = {
        "frame_interval_ms": distribution(
            [(row["presented_usec"] - row["previous_draw_usec"]) / 1000 for row in samples]
        ),
        "request_to_frame_ms": distribution(
            [(row["presented_usec"] - row["requested_usec"]) / 1000 for row in samples]
        )
        if is_refresh
        else None,
        "request_callback_ms": distribution(
            [(row["submitted_usec"] - row["requested_usec"]) / 1000 for row in samples]
        )
        if is_refresh
        else None,
        "draw_calls": distribution([row["draw_calls"] for row in samples]),
        "terrain_draw_calls": distribution([row["terrain_draw_calls"] for row in samples])
        if is_refresh
        else None,
        "static_bytes_max": max(row["static_bytes"] for row in samples),
        "texture_bytes_max": max(row["texture_bytes"] for row in samples),
        "gpu_time_ms": None,
    }
    return metrics


def check_launch(path: Path, state: Data, variant: str, script: str) -> None:
    launch = c.read(path / "launch.json")
    command = " ".join(launch["command"])
    c.require(
        launch["pid"] == state["pid"]
        and launch["profile"] == state["profile"]
        and re.fullmatch(r"Codex-VPERF-003-[a-f0-9]{32}", state["profile"])
        and launch["variant"] == variant
        and launch["exit_code"] == 0
        and launch["timeout"] is False
        and "--display-driver x11 --windowed --resolution 1152x648" in command
        and "--rendering-method gl_compatibility --audio-driver Dummy" in command
        and f"--script res://{contract.DIRECTORY}/{script} --" in command,
        "launch receipt differs",
    )


def check_adapter(state: Data, version: str) -> tuple[str, ...]:
    fields = (state["display"], state["driver"], state["adapter"], state["engine_build"])
    c.require(
        fields[:2] == ("X11", "opengl3")
        and "llvmpipe" in fields[2].lower()
        and fields[3].startswith(version.rsplit(".", 1)[1]),
        "X11 software adapter or engine build differs",
    )
    return fields


def fixed_frame(
    path: Path,
    label: str,
    variant: str,
    frame: Data,
    camera: list[float],
    *,
    cache: bool = False,
) -> tuple[int, int]:
    draw, usec = frame["draw_id"], frame["usec"]
    c.require(
        frame["view"] == label
        and frame["variant"] == variant
        and frame["camera"] == camera
        and type(draw) is int
        and draw > 0
        and type(usec) is int
        and usec > 0
        and type(frame["terrain_revision"]) is int
        and frame["terrain_revision"] >= 0,
        f"fixed frame identity differs: {variant}/{label}",
    )
    hashes = {"window": c.digest(path / f"{label}.png")}
    if cache:
        hashes["terrain"] = c.digest(path / f"{label}-terrain.png")
    c.require(frame["sha256"] == hashes, f"PNG bytes differ from capture: {variant}/{label}")
    return draw, usec


def fixed(output: Path, version: str) -> tuple[Data, tuple[str, ...], Data, set[str]]:
    folder = output / "fixed"
    states: Data = {}
    phase_metrics: Data = {}
    pairs: Data = {case: {} for case in geometry.CASES}
    plan = contract.plan()
    for variant in geometry.VARIANTS:
        path = folder / variant
        data = states[variant] = c.read(path / "fixed.json")
        check_launch(path, data, variant, "fixed_capture.gd")
        c.require(
            data["complete"] is True
            and data["variant"] == variant
            and data["cases"].keys() == plan_ids(plan["cases"])
            and data["overlap"].keys() == plan_ids(plan["overlap"]),
            "fixed matrix incomplete",
        )
        events = []
        for spec in plan["cases"]:
            label, phase = spec["id"], spec["phase"]
            case = data["cases"][label]
            check_state(case["state"], spec)
            pairs[label][variant] = case["geometry"]
            metrics = phase_metrics.setdefault(phase, {}).setdefault(label, {})
            metrics[variant] = refresh_summary(case["samples"], spec)
            frame = case["frame"]
            latest = case["samples"][-1]
            event = fixed_frame(path, label, variant, frame, case["state"]["camera"], cache=True)
            c.require(
                event[1] > latest["presented_usec"]
                and frame["terrain_revision"] == latest["after"]["revision"],
                f"fixed PNG does not correspond to the completed terrain refresh: {label}",
            )
            events.append(event)
        for spec in plan["overlap"]:
            label = spec["id"]
            overlap = data["overlap"][label]
            check_state(overlap["state"], spec)
            events.append(
                fixed_frame(path, label, variant, overlap["frame"], overlap["state"]["camera"])
            )
        if variant == "baseline":
            for label in ("flower-order-correct", "flower-order-wrong"):
                events.append(
                    fixed_frame(
                        path,
                        label,
                        variant,
                        data["negative_frames"][label],
                        data["negative_camera"],
                    )
                )
        c.require(
            all(
                draw < next_draw and usec < next_usec
                for (draw, usec), (next_draw, next_usec) in itertools.pairwise(events)
            ),
            "fixed frame events are reused or out of order",
        )
    profiles = {data["profile"] for data in states.values()}
    c.require(len(profiles) == len(states), "fixed profiles were reused")
    adapters = {check_adapter(data, version) for data in states.values()}
    c.require(len(adapters) == 1, "fixed adapters differ")
    baseline = states["baseline"]
    environment = baseline["cases"]["full_rebuild"]["state"]
    compare_fixed_frames(folder, plan, states, phase_metrics, environment)
    check_negative(folder / "baseline", baseline)
    result = geometry.verify(pairs, geometry.flowers())
    result["scope"] = "native_fixed_geometry"
    return {"geometry": result, "metrics": phase_metrics}, adapters.pop(), environment, profiles


def plan_ids(entries: list[Data]) -> set[str]:
    return {spec["id"] for spec in entries}


def compare_fixed_frames(
    folder: Path,
    plan: Data,
    states: Data,
    phase_metrics: Data,
    environment: Data,
) -> None:
    world_size = geometry.WORLD[2:]
    for section in ("cases", "overlap"):
        for spec in plan[section]:
            label = spec["id"]
            reference = states["baseline"][section][label]
            for variant in geometry.VARIANTS:
                actual = states[variant][section][label]
                state = actual["state"]
                c.require(
                    state["preset"] == environment["preset"]
                    and state["vsync"] == environment["vsync"],
                    "fixed render preset or effective VSync changed",
                )
                if variant == "baseline":
                    native_image(folder / variant / f"{label}.png", geometry.WINDOW)
                    if section == "cases":
                        native_image(folder / variant / f"{label}-terrain.png", world_size)
                    continue
                c.require(
                    state == reference["state"],
                    "fixed paired state or prop geometry differs",
                )
                reference_dir, candidate_dir = folder / "baseline", folder / variant
                checks = {
                    "window_pixels": compare_png(
                        reference_dir / f"{label}.png",
                        candidate_dir / f"{label}.png",
                        geometry.WINDOW,
                    ),
                }
                if section == "cases":
                    c.require(
                        all(
                            before["before"] == after["before"]
                            and before["after"] == after["after"]
                            for before, after in zip(
                                reference["samples"], actual["samples"], strict=True
                            )
                        ),
                        "fixed terrain cache history differs",
                    )
                    filename = f"{label}-terrain.png"
                    checks["terrain_pixels"] = compare_png(
                        reference_dir / filename, candidate_dir / filename, world_size
                    )
                    phase_metrics[spec["phase"]][label][variant].update(checks)
                else:
                    phase_metrics.setdefault("overlap", {}).setdefault(label, {})[variant] = checks


def warm_routes(
    output: Path,
    version: str,
    adapter: tuple[str, ...],
    fixed_environment: Data,
    profiles: set[str],
) -> Data:
    route = c.read(c.ROOT / c.ROUTE)
    anchors = geometry.flowers()
    batch_nodes = {
        "baseline": 0,
        **{
            variant: len(geometry.batches(anchors, variant, geometry.WORLD))
            for variant in geometry.VARIANTS[1:]
        },
    }
    results: Data = {}
    for run, variant, seconds in contract.schedule():
        if not seconds:
            continue
        path = output / run / variant
        origin = trace_origin(path, batch_nodes[variant])
        data, metrics = warm.inspect(path, "baseline", seconds, route, version)
        check_launch(path, data, variant, "warm_capture.gd")
        c.require(data["profile"] not in profiles, "warm launch profile was reused")
        profiles.add(data["profile"])
        c.require(check_adapter(data, version) == adapter, "warm adapter differs")
        for phase in ("initial", "final"):
            state = data[phase]
            c.require(
                state["decor"] == variant
                and state["decor_preset"] == fixed_environment["preset"]
                and state["vsync"] == fixed_environment["vsync"],
                "warm paired variant or render preset differs",
            )
        metrics["terrain_before"] = data["initial"]["decor_terrain"]
        metrics["terrain_after"] = data["final"]["decor_terrain"]
        metrics.update(warm_cache_intervals(path, data, origin["events"]))
        results.setdefault(run, {})[variant] = metrics
    deltas: Data = {}
    for run, group in results.items():
        baseline = group["baseline"]
        deltas[run] = {}
        for variant in geometry.VARIANTS[1:]:
            candidate = group[variant]
            c.require(
                baseline["terrain_before"] == candidate["terrain_before"]
                and baseline["terrain_after"] == candidate["terrain_after"],
                "warm terrain cache history differs",
            )
            deltas[run][variant] = warm.deltas(baseline, candidate)
    return {
        "runs": results,
        "paired_deltas_baseline_minus_candidate": deltas,
        "short_median_p95_delta_ms": {
            variant: statistics.median(
                deltas[run][variant]["frame_interval_ms"]["p95"]
                for run, seconds in c.RUNS
                if seconds == 30
            )
            for variant in geometry.VARIANTS[1:]
        },
    }


def trace_origin(path: Path, expected_batches: int) -> Data:
    origin = c.read(path / "terrain-events.json")
    launch = c.read(path / "launch.json")
    c.require(
        origin["pid"] == launch["pid"] and origin["profile"] == launch["profile"],
        "trace capture profile or process differs",
    )
    c.require(
        type(origin["batch_nodes"]) is int and origin["batch_nodes"] == expected_batches,
        "trace capture group count differs from the scheduled variant",
    )
    c.require(
        origin["raw_sha256"] == contract.trace_digests(path), "raw trace differs from capture"
    )
    return cast(Data, origin)


def warm_cache_intervals(path: Path, data: Data, events: list[Data]) -> Data:
    """Keep the complete route and separately summarize intervals away from cache updates."""
    rows = warm.csv_rows(path / "frames.csv.gz", c.FRAME_FIELDS)
    edge_start = data["first_draw"]["draw_id"]
    edge_end = data["final_draw"]["draw_id"]
    revision_start = data["initial"]["decor_terrain"]["revision"]
    revision_end = data["final"]["decor_terrain"]["revision"]
    prior_draw = edge_start - 1
    revision = revision_start
    excluded: set[int] = set()
    c.require(isinstance(events, list), "invalid warm terrain events")
    for event in events:
        draw, current = event["draw_id"], event["revision"]
        c.require(
            type(draw) is int
            and type(current) is int
            and type(event["terrain_ready"]) is bool
            and edge_start <= draw <= edge_end
            and draw > prior_draw
            and revision <= current <= revision_end,
            "invalid or reordered warm cache event",
        )
        excluded.update((draw, draw + 1))
        prior_draw, revision = draw, current
    c.require(revision == revision_end, "terrain revision changed without a captured frame")
    intervals = [row[1] for row in rows if row[2] not in excluded]
    c.require(intervals, "warm route has no intervals with a settled terrain cache")
    return {
        "settled_cache_frame_interval_ms": distribution(intervals),
        "terrain_event_count": len(events),
        "intervals_touching_terrain_events": len(rows) - len(intervals),
    }


def verify(output: Path, head: str) -> Data:
    source = c.read(output / "source.json")
    c.require(
        source["task"] == contract.TASK
        and source["complete"] is True
        and source["head"] == head
        and source["tree"] == c.tree(head)
        and source["renderer"] == contract.RENDERER
        and source["inputs"] == contract.inputs(head)
        and source["schedule"] == contract.schedule()
        and source["files"] == contract.inventory(output)
        and c.read(output / "plan.json") == contract.plan()
        and re.fullmatch(r"[0-9a-f]{64}", source["engine_sha256"])
        and all(
            re.fullmatch(r"[1-9][0-9]*", source[field]) for field in ("runner_id", "runner_attempt")
        ),
        "source, capture plan, or raw archive differs",
    )
    version = (output / "engine-version.txt").read_text().strip()
    c.require(re.fullmatch(r"4\.7\.1\.stable\.official\.[0-9a-f]+", version), "engine differs")
    fixed_result, adapter, environment, profiles = fixed(output, version)
    return {
        "task": contract.TASK,
        "head": head,
        "renderer": source["renderer"],
        "adapter": adapter,
        "fixed": fixed_result,
        "warm": warm_routes(output, version, adapter, environment, profiles),
        "gpu_time_ms": None,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-head", required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.output.resolve(strict=True), args.expected_head), indent=2))
    except (KeyError, TypeError, OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
