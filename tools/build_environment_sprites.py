#!/usr/bin/env python3
"""Собирает модульные сезонные, лунные и биомные спрайты из старых дробных листов."""

from pathlib import Path

from PIL import Image


BASE_CELL = 24
ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "assets/game/generated"
DESTINATION = ROOT / "assets/game/environment"

SEASONS = ("spring", "summer", "autumn", "winter")
BIOMES = ("forest", "rocky", "ruins", "cursed", "glassworks")
MOON_KINDS = ("portal", "flower", "crystal", "altar", "echo", "guardian", "stag", "chest")

SEASON_TREE_SIZE = (264, 360)
SEASON_GROUND_SIZE = (144, 144)
MOON_SIZES = {
    "portal": (168, 240),
    "flower": (144, 216),
    "crystal": (192, 240),
    "altar": (288, 384),
    "echo": (144, 216),
    "guardian": (168, 240),
    "stag": (168, 240),
    "chest": (168, 168),
}
BIOME_LARGE_SIZES = {
    "forest": (168, 240),
    "rocky": (192, 240),
    "ruins": (192, 240),
    "cursed": (168, 240),
    "glassworks": (168, 240),
}
BIOME_DETAIL_SIZE = (144, 168)
ACTION_EFFECT_SIZE = (72, 72)


def crop_cell(
    source: Image.Image,
    column: int,
    row: int,
    columns: int,
    rows: int,
    left_overlap: int = 0,
    right_trim: int = 0,
) -> Image.Image:
    """Вырезает дробную авторскую ячейку по округлённым границам без захвата соседей."""
    bounds = (
        max(0, round(source.width * column / columns) - left_overlap),
        round(source.height * row / rows),
        round(source.width * (column + 1) / columns) - right_trim,
        round(source.height * (row + 1) / rows),
    )
    cell = source.crop(bounds)
    alpha_bounds = cell.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise RuntimeError(f"Пустая ячейка {column}:{row}")
    return cell.crop(alpha_bounds)


def clean_magenta_edge(sprite: Image.Image) -> Image.Image:
    """Удаляет только внешний пурпурный chroma-key ореол, не затрагивая внутренние цвета рисунка."""
    result = sprite.copy()
    source = sprite.load()
    target = result.load()
    width, height = sprite.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = source[x, y]
            if alpha == 0 or red < 145 or blue < 120 or green > 115:
                continue
            edge = False
            for offset_x, offset_y in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                neighbour_x, neighbour_y = x + offset_x, y + offset_y
                if neighbour_x < 0 or neighbour_y < 0 or neighbour_x >= width or neighbour_y >= height or source[neighbour_x, neighbour_y][3] < 24:
                    edge = True
                    break
            if edge:
                target[x, y] = (red, green, blue, 0)
    return result


def fit_to_canvas(sprite: Image.Image, canvas_size: tuple[int, int], clean_edge: bool, ground_gap: int = 24) -> Image.Image:
    """Вписывает объект пропорционально и совмещает его нижнюю опору с модульным холстом."""
    if clean_edge:
        sprite = clean_magenta_edge(sprite)
    available = (canvas_size[0] - 24, canvas_size[1] - ground_gap)
    scale = min(1.0, available[0] / sprite.width, available[1] / sprite.height)
    if scale < 1.0:
        size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
        sprite = sprite.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    position = ((canvas_size[0] - sprite.width) // 2, canvas_size[1] - ground_gap - sprite.height)
    canvas.alpha_composite(sprite, position)
    return canvas


def save_sprite(sprite: Image.Image, relative_path: str, size: tuple[int, int], clean_edge: bool = False, ground_gap: int = 24) -> None:
    """Сохраняет один воспроизводимый runtime-спрайт и проверяет кратность общей сетке."""
    if size[0] % BASE_CELL or size[1] % BASE_CELL:
        raise RuntimeError(f"Немодульный холст {relative_path}: {size}")
    destination = DESTINATION / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    fit_to_canvas(sprite, size, clean_edge, ground_gap).save(destination, compress_level=6)


def build_seasons() -> None:
    """Разделяет четыре дерева и четыре напочвенных сезонных кластера."""
    source = Image.open(GENERATED / "seasonal_environment_atlas.png").convert("RGBA")
    for column, season in enumerate(SEASONS):
        save_sprite(crop_cell(source, column, 0, 4, 2), f"seasons/tree_{season}.png", SEASON_TREE_SIZE, True)
        save_sprite(crop_cell(source, column, 1, 4, 2), f"seasons/ground_{season}.png", SEASON_GROUND_SIZE, True, 12)


def build_moon() -> None:
    """Разделяет восемь объектов Лунной поляны и сохраняет их естественные пропорции."""
    source = Image.open(GENERATED / "eclipse_event_atlas.png").convert("RGBA")
    left_overlaps = {"altar": 24, "guardian": 20, "chest": 18}
    right_trims = {"crystal": 30, "echo": 20, "stag": 20}
    for index, kind in enumerate(MOON_KINDS):
        sprite = crop_cell(
            source,
            index % 4,
            index // 4,
            4,
            2,
            left_overlaps.get(kind, 0),
            right_trims.get(kind, 0),
        )
        save_sprite(sprite, f"moon/{kind}.png", MOON_SIZES[kind])


def build_biomes() -> None:
    """Разделяет крупный ориентир и малую деталь каждого приключенческого биома."""
    source = Image.open(GENERATED / "biome_prop_atlas.png").convert("RGBA")
    for column, biome in enumerate(BIOMES):
        save_sprite(crop_cell(source, column, 0, 5, 2), f"biomes/{biome}_landmark.png", BIOME_LARGE_SIZES[biome], True)
        save_sprite(crop_cell(source, column, 1, 5, 2), f"biomes/{biome}_detail.png", BIOME_DETAIL_SIZE, True, 12)


def build_action_effects() -> None:
    """Разделяет шестнадцать эффектов действий на компактные спрайты 72×72."""
    source = Image.open(ROOT / "assets/game/effects/action_effects_atlas.png").convert("RGBA")
    catalog = Image.new("RGBA", (ACTION_EFFECT_SIZE[0] * 4, ACTION_EFFECT_SIZE[1] * 4), (19, 24, 34, 255))
    for index in range(16):
        sprite = crop_cell(source, index % 4, index // 4, 4, 4)
        destination = ROOT / "assets/game/effects/actions" / f"effect_{index:02d}.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        runtime = fit_to_canvas(sprite, ACTION_EFFECT_SIZE, True, 4)
        runtime.save(destination, compress_level=6)
        catalog.alpha_composite(runtime, ((index % 4) * ACTION_EFFECT_SIZE[0], (index // 4) * ACTION_EFFECT_SIZE[1]))
    preview = ROOT / "assets/generated/level_drafts/action_effects_catalog.png"
    preview.parent.mkdir(parents=True, exist_ok=True)
    catalog.save(preview, compress_level=6)


def main() -> None:
    """Воспроизводимо пересобирает все три семейства окружения относительно корня проекта."""
    build_seasons()
    build_moon()
    build_biomes()
    build_action_effects()
    print("ENVIRONMENT SPRITES: 8 seasonal · 8 moon · 10 biome · 16 action effects")


if __name__ == "__main__":
    main()
