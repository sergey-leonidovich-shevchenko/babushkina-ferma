"""Post-collection analysis. Inclusive spans are unioned; unavailable CPU samples stay null."""

from __future__ import annotations
import bisect
import csv
import gzip
import json
from pathlib import Path
import statistics
import sys

TOP = {"_process", "_physics_process", "_draw", "background._draw"}


def read(path):
    return (
        path.read_bytes()
        if path.exists()
        else gzip.decompress(path.with_suffix(path.suffix + ".gz").read_bytes())
    )


def union_length(spans, start, end):
    total, previous = 0, start
    for left, right in sorted(spans):
        left, right = max(left, start, previous), min(right, end)
        if right > left:
            total += right - left
            previous = right
    return total


def percentile(values, portion):
    return (
        sorted(values)[min(len(values) - 1, int((len(values) - 1) * portion))]
        if values
        else None
    )


def host_delta(first, last):
    a, b = first.get("host_cpu_ticks"), last.get("host_cpu_ticks")
    if a is None or b is None:
        return None
    differences = [(y - x) % 2**32 for x, y in zip(a, b)]
    total = sum(differences)
    return (total - differences[2]) / total if total else None


def cpu_delta(first, last, role):
    a, b = first["processes"].get(role), last["processes"].get(role)
    if (
        not a
        or not b
        or not a["available"]
        or not b["available"]
        or a["pid"] != b["pid"]
    ):
        return None
    duration = b["query_end_ns"] - a["query_end_ns"]
    return (b["cpu_ns"] - a["cpu_ns"]) / duration if duration > 0 else None


def analyze(folder):
    context = json.loads((folder / "context.json").read_text())
    observer = json.loads(read(folder / "observer.json"))
    protocol, spans, states, final, settings = [], [], [], None, []
    for line in read(folder / "stdout.txt").decode().splitlines():
        if line.startswith("PERF_CAPTURE "):
            protocol.append(json.loads(line[len("PERF_CAPTURE ") :]))
        elif line.startswith("DIAG_SPAN "):
            spans.append(json.loads(line[len("DIAG_SPAN ") :]))
        elif line.startswith("DIAG_STATE "):
            states.append(json.loads(line[len("DIAG_STATE ") :]))
        elif line.startswith("DIAG_FINAL "):
            final = json.loads(line[len("DIAG_FINAL ") :])
        elif line.startswith("DIAG_SETTINGS "):
            settings.append(json.loads(line[len("DIAG_SETTINGS ") :]))
    begin = next((r for r in protocol if r["kind"] == "begin"), None)
    end = next((r for r in protocol if r["kind"] == "end"), None)
    if not begin or not end or not final:
        return {
            "folder": folder.name,
            "complete": False,
            "context_measurement": context.get("measurement"),
        }
    start, stop = begin["time_us"], begin["time_us"] + 10_000_000
    names = final["names"]
    root = sorted((r[1], r[2]) for r in spans if names[r[0]] in TOP)
    # Root callbacks run on one main thread. Merge once, then query only overlapping intervals.
    merged = []
    for left, right in root:
        if merged and left <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(right, merged[-1][1]))
        else:
            merged.append((left, right))
    root_starts = [r[0] for r in merged]

    def root_time(left, right):
        low = max(0, bisect.bisect_right(root_starts, left) - 1)
        high = bisect.bisect_left(root_starts, right)
        return union_length(merged[low:high], left, right)

    phase_times = {}
    for row in spans:
        clipped = max(0, min(row[2], stop) - max(row[1], start))
        if clipped:
            phase_times.setdefault(names[row[0]], []).append(clipped)
    samples = observer["samples"]
    sample_ns = [r["host_ns"] for r in samples]
    marker = next(r for r in observer["receipt"] if r["kind"] == "begin")

    def nearest(game_us):
        host_ns = marker["host_ns"] + (game_us - start) * 1000
        at = bisect.bisect_left(sample_ns, host_ns)
        options = [samples[n] for n in {max(0, at - 1), min(len(samples) - 1, at)}]
        return min(options, key=lambda r: abs(r["host_ns"] - host_ns))

    frames, previous = [], start
    for row in protocol:
        if row["kind"] != "frame":
            continue
        finish = row["time_us"]
        first, last = nearest(previous), nearest(finish)
        wall = finish - previous
        actual_root = root_time(previous, finish)
        frames.append(
            {
                "finish_us": finish,
                "frame": row["engine_frame"],
                "gap_us": wall,
                "root_union_us": actual_root,
                "outside_root_us": wall - actual_root,
                "approx_cpu_to_wall": cpu_delta(first, last, "game"),
                "approx_host_busy": host_delta(first, last),
                "closing_callback": finish >= stop,
            }
        )
        previous = finish
    with (folder / "frame-analysis.csv").open("w") as handle:
        writer = csv.DictWriter(handle, fieldnames=frames[0].keys())
        writer.writeheader()
        writer.writerows(frames)
    bins = []
    for n in range(10):
        left, right = start + n * 1_000_000, start + (n + 1) * 1_000_000
        first, last = nearest(left), nearest(right)
        bins.append(
            {
                "index": n,
                "frames": sum(left <= r["finish_us"] < right for r in frames),
                "root_union_us": root_time(left, right),
                "approx_game_cpu_to_wall": cpu_delta(first, last, "game"),
                "approx_runner_cpu_to_wall": cpu_delta(first, last, "runner"),
                "approx_sample_cpu_to_wall": cpu_delta(first, last, "sample"),
                "approx_host_busy": host_delta(first, last),
                "host_load_average": first["load_average"],
            }
        )
    wanted = json.loads((folder.parents[1] / "plan.json").read_text())
    settings_ok = len(settings) == 3 and all(
        all(
            item["settings"].get(k) == value
            for k, value in wanted["effective_after_startup"].items()
        )
        and all(
            item["settings"].get(k) == wanted["backend"][k]
            for k in ("display", "driver", "method")
        )
        and item["settings"]["max_fps"] == context["cap"]
        and item["settings"]["plan_sha256"] == context["causal_plan_sha256"]
        for item in settings
    )
    result = {
        "folder": folder.name,
        "measurement": context["measurement"],
        "cpu_window": observer.get("cpu_window"),
        "game_marker_interval_us": end["time_us"] - start,
        "marker_delivery_interval_ns": observer["markers"]["end"]["host_ns"]
        - observer["markers"]["begin"]["host_ns"],
        "effective_settings_match": settings_ok,
        "all_frame_settings_match": bool(states)
        and all(
            r[5:12] == [context["cap"], True, 500, 1.0, False, True, True]
            for r in states
        ),
        "recorded_route_locations": sorted({r[12] for r in states}),
        "overflow": final["overflow"],
        "span_count": len(spans),
        "state_count": len(states),
        "root_union_us": root_time(start, stop),
        "bins": bins,
        "phase_inclusive_us": {
            name: {
                "count": len(times),
                "sum": sum(times),
                "median": statistics.median(times),
                "p95": percentile(times, 0.95),
                "max": max(times),
            }
            for name, times in phase_times.items()
        },
        "frame_gap_us": {
            "median": statistics.median([r["gap_us"] for r in frames]),
            "p95": percentile([r["gap_us"] for r in frames], 0.95),
            "max": max(r["gap_us"] for r in frames),
        },
        "long_frames_gt_33333us": sum(r["gap_us"] > 33333 for r in frames),
        "heavy_frames_gt_100000us": sum(r["gap_us"] > 100000 for r in frames),
        "longest_frames": sorted(frames, key=lambda r: r["gap_us"], reverse=True)[:20],
        "native_profiler": observer["profiler"],
        "sources_unchanged": context["sources_unchanged"],
        "assets_unchanged": context["assets_unchanged"],
    }
    (folder / "analysis.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


if __name__ == "__main__":
    campaign = Path(sys.argv[1])
    manifest = json.loads((campaign / "manifest.json").read_text())
    results = []
    for case in manifest["cases"]:
        row = analyze(campaign / case["folder"])
        results.append(row)
        print(row["folder"], row.get("measurement"), row.get("cpu_window"), flush=True)
    (campaign / "analysis.json").write_text(
        json.dumps(
            {"campaign_complete": manifest["complete"], "cases": results}, indent=2
        )
        + "\n"
    )
