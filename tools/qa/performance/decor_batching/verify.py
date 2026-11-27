"""Проверяет пары геометрии декора VPERF-006 по закреплённой карте и контрольному экспорту."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from tools.qa.performance.pass_cost.contract import ROOT, git, read, require

BASE = "c88db730ffb604fd64f818fa9ef9e6e287dd4cd4"
MAP_SOURCE = "scripts/systems/village_map_data.gd"
CONTROL = ROOT / "docs/reports/visual-overhaul/vperf-006/geometry-control.json"
WINDOW = (1152, 648)
ZOOM_PERCENT = 120
WORLD = (0, 0, 2400, 1368)
CHUNK = (480, 336)
VARIANTS = ("baseline", "one_batch", "spatial_batches")

Point = tuple[int, int]
Rect = tuple[int, int, int, int]
Batch = tuple[Point, ...]


@dataclass(frozen=True)
class Case:
    phase: str
    camera: Point
    repaint: Rect | None = None

    @property
    def view(self) -> Rect:
        width, height = WINDOW
        return (*self.camera, width * 100 // ZOOM_PERCENT, height * 100 // ZOOM_PERCENT)

    @property
    def clip(self) -> Rect:
        return self.repaint if self.repaint is not None else self.view


CASES = {
    "full_rebuild": Case("full_refresh", (0, 402), WORLD),
    "flower_crossing_cell": Case("local_refresh", (0, 402), (468, 528, 24, 72)),
    "three_flowers": Case("local_refresh", (384, 186), (480, 520, 384, 144)),
    "empty_patch": Case("local_refresh", (1440, 828), (2088, 1200, 144, 96)),
    "home_view": Case("warm_route", (0, 402)),
    "west_bridge_view": Case("warm_route", (384, 186)),
    "village_square_view": Case("warm_route", (648, 474)),
    "east_view": Case("warm_route", (1440, 385)),
    "north_view": Case("warm_route", (648, 0)),
}


def flowers() -> tuple[Point, ...]:
    """Берёт опоры из принятой карты, независимо от обоих сравниваемых кадров."""
    source = git("show", f"{BASE}:{MAP_SOURCE}").decode()
    section = re.search(r"^const FLOWERS := \[\n((?:\tVector2\(\d+, \d+\),?\n)+)\]$", source, re.M)
    if section is None:
        raise ValueError("canonical flower layout is missing or has changed format")
    anchors = tuple((int(x), int(y)) for x, y in re.findall(r"Vector2\((\d+), (\d+)\)", section[1]))
    require(len(anchors) == len(set(anchors)), "canonical layout contains duplicate flower anchors")
    return anchors


def footprint(anchor: Point) -> Rect:
    """Проецирует опору в штатный прямоугольник 72×72 с нижней привязкой и сдвигом +24."""
    x, y = anchor
    return x - 36, y - 48, 72, 72


def intersects(first: Rect, second: Rect) -> bool:
    x, y, width, height = first
    left, top, other_width, other_height = second
    return (
        x < left + other_width and left < x + width and y < top + other_height and top < y + height
    )


def bounds(batch: Batch) -> Rect:
    left = min(x for x, _ in batch) - 36
    top = min(y for _, y in batch) - 48
    right = max(x for x, _ in batch) + 36
    bottom = max(y for _, y in batch) + 24
    return left, top, right - left, bottom - top


def visible(anchors: Sequence[Point], clip: Rect) -> tuple[Point, ...]:
    return tuple(anchor for anchor in anchors if intersects(footprint(anchor), clip))


def batches(anchors: Sequence[Point], variant: str, clip: Rect) -> tuple[Batch, ...]:
    if variant == "baseline":
        return tuple((anchor,) for anchor in anchors)
    if variant == "one_batch":
        batch = tuple(anchors)
        return (batch,) if intersects(bounds(batch), clip) else ()
    chunks: dict[Point, list[Point]] = {}
    for x, y in anchors:
        chunks.setdefault((x // CHUNK[0], y // CHUNK[1]), []).append((x, y))
    groups = [tuple(group) for group in chunks.values()]
    return tuple(group for group in groups if intersects(bounds(group), clip))


def counts(batch_plan: Sequence[Batch], visible_anchors: Sequence[Point]) -> dict[str, int]:
    return {
        "groups": len(batch_plan),
        "submitted": sum(map(len, batch_plan)),
        "visible": len(visible_anchors),
    }


def check_control(control: Any, anchors: Sequence[Point]) -> None:
    """Сверяет модель с ранее снятым выводом inventory.gd для девяти областей."""
    expected = {
        label: {
            variant: counts(batches(anchors, variant, case.clip), visible(anchors, case.clip))
            for variant in VARIANTS[1:]
        }
        for label, case in CASES.items()
    }
    require(
        control == {"scope": "offline_geometry", "branches": expected}, "prototype control differs"
    )


def parse_anchors(raw: Any, label: str) -> tuple[Point, ...]:
    require(isinstance(raw, list), f"invalid {label}")
    anchors: list[Point] = []
    for item in raw:
        require(
            isinstance(item, list) and len(item) == 2 and all(type(value) is int for value in item),
            f"invalid {label} anchor",
        )
        anchors.append((item[0], item[1]))
    require(len(anchors) == len(set(anchors)), f"duplicate {label} anchor")
    return tuple(anchors)


def matches_coordinates(value: Any, expected: tuple[int, ...]) -> bool:
    return (
        isinstance(value, list)
        and all(type(item) is int for item in value)
        and tuple(value) == expected
    )


def verify_record(
    record: Any, case: Case, anchors: Sequence[Point], variant: str
) -> dict[str, int]:
    required = {
        "window",
        "framebuffer",
        "zoom_percent",
        "camera",
        "phase",
        "repaint",
        "batches",
        "visible",
    }
    require(
        isinstance(record, dict) and record.keys() == required, "invalid geometry record fields"
    )
    require(record["phase"] == case.phase, "refresh phase differs")
    require(matches_coordinates(record["window"], WINDOW), "window differs")
    require(matches_coordinates(record["framebuffer"], WINDOW), "framebuffer differs")
    require(
        type(record["zoom_percent"]) is int and record["zoom_percent"] == ZOOM_PERCENT,
        "zoom differs",
    )
    require(matches_coordinates(record["camera"], case.camera), "camera differs")
    observed_region = record["repaint"]
    correct_region = (
        observed_region is None
        if case.repaint is None
        else matches_coordinates(observed_region, case.repaint)
    )
    require(correct_region, "repaint region differs")

    require(isinstance(record["batches"], list), "invalid batches")
    batch_plan = tuple(parse_anchors(group, "batch") for group in record["batches"])
    submitted = tuple(anchor for group in batch_plan for anchor in group)
    require(len(submitted) == len(set(submitted)), "duplicate submitted flower anchor")
    expected = batches(anchors, variant, case.repaint) if case.repaint is not None else ()
    require(
        set(submitted) == {point for group in expected for point in group},
        "submitted anchors differ",
    )
    require(
        len(batch_plan) == len(expected)
        and set(map(frozenset, batch_plan)) == set(map(frozenset, expected)),
        "batch membership differs",
    )
    view_anchors = parse_anchors(record["visible"], "visible")
    require(set(view_anchors) == set(visible(anchors, case.clip)), "visible anchors differ")
    return counts(batch_plan, view_anchors)


def verify(pairs: Any, anchors: Sequence[Point]) -> dict[str, Any]:
    require(isinstance(pairs, dict) and pairs.keys() == CASES.keys(), "case matrix differs")
    phases: dict[str, dict[str, Any]] = {}
    for label, case in CASES.items():
        measurements = pairs[label]
        require(
            isinstance(measurements, dict) and measurements.keys() == set(VARIANTS),
            f"variant matrix differs: {label}",
        )
        phases.setdefault(case.phase, {})[label] = {
            variant: verify_record(measurements[variant], case, anchors, variant)
            for variant in VARIANTS
        }
    return {"task": "VPERF-006", "scope": "offline_geometry", "base": BASE, "phases": phases}


def replay(anchors: Sequence[Point]) -> dict[str, Any]:
    """Восстанавливает геометрические входы из карты для офлайн-контроля протокола."""
    return {
        label: {
            variant: {
                "window": list(WINDOW),
                "framebuffer": list(WINDOW),
                "zoom_percent": ZOOM_PERCENT,
                "camera": list(case.camera),
                "phase": case.phase,
                "repaint": list(case.repaint) if case.repaint is not None else None,
                "batches": [
                    [list(point) for point in group]
                    for group in (batches(anchors, variant, case.repaint) if case.repaint else ())
                ],
                "visible": [list(point) for point in visible(anchors, case.clip)],
            }
            for variant in VARIANTS
        }
        for label, case in CASES.items()
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pairs",
        type=Path,
        help="JSON пар по контракту. Без параметра используется офлайн-контроль.",
    )
    try:
        path = parser.parse_args().pairs
        anchors = flowers()
        check_control(read(CONTROL), anchors)
        print(json.dumps(verify(read(path) if path else replay(anchors), anchors), indent=2))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
