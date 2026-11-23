"""Проверяет реальные сырые CPU/frame samples, не выдавая software X11 за аппаратный FPS."""

from __future__ import annotations

import math
from typing import Any

from tools.qa.world.lighting.quality import contract as c


def statistics(samples: list[int]) -> dict[str, float]:
    """Процентили вычисляются из исходных значений с линейной интерполяцией, в микросекундах."""
    c.need(
        len(samples) == 60
        and all(
            isinstance(x, (int, float)) and not isinstance(x, bool) and math.isfinite(x) and x > 0
            for x in samples
        ),
        "invalid actual raw timing samples",
    )
    ordered = sorted(samples)

    def percentile(fraction: float) -> float:
        """Интерполирует соседние наблюдения без округления исходных измерений."""
        at = (len(ordered) - 1) * fraction
        lo, hi = math.floor(at), math.ceil(at)
        return float(ordered[lo] + (ordered[hi] - ordered[lo]) * (at - lo))

    return {
        "p50_us": percentile(0.5),
        "p95_us": percentile(0.95),
        "p99_us": percentile(0.99),
        "max_us": float(ordered[-1]),
    }


def check(rows: list[dict[str, Any]], baseline: bool, width: int) -> list[dict[str, Any]]:
    """Неактивное окно, неверный лимит, подменённые тики или изменённый save отклоняются."""
    modes = ("standard",) if baseline else c.MODES
    expected = {(mode, repeat) for mode in modes for repeat in range(3)}
    c.need(
        len(rows) == len(expected) and {(row["mode"], row["repeat"]) for row in rows} == expected,
        "three-repeat cost matrix differs",
    )
    order: list[tuple[str, int]] = []
    for repeat in range(3):
        selected = list(modes)
        if repeat == 1:
            selected.reverse()
        elif repeat == 2 and not baseline:
            selected = ["low", "off", "standard"]
        order.extend((mode, repeat) for mode in selected)
    c.need(
        [(row["mode"], row["repeat"]) for row in rows] == order, "measurement alternation differs"
    )
    result = []
    frames: set[int] = set()
    for row in rows:
        c.need(
            row["before"] == row["after"]
            and row["before"]["profile"] == row["mode"]
            and row["before"]["seed"] == c.SEED,
            "measurement changed gameplay/profile/seed",
        )
        c.need(
            row["warmup"] == 20 and len(row["observations"]) == 60,
            "measurement sample/warmup count differs",
        )
        previous_tick = row["start_tick_us"]
        previous_frame = -1
        spans = []
        for observation in row["observations"]:
            c.need(
                observation["visible"] is True
                and observation["focused"] is True
                and observation["window"] == [width, width * 9 // 16],
                "inactive/resized measurement window",
            )
            c.need(
                observation["engine_max_fps"] == 0 and observation["vsync"] == 0,
                "capped timing cannot accept raw frame sample",
            )
            tick, frame = observation["tick_us"], observation["process_frame"]
            c.need(
                frame > previous_frame
                and frame not in frames
                and tick > previous_tick
                and observation["frame_us"] == tick - previous_tick,
                "reused/nonadvancing actual frame or forged interval",
            )
            spans.append(observation["frame_us"])
            frames.add(frame)
            previous_tick, previous_frame = tick, frame
        result.append(
            {
                "mode": row["mode"],
                "repeat": row["repeat"],
                "draw": statistics(row["draw_us"]),
                "frame": statistics(spans),
                "gpu_time_measured": False,
                "hardware_fps_acceptance": False,
            }
        )
    return result
