"""Читает raw/ZIP-транспорт нативных снимков, не извлекая чужие пути."""

from __future__ import annotations

import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

from tools.qa.world.lighting.contract import WIDTHS

SETUP = {
    prefix + suffix
    for prefix in ("import", "compile-production", "compile-control")
    for suffix in (".txt", ".stdout.txt", ".launch.json")
}
MAX_ARTIFACT = 64 * 1024 * 1024


class Artifacts:
    """Manifest задаёт точный состав; одновременный raw/ZIP отклоняется как неоднозначный."""

    def __init__(self, folder: Path, source: dict[str, Any]) -> None:
        self.folder = folder.resolve()
        self.source = source
        self.widths = {int(key.split("-", 1)[0]) for key in source["runs"]}
        present = {width for width in WIDTHS if (self.folder / f"{width}.zip").exists()}
        self.packed = bool(present)
        if not self.packed:
            for key, run in source["runs"].items():
                parent = self.folder / key
                actual = {
                    path.relative_to(parent).as_posix()
                    for path in parent.rglob("*")
                    if path.is_file() or path.is_symlink()
                }
                if actual != set(run["artifacts"]):
                    raise ValueError("raw artifact inventory: " + key)
            return
        if present != self.widths:
            raise ValueError("ZIP width inventory")
        for width in present:
            expected = {
                f"{key}/{name}"
                for key, run in source["runs"].items()
                if key.startswith(str(width) + "-")
                for name in run["artifacts"]
            }
            if width == min(present):
                expected.update(SETUP)
            with zipfile.ZipFile(self.folder / f"{width}.zip") as archive:
                names = archive.namelist()
                if len(names) != len(set(names)) or set(names) != expected:
                    raise ValueError("ZIP artifact inventory")
                for name in names:
                    self.validate_name(name)
                    if (self.folder / name).exists() or (self.folder / name).is_symlink():
                        raise ValueError("ambiguous raw/ZIP artifact: " + name)

    @staticmethod
    def validate_name(name: str) -> None:
        """Логические имена не могут обозначать абсолютный путь или traversal."""
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or path.as_posix() != name or "\\" in name:
            raise ValueError("non-canonical artifact path")

    def read(self, name: str) -> bytes:
        """CRC и размер проверяются до чтения ZIP; raw-файл не проходит по ссылкам."""
        self.validate_name(name)
        if self.packed:
            width = min(self.widths) if name in SETUP else int(name.split("-", 1)[0])
            with zipfile.ZipFile(self.folder / f"{width}.zip") as archive:
                if archive.namelist().count(name) != 1:
                    raise ValueError("missing/duplicate ZIP member: " + name)
                if archive.getinfo(name).file_size > MAX_ARTIFACT:
                    raise ValueError("oversized evidence artifact")
                return archive.read(name)
        path = self.folder / name
        if any(
            value.is_symlink()
            for value in (path, *path.parents)
            if value.is_relative_to(self.folder)
        ):
            raise ValueError("raw evidence must not traverse symlinks")
        if path.stat().st_size > MAX_ARTIFACT:
            raise ValueError("oversized evidence artifact")
        return path.read_bytes()
