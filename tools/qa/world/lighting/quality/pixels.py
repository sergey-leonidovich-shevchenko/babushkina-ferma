"""Измеряет настоящий сигнал объектов и проверяет геометрию без resize/перерисовки PNG."""

from __future__ import annotations

import math
from typing import Any

from PIL import Image, ImageChops, ImageStat

from tools.qa.world.lighting.quality import contract as c


def equal(left: Image.Image, right: Image.Image) -> bool:
    """Все RGBA каналы точны, включая RGB прозрачного HUD."""
    return (
        left.size == right.size
        and left.convert("RGBA").tobytes() == right.convert("RGBA").tobytes()
    )


def hud(root: Image.Image, layer: Image.Image) -> int:
    """Непрозрачные свидетели HUD совпадают с корнем независимо от светового профиля."""
    c.need(root.size == layer.size, "HUD size differs")
    opaque = layer.convert("RGBA").getchannel("A").point([0] * 255 + [255])
    count = opaque.histogram()[255]
    c.need(count > 1000, "HUD opaque witness missing")
    delta = ImageChops.difference(root.convert("RGB"), layer.convert("RGB"))
    masked = Image.composite(delta, Image.new("RGB", root.size), opaque)
    values = masked.histogram()
    c.need(
        all(sum(values[start + 3 : start + 256]) == 0 for start in (0, 256, 512)),
        "world lighting recolors opaque HUD",
    )
    return count


def geometry(row: dict[str, Any], case: str) -> None:
    """ROI сверяются с production-размерами и настоящими сущностями, камерой и stretch."""
    before = row["before"]
    room = case.split("-")[0]
    player = [456, 624] if room == "street" else [576, 500]
    location = "overworld" if room == "street" else "cottage_interior"
    saved, geom, entities = before["save"], before["geometry"], before["entities"]
    c.need(
        saved["player"] == geom["player"] == player
        and saved["location"] == geom["location"] == location,
        "fixture player/location differs",
    )
    c.need(
        len(entities["enemies"]) == len(entities["resources"]) == 1, "target entity matrix differs"
    )
    enemy, resource = entities["enemies"][0], entities["resources"][0]
    c.need(
        enemy["kind"] == "skeleton"
        and enemy["level"] == 1
        and enemy["alive"] is True
        and enemy["location"] == location
        and enemy["position"] == saved["enemies"][0]["position"] == [player[0] + 140, player[1]],
        "actual enemy target differs",
    )
    c.need(
        resource["kind"] == "stone"
        and resource["location"] == location
        and resource["hits"] == 2
        and resource["position"] == [player[0] - 130, player[1]],
        "actual resource target differs",
    )
    # Протокол закреплённой геометрии: actor96/ground0.72, resource72/bottom+24,
    # существующий интерактивный порог cottage48x24 и напольный выход дома70x24.
    expected: dict[str, list[float]] = {
        "enemy": [player[0] + 140 - 48, player[1] - 96 * 0.72, 96, 96],
        "resource": [player[0] - 130 - 36, player[1] - 48, 72, 72],
        "door": [336, 528, 48, 24] if room == "street" else [541, 533, 70, 24],
    }
    zoom = geom["zoom"]
    c.need(abs(zoom - (1.2 if room == "street" else 1.0)) < 0.000001, "actual room zoom differs")
    a, b, cc, d, tx, ty = row["stretch"]
    c.need(
        all(math.isfinite(x) for x in row["stretch"])
        and a > 0
        and d > 0
        and abs(b) < 0.000001
        and abs(cc) < 0.000001,
        "invalid physical stretch",
    )
    c.need(set(row["targets"]) == set(c.TARGETS), "target ROI set differs")
    for name, world in expected.items():
        target = row["targets"][name]
        c.need(
            len(target["world"]) == 4
            and all(abs(x - y) < 0.00001 for x, y in zip(target["world"], world, strict=True)),
            "production target geometry differs: " + name,
        )
        x, y, width, height = world
        points = [
            (a * (u - geom["camera"][0]) * zoom + tx, d * (v - geom["camera"][1]) * zoom + ty)
            for u in (x, x + width)
            for v in (y, y + height)
        ]
        left, top = math.floor(min(p[0] for p in points)), math.floor(min(p[1] for p in points))
        native = [
            left,
            top,
            math.ceil(max(p[0] for p in points)) - left,
            math.ceil(max(p[1] for p in points)) - top,
        ]
        actual = target["native"]
        c.need(len(actual) == 4, "native ROI needs four coordinates")
        actual_edges = [actual[0], actual[1], actual[0] + actual[2], actual[1] + actual[3]]
        expected_edges = [native[0], native[1], native[0] + native[2], native[1] + native[3]]
        c.need(
            all(abs(x - y) <= 1 for x, y in zip(actual_edges, expected_edges, strict=True)),
            "native ROI does not follow actual camera/stretch: " + name,
        )


def target(root: Image.Image, hidden: Image.Image, bounds: list[int]) -> float:
    """Порог двери использует контроль без фона; враг и жила — без их настоящего draw-прохода."""
    x, y, width, height = bounds
    c.need(
        root.size == hidden.size
        and x >= 0
        and y >= 0
        and width > 0
        and height > 0
        and x + width <= root.width
        and y + height <= root.height,
        "target ROI outside framebuffer",
    )
    delta = ImageChops.difference(root.convert("RGB"), hidden.convert("RGB")).crop(
        (x, y, x + width, y + height)
    )
    witness = delta.convert("L").point([0] * 6 + [255] * 250)
    c.need(witness.histogram()[255] >= 80, "target has no readable native pixel witness")
    return float(sum(ImageStat.Stat(delta).mean))
