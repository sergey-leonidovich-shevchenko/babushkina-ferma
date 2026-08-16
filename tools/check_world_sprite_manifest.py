#!/usr/bin/env python3
"""Автоматически проверяет реестр, runtime-ссылки и владельцев мировых спрайтов."""

from __future__ import annotations

import argparse
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
WORLD_ASSET_PREFIXES = (
    "assets/game/buildings/", "assets/game/characters/", "assets/game/enemies/",
    "assets/game/environment/", "assets/game/expansion_pack/", "assets/game/fishing/",
    "assets/game/generated/", "assets/game/locations/", "assets/game/resources/",
    "assets/game/tiles/", "assets/game/wildlife/", "assets/game/world_loot/",
    "assets/game/world_polish/",
)
ASSET_PATTERN = re.compile(r'res://(assets/[^"\']+\.(?:png|jpg|jpeg|webp))', re.IGNORECASE)
PRELOAD_PATTERN = re.compile(
    r'const\s+([A-Z][A-Z0-9_]*)\s*(?::[^=]+)?\s*:?=\s*preload\("res://(assets/[^"\']+\.(?:png|jpg|jpeg|webp))"\)',
    re.IGNORECASE,
)
SIZE_PATTERN = re.compile(r"^(\d+(?:\.\d+)?)×(\d+(?:\.\d+)?)$")
RENDERER_PROFILE_PATTERN = re.compile(r"const\s+(?:PROFILES|[A-Z0-9_]*(?:VISUAL|COLLISION)_SIZE)\b")


# Читает размеры и формат PNG без внешних библиотек, чтобы проверка одинаково работала в CI и локально.
def png_metadata(path: Path) -> tuple[int, int, int, int] | None:
    with path.open("rb") as stream:
        header = stream.read(26)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", header[16:24])
    return width, height, header[24], header[25]


# Находит все GDScript-файлы внутри корней манифеста без ручного списка владельцев.
def script_sources(root: Path, scan_roots: list[str]) -> list[Path]:
    result: list[Path] = []
    for relative in scan_roots:
        base = root / relative
        if base.is_file() and base.suffix == ".gd":
            result.append(base)
        elif base.is_dir():
            result.extend(base.rglob("*.gd"))
    return sorted(set(result))


# Собирает мировые изображения из всех runtime-скриптов и возвращает исходный текст для дополнительных проверок.
def referenced_assets(root: Path, scan_roots: list[str]) -> tuple[set[str], dict[Path, str]]:
    references: set[str] = set()
    sources: dict[Path, str] = {}
    for path in script_sources(root, scan_roots):
        text = path.read_text(encoding="utf-8")
        sources[path] = text
        for match in ASSET_PATTERN.finditer(text):
            relative = match.group(1)
            if "%" not in relative and relative.startswith(WORLD_ASSET_PREFIXES):
                references.add(relative)
    return references, sources


# Выявляет preload-константы мировых изображений, которые объявлены, но не используются runtime-кодом.
def dead_world_preloads(root: Path, sources: dict[Path, str]) -> list[str]:
    combined = "\n".join(sources.values())
    errors: list[str] = []
    for path, text in sources.items():
        for match in PRELOAD_PATTERN.finditer(text):
            symbol, asset = match.groups()
            if asset.startswith(WORLD_ASSET_PREFIXES) and len(re.findall(rf"\b{re.escape(symbol)}\b", combined)) == 1:
                errors.append(f"мёртвый runtime preload {symbol}: {path.relative_to(root)} -> {asset}")
    return errors


# Запрещает renderer-файлам снова становиться владельцами уникальных мировых профилей и размеров.
def renderer_profile_errors(root: Path, sources: dict[Path, str]) -> list[str]:
    errors: list[str] = []
    for path, text in sources.items():
        if path.name.endswith("_renderer.gd") and RENDERER_PROFILE_PATTERN.search(text):
            errors.append(f"renderer хранит мировой профиль или уникальный размер: {path.relative_to(root)}")
    return errors


# Формирует машиночитаемый отчёт фактических файлов и заявленных runtime/target-размеров.
def build_report(root: Path, manifest: dict) -> dict:
    families: list[dict] = []
    for entry in manifest.get("entries", []):
        actual_assets: list[dict] = []
        for asset in entry.get("assets", []):
            relative = str(asset.get("path", ""))
            metadata = png_metadata(root / relative) if (root / relative).is_file() else None
            actual_assets.append({"path": relative, "actual_size": list(metadata[:2]) if metadata else None})
        families.append({
            "id": entry.get("id"), "family": entry.get("family"), "assets": actual_assets,
            "runtime_sizes": entry.get("runtime_sizes", []), "target_modules": entry.get("target_modules", []),
        })
    return {"base_cell": manifest.get("base_cell"), "families": families}


# Проверяет схему, файлы, размеры, динамические ссылки, мёртвые preload и границы renderer-слоя.
def validate(root: Path, manifest: dict) -> tuple[list[str], Counter[str], Counter[str]]:
    errors: list[str] = []
    entries = manifest.get("entries", [])
    base_cell = int(manifest.get("base_cell", 0))
    scan_roots = list(manifest.get("scan_roots", []))
    if manifest.get("schema_version") != 2:
        errors.append("неподдерживаемая schema_version")
    if base_cell <= 0:
        errors.append("base_cell должен быть положительным")
    if not scan_roots:
        errors.append("scan_roots должен содержать хотя бы один runtime-корень")
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
            metadata = png_metadata(path)
            expected = (int(asset.get("width", -1)), int(asset.get("height", -1)))
            if metadata is not None and metadata[:2] != expected:
                errors.append(f"{entry['id']}: {relative} имеет {metadata[:2]}, в реестре {expected}")
            if metadata is not None and (metadata[2] != 8 or metadata[3] not in {2, 6}):
                errors.append(f"{entry['id']}: {relative} должен быть 8-bit RGB/RGBA PNG, сейчас bit_depth={metadata[2]} color_type={metadata[3]}")
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
    references, sources = referenced_assets(root, scan_roots)
    for relative in sorted(references - declared_assets - ignored_assets):
        errors.append(f"runtime ссылается на незарегистрированный мировой asset: {relative}")
    for relative in sorted(ignored_assets - references):
        errors.append(f"ignored asset больше не встречается в runtime-коде: {relative}")
    errors.extend(dead_world_preloads(root, sources))
    errors.extend(renderer_profile_errors(root, sources))
    return errors, Counter(entry.get("status", "invalid") for entry in entries), Counter(entry.get("priority", "invalid") for entry in entries if entry.get("status") != "compliant")


# Загружает постоянный манифест, печатает аудит либо JSON-отчёт actual/target для инструментов проекта.
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json-report", action="store_true")
    arguments = parser.parse_args()
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
    if arguments.json_report:
        print(json.dumps(build_report(root, manifest), ensure_ascii=False, indent=2))
    else:
        print(
            "WORLD SPRITE AUDIT: "
            f"{len(manifest['entries'])} семейств; готово {statuses['compliant']}; "
            f"открыто P1={priorities['P1']}, P2={priorities['P2']}, P3={priorities['P3']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
