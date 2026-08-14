#!/usr/bin/env python3
"""Нарезает утверждённые мастера местности на отдельные игровые тайлы 24×24."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CELL_SIZE = 256
OUTPUT_SIZE = 24
SHEET_COLUMNS = 6
SHEET_ROWS = 4

TERRAIN_NAMES = (
    "grass_lush",
    "grass_flowers",
    "grass_autumn",
    "ground_dirt",
    "ground_farm_soil",
    "ground_sand",
    "ground_cobblestone",
    "ground_cracked_rock",
    "ground_mossy_stone",
    "ground_wood_deck",
    "ground_snow_grass",
    "ground_wet_mud",
    "dirt_path_horizontal",
    "dirt_path_vertical",
    "dirt_path_corner",
    "dirt_path_t_junction",
    "dirt_path_cross",
    "dirt_path_end",
    "stone_road_horizontal",
    "stone_road_vertical",
    "stone_road_corner",
    "stone_road_t_junction",
    "stone_road_cross",
    "stone_road_end",
)

WATER_NAMES = (
    "water_clear",
    "water_ripples",
    "water_deep",
    "water_shallow",
    "water_lilies",
    "water_sparkles",
    "shore_north",
    "shore_south",
    "shore_west",
    "shore_east",
    "shore_outer_corner",
    "shore_inner_corner",
    "river_horizontal",
    "river_vertical",
    "river_corner",
    "river_t_junction",
    "river_cross",
    "river_end",
    "cliff_horizontal",
    "cliff_vertical",
    "cliff_corner",
    "cliff_t_junction",
    "cliff_island_cross",
    "pond_rocky",
)


def slice_sheet(source: Path, output: Path, names: tuple[str, ...]) -> None:
    """Проверяет геометрию листа и сохраняет каждую ячейку отдельным PNG без атласных утечек."""
    sheet = Image.open(source).convert("RGBA")
    expected = (CELL_SIZE * SHEET_COLUMNS, CELL_SIZE * SHEET_ROWS)
    if sheet.size != expected:
        raise ValueError(f"{source}: ожидался мастер {expected[0]}×{expected[1]}, получен {sheet.size}")
    if len(names) != SHEET_COLUMNS * SHEET_ROWS:
        raise ValueError("Количество имён не совпадает с числом ячеек мастера")
    output.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(names):
        column, row = index % SHEET_COLUMNS, index // SHEET_COLUMNS
        bounds = (
            column * CELL_SIZE,
            row * CELL_SIZE,
            (column + 1) * CELL_SIZE,
            (row + 1) * CELL_SIZE,
        )
        tile = sheet.crop(bounds).resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
        tile.save(output / f"{name}.png", compress_level=6)


def build_preview(tile_root: Path, destination: Path) -> None:
    """Собирает контрольный лист из готовых 24×24 файлов для быстрой визуальной проверки границ."""
    names = TERRAIN_NAMES + WATER_NAMES
    scale = 4
    preview = Image.new("RGBA", (SHEET_COLUMNS * OUTPUT_SIZE * scale, 8 * OUTPUT_SIZE * scale))
    for index, name in enumerate(names):
        folder = "terrain" if index < len(TERRAIN_NAMES) else "water"
        tile = Image.open(tile_root / folder / f"{name}.png").convert("RGBA")
        tile = tile.resize((OUTPUT_SIZE * scale, OUTPUT_SIZE * scale), Image.Resampling.NEAREST)
        column, row = index % SHEET_COLUMNS, index // SHEET_COLUMNS
        preview.alpha_composite(tile, (column * OUTPUT_SIZE * scale, row * OUTPUT_SIZE * scale))
    destination.parent.mkdir(parents=True, exist_ok=True)
    preview.save(destination, compress_level=6)


def main() -> None:
    """Читает пути проекта и воспроизводимо обновляет набор редакторских тайлов."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    project = args.project.resolve()
    source = project / "assets/game/tiles/editor/source"
    output = project / "assets/game/tiles/editor"
    slice_sheet(source / "editor_terrain_master_v1.png", output / "terrain", TERRAIN_NAMES)
    slice_sheet(source / "editor_water_master_v1.png", output / "water", WATER_NAMES)
    build_preview(output, output / "preview/editor_tiles_preview_v1.png")
    print(f"Создано {len(TERRAIN_NAMES) + len(WATER_NAMES)} тайлов 24×24 в {output}")


if __name__ == "__main__":
    main()
