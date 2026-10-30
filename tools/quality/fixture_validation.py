"""Сверяет реальные результаты генератора и адрес коллектора для действующей команды."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from tools.assets.migration import migration_fixture as fixture


def validate(target: Path, source_root: Path) -> dict[str, Any]:
    """Отклоняет устаревшие пути проекта до настоящего импорта и сбора данных Godot."""
    case: dict[str, Any] = json.loads((target / fixture.CASE).read_text())
    capture = target / "tools/migration_capture.gd"
    if not capture.is_file() or (target / "tools/assets").exists():
        raise ValueError("external fixture namespace differs from its live capture command")
    if (
        capture.read_bytes()
        != (source_root / "tools/assets/migration/migration_capture.gd").read_bytes()
    ):
        raise ValueError("fixture collector is not the real current source")
    if not all((target / name).is_file() for name in case["copied_files"]):
        raise ValueError("fixture producer omitted a real dependency")
    draft = json.loads((target / "saved-draft.json").read_text())
    if [row["asset_path"] for row in draft["objects"]] != [case["paths"][s] for s in fixture.SIDES]:
        raise ValueError("fixture draft/resource URIs differ")
    for uri in case["paths"].values():
        if not uri.startswith("res://") or not (target / uri.removeprefix("res://")).is_file():
            raise ValueError("fixture contains a missing resource URI")
    return case
