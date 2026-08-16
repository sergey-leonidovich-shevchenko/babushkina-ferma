#!/usr/bin/env python3
"""Извлекает восемь фасадов из дробного исходного листа без повторного масштабирования."""

from pathlib import Path

from PIL import Image


BASE_CELL = 24
GROUND_GAP = 24
HORIZONTAL_PADDING = 24
BUILDING_IDS = (
    "cottage",
    "shop_house",
    "guild_hall",
    "forge",
    "chapel",
    "prison",
    "wizard_tower",
    "moon_castle",
)
CELL_LIMITS = {
    # У границы дробного исходника несколько пикселей соседнего ряда попали в ячейку гильдии.
    "guild_hall": (0, 0, None, 420),
    # Правая башня замка начинается внутри дробной ячейки волшебника и не относится к его фасаду.
    "wizard_tower": (0, 0, 340, None),
}


def align(value: int) -> int:
    """Округляет размер вверх до ближайшей базовой клетки 24 px."""
    return ((value + BASE_CELL - 1) // BASE_CELL) * BASE_CELL


def build(source_path: Path, destination: Path) -> dict[str, tuple[int, int]]:
    """Обрезает прозрачные поля каждой авторской ячейки и сохраняет нижнюю опору двери."""
    source = Image.open(source_path).convert("RGBA")
    destination.mkdir(parents=True, exist_ok=True)
    sizes: dict[str, tuple[int, int]] = {}
    for index, building_id in enumerate(BUILDING_IDS):
        column = index % 4
        row = index // 4
        bounds = (
            round(source.width * column / 4),
            round(source.height * row / 2),
            round(source.width * (column + 1) / 4),
            round(source.height * (row + 1) / 2),
        )
        cell = source.crop(bounds)
        if building_id in CELL_LIMITS:
            left, top, right, bottom = CELL_LIMITS[building_id]
            cell = cell.crop((left, top, right or cell.width, bottom or cell.height))
        alpha_bounds = cell.getchannel("A").getbbox()
        if alpha_bounds is None:
            raise RuntimeError(f"Пустая ячейка здания: {building_id}")
        sprite = cell.crop(alpha_bounds)
        width = align(sprite.width + HORIZONTAL_PADDING)
        height = align(sprite.height + GROUND_GAP)
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        paste_x = (width - sprite.width) // 2
        paste_y = height - GROUND_GAP - sprite.height
        canvas.alpha_composite(sprite, (paste_x, paste_y))
        canvas.save(destination / f"{building_id}.png", compress_level=6)
        sizes[building_id] = canvas.size
    return sizes


def main() -> None:
    """Собирает отдельные runtime-фасады из путей относительно корня проекта."""
    root = Path(__file__).resolve().parents[1]
    sizes = build(
        root / "assets/game/buildings/building_atlas.png",
        root / "assets/game/buildings/exteriors",
    )
    summary = " · ".join(f"{name}={size[0]}×{size[1]}" for name, size in sizes.items())
    print(f"BUILDING SPRITES: {summary}")


if __name__ == "__main__":
    main()
