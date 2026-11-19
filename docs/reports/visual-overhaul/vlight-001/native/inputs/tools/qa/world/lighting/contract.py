"""Ограничивает QA-прибор известными вызовами света в отдельной копии проекта."""

from __future__ import annotations

import hashlib
import re
import subprocess
from pathlib import Path

from tools.common.git import git_environment
from tools.common.paths import project_root

ROOT = project_root(__file__)
PREFIX = "tools/qa/world/lighting/"
PROBE = "res://" + PREFIX + "light_probe.gd"
WIDTHS = (1152, 1280)
MINUTES = (720, 1140, 1320)
VARIANTS = ("production", "on", "off")
GROUPS = ("west-lamp", "east-lamp", "home")
FRAME_IDS = {f"{group}-{minute}" for group in GROUPS for minute in MINUTES}

# Полные характерные префиксы исключают тени, погоду и другие похожие примитивы.
CALLS = {
    "scripts/systems/atmosphere_renderer.gd": (
        (
            "world-darkness",
            "game.draw_rect(Rect2(Vector2.ZERO, game.get_viewport_rect().size), tint)",
            'rect("world-darkness", game, Rect2(Vector2.ZERO, game.get_viewport_rect().size), tint)',
        ),
        (
            "moon-portal",
            "game.draw_circle(return_screen, 72.0,",
            'circle("moon-portal", game, return_screen, 72.0,',
        ),
        (
            "eclipse-portal",
            "game.draw_circle(portal_screen, 76.0*projection.zoom(game),",
            'circle("eclipse-portal", game, portal_screen, 76.0*projection.zoom(game),',
        ),
    ),
    "scripts/presentation/village_lamp_visual.gd": (
        (
            "village-lamp",
            "canvas.draw_mesh(glow_mesh(direction),",
            'mesh("village-lamp", canvas, glow_mesh(direction),',
        ),
    ),
    "scripts/systems/interior_renderer.gd": (
        (
            "window-ray",
            "canvas.draw_colored_polygon(PackedVector2Array([light_center",
            'polygon("window-ray", canvas, PackedVector2Array([light_center',
        ),
    ),
}
SOURCES = tuple(CALLS)
OWNED_FUNCTIONS = {
    SOURCES[0]: {"draw": {"draw_rect": 1}, "draw_lights": {"draw_circle": 2}},
    SOURCES[1]: {"draw_glow": {"draw_mesh": 1}},
    SOURCES[2]: {
        "draw_textured_shell": {
            "draw_rect": 3,
            "draw_texture_rect_region": 3,
            "draw_line": 2,
            "draw_colored_polygon": 1,
        }
    },
}


def digest(raw: bytes) -> str:
    """Связывает действительные байты с manifest, независимо от имени папки."""
    return hashlib.sha256(raw).hexdigest()


def git(*arguments: str) -> bytes:
    """Git читает только выбранный проект, в том числе внутри настоящего hook."""
    return subprocess.check_output(
        ["git", "--no-replace-objects", "-C", str(ROOT), *arguments], env=git_environment()
    )


def head() -> str:
    """Для аудита production должен совпадать с закреплённым коммитом."""
    commit = git("rev-parse", "HEAD").decode().strip()
    if not re.fullmatch("[0-9a-f]{40}", commit):
        raise ValueError("full source commit required")
    if git(
        "diff", commit, "--name-only", "--", "scripts", "assets/game", "main.tscn", "project.godot"
    ):
        raise ValueError("lighting audit requires unchanged production sources")
    return commit


def instrument(name: str, raw: bytes) -> bytes:
    """Меняет ровно пять вызовов света; не отключает воду, погоду, тела или HUD."""
    if name not in CALLS:
        raise ValueError("unexpected lighting instrumentation target: " + name)
    text = raw.decode()
    for function, expected in OWNED_FUNCTIONS[name].items():
        body = function_body(text, function)
        methods = re.findall(r"\b(?:game|canvas)\.(draw_\w+)\(", body)
        actual = {method: methods.count(method) for method in set(methods)}
        if actual != expected:
            raise ValueError("lighting owner call inventory changed: " + name + ":" + function)
    for _owner, original, replacement in CALLS[name]:
        if text.count(original) != 1:
            raise ValueError("expected one lighting call: " + original)
        text = text.replace(original, f'preload("{PROBE}").' + replacement)
    return text.encode()


def function_body(source: str, name: str) -> str:
    """Выделяет единственного объявленного владельца до следующей функции, не весь файл."""
    matches = list(
        re.finditer(
            r"^static func " + re.escape(name) + r"\([^\n]*\)[^\n]*:\n", source, re.MULTILINE
        )
    )
    if len(matches) != 1:
        raise ValueError("expected one lighting function: " + name)
    start = matches[0].start()
    following = re.search(r"^static func ", source[matches[0].end() :], re.MULTILINE)
    end = matches[0].end() + following.start() if following else len(source)
    return source[start:end]


def fresh_output(path: Path) -> Path:
    """Создаёт новый внешний каталог и отказывается от перезаписи и symlink-переходов."""
    lexical = path.absolute()
    if any(item.is_symlink() for item in (lexical, *lexical.parents)):
        raise ValueError("output must not traverse symlinks")
    output = lexical.resolve()
    if output.exists() or output == ROOT or ROOT in output.parents or not output.parent.is_dir():
        raise ValueError("fresh external output with existing parent required")
    output.mkdir()
    return output
