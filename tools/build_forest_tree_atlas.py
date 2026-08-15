#!/usr/bin/env python3
"""Собирает строгие RGBA-атласы стадий лесных и плодовых деревьев."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CELL_SIZE = 256
STAGE_COUNT = 4
ORCHARD_SPECIES = 4


def alpha_from_checker(pixel: tuple[int, int, int]) -> int:
    """Отделяет почти белую нейтральную шахматную подложку от насыщенного пиксель-арта."""
    red, green, blue = pixel
    neutral = max(pixel) - min(pixel) < 24
    return 0 if neutral and min(pixel) > 205 else 255


def stage_runs(source: Image.Image) -> list[tuple[int, int]]:
    """Находит четыре занятых диапазона по полностью прозрачным вертикальным разделителям."""
    occupied = []
    for x in range(source.width):
        occupied.append(any(alpha_from_checker(source.getpixel((x, y))) > 0 for y in range(source.height)))
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for x, value in enumerate(occupied + [False]):
        if value and start is None:
            start = x
        elif not value and start is not None:
            runs.append((start, x))
            start = None
    if len(runs) != STAGE_COUNT:
        raise ValueError(f"Ожидалось {STAGE_COUNT} изолированных стадий, найдено {len(runs)}")
    return runs


def isolate_stage(source: Image.Image, bounds_x: tuple[int, int], index: int) -> Image.Image:
    """Извлекает одну четверть мастера, удаляет фон и сохраняет нижнюю центральную опору."""
    left, right = bounds_x
    crop = source.crop((left, 0, right, source.height)).convert("RGB")
    rgba = crop.convert("RGBA")
    alpha = Image.new("L", crop.size)
    alpha.putdata([alpha_from_checker(pixel) for pixel in crop.getdata()])
    rgba.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"Стадия {index} не содержит дерева")
    sprite = rgba.crop(bounds)
    scale = min(224 / sprite.width, 224 / sprite.height)
    size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    return sprite.resize(size, Image.Resampling.LANCZOS)


def build(source_path: Path, destination: Path) -> None:
    """Размещает четыре очищенные стадии в одинаковых ячейках с общей линией земли."""
    source = Image.open(source_path).convert("RGB")
    atlas = Image.new("RGBA", (CELL_SIZE * STAGE_COUNT, CELL_SIZE), (0, 0, 0, 0))
    for index, bounds_x in enumerate(stage_runs(source)):
        sprite = isolate_stage(source, bounds_x, index)
        position = (index * CELL_SIZE + (CELL_SIZE - sprite.width) // 2, 244 - sprite.height)
        atlas.alpha_composite(sprite, position)
    destination.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(destination, compress_level=6)


def normalize_orchard(source_path: Path, destination: Path) -> None:
    """Переносит дробный исходный лист 4×4 в целые ячейки 256×256 без захвата соседей."""
    source = Image.open(source_path).convert("RGBA")
    atlas = Image.new("RGBA", (CELL_SIZE * STAGE_COUNT, CELL_SIZE * ORCHARD_SPECIES), (0, 0, 0, 0))
    for row in range(ORCHARD_SPECIES):
        for column in range(STAGE_COUNT):
            bounds = (
                round(source.width * column / STAGE_COUNT),
                round(source.height * row / ORCHARD_SPECIES),
                round(source.width * (column + 1) / STAGE_COUNT),
                round(source.height * (row + 1) / ORCHARD_SPECIES),
            )
            sprite = source.crop(bounds).resize((CELL_SIZE, CELL_SIZE), Image.Resampling.LANCZOS)
            atlas.alpha_composite(sprite, (column * CELL_SIZE, row * CELL_SIZE))
    destination.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(destination, compress_level=6)


def main() -> None:
    """Разрешает переносимый запуск из любой рабочей папки проекта."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.project.resolve()
    source = root / "assets/generated/sprite_sources/forest_tree_growth_source_v1.png"
    destination = root / "assets/game/environment/forest_tree_growth_atlas_v1.png"
    build(source, destination)
    orchard_source = root / "assets/game/environment/orchard/fruit_trees_clear.png"
    orchard_destination = root / "assets/game/environment/orchard/fruit_trees_4x4_v2.png"
    normalize_orchard(orchard_source, orchard_destination)
    print(f"TREE ATLASES: forest {CELL_SIZE * STAGE_COUNT}×{CELL_SIZE} · orchard {CELL_SIZE * STAGE_COUNT}×{CELL_SIZE * ORCHARD_SPECIES} RGBA")


if __name__ == "__main__":
    main()
