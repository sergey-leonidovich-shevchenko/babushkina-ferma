"""Ограниченная QA-инструментация: только отдельные вызовы контактных теней."""

from __future__ import annotations

import hashlib
import re
import subprocess
from pathlib import Path

from tools.common.git import git_environment
from tools.common.paths import project_root

ROOT = project_root(__file__)
PREFIX = "tools/qa/world/shadows/"
PROBE = "res://" + PREFIX + "contact_probe.gd"
MESH_FILES = [
    "scripts/presentation/contact_shadow_shapes.gd",
    *[
        f"scripts/presentation/village_{kind}_visual.gd"
        for kind in ("bench", "street", "lamp", "board", "trade")
    ],
]
DIRECTIONAL = "scripts/systems/directional_character_system.gd"
SOURCES = MESH_FILES + [DIRECTIONAL]
VARIANTS = ("production", "on", "off", "no-loot")
FRAME_IDS = {
    f"{group}-{minute}" for group in ("farm", "street", "grove", "home") for minute in (720, 1140)
}
GD_FILES = tuple(
    PREFIX + name
    for name in (
        "contact_probe.gd",
        "readability_game.gd",
        "readability_cases.gd",
        "readability_capture.gd",
    )
)
QA_INPUTS = tuple(name for gd in GD_FILES for name in (gd, gd + ".uid")) + tuple(
    PREFIX + name for name in ("collect.py", "contract.py", "__init__.py")
)
RUNTIME = (
    "scripts/systems/hero_visual_system.gd",
    "scripts/systems/render_system.gd",
)


def digest(raw: bytes) -> str:
    """Связывает вход и доказательство без зависимости от имени каталога."""
    return hashlib.sha256(raw).hexdigest()


def git(*arguments: str) -> bytes:
    """Читает собственный checkout без унаследованных Git overrides."""
    return subprocess.check_output(
        ["git", "--no-replace-objects", "-C", str(ROOT), *arguments], env=git_environment()
    )


def instrument(name: str, raw: bytes) -> bytes:
    """Добавляет прибор в один shadow-вызов; тела, слои и растры остаются побайтно прежними."""
    source = raw.decode()
    if name in MESH_FILES:
        function = "draw" if name == MESH_FILES[0] else "draw_shadow"
        matches = list(
            re.finditer(
                r"^static func " + function + r"\([^\n]*\)\s*->\s*void:\n(?:\t[^\n]*\n|\n)+",
                source,
                re.MULTILINE,
            )
        )
        if len(matches) != 1:
            raise ValueError("expected one shadow owner: " + name)
        match = matches[0]
        body = match.group()
        marker = "\tcanvas.draw_mesh("
        if body.count(marker) != 1:
            raise ValueError("expected one shadow mesh call: " + name)
        owner = Path(name).stem
        replacement = f'\tpreload("{PROBE}").mesh("{owner}", canvas, '
        return (
            source[: match.start()] + body.replace(marker, replacement) + source[match.end() :]
        ).encode()
    if name != DIRECTIONAL:
        raise ValueError("unexpected instrumentation target")
    signature = (
        "static func draw_soft_shadow(game: Node2D, center: Vector2, radii: Vector2) -> void:\n"
    )
    if source.count(signature) != 1:
        raise ValueError("expected one directional shadow owner")
    gate = f'\tif not preload("{PROBE}").ellipse(center, radii):\n\t\treturn\n'
    return source.replace(signature, signature + gate).encode()


def fresh_output(path: Path) -> Path:
    """Не заменяет данные, не проходит по ссылкам и не пишет приёмку внутрь проекта."""
    output = Path(path.absolute())
    if any(p.is_symlink() for p in (output, *output.parents)):
        raise ValueError("output must not traverse symlinks")
    if output.exists() or output == ROOT or ROOT in output.parents or not output.parent.is_dir():
        raise ValueError("fresh external output with existing parent required")
    output.mkdir()
    return output


def head(working_candidate: bool = False) -> str:
    """Публикует полный commit и требует неизменённый production-код для этой приёмки."""
    commit = git("rev-parse", "HEAD").decode().strip()
    if not re.fullmatch("[0-9a-f]{40}", commit):
        raise ValueError("full source commit required")
    changed = (
        git(
            "diff",
            commit,
            "--name-only",
            "--",
            "scripts",
            "assets/game",
            "main.tscn",
            "project.godot",
        )
        .decode()
        .splitlines()
    )
    if changed and (not working_candidate or not set(changed).issubset(RUNTIME)):
        raise ValueError("production must match the pinned commit")
    return commit
