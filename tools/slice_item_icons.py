#!/usr/bin/env python3
"""Нарезает предметные атласы на очищенные PNG с единым прозрачным холстом."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/game/items/catalog"
CANVAS_SIZE = 256
CONTENT_SIZE = 216
ALPHA_THRESHOLD = 5

ATLASES = {
    "inventory_core_atlas.png": {
        "grid": (6, 4),
        "items": [
            "hoe", "seeds", "water", "hand", "pickaxe", "fishing_rod",
            "axe", "carrot", "apple", "berries", "nut", "mushroom",
            "slime", "wood", "stone", "crystal", "red_crystal", "green_crystal",
            "fish", "sword", "bow", "arrows", "crystal_sword", "fiber",
        ],
    },
    "inventory_rare_atlas.png": {
        "grid": (6, 4),
        "items": [
            "rare_seeds", "metal", "bones", "ancient_key", "blue_gem", "moon_relic",
            "raw_meat", "hide", "fur", "tusk", "bat_wing", "lizard_scale",
            "orc_blade", "home_chest", "guild_badge", "iron_helmet", "guardian_armor", "travel_boots",
            "crystal_ring", "orange", "watermelon", "oak_shield", "", "backpack_upgrade",
        ],
    },
    "farm_food_atlas.png": {
        "grid": (6, 4),
        "items": [
            "tomato", "cabbage", "egg", "milk", "wheat", "corn",
            "potato", "onion", "cheese", "rope", "cotton", "flower",
            "honey", "bread", "pie", "pumpkin", "flour", "butter",
            "jam", "soup", "omelet", "cornbread", "wool", "bouquet",
        ],
    },
    "potion_atlas.png": {
        "grid": (4, 2),
        "items": [
            "healing_potion", "mana_potion", "energy_potion", "invisibility_potion",
            "strength_potion", "regeneration_potion", "speed_potion", "defense_potion",
        ],
    },
    "pirate_item_atlas.png": {
        "grid": (4, 2),
        "items": [
            "pirate_doubloon", "ectoplasm", "cursed_compass", "pirate_cutlass",
            "powder_keg", "ship_key", "treasure_map", "captain_medallion",
        ],
    },
}

FARM_LIFE_ITEMS = {
    "rustic_table": (0, 2),
    "wooden_chair": (1, 2),
    "woven_rug": (2, 2),
    "potted_fern": (3, 2),
    "wooden_wardrobe": (4, 2),
    "museum_token": (2, 1),
}


## Возвращает все связные непрозрачные компоненты, не объединяя случайный мусор с предметом.
def alpha_components(image: Image.Image) -> list[tuple[int, int, int, int, int]]:
    alpha = image.getchannel("A")
    width, height = image.size
    visible = bytearray(width * height)
    pixels = alpha.load()
    for y in range(height):
        for x in range(width):
            if pixels[x, y] > ALPHA_THRESHOLD:
                visible[y * width + x] = 1
    components: list[tuple[int, int, int, int, int]] = []
    for y in range(height):
        for x in range(width):
            start = y * width + x
            if not visible[start]:
                continue
            visible[start] = 0
            queue = deque([(x, y)])
            left = right = x
            top = bottom = y
            area = 0
            while queue:
                current_x, current_y = queue.popleft()
                area += 1
                left = min(left, current_x)
                right = max(right, current_x)
                top = min(top, current_y)
                bottom = max(bottom, current_y)
                for next_x, next_y in ((current_x - 1, current_y), (current_x + 1, current_y), (current_x, current_y - 1), (current_x, current_y + 1)):
                    if 0 <= next_x < width and 0 <= next_y < height:
                        offset = next_y * width + next_x
                        if visible[offset]:
                            visible[offset] = 0
                            queue.append((next_x, next_y))
            components.append((left, top, right + 1, bottom + 1, area))
    return components


## Выбирает главный предмет и его осмысленные детали, отбрасывая чужие пиксели по краям ячейки.
def clean_cell(cell: Image.Image) -> Image.Image:
    components = alpha_components(cell)
    if not components:
        return Image.new("RGBA", cell.size)
    largest = max(component[4] for component in components)
    center_x = cell.width * 0.5
    center_y = cell.height * 0.5
    kept = []
    for component in components:
        left, top, right, bottom, area = component
        component_x = (left + right) * 0.5
        component_y = (top + bottom) * 0.5
        close_to_center = abs(component_x - center_x) <= cell.width * 0.38 and abs(component_y - center_y) <= cell.height * 0.38
        if area >= max(10, largest * 0.012) and (area >= largest * 0.08 or close_to_center):
            kept.append(component)
    bounds = (
        min(component[0] for component in kept),
        min(component[1] for component in kept),
        max(component[2] for component in kept),
        max(component[3] for component in kept),
    )
    return cell.crop(bounds)


## Центрирует предмет на квадратном холсте без изменения его исходных пропорций.
def normalize_icon(icon: Image.Image) -> Image.Image:
    scale = min(CONTENT_SIZE / icon.width, CONTENT_SIZE / icon.height)
    target = (max(1, round(icon.width * scale)), max(1, round(icon.height * scale)))
    if target != icon.size:
        icon = icon.resize(target, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE))
    position = ((CANVAS_SIZE - icon.width) // 2, (CANVAS_SIZE - icon.height) // 2)
    canvas.alpha_composite(icon, position)
    return canvas


## Сохраняет одну очищенную и нормализованную иконку каталога.
def save_icon(kind: str, cell: Image.Image) -> None:
    if not kind:
        return
    normalize_icon(clean_cell(cell)).save(OUTPUT / f"{kind}.png", optimize=True)


## Нарезает все регулярные предметные атласы по объявленным сеткам.
def slice_regular_atlases() -> None:
    source_dir = ROOT / "assets/game/generated"
    for filename, definition in ATLASES.items():
        atlas = Image.open(source_dir / filename).convert("RGBA")
        columns, rows = definition["grid"]
        cell_width = atlas.width / columns
        cell_height = atlas.height / rows
        for index, kind in enumerate(definition["items"]):
            column = index % columns
            row = index // columns
            bounds = (round(column * cell_width), round(row * cell_height), round((column + 1) * cell_width), round((row + 1) * cell_height))
            save_icon(kind, atlas.crop(bounds))


## Нарезает бытовые предметы из атласа расширения с фиксированной ячейкой 128 пикселей.
def slice_farm_life_atlas() -> None:
    atlas = Image.open(ROOT / "assets/game/expansion_pack/expansion_atlas.png").convert("RGBA")
    for kind, (column, row) in FARM_LIFE_ITEMS.items():
        bounds = (column * 128, row * 128, (column + 1) * 128, (row + 1) * 128)
        save_icon(kind, atlas.crop(bounds))


## Вырезает уникальный предмет затмения из событийной сетки четыре на два.
def slice_eclipse_icon() -> None:
    atlas = Image.open(ROOT / "assets/game/generated/eclipse_event_atlas.png").convert("RGBA")
    cell_width = atlas.width / 4
    cell_height = atlas.height / 2
    bounds = (round(2 * cell_width), 0, round(3 * cell_width), round(cell_height))
    save_icon("eclipse_core", atlas.crop(bounds))


## Пересобирает каталог отдельных PNG и удаляет только устаревшие результаты этого инструмента.
def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for path in OUTPUT.glob("*.png"):
        path.unlink()
    slice_regular_atlases()
    slice_farm_life_atlas()
    slice_eclipse_icon()
    print(f"ITEM ICONS: {len(list(OUTPUT.glob('*.png')))} sprites written to {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
