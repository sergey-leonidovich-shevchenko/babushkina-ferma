"""Read-only доступ к исходному внешнему прогону или его неизменённым ZIP-пакетам."""

from __future__ import annotations

import io
import json
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

from PIL import Image

from tools.qa.world.lighting.daycycle.contract import need


class Evidence:
    """Имена относительно output не могут уйти по traversal, absolute path или symlink."""

    def __init__(self, folder: Path) -> None:
        self.folder = folder

    def read(self, name: str) -> bytes:
        """ZIP используется только как контейнер фактических bytes, без extractall."""
        path = PurePosixPath(name)
        need(
            not path.is_absolute() and ".." not in path.parts and "\\" not in name,
            "unsafe evidence path",
        )
        target = self.folder / name
        need(not any(p.is_symlink() for p in (target, *target.parents)), "symlink evidence path")
        if target.is_file():
            return target.read_bytes()
        archive = self.folder / (path.parts[0] + ".zip")
        need(archive.is_file() and not archive.is_symlink(), "missing evidence: " + name)
        with zipfile.ZipFile(archive) as stream:
            key = PurePosixPath(*path.parts[1:]).as_posix()
            need(stream.namelist().count(key) == 1, "duplicate/missing ZIP member")
            entry = stream.getinfo(key)
            need(entry.file_size < 128 * 1024 * 1024, "oversized evidence member")
            return stream.read(entry)

    def document(self, name: str) -> Any:
        """Разбирает ровно сохранённый JSON из проверяемого source/capture."""
        return json.loads(self.read(name))

    def image(self, name: str, size: list[int]) -> Image.Image:
        """Размер и PNG проверяются до приведения каналов; никакого resize доказательства."""
        with Image.open(io.BytesIO(self.read(name))) as image:
            need(image.format == "PNG" and list(image.size) == size, "native PNG/size differs")
            result: Image.Image = image.convert("RGBA")
            return result
