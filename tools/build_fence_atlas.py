#!/usr/bin/env python3
"""Нормализует художественный лист заборов в строгую сетку 8×5 по 64 px."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/game/environment/source/buildable_fence_atlas_v1.png"
OUTPUT = ROOT / "assets/game/environment/buildable_fence_atlas_v1.png"
ICON_DIRECTORY = ROOT / "assets/game/items/catalog"
COLS = 8
ROWS = 5
CELL = 64


def main() -> None:
    """Нарезает неравномерную высоту исходника без щелей и сохраняет RGBA-атлас."""
    source = Image.open(SOURCE).convert("RGBA")
    atlas = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    for row in range(ROWS):
        y0 = round(row * source.height / ROWS)
        y1 = round((row + 1) * source.height / ROWS)
        for column in range(COLS):
            x0 = round(column * source.width / COLS)
            x1 = round((column + 1) * source.width / COLS)
            sprite = source.crop((x0, y0, x1, y1)).resize((CELL, CELL), Image.Resampling.LANCZOS)
            atlas.alpha_composite(sprite, (column * CELL, row * CELL))
    atlas.save(OUTPUT, optimize=True)
    ICON_DIRECTORY.mkdir(parents=True, exist_ok=True)
    atlas.crop((CELL, 0, 2 * CELL, CELL)).save(ICON_DIRECTORY / "fence_kit.png", optimize=True)
    atlas.crop((6 * CELL, 0, 7 * CELL, CELL)).save(ICON_DIRECTORY / "gate_kit.png", optimize=True)
    print(f"FENCE ATLAS: {OUTPUT.relative_to(ROOT)} {atlas.width}x{atlas.height} RGBA")


if __name__ == "__main__":
    main()
