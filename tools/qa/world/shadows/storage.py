"""Читает ZIP-транспорт нативных артефактов, сохраняя прежние raw SHA producer."""

from __future__ import annotations

import zipfile
from pathlib import Path
from typing import Any

WIDTHS = (1152, 1280)
SETUP = {"import.txt", "import.stdout.txt"}
MAX_ARTIFACT = 64 * 1024 * 1024


def container(path: Path) -> tuple[Path, str] | None:
    """Находит только пакет матрицы рядом с source.json, без извлечения файлов."""
    for folder in path.parents:
        if not (folder / "source.json").is_file():
            continue
        packages = [
            folder / f"{width}.zip" for width in WIDTHS if (folder / f"{width}.zip").is_file()
        ]
        if not packages:
            continue
        relative = path.relative_to(folder).as_posix()
        if relative in SETUP:
            return packages[0], relative
        group = relative.split("/", 1)[0]
        for width in WIDTHS:
            if group in {
                f"{width}-{variant}" for variant in ("production", "on", "off", "no-loot")
            }:
                return folder / f"{width}.zip", relative
    return None


def artifact_bytes(path: Path) -> bytes:
    """Отклоняет неоднозначный носитель, дубликаты и чрезмерную распаковку; проверяет CRC."""
    location = container(path)
    if location is None:
        return path.read_bytes()
    package, relative = location
    if path.exists():
        raise ValueError("ambiguous raw/ZIP artifact: " + str(path))
    with zipfile.ZipFile(package) as archive:
        if archive.namelist().count(relative) != 1:
            raise ValueError("missing/duplicate ZIP artifact: " + relative)
        entry = archive.getinfo(relative)
        if entry.file_size > MAX_ARTIFACT:
            raise ValueError("oversized evidence artifact")
        return archive.read(entry)


def validate_storage(folder: Path, source: dict[str, Any]) -> None:
    """Состав контейнера точно равен логическому manifest; лишние пути не извлекаются."""
    present = {width for width in WIDTHS if (folder / f"{width}.zip").exists()}
    if not present:
        return
    widths = {int(key.split("-", 1)[0]) for key in source["runs"]}
    if present != widths:
        raise ValueError("ZIP width inventory")
    for width in sorted(widths):
        expected = {
            f"{key}/{name}"
            for key, run in source["runs"].items()
            if key.startswith(str(width) + "-")
            for name in run["artifacts"]
        }
        if width == min(widths):
            expected.update(SETUP)
        with zipfile.ZipFile(folder / f"{width}.zip") as archive:
            names = archive.namelist()
            if len(names) != len(set(names)) or set(names) != expected:
                raise ValueError("ZIP artifact inventory")
            if any((folder / name).exists() for name in names):
                raise ValueError("ambiguous raw/ZIP artifacts")
