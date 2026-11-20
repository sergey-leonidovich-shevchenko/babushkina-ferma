"""Проверяет парные CPU/wall-frame samples, сохраняя медленные и отрицательные результаты."""

from __future__ import annotations

import statistics
from typing import Any

from tools.qa.world.lighting.comparison import contract
from tools.qa.world.lighting.comparison.assertions import require
from tools.qa.world.lighting.comparison.pixels import light_geometry, light_mode


def costs(capture: dict[str, Any]) -> list[dict[str, Any]]:
    """Пары сравниваются по полным saves/контекстам и всем девяноста samples каждого повтора."""
    rows = capture["costs"]
    expected = {
        (room, repeat, mode)
        for room in contract.ROOMS
        for repeat in range(3)
        for mode in contract.MODES
    }
    require(
        {(r["room"], r["repeat"], r["mode"]) for r in rows} == expected
        and len(rows) == len(expected),
        "cost matrix",
    )
    summaries = []
    baseline = {
        room: next(r["before"] for r in rows if r["room"] == room) for room in contract.ROOMS
    }
    for row in rows:
        light_geometry(row["light"], row["before"]["world_context"])
        light_mode(row["light"], row["before"]["world_context"], row["mode"])
        reference = capture["frames"][f"{row['room']}-1320-{row['mode']}"]
        for name in ["world_context", "hud_context"]:
            require(
                row["before"][name] == reference["before"][name],
                "timed scene differs from validated 1320 visual context",
            )
        require(
            row["light"] == reference["light"], "timed light differs from validated visual state"
        )
        require(row["before"] == row["after"] == baseline[row["room"]], "cost save/context changed")
        require(row["warmup_frames"] == 30 and row["sample_frames"] == 90, "fixed sampling plan")
        require(len(row["samples"]) == len(row["draw_us"]) == 90, "missing CPU/frame samples")
        require(all(type(v) is int and v > 0 for v in row["draw_us"]), "invalid CPU sample")
        ticks = [r["tick_us"] for r in row["samples"]]
        require(
            all(a < b for a, b in zip(ticks, ticks[1:], strict=False)), "nonmonotonic frame ticks"
        )
        for index, sample in enumerate(row["samples"]):
            require(
                sample["engine_max_fps"] == 0 and sample["vsync_mode"] == 0,
                "native sampling cap/vsync changed",
            )
            require(sample["window"] == capture["window"], "native sample window changed")
            require(
                sample["focused"] and sample["visible"] and sample["frame_us"] > 0,
                "lost native focus/visibility/sample",
            )
            if index:
                require(
                    sample["process_frame"] > row["samples"][index - 1]["process_frame"],
                    "native process frame did not advance",
                )
                require(
                    sample["frame_us"] == ticks[index] - ticks[index - 1],
                    "frame interval/tick mismatch",
                )
        summaries.append(
            {
                "room": row["room"],
                "mode": row["mode"],
                "repeat": row["repeat"],
                "draw_median_us": statistics.median(row["draw_us"]),
                "frame_median_us": statistics.median(r["frame_us"] for r in row["samples"]),
                "frame_max_us": max(r["frame_us"] for r in row["samples"]),
                "frame_p95_us": sorted(r["frame_us"] for r in row["samples"])[85],
            }
        )
    return summaries
