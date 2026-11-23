"""Читает исходные bytes native-каталога либо целого ZIP без извлечения или правки."""

from __future__ import annotations

import io
import json
import stat
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

from PIL import Image

from tools.qa.world.lighting.quality.contract import need


class Evidence:
    """Пути, symlink, повторные ZIP-members и размер проверяются до разбора содержимого."""

    def __init__(self, source: Path) -> None:
        need(not any(p.is_symlink() for p in (source, *source.parents)), "symlink evidence source")
        need(
            source.is_dir() or source.is_file() and zipfile.is_zipfile(source),
            "native directory or original ZIP required",
        )
        self.source = source
        self.prefix = ""
        if source.is_file():
            with zipfile.ZipFile(source) as stream:
                names = stream.namelist()
                roots = [prefix for prefix in ("", "evidence/") if prefix + "source.json" in names]
                need(len(roots) <= 1, "ambiguous original native ZIP root")
                if roots:
                    self.prefix = roots[0]
                    need(
                        names.count(self.prefix + "source.json") == 1,
                        "duplicate original source manifest",
                    )

    def read(self, name: str) -> bytes:
        """Никакой extractall, сетевого fallback или произвольных абсолютных путей в manifest."""
        key = PurePosixPath(name)
        need(
            bool(name)
            and not key.is_absolute()
            and ".." not in key.parts
            and "\\" not in name
            and key.as_posix() == name,
            "unsafe evidence path",
        )
        if self.source.is_dir():
            target = self.source / name
            need(not any(p.is_symlink() for p in (target, *target.parents)), "symlink artifact")
            need(
                target.is_file() and target.stat().st_size < 128 * 1024 * 1024,
                "missing/oversized artifact: " + name,
            )
            return target.read_bytes()
        with zipfile.ZipFile(self.source) as stream:
            member = self.prefix + name
            need(stream.namelist().count(member) == 1, "duplicate or missing original ZIP member")
            entry = stream.getinfo(member)
            need(
                entry.file_size < 128 * 1024 * 1024 and not stat.S_ISLNK(entry.external_attr >> 16),
                "oversized or symlink ZIP member",
            )
            return stream.read(entry)

    def document(self, name: str) -> Any:
        """Разбирает только фактический сохранённый JSON, не создавая недостающий документ."""
        return json.loads(self.read(name))

    def image(self, name: str, size: list[int]) -> Image.Image:
        """Точное PNG и размер проверяются до RGBA conversion; resize доказательства запрещён."""
        with Image.open(io.BytesIO(self.read(name))) as image:
            need(image.format == "PNG" and list(image.size) == size, "physical PNG/size differs")
            result: Image.Image = image.convert("RGBA")
            return result
