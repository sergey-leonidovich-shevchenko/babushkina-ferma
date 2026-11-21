"""Находит проект по исходнику инструмента, независимо от cwd и глубины пакета."""
from __future__ import annotations

from pathlib import Path


def project_root(anchor: str | Path = __file__) -> Path:
    """Требует настоящие маркеры проекта; Git-окружение не выбирает чужой checkout."""
    source = Path(anchor).resolve(strict=True)
    start = source if source.is_dir() else source.parent
    for candidate in (start, *start.parents):
        if ((candidate / "project.godot").is_file()
                and (candidate / "VERSION").is_file()
                and (candidate / "tools").is_dir()):
            return candidate
    raise RuntimeError(f"Не найден корень проекта для {source}")
