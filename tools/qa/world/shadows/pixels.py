"""Сравнивает настоящие RGBA-кадры и области фактически нарисованных контактов."""

from __future__ import annotations

import math
from typing import Any

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def changed(left: Image.Image, right: Image.Image) -> Image.Image:
    """Учитывает все четыре канала, включая прозрачность."""
    if left.size != right.size or left.mode != "RGBA" or right.mode != "RGBA":
        raise ValueError("matching RGBA frames required")
    bands = ImageChops.difference(left, right).split()
    result = bands[0]
    for band in bands[1:]:
        result = ImageChops.lighter(result, band)
    return result.point(lambda value: 255 if value else 0)


def mask(size: tuple[int, int], entries: list[dict[str, Any]], margin: int) -> Image.Image:
    """Округляет наружу только зарегистрированные bounds плюс заданный AA-запас."""
    result = Image.new("L", size)
    draw = ImageDraw.Draw(result)
    for entry in entries:
        rect = entry["rect"]
        if len(rect) != 4 or not all(math.isfinite(v) for v in rect):
            raise ValueError("finite four-component bounds required")
        x, y, width, height = rect
        if width <= 0 or height <= 0:
            raise ValueError("positive contact bounds required")
        draw.rectangle(
            (
                math.floor(x) - margin,
                math.floor(y) - margin,
                math.ceil(x + width) + margin,
                math.ceil(y + height) + margin,
            ),
            fill=255,
        )
    return result


def count(image: Image.Image) -> int:
    """Считает изменённые пиксели бинарной маски."""
    return image.histogram()[255]


def opaque_core(size: tuple[int, int], source: Image.Image, item: dict[str, Any]) -> Image.Image:
    """Исключает два экранных пикселя AA-кромки фактической текстуры предмета."""
    x, y, width, height = item["rect"]
    box = (math.floor(x), math.floor(y), math.ceil(x + width), math.ceil(y + height))
    alpha = source.getchannel("A").resize(
        (box[2] - box[0], box[3] - box[1]), Image.Resampling.BILINEAR
    )
    alpha = alpha.point(lambda value: 255 if value == 255 else 0).filter(ImageFilter.MinFilter(5))
    result = Image.new("L", size)
    result.paste(alpha, box[:2])
    return result


def compare(
    images: dict[str, Image.Image], frame: dict[str, Any], sources: dict[str, Image.Image]
) -> dict[str, Any]:
    """Тело и фон неизменны вне контакта; каждый настоящий предмет остаётся видимым."""
    if changed(images["production"], images["on"]).getbbox():
        raise ValueError("instrumentation changed production pixels")
    contacts = mask(images["on"].size, frame["contacts"], 2)
    difference = changed(images["on"], images["off"])
    if ImageChops.subtract(difference, contacts).getbbox():
        raise ValueError("contact switch changed body/background outside contact bounds")
    if count(difference) < 20:
        raise ValueError("contact switch has no visible effect")
    loot_difference = changed(images["on"], images["no-loot"])
    visible = {}
    for item in frame["loot"]:
        if item["textured"] is not True:
            raise ValueError("loot fixture is a prototype")
        area = mask(images["on"].size, [item], 0)
        pixels = count(ImageChops.multiply(loot_difference, area))
        if pixels < 30:
            raise ValueError("loot is not readable: " + item["kind"])
        core = opaque_core(images["on"].size, sources[item["kind"]], item)
        visible_core = ImageChops.multiply(core, loot_difference)
        if count(visible_core) < 10:
            raise ValueError("loot has no visible opaque core: " + item["kind"])
        overlap = count(ImageChops.multiply(visible_core, difference))
        if overlap:
            raise ValueError(f"shadow covers opaque loot: {item['kind']} ({overlap} pixels)")
        visible[item["kind"]] = {
            "visible_pixels": pixels,
            "opaque_core_pixels": count(visible_core),
        }
    return {"contact_pixels": count(difference), "visible_loot_pixels": visible}
