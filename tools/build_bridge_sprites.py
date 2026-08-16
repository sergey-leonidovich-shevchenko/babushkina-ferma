#!/usr/bin/env python3
"""Детерминированно извлекает законченные мосты из лицензионного монтажного листа."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/inbox/craftpix-net-668008-free-bridges-top-down-pixel-art-asset-pack/PNG_n_Tiled/Bridges.png"
OUTPUT = ROOT / "assets/game/environment/bridges"
PREVIEW = ROOT / "assets/generated/level_drafts/bridge_catalog_preview.png"

# Области выбраны по законченным композициям исходника, а не по формальной сетке 16 px.
# Целевые холсты кратны базовой клетке 24 px и сохраняют нижнюю центральную опору.
SPRITES = {
    "stone_vertical": ((0, 0, 64, 168), (96, 192)),
    "stone_arch": ((60, 0, 152, 80), (168, 96)),
    "stone_wood_vertical": ((0, 320, 64, 168), (96, 192)),
    "stone_wood_horizontal": ((60, 316, 152, 76), (168, 96)),
    "wood_vertical": ((216, 328, 48, 140), (72, 168)),
    "wood_horizontal": ((268, 332, 152, 72), (168, 96)),
    "copper_vertical": ((420, 0, 56, 212), (72, 240)),
    "copper_arch": ((480, 0, 176, 84), (192, 96)),
    "copper_arch_rail": ((480, 92, 176, 100), (192, 120)),
}


def extract(source: Image.Image, box: tuple[int, int, int, int], canvas_size: tuple[int, int]) -> Image.Image:
    """Вырезает один мост, удаляет пустые поля и ставит его по нижнему центру модульного холста."""
    x, y, width, height = box
    fragment = source.crop((x, y, x + width, y + height))
    alpha_bounds = fragment.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise RuntimeError(f"Пустая область моста: {box}")
    fragment = fragment.crop(alpha_bounds)
    if fragment.width > canvas_size[0] or fragment.height > canvas_size[1]:
        raise RuntimeError(f"Мост {box} не помещается в холст {canvas_size}: {fragment.size}")
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    position = ((canvas.width - fragment.width) // 2, canvas.height - fragment.height)
    canvas.alpha_composite(fragment, position)
    return canvas


def build_preview(sprites: dict[str, Image.Image]) -> None:
    """Собирает прозрачный контрольный лист с подписями и модульной сеткой 24 px."""
    width, height = 768, 792
    preview = Image.new("RGBA", (width, height), (24, 33, 38, 255))
    draw = ImageDraw.Draw(preview)
    for x in range(0, width, 24):
        draw.line((x, 0, x, height), fill=(255, 230, 160, 24))
    for y in range(0, height, 24):
        draw.line((0, y, width, y), fill=(255, 230, 160, 24))
    for index, (name, sprite) in enumerate(sprites.items()):
        column, row = index % 3, index // 3
        cell_x, cell_y = column * 256, row * 264
        position = (cell_x + (256 - sprite.width) // 2, cell_y + 20 + (232 - sprite.height))
        preview.alpha_composite(sprite, position)
        draw.rectangle((cell_x + 8, cell_y + 8, cell_x + 248, cell_y + 256), outline=(230, 178, 78, 180), width=2)
        draw.text((cell_x + 14, cell_y + 14), name, fill=(255, 240, 205, 255))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW)


def main() -> None:
    """Пересобирает независимые PNG и визуальный эталон из одного неизменяемого исходника."""
    source = Image.open(SOURCE).convert("RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sprites: dict[str, Image.Image] = {}
    for name, (box, canvas_size) in SPRITES.items():
        sprite = extract(source, box, canvas_size)
        sprite.save(OUTPUT / f"bridge_{name}.png")
        sprites[name] = sprite
    build_preview(sprites)
    print(f"BRIDGES: {len(sprites)} independent sprites -> {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
