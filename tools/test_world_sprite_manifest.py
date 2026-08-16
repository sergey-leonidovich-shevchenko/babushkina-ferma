#!/usr/bin/env python3
"""Проверяет динамический world-аудитор на изолированной файловой фикстуре."""

from __future__ import annotations

import struct
import tempfile
from pathlib import Path

from check_world_sprite_manifest import validate


# Создаёт минимальный PNG-заголовок, достаточный для проверки размеров и цветового формата.
def write_png_header(path: Path, width: int, height: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + struct.pack(">II", width, height) + bytes([8, 6]))


# Возвращает минимальную корректную запись семейства для fixture-сценариев аудитора.
def entry() -> dict:
    return {
        "id": "WS-T01", "family": "fixture", "assets": [{"path": "assets/game/environment/tree.png", "width": 24, "height": 24}],
        "render_owner": "TreeSystem", "source_layout": "fixture", "runtime_sizes": ["24×24"], "target_modules": ["24×24"],
        "anchor": "top_left", "collision": "none", "status": "compliant", "priority": "P3", "debt": "none", "done_when": "validated",
    }


# Сценарий: валидный asset используется, затем рядом появляются незарегистрированная ссылка и мёртвый preload.
# Исходное состояние: временный проект содержит один зарегистрированный PNG и использующую его константу.
# Ожидаемый результат: чистая фикстура проходит, а обе новые ошибки находятся без ручного изменения scan_sources.
def test_dynamic_discovery_and_dead_preload() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        write_png_header(root / "assets/game/environment/tree.png", 24, 24)
        script = root / "scripts/tree_system.gd"
        script.parent.mkdir(parents=True)
        script.write_text('const TREE := preload("res://assets/game/environment/tree.png")\nfunc texture(): return TREE\n', encoding="utf-8")
        manifest = {"schema_version": 2, "base_cell": 24, "scan_roots": ["scripts"], "ignored_assets": [], "entries": [entry()]}
        errors, _, _ = validate(root, manifest)
        assert not errors, errors
        script.write_text(script.read_text(encoding="utf-8") + 'const DEAD := preload("res://assets/game/environment/tree.png")\nvar missing="res://assets/game/environment/missing.png"\n', encoding="utf-8")
        errors, _, _ = validate(root, manifest)
        assert any("незарегистрированный" in error for error in errors), errors
        assert any("мёртвый runtime preload DEAD" in error for error in errors), errors


# Запускает fixture-тест как самостоятельный шаг архитектурного gate.
def main() -> int:
    test_dynamic_discovery_and_dead_preload()
    print("WORLD SPRITE AUDIT TEST: dynamic discovery and dead preload checks are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
