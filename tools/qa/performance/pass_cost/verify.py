"""Проверяет и пересчитывает полную парную серию VPERF-003 без запуска Godot."""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import math
import re
import statistics
import subprocess
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops

from tools.qa.performance.pass_cost import contract as c
from tools.qa.performance.perf_contract import distribution


def csv_rows(path: Path, fields: tuple[str, ...]) -> list[tuple[float, ...]]:
    with gzip.open(path, "rt", newline="") as stream:
        source = csv.reader(stream)
        c.require(next(source, None) == list(fields), f"wrong CSV fields: {path.name}")
        rows = [tuple(float(value) for value in row) for row in source]
    c.require(
        all(len(row) == len(fields) and all(map(math.isfinite, row)) for row in rows),
        f"malformed or nonfinite CSV data: {path.name}",
    )
    return rows


def projected_camera(x: float, y: float) -> tuple[float, float]:
    return max(0.0, min(x - 480, 1440)), max(0.0, min(y - 270, 828))


def check_trajectory(
    rows: list[tuple[float, ...]],
    metadata: dict[str, Any],
    route: dict[str, Any],
) -> None:
    targets = route["route_targets"]
    position = route["route_start"]
    c.require(len(rows) == metadata["tick_count"] == metadata["seconds"] * 60, "missing tick rows")
    c.require(len(targets) == 16, "VBASE-001 route requires 16 checkpoints")
    checkpoints: list[tuple[int, int, tuple[float, float], tuple[float, float]]] = []
    target = 0
    still_ticks = 0
    for index, (tick, current, x, y, camera_x, camera_y, minutes) in enumerate(rows, 1):
        c.require(tick == index and current == target, f"route tick or target missing: {index}")
        distance = math.dist(position, (x, y))
        c.require(distance <= 8, f"route skipped physical movement: {index}")
        still_ticks = still_ticks + 1 if distance < 0.001 else 0
        c.require(still_ticks < 120, f"route stopped for 120 physics ticks: {index}")
        c.require(math.dist(projected_camera(x, y), (camera_x, camera_y)) < 0.002, "camera changed")
        c.require(abs(minutes - 1200 - tick / 60) < 0.002, "world time stopped or drifted")
        if math.dist((x, y), targets[target]) <= 4.0:
            checkpoints.append((index, target, (x, y), (camera_x, camera_y)))
            target = (target + 1) % len(targets)
        position = (x, y)
    reported = metadata["checkpoints"]
    c.require(len(reported) == len(checkpoints), "checkpoint count differs")
    for observed, (tick_index, target_index, point, camera) in zip(
        reported,
        checkpoints,
        strict=True,
    ):
        c.require(
            observed[:2] == [tick_index, target_index]
            and math.dist(observed[2], point) < 0.002
            and math.dist(observed[3], camera) < 0.002,
            "recorded checkpoint disagrees with raw trajectory",
        )
    c.require(
        len(checkpoints) // len(targets) == metadata["route_start_end"] >= len(rows) // 1100,
        "incomplete outward and return loops",
    )


def cpu_and_rss(path: Path, start: float, end: float) -> dict[str, Any]:
    data = c.read(path)
    rate = data["clock_ticks_per_second"]
    page_size = data["page_size"]
    samples = data["samples"]
    c.require(rate > 0 and page_size > 0, "external CPU/RSS units unavailable")
    for before, after in zip(samples, samples[1:], strict=False):
        c.require(
            after["utc_ns"] > before["utc_ns"]
            and after["user_ticks"] >= before["user_ticks"]
            and after["system_ticks"] >= before["system_ticks"],
            "external process clock or CPU counter went backwards",
        )
    admitted = [sample for sample in samples if start < sample["utc_ns"] / 1e9 < end]
    c.require(
        len(admitted) >= 4 and all(row["resident_pages"] > 0 for row in admitted),
        "external samples do not cover the measured run",
    )
    first, last = admitted[0], admitted[-1]
    wall = (last["utc_ns"] - first["utc_ns"]) / 1e9
    c.require(wall >= (end - start) * 0.6, "insufficient sampled CPU span")
    user = (last["user_ticks"] - first["user_ticks"]) / rate
    kernel = (last["system_ticks"] - first["system_ticks"]) / rate
    rss = [sample["resident_pages"] * page_size for sample in admitted]
    return {
        "sample_count": len(admitted),
        "sampled_wall_s": wall,
        "user_cpu_s": user,
        "system_cpu_s": kernel,
        "mean_cpu_cores": (user + kernel) / wall,
        "rss_bytes": {"first": rss[0], "last": rss[-1], "max": max(rss)},
    }


def frames_summary(
    rows: list[tuple[float, ...]],
    metadata: dict[str, Any],
) -> dict[str, Any]:
    seconds = metadata["seconds"]
    c.require(
        len(rows) == metadata["draw_count"] == metadata["retained_interval_count"]
        and len(rows) >= seconds * 5,
        "missing or truncated native render intervals",
    )
    start, finish = metadata["sample_start_usec"], metadata["sample_end_usec"]
    opening = metadata["first_draw"]
    closing = metadata["final_draw"]
    previous_time = opening["usec"]
    c.require(start < previous_time < finish, "initial draw boundary lies outside measurement")
    c.require(
        seconds - 0.5 <= (finish - start) / 1e6 <= seconds * 1.25,
        "unusable wall duration at fixed physics ticks",
    )
    previous_draw: float = opening["draw_id"]
    previous_process: float = opening["process_id"]
    previous_tick: float = opening["physics_tick"]
    c.require(1 <= previous_tick < seconds * 60, "opening draw did not observe live physics")
    for usec, interval, draw, process, tick, calls, static, texture, idle, physics, *_ in rows:
        c.require(
            previous_time < usec <= finish
            and draw == previous_draw + 1
            and process >= previous_process
            and previous_tick <= tick <= seconds * 60
            and tick == int(tick),
            "draw, process or physics row missing or out of order",
        )
        c.require(
            abs((usec - previous_time) / 1000 - interval) < 0.002,
            "raw frame interval differs from the monotonic clock",
        )
        c.require(
            interval > 0 and calls > 0 and static > 0 and min(texture, idle, physics) >= 0,
            "invalid drawable frame, memory or engine counters",
        )
        previous_time, previous_draw, previous_process, previous_tick = usec, draw, process, tick
    c.require(
        previous_time == finish == closing["usec"]
        and previous_draw == closing["draw_id"]
        and previous_process == closing["process_id"]
        and previous_tick == closing["physics_tick"] == seconds * 60,
        "last row is not the final native draw on the last physics tick",
    )
    late = sum(row[1] > 33.4 for row in rows)
    return {
        "interval_count": len(rows),
        "sample_wall_s": (finish - start) / 1e6,
        "frame_interval_ms": distribution([row[1] for row in rows]),
        "draw_calls": distribution([row[5] for row in rows]),
        "engine_process_ms": distribution([row[8] for row in rows]),
        "engine_physics_ms": distribution([row[9] for row in rows]),
        "engine_static_bytes_max": max(row[6] for row in rows),
        "engine_texture_bytes_max": max(row[7] for row in rows),
        "intervals_over_33_4_ms": late,
        "late_fraction": late / len(rows),
    }


def check_render_camera(
    draws: Sequence[tuple[float, ...]],
    trajectory: Sequence[tuple[float, ...]],
    start_position: tuple[float, float],
) -> None:
    """Сопоставляет фактический кадр с отрезком камеры между подтверждёнными тиками."""
    for row in draws:
        tick = int(row[4])
        ground_x, ground_y, camera_x, camera_y = row[-4:]
        before_x, before_y = start_position if tick == 1 else trajectory[tick - 2][2:4]
        end_x, end_y = trajectory[tick - 1][2:4]
        step_x, step_y = end_x - before_x, end_y - before_y
        squared_distance = step_x**2 + step_y**2
        fraction = (
            ((ground_x - before_x) * step_x + (ground_y - before_y) * step_y) / squared_distance
            if squared_distance
            else 0.0
        )
        fraction = max(0.0, min(fraction, 1.0))
        expected_ground = (before_x + fraction * step_x, before_y + fraction * step_y)
        c.require(
            math.dist(expected_ground, (ground_x, ground_y)) < 0.002, "rendered route differs"
        )
        c.require(
            math.dist(projected_camera(ground_x, ground_y), (camera_x, camera_y)) < 0.002,
            "render camera differs from projection",
        )


def inspect(
    path: Path,
    variant: str,
    seconds: int,
    route: dict[str, Any],
    expected_version: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    data = c.read(path / "run.json")
    launch = c.read(path / "launch.json")
    c.require(
        data["task"] == c.TASK
        and data["schema"] == 2
        and not data["error"]
        and data["route_only"] is False
        and data["seconds"] == seconds
        and data["pass"] == variant,
        "run metadata mismatches schedule or contains a rejection",
    )
    c.require(
        launch["exit_code"] == 0
        and launch["timeout"] is False
        and launch["profile"] == data["profile"]
        and launch["pid"] == data["pid"]
        and re.fullmatch(r"Codex-VPERF-003-[a-f0-9]{32}", data["profile"])
        and launch["command"][-3:]
        == [
            "--profile=" + data["profile"],
            "--pass=" + variant,
            "--seconds=" + str(seconds),
        ],
        "runtime arguments or userdata receipt differ",
    )
    c.require(
        data["display"] == "X11"
        and data["driver"] == "opengl3"
        and "llvmpipe" in data["adapter"].lower()
        and data["engine"] == "4.7.1-stable (official)"
        and data["engine_build"].startswith(expected_version.rsplit(".", 1)[1])
        and data["warmup_draws"] == 120
        and data["world_scale"] == 1.2
        and data["physics_hz"] == 60
        and data["fps_cap"] == 0
        and data["seed"] == 20261015
        and data["audio_enabled"] is False
        and data["reduced_motion"] is False
        and data["gpu_time_ms"] is None
        and data["frame_boundary"] == "frame_post_draw",
        "native configuration or measurement attribution mismatch",
    )
    c.require(
        abs(
            (data["utc_ended"] - data["utc_started"])
            - (data["sample_end_usec"] - data["sample_start_usec"]) / 1e6
        )
        < 0.2,
        "external and monotonic measurement boundaries disagree",
    )
    for phase in ("initial", "final"):
        endpoint = data[phase]
        c.require(
            endpoint["valid"] is True
            and endpoint["focus"] is True
            and endpoint["vsync_requested"] == 1
            and endpoint["vsync"] == data["initial"]["vsync"]
            and endpoint["window"] == endpoint["framebuffer"] == [1152, 648]
            and all(endpoint[key] is (key != variant) for key in c.VARIANTS[1:]),
            "native framebuffer, focus or independent pass differs",
        )
    c.require(
        data["initial"]["weather"] == "clear" and data["final"]["weather"] == data["weather"],
        "weather at a sampling boundary differs",
    )
    for image in ("before", "after"):
        with Image.open(path / (image + ".png")) as png:
            c.require(png.size == (1152, 648) and png.format == "PNG", "invalid native PNG")
            png.load()
    trajectory = csv_rows(path / "trajectory.csv.gz", c.ROUTE_FIELDS)
    draws = csv_rows(path / "frames.csv.gz", c.FRAME_FIELDS)
    check_trajectory(trajectory, data, route)
    frame = frames_summary(draws, data)
    start_x, start_y = route["route_start"]
    check_render_camera(draws, trajectory, (start_x, start_y))
    external = cpu_and_rss(path / "cpu-rss.json", data["utc_started"], data["utc_ended"])
    passive = ["trajectory.csv.gz", "save-before.json", "save-after.json"]
    return data, {
        **frame,
        "process": external,
        "observer_buffer_bytes": data["observer_buffer_bytes"],
        "gpu_time_ms": None,
        "loops": data["route_start_end"],
        "maintenance_cycles": data["maintenance_cycles"],
        "simulation": {
            **{name: c.digest(path / name) for name in passive},
            "final_weather": data["weather"],
        },
    }


def comparable(reference: dict[str, Any], candidate: dict[str, Any]) -> bool:
    return bool(reference["simulation"] == candidate["simulation"])


def deltas(reference: dict[str, Any], candidate: dict[str, Any]) -> dict[str, Any]:
    """Baseline minus omitted: положительное значение означает меньшую наблюдаемую стоимость."""
    c.require(comparable(reference, candidate), "trajectory/camera or save fields drifted")
    return {
        "frame_interval_ms": {
            k: reference["frame_interval_ms"][k] - candidate["frame_interval_ms"][k]
            for k in ("p50", "p95", "p99", "max")
        },
        "draw_calls_p50": reference["draw_calls"]["p50"] - candidate["draw_calls"]["p50"],
        "mean_cpu_cores": reference["process"]["mean_cpu_cores"]
        - candidate["process"]["mean_cpu_cores"],
        "rss_peak_bytes": reference["process"]["rss_bytes"]["max"]
        - candidate["process"]["rss_bytes"]["max"],
        "gpu_time_ms": None,
    }


def verify(folder: Path, expected_head: str) -> dict[str, Any]:
    root = folder.resolve(strict=True)
    source = c.read(c.ordinary_file(root, "source.json"))
    tree = c.tree(expected_head)
    route_source = c.git("show", expected_head + ":" + c.ROUTE)
    route = c.read(c.ROOT / c.ROUTE)
    c.require((c.ROOT / c.ROUTE).read_bytes() == route_source, "reference route differs from Git")
    c.require(
        source["schema"] == 1
        and source["task"] == c.TASK
        and source["complete"] is True
        and source["head"] == expected_head
        and source["tree"] == tree
        and source["schedule"] == [list(entry) for entry in c.schedule()]
        and source["route_sha256"] == c.digest(c.ROOT / c.ROUTE)
        and re.fullmatch(r"[0-9a-f]{64}", source["engine_sha256"]),
        "manifest does not describe this exact complete source",
    )
    expected = c.expected_files()
    c.require(set(source["artifacts"]) == expected, "complete scheduled raw file set required")
    for name in expected:
        c.require(
            c.digest(c.ordinary_file(root, name)) == source["artifacts"][name],
            f"evidence bytes differ: {name}",
        )
    version = (root / "engine-version.txt").read_text().strip()
    c.require(version.startswith("4.7.1.stable.official"), "non-pinned engine")
    runs: dict[str, Any] = {}
    profiles, process_ids = set(), set()
    equipment: tuple[Any, ...] | None = None
    previous_end = 0.0
    for run, variant, seconds in c.schedule():
        data, stats = inspect(root / run / variant, variant, seconds, route, version)
        mode = (
            data["display"],
            data["driver"],
            data["adapter"],
            data["refresh_hz"],
            data["initial"]["vsync"],
        )
        if equipment is None:
            equipment = mode
        c.require(equipment == mode, "host presentation or weather differed")
        c.require(
            data["pid"] not in process_ids
            and data["profile"] not in profiles
            and data["utc_started"] >= previous_end
            and data["utc_ended"] > data["utc_started"],
            "process, profile or measured interval reused",
        )
        previous_end = data["utc_ended"]
        profiles.add(data["profile"])
        process_ids.add(data["pid"])
        runs.setdefault(run, {})[variant] = stats
    comparisons: dict[str, Any] = {}
    for run, _ in c.RUNS:
        baseline = runs[run]["baseline"]
        comparisons[run] = {}
        for variant in c.VARIANTS[1:]:
            with (
                Image.open(root / run / "baseline" / "before.png") as original,
                Image.open(root / run / variant / "before.png") as modified,
            ):
                difference = ImageChops.difference(original.convert("RGB"), modified.convert("RGB"))
                c.require(
                    difference.getbbox() is not None, f"no visible pass difference: {run}/{variant}"
                )
            comparisons[run][variant] = deltas(baseline, runs[run][variant])
    return {
        "task": c.TASK,
        "schema": 1,
        "head": expected_head,
        "tree": tree,
        "execution": "same remote X11/Mesa software renderer for all sequential runs",
        "equipment": equipment,
        "host": source["host"],
        "engine_sha256": source["engine_sha256"],
        "runner_id": source["runner_id"],
        "runner_attempt": source["runner_attempt"],
        "hardware_fps_accepted": False,
        "gpu_time_ms": None,
        "runs": runs,
        "paired_deltas": comparisons,
        "short_median_delta_ms": {
            variant: statistics.median(
                comparisons[run][variant]["frame_interval_ms"]["p95"] for run, _ in c.RUNS[:3]
            )
            for variant in c.VARIANTS[1:]
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-head", required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.output, args.expected_head), ensure_ascii=False, indent=2))
    except (
        ValueError,
        TypeError,
        IndexError,
        KeyError,
        OSError,
        subprocess.SubprocessError,
    ) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
