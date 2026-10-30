"""Фиксирует реальные входы генератора и метаданные checkout без изменения Git."""

from __future__ import annotations

import subprocess
from pathlib import Path

from tools.common.git import git_environment
from tools.quality.selection import git_paths, sha


def source_state(root: Path) -> dict[str, str]:
    """Обнаруживает изменения исходников, картинок, UID, собственного index и config."""
    names = [
        name
        for name in git_paths(root)
        if name.startswith(("tools/", "scripts/", "tests/", "assets/"))
        or name in {"project.godot", "VERSION"}
    ]
    state = {
        name: sha(root / name) + ":" + str((root / name).stat().st_mode & 0o777)
        for name in names
        if (root / name).is_file()
    }
    for name in ("index", "config"):
        raw = subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "--git-path", name],
            env=git_environment(),
            text=True,
        ).strip()
        path = Path(raw)
        if not path.is_absolute():
            path = root / path
        state["git:" + name] = sha(path)
    return state
