"""Выбирает целиком новые и изменённые исходники; baseline задаётся точными старыми байтами."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from pathlib import Path

from tools.common.git import git_environment

BASE = "464328853c2fbbed1410ac0312de75c3fee7cfa2"
BASELINE = "docs/reports/refactor-07/baseline/legacy-sources.json"
BASELINE_SHA = "a2752855a096fbe144b23a173bc15f1ab53f9da704a37b45ee2fcde510cf16df"
SOURCE_ROOTS = ("scripts", "tests", "tools", "wiki/scripts")
SKIP_DIRS = {".godot", ".git", "__pycache__", "node_modules", "Godot.app"}


def sha(path: Path) -> str:
    """Сравнивает полные байты файла вместе с пробелами, а не выбранные строки diff."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_paths(root: Path) -> list[str]:
    """Читает список своего checkout без унаследованных подмен hook/index/config."""
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        env=git_environment(),
        check=True,
        capture_output=True,
    )
    return [os.fsdecode(name) for name in result.stdout.split(b"\0") if name]


def baseline(root: Path) -> dict[str, str]:
    """Отклоняет скрытое расширение baseline; новая политика требует отдельного ревью."""
    path = root / BASELINE
    if path.is_symlink() or sha(path) != BASELINE_SHA:
        raise ValueError("legacy baseline differs from the accepted REFACTOR-07 snapshot")
    data = json.loads(path.read_text())
    if data["base"] != BASE or data["schema"] != 1:
        raise ValueError("unexpected legacy baseline base/schema")
    return dict(data["files"])


def discover(root: Path) -> list[str]:
    """Находит новый вложенный исходник даже под старым скрывающим правилом Git ignore."""
    names = set(git_paths(root))
    for relative in SOURCE_ROOTS:
        parent = root / relative
        if not parent.is_dir():
            continue
        for current, directories, files in os.walk(parent, followlinks=False):
            directories[:] = [name for name in directories if name not in SKIP_DIRS]
            if any((Path(current) / name).is_symlink() for name in directories):
                raise ValueError("source package directory must not be a symlink: " + current)
            for name in files:
                if Path(name).suffix in {".py", ".gd"}:
                    names.add((Path(current) / name).relative_to(root).as_posix())
    return sorted(
        name
        for name in names
        if Path(name).suffix in {".py", ".gd"}
        and not name.startswith("docs/reports/")
        and ((root / name).exists() or (root / name).is_symlink())
    )


def selected(root: Path, legacy: dict[str, str]) -> list[str]:
    """Включает все правила для целого файла после изменения хотя бы одного байта."""
    result = []
    for name in discover(root):
        path = root / name
        if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError("source must be a regular file within its checkout: " + name)
        if sha(path) != legacy.get(name):
            result.append(name)
    return result
