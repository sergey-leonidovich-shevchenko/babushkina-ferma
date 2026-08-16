#!/usr/bin/env python3
"""Обновляет размеры и SHA-256 уже зарегистрированных UI-эталонов."""

from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/generated/ui/visual_regression_manifest.json"
REFERENCE_DIR = MANIFEST.parent


def png_size(path: Path) -> tuple[int, int]:
    """Читает нативные размеры PNG без зависимости от внешней библиотеки."""
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


def main() -> None:
    """Пересчитывает метаданные только для существующего утверждённого списка."""
    document = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for entry in document["references"]:
        path = REFERENCE_DIR / entry["file"]
        if not path.is_file():
            raise FileNotFoundError(path)
        entry["width"], entry["height"] = png_size(path)
        entry["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    MANIFEST.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"UI VISUAL MANIFEST: updated {len(document['references'])} references")


if __name__ == "__main__":
    main()
