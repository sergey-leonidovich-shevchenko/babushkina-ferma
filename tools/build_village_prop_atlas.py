#!/usr/bin/env python3
"""Нормализует дробный деревенский лист 4×2 в строгий RGBA-атлас."""

from pathlib import Path

from PIL import Image


CELL = 512
COLUMNS = 4
ROWS = 2


def build(source_path: Path, destination: Path) -> None:
    """Переносит восемь авторских ячеек без захвата соседнего ряда."""
    source = Image.open(source_path).convert("RGBA")
    atlas = Image.new("RGBA", (CELL * COLUMNS, CELL * ROWS), (0, 0, 0, 0))
    for row in range(ROWS):
        for column in range(COLUMNS):
            bounds = (
                round(source.width * column / COLUMNS),
                round(source.height * row / ROWS),
                round(source.width * (column + 1) / COLUMNS),
                round(source.height * (row + 1) / ROWS),
            )
            sprite = source.crop(bounds).resize((CELL, CELL), Image.Resampling.LANCZOS)
            atlas.alpha_composite(sprite, (column * CELL, row * CELL))
    destination.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(destination, compress_level=6)


def main() -> None:
    """Собирает runtime-атлас из путей относительно корня репозитория."""
    root = Path(__file__).resolve().parents[1]
    build(
        root / "assets/game/environment/village_prop_atlas.png",
        root / "assets/game/environment/village_prop_atlas_v2.png",
    )
    print(f"VILLAGE PROP ATLAS: {CELL * COLUMNS}×{CELL * ROWS} RGBA · {COLUMNS}×{ROWS}")


if __name__ == "__main__":
    main()
