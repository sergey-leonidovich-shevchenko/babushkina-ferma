#!/usr/bin/env python3
"""Проверяет полноту и непротиворечивость реестра мировых спрайтов."""

from __future__ import annotations

import json
import re
import struct
import sys
from collections import Counter
from pathlib import Path


REQUIRED_FIELDS = {
    "id", "family", "assets", "render_owner", "source_layout", "runtime_sizes",
    "target_modules", "anchor", "collision", "status", "priority", "debt", "done_when",
}
ALLOWED_STATUSES = {"compliant", "migration", "redraw", "legacy"}
ALLOWED_PRIORITIES = {"P0", "P1", "P2", "P3"}
ASSET_PATTERN = re.compile(r'res://(assets/[^"\']+\.(?:png|jpg|jpeg|webp))', re.IGNORECASE)
SIZE_PATTERN = re.compile(r"^(\d+(?:\.\d+)?)×(\d+(?:\.\d+)?)$")


# Читает размеры PNG без внешних библиотек, чтобы проверка одинаково работала в CI и локально.
def png_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as stream:
        header = stream.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", header[16:24])


# Собирает прямые ссылки на мировые изображения только из утверждённых владельцев отрисовки.
def referenced_assets(root: Path, sources: list[str]) -> set[str]:
    result: set[str] = set()
    for relative in sources:
        path = root / relative
        if not path.is_file():
            continue
        result.update(match.group(1) for match in ASSET_PATTERN.finditer(path.read_text(encoding="utf-8")))
    return result


# Проверяет поля, файлы, фактические размеры и модульность записей, объявленных готовыми.
def validate(root: Path, manifest: dict) -> tuple[list[str], Counter[str], Counter[str]]:
    errors: list[str] = []
    entries = manifest.get("entries", [])
    base_cell = int(manifest.get("base_cell", 0))
    if manifest.get("schema_version") != 1:
        errors.append("неподдерживаемая schema_version")
    if base_cell <= 0:
        errors.append("base_cell должен быть положительным")
    identifiers = [entry.get("id", "") for entry in entries]
    for identifier, count in Counter(identifiers).items():
        if not identifier or count != 1:
            errors.append(f"идентификатор {identifier or '<пусто>'} встречается {count} раз")
    declared_assets: set[str] = set()
    for index, entry in enumerate(entries):
        missing = REQUIRED_FIELDS - entry.keys()
        if missing:
            errors.append(f"запись {index}: отсутствуют поля {sorted(missing)}")
            continue
        if entry["status"] not in ALLOWED_STATUSES:
            errors.append(f"{entry['id']}: неизвестный статус {entry['status']}")
        if entry["priority"] not in ALLOWED_PRIORITIES:
            errors.append(f"{entry['id']}: неизвестный приоритет {entry['priority']}")
        if not entry["assets"] or not str(entry["done_when"]).strip() or not str(entry["debt"]).strip():
            errors.append(f"{entry['id']}: нужны assets, debt и проверяемый done_when")
        for asset in entry["assets"]:
            relative = str(asset.get("path", ""))
            declared_assets.add(relative)
            path = root / relative
            if not path.is_file():
                errors.append(f"{entry['id']}: отсутствует {relative}")
                continue
            actual = png_size(path)
            expected = (int(asset.get("width", -1)), int(asset.get("height", -1)))
            if actual is not None and actual != expected:
                errors.append(f"{entry['id']}: {relative} имеет {actual}, в реестре {expected}")
        if entry["status"] == "compliant":
            for raw_size in entry["runtime_sizes"]:
                match = SIZE_PATTERN.fullmatch(str(raw_size))
                if not match:
                    errors.append(f"{entry['id']}: готовый runtime-размер должен быть точным: {raw_size}")
                    continue
                width, height = float(match.group(1)), float(match.group(2))
                if width % base_cell or height % base_cell:
                    errors.append(f"{entry['id']}: готовый размер {raw_size} не кратен сетке {base_cell}")
    ignored_assets = set(manifest.get("ignored_assets", []))
    references = referenced_assets(root, list(manifest.get("scan_sources", [])))
    for relative in sorted(references - declared_assets - ignored_assets):
        errors.append(f"мировой renderer ссылается на незарегистрированный asset: {relative}")
    for relative in sorted(ignored_assets - references):
        errors.append(f"ignored asset больше не встречается в scan_sources: {relative}")
    return errors, Counter(entry.get("status", "invalid") for entry in entries), Counter(entry.get("priority", "invalid") for entry in entries if entry.get("status") != "compliant")


# Загружает постоянный манифест и печатает краткую метрику открытого художественного долга.
def main() -> int:
    root = Path(__file__).resolve().parent.parent
    manifest_path = root / "assets/game/world_sprite_manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"WORLD SPRITE AUDIT ERROR: {error}", file=sys.stderr)
        return 1
    errors, statuses, priorities = validate(root, manifest)
    if errors:
        for error in errors:
            print(f"WORLD SPRITE AUDIT ERROR: {error}", file=sys.stderr)
        return 1
    print(
        "WORLD SPRITE AUDIT: "
        f"{len(manifest['entries'])} семейств; "
        f"готово {statuses['compliant']}; "
        f"открыто P1={priorities['P1']}, P2={priorities['P2']}, P3={priorities['P3']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
