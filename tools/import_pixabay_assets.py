#!/usr/bin/env python3
"""Convert downloaded Pixabay sheets into small transparent game sprites."""

from pathlib import Path
from PIL import Image

DOWNLOADS = Path.home() / "Downloads"
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "game" / "items"


def keyed_crop(source: Path, box: tuple[int, int, int, int], output: str) -> None:
    image = Image.open(source).convert("RGBA").crop(box)
    background = image.getpixel((0, 0))[:3]
    pixels = []
    for red, green, blue, alpha in image.getdata():
        distance = sum((value - key) ** 2 for value, key in zip((red, green, blue), background)) ** 0.5
        pixels.append((red, green, blue, 0 if distance < 42 else alpha))
    image.putdata(pixels)
    bounds = image.getbbox()
    if bounds:
        image = image.crop(bounds)
    image.thumbnail((64, 64), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (64, 64))
    canvas.alpha_composite(image, ((64 - image.width) // 2, (64 - image.height) // 2))
    canvas.save(OUTPUT / output)


def alpha_sprite(source: Path, output: str) -> None:
    image = Image.open(source).convert("RGBA")
    bounds = image.getbbox()
    if bounds:
        image = image.crop(bounds)
    image.thumbnail((64, 64), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (64, 64))
    canvas.alpha_composite(image, ((64 - image.width) // 2, (64 - image.height) // 2))
    canvas.save(OUTPUT / output)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    armor = DOWNLOADS / "keinianz-helmet-5724641.jpg"
    gems = DOWNLOADS / "keinianz-diamond-5724650.jpg"
    keyed_crop(armor, (1920, 1420, 2440, 1960), "iron_helmet.png")
    keyed_crop(armor, (1390, 470, 1980, 980), "guardian_armor.png")
    keyed_crop(armor, (2380, 470, 2920, 980), "travel_boots.png")
    keyed_crop(gems, (460, 480, 960, 1030), "crystal_ring.png")
    alpha_sprite(DOWNLOADS / "divexfre-orange-9741354.png", "orange.png")
    # The source contains several bars; keep it as an atlas, compact enough for HUD regions.
    health = Image.open(DOWNLOADS / "pikura-retro-9342597.png").convert("RGBA")
    health.thumbnail((352, 512), Image.Resampling.NEAREST)
    health.save(OUTPUT / "health_bars.png")


if __name__ == "__main__":
    main()
