#!/usr/bin/env python3
"""Обновляет геометрию, SHA-256 и устойчивые perceptual-отпечатки UI-эталонов."""

from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path

from PIL import Image

from tools.common.paths import project_root


ROOT = project_root(__file__)
MANIFEST = ROOT / "assets/generated/ui/visual_regression_manifest.json"
REFERENCE_DIR = MANIFEST.parent
GRID = (8, 8)
CELL_SAMPLES = 4
THRESHOLDS = {"mean": 0.020, "max_cell": 0.100, "changed_ratio": 0.150, "changed_cell": 0.035}


def png_size(path: Path) -> tuple[int, int]:
    """Читает нативные размеры PNG без зависимости от внешней библиотеки."""
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


def perceptual_signature(path: Path) -> list[int]:
    """Усредняет RGB по малой сетке, устойчивой к единичному GPU-шуму и сглаживанию шрифта."""
    with Image.open(path) as source:
        image = source.convert("RGB")
        width, height = image.size
        pixels = image.load()
        result: list[int] = []
        for row in range(GRID[1]):
            for column in range(GRID[0]):
                totals = [0, 0, 0]
                for sample_y in range(CELL_SAMPLES):
                    for sample_x in range(CELL_SAMPLES):
                        x = min(int((column + (sample_x + 0.5) / CELL_SAMPLES) * width / GRID[0]), width - 1)
                        y = min(int((row + (sample_y + 0.5) / CELL_SAMPLES) * height / GRID[1]), height - 1)
                        color = pixels[x, y]
                        for channel in range(3):
                            totals[channel] += color[channel]
                result.extend(round(value / (CELL_SAMPLES * CELL_SAMPLES)) for value in totals)
        return result


def main() -> None:
    """Пересчитывает метаданные только для существующего утверждённого списка."""
    document = json.loads(MANIFEST.read_text(encoding="utf-8"))
    document["schema"] = 2
    for entry in document["references"]:
        path = REFERENCE_DIR / entry["file"]
        if not path.is_file():
            raise FileNotFoundError(path)
        entry["width"], entry["height"] = png_size(path)
        entry["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        signature = perceptual_signature(path)
        entry["perceptual"] = {"grid": list(GRID), "rgb_hex": bytes(signature).hex(), "thresholds": THRESHOLDS}
    MANIFEST.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"UI VISUAL MANIFEST: updated {len(document['references'])} references")


if __name__ == "__main__":
    main()
