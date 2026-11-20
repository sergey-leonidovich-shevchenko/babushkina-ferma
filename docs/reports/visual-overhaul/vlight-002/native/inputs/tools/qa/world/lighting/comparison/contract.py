"""Фиксирует два узких QA-overlay и полную матрицу одного фонаря."""

from __future__ import annotations

from tools.qa.world.lighting import contract as inventory_contract

ROOT = inventory_contract.ROOT
PREFIX = "tools/qa/world/lighting/comparison/"
BASE = "be306229e41700aa75220c13ab24d3f7c8940dcb"
WIDTHS = (1152, 1280)
MODES = ("off", "mask", "local", "shadow")
ROOMS = ("west-lamp", "home")
MINUTES = (720, 1140, 1320)
FRAME_IDS = {f"{room}-{minute}-{mode}" for room in ROOMS for minute in MINUTES for mode in MODES}
GDSCRIPTS = tuple(
    PREFIX + name for name in ("fixture.gd", "scenarios.gd", "capture.gd", "viewports.gd")
)
OVERLAYS = {
    "scripts/systems/atmosphere_renderer.gd": (
        "static func draw_lights(game: Node2D, darkness: float) -> void:\n",
        "static func draw_lights(game: Node2D, darkness: float) -> void:\n"
        '\tif game.has_meta("qa_lantern_comparison"):\n\t\treturn\n',
    ),
    "scripts/systems/render_system.gd": (
        "\tdraw_screen(game, clean_level_capture)\n",
        '\tif not game.has_meta("qa_lantern_comparison"):\n'
        "\t\tdraw_screen(game, clean_level_capture)\n",
    ),
}


def instrument(name: str, raw: bytes) -> bytes:
    """Изолирует один halo и HUD; производственные текстуры/шейдеры остаются действительными."""
    if name not in OVERLAYS:
        raise ValueError("unexpected comparison overlay: " + name)
    old, new = OVERLAYS[name]
    source = raw.decode()
    if source.count(old) != 1:
        raise ValueError("comparison owner changed: " + name)
    return source.replace(old, new).encode()
