#!/usr/bin/env python3
"""Нарезает художественный мастер UI на независимые PNG без соседнего bleed."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/generated/ui_sources/grandmother_ui_kit_master_v1.png"
OUTPUT = ROOT / "assets/game/ui/kit_v1"

# Регионы намеренно разделены пустым прозрачным полем исходного мастера.
REGIONS = {
    "panel_large": (28, 42, 402, 340),
    "panel_medium": (425, 126, 734, 331),
    "button_normal": (754, 170, 1073, 296),
    "button_selected": (1104, 170, 1417, 296),
    "slot_normal": (111, 380, 282, 550),
    "slot_selected": (410, 380, 583, 550),
    "progress_frame": (696, 418, 1102, 520),
    "scrollbar": (1227, 345, 1303, 576),
    "tooltip": (73, 600, 347, 790),
    "tab_normal": (438, 646, 666, 760),
    "tab_selected": (770, 646, 993, 760),
    "portrait_frame": (1135, 590, 1378, 827),
    "badge": (79, 824, 310, 1024),
    "close_button": (390, 859, 557, 1018),
    "quest_ribbon": (625, 876, 1070, 1021),
    "divider": (1117, 919, 1412, 1015),
}


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    """Возвращает непустую альфа-область или сообщает о повреждённом элементе."""
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("UI component has no opaque pixels")
    return bounds


def padded_crop(image: Image.Image, bounds: tuple[int, int, int, int], padding: int = 4) -> Image.Image:
    """Обрезает компонент по альфе и сохраняет одинаковое прозрачное поле вокруг."""
    fragment = image.crop(bounds)
    trimmed = fragment.crop(alpha_bounds(fragment))
    result = Image.new("RGBA", (trimmed.width + padding * 2, trimmed.height + padding * 2), (0, 0, 0, 0))
    result.alpha_composite(trimmed, (padding, padding))
    return result


def main() -> None:
    """Создаёт воспроизводимый набор независимых UI-спрайтов и проверяет прозрачность."""
    source = Image.open(SOURCE).convert("RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, bounds in REGIONS.items():
        component = padded_crop(source, bounds)
        if component.getpixel((0, 0))[3] != 0 or component.getpixel((component.width - 1, component.height - 1))[3] != 0:
            raise ValueError(f"{name}: transparent padding was lost")
        component.save(OUTPUT / f"{name}.png")
        print(f"{name}: {component.width}x{component.height}")


if __name__ == "__main__":
    main()
