"""Читает точные raw/ZIP артефакты сравнения без извлечения архивных путей."""

from __future__ import annotations

import zipfile
from pathlib import Path
from typing import Any

from tools.qa.world.lighting.storage import MAX_ARTIFACT, Artifacts


class Evidence:
    """Manifest определяет единственный транспорт каждого run; смешанные копии запрещены."""

    def __init__(self, folder: Path, source: dict[str, Any]) -> None:
        self.folder = folder.resolve()
        self.source = source
        for key, run in source["runs"].items():
            self._validate_key(key)
            packed = self.folder / (key + ".zip")
            raw = self.folder / key
            if packed.is_symlink() or raw.is_symlink():
                raise ValueError("symlink evidence transport")
            if packed.is_file():
                if raw.exists():
                    raise ValueError("ambiguous raw/ZIP evidence")
                with zipfile.ZipFile(packed) as archive:
                    names = archive.namelist()
                    if len(names) != len(set(names)) or set(names) != set(run["artifacts"]):
                        raise ValueError("ZIP artifact inventory")
                    for name in names:
                        Artifacts.validate_name(name)
                        if archive.getinfo(name).file_size > MAX_ARTIFACT:
                            raise ValueError("oversized ZIP artifact")
            else:
                raw_names = {
                    p.relative_to(raw).as_posix()
                    for p in raw.rglob("*")
                    if p.is_file() or p.is_symlink()
                }
                if raw_names != set(run["artifacts"]):
                    raise ValueError("raw artifact inventory")

    @staticmethod
    def _validate_key(key: str) -> None:
        if key not in ["1152", "1280"]:
            raise ValueError("unknown comparison run")

    def read(self, key: str, name: str) -> bytes:
        """Проверяет traversal/symlink и ограничивает размер до чтения."""
        self._validate_key(key)
        Artifacts.validate_name(name)
        packed = self.folder / (key + ".zip")
        if packed.is_file():
            with zipfile.ZipFile(packed) as archive:
                return archive.read(name)
        path = self.folder / key / name
        if any(p.is_symlink() for p in (path, *path.parents) if p.is_relative_to(self.folder)):
            raise ValueError("symlink in raw evidence")
        if path.stat().st_size > MAX_ARTIFACT:
            raise ValueError("oversized raw artifact")
        return path.read_bytes()
