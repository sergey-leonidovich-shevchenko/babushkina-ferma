#!/usr/bin/env python3
"""Собирает сезонную траву и диагональные переходы редактора из утверждённых тайлов 24×24."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
TERRAIN = ROOT / "assets/game/tiles/editor/terrain"
TRANSITIONS = ROOT / "assets/game/tiles/editor/transitions"
PREVIEW = ROOT / "assets/generated/level_drafts/editor_transition_preview_v2.png"
SURFACES = ("dirt", "gravel", "sand")


def build_spring_grass() -> Image.Image:
    """Создаёт бесшовную весеннюю траву с редкими локальными цветами без изменения краёв тайла."""
    source = Image.open(TERRAIN / "grass_lush.png").convert("RGBA")
    image = ImageEnhance.Color(ImageEnhance.Brightness(source).enhance(1.07)).enhance(1.10)
    draw = ImageDraw.Draw(image)
    for x, y, color in ((5, 6, (247, 218, 211, 255)), (16, 11, (255, 238, 164, 255)), (10, 18, (214, 225, 255, 255))):
        draw.point((x, y), fill=(255, 247, 220, 255))
        draw.point((x - 1, y), fill=color)
        draw.point((x + 1, y), fill=color)
        draw.point((x, y - 1), fill=color)
    image.save(TERRAIN / "grass_spring.png")
    return image


def build_inner_corner(surface: str) -> Image.Image:
    """Формирует прозрачный внутренний угол северо-восточной ориентации из проверенного края покрытия."""
    north = Image.open(TRANSITIONS / f"{surface}_edge.png").convert("RGBA")
    east = north.transpose(Image.Transpose.ROTATE_270)
    combined = Image.alpha_composite(north, east)
    pixels = combined.load()
    for y in range(24):
        for x in range(24):
            distance = (23 - x) + y
            jitter = ((x * 7 + y * 11) % 3) - 1
            if distance > 10 + jitter:
                pixels[x, y] = (0, 0, 0, 0)
            elif distance > 7 + jitter:
                red, green, blue, alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, min(alpha, 170))
    combined.save(TRANSITIONS / f"{surface}_inner_corner.png")
    return combined


def build_preview(spring: Image.Image, corners: dict[str, Image.Image]) -> None:
    """Сохраняет увеличенный контрольный лист четырёх сезонов и трёх внутренних углов."""
    seasonal = {
        "SPRING": spring,
        "SUMMER": Image.open(TERRAIN / "grass_lush.png").convert("RGBA"),
        "AUTUMN": Image.open(TERRAIN / "grass_autumn.png").convert("RGBA"),
        "WINTER": Image.open(TERRAIN / "ground_snow_grass.png").convert("RGBA"),
    }
    scale = 8
    tile = 24 * scale
    preview = Image.new("RGBA", (tile * 4, tile * 2 + 60), (25, 34, 38, 255))
    draw = ImageDraw.Draw(preview)
    for index, (label, image) in enumerate(seasonal.items()):
        preview.alpha_composite(image.resize((tile, tile), Image.Resampling.NEAREST), (index * tile, 24))
        draw.text((index * tile + 8, 6), label, fill=(255, 239, 196, 255))
    base = seasonal["SUMMER"]
    for index, (surface, corner) in enumerate(corners.items()):
        composed = Image.alpha_composite(base, corner).resize((tile, tile), Image.Resampling.NEAREST)
        preview.alpha_composite(composed, (index * tile, tile + 52))
        draw.text((index * tile + 8, tile + 34), f"{surface}: INNER CORNER", fill=(255, 239, 196, 255))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW)


def main() -> None:
    """Пересобирает все производные тайлы и визуальный эталон одной командой."""
    spring = build_spring_grass()
    corners = {surface: build_inner_corner(surface) for surface in SURFACES}
    build_preview(spring, corners)
    print("EDITOR TRANSITIONS: spring grass + 3 inner corners")


if __name__ == "__main__":
    main()
