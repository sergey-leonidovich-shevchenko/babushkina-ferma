#!/usr/bin/env python3
"""Проверяет полный снимок рисунков и точное покрытие художественных партий."""
import hashlib
import json
import math
import re
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "docs/concepts/visual-polish-2026-10-13/v1"


def validate(audit, backlog, folder=FOLDER):
    """Не допускает пропуски, повторы, повреждённые PNG, подменённые изображения и неверные границы."""
    entries = audit["entries"]
    ids = [entry["id"] for entry in entries]
    if len(ids) != len(set(ids)) or len(ids) != audit["stats"]["items"]:
        raise ValueError("Неполный или повторный реестр")
    batches = [kind for batch in backlog["batches"] for kind in batch["items"]]
    if Counter(batches) != Counter(ids) or set(backlog["itemBatches"]) != set(ids):
        raise ValueError("Пропуск или повтор в партиях")
    for batch in backlog["batches"]:
        if any(backlog["itemBatches"][kind] != batch["id"] for kind in batch["items"]):
            raise ValueError("Неверная связь партии")
    images = {}
    for entry in entries:
        if not re.fullmatch(r"[0-9a-f]{6}", entry["tint"]):
            raise ValueError("Неверная окраска")
        uri = entry["icon"]["image"]
        if not re.fullmatch(r"generated/sprites/[0-9a-f]{24}\.png", uri):
            raise ValueError("Неверный путь PNG")
        if uri not in images:
            png = (folder / "current" / uri.removeprefix("generated/")).read_bytes()
            if png[:8] != b"\x89PNG\r\n\x1a\n" or hashlib.sha256(png).hexdigest()[:24] != Path(uri).stem:
                raise ValueError("Подменён или повреждён PNG")
            images[uri] = struct.unpack(">II", png[16:24])
        width, height = images[uri]
        x, y, w, h = entry["icon"]["rect"]
        if not all(math.isfinite(value) for value in [x, y, w, h]) or x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > width or y + h > height:
            raise ValueError("Рисунок выходит за PNG")
        if entry["pixels"]["empty"] or [width, height] != [entry["pixels"]["width"], entry["pixels"]["height"]]:
            raise ValueError("Пустой рисунок или неверные размеры")
    if len(images) != audit["stats"]["images"]:
        raise ValueError("Неверное количество изображений")
    flags = Counter(flag for entry in entries for flag in entry["flags"])
    if dict(flags) != audit["stats"]["flags"]:
        raise ValueError("Статистика признаков не соответствует реестру")
    return len(ids), len(images), len(backlog["batches"])


if __name__ == "__main__":
    audit = json.loads((FOLDER / "current/audit.json").read_text(encoding="utf-8"))
    backlog = json.loads((FOLDER / "backlog.json").read_text(encoding="utf-8"))
    print("ART REVIEW VALID:", *validate(audit, backlog))
