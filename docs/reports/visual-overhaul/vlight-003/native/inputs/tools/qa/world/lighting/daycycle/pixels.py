"""Проверяет настоящий HUD и видимость героя/угрозы в нативных PNG, без перерисовки."""

from __future__ import annotations

import math
from typing import Any

from PIL import Image, ImageChops, ImageStat

from tools.qa.world.lighting.daycycle.contract import need


def equal(left: Image.Image, right: Image.Image) -> bool:
    """Сравнивает все RGBA каналы, включая RGB прозрачных пикселей."""
    return (
        left.size == right.size
        and left.convert("RGBA").tobytes() == right.convert("RGBA").tobytes()
    )


def hud(root: Image.Image, layer: Image.Image) -> int:
    """Непрозрачные пиксели реального HUD обязаны совпасть с нормальным production root."""
    need(root.size == layer.size, "HUD size differs")
    opaque = layer.convert("RGBA").getchannel("A").point([0] * 255 + [255])
    count = opaque.histogram()[255]
    need(count > 1000, "HUD opaque witness is missing")
    difference = ImageChops.difference(root.convert("RGB"), layer.convert("RGB"))
    masked = Image.composite(difference, Image.new("RGB", root.size), opaque)
    histogram = masked.histogram()
    need(
        all(sum(histogram[start + 3 : start + 256]) == 0 for start in (0, 256, 512)),
        "normal root recolors opaque HUD",
    )
    return count


def stable_hud(accepted: Image.Image, legacy: Image.Image, selected: Image.Image) -> None:
    """Оба ошибочно перекрашенных контроля не могут подтвердить друг друга без старого HUD."""
    need(equal(accepted, legacy), "legacy HUD differs from accepted same-time HUD")
    need(equal(accepted, selected), "palette recolors accepted same-time HUD")


def geometry(row: dict[str, Any]) -> None:
    """Сверяет framebuffer-области с камерой и реальным stretch; округление допускает1px."""
    context = row["before"]["geometry"]
    expected_ground = [
        (context["player"][i] - context["camera"][i]) * context["zoom"] for i in (0, 1)
    ]
    need(
        all(abs(row["ground"][i] - expected_ground[i]) < 0.01 for i in (0, 1)),
        "logical ground differs",
    )
    need(
        len(row["stretch"]) == 6 and all(math.isfinite(v) for v in row["stretch"]),
        "invalid native stretch",
    )
    a, b, c, d, tx, ty = row["stretch"]
    need(
        a > 0 and d > 0 and abs(b) < 0.0001 and abs(c) < 0.0001,
        "unexpected native stretch orientation",
    )
    x, y = row["ground"]
    for name, logical in (
        ("hero", [x - 45, y - 105, 90, 130]),
        ("threat", [x + 105, y - 85, 125, 145]),
    ):
        left, top, width, height = logical
        points = [
            (a * u + c * v + tx, b * u + d * v + ty)
            for u in (left, left + width)
            for v in (top, top + height)
        ]
        edges = [
            math.floor(min(p[0] for p in points)),
            math.floor(min(p[1] for p in points)),
            math.ceil(max(p[0] for p in points)),
            math.ceil(max(p[1] for p in points)),
        ]
        rect = row[name]
        actual = [rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]]
        need(
            all(abs(actual[i] - edges[i]) <= 1 for i in range(4)),
            "target native rectangle differs: " + name,
        )


def target(root: Image.Image, hidden: Image.Image, rect: list[int]) -> float:
    """Нативная пара с/без прежнего renderer выделяет видимый сигнал существующего объекта."""
    x, y, width, height = rect
    need(
        x >= 0 and y >= 0 and x + width <= root.width and y + height <= root.height,
        "target ROI outside frame",
    )
    difference = ImageChops.difference(root.convert("RGB"), hidden.convert("RGB")).crop(
        (x, y, x + width, y + height)
    )
    mask = difference.convert("L").point([0] * 6 + [255] * 250)
    need(mask.histogram()[255] >= 80, "hero/threat has no readable native pixels")
    return float(sum(ImageStat.Stat(difference).mean))
