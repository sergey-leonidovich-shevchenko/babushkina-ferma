"""Контракт двух настоящих Git-экспортов календарной палитры VLIGHT-003."""

from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

from tools.qa.world.lighting import contract as shared

ROOT = shared.ROOT
BASE = "c1f2eda0d1d36e1491dab32fef090bb5a3d22e12"
PREFIX = "tools/qa/world/lighting/daycycle/"
WIDTHS = (1152, 1280)
SEED = 20261015
MINUTES = {"dawn": 360, "day": 720, "dusk": 1140, "night": 1320}
CASES = tuple(f"{room}-{time}" for room in ("street", "home") for time in MINUTES) + (
    "market-dusk",
    "eclipse-night",
)
MODES = ("palette", "legacy", "reference")
PRODUCTION = ("scripts", "assets/game", "main.tscn", "project.godot", "VERSION")
GDSCRIPTS = tuple(
    PREFIX + name + ".gd" for name in ("game", "scenarios", "viewports", "capture", "profile")
)
SHARED_GD = (
    "tools/qa/world/lighting/inventory_cases.gd",
    "tools/qa/world/lighting/inventory_game.gd",
    "tools/qa/world/lighting/light_probe.gd",
    "tools/qa/world/render_order_game.gd",
    "tools/qa/camera/visual_camera_points.gd",
)
# У исторического camera-points нет Git UID: ссылки используют res://путь,
# а импорт disposable-проекта создаёт свой локальный UID. Его не выдаём за source input.
SHARED_UIDS = tuple(
    name + ".uid" for name in SHARED_GD if name != "tools/qa/camera/visual_camera_points.gd"
)
INPUTS = (
    tuple(path for name in GDSCRIPTS for path in (name, name + ".uid"))
    + SHARED_GD
    + SHARED_UIDS
    + (
        "docs/reports/visual-overhaul/vbase-003/camera-points.json",
        ".github/workflows/vlight-003.yml",
        "tools/run.py",
        "tools/common/git.py",
        "tools/common/paths.py",
        "tools/common/launch.py",
        "tools/qa/world/lighting/contract.py",
        *(
            PREFIX + name
            for name in (
                "__init__.py",
                "contract.py",
                "collect.py",
                "evidence.py",
                "pixels.py",
                "verify.py",
                "provenance.py",
                "readings.py",
            )
        ),
    )
)


def digest(raw: bytes) -> str:
    """Связывает точные байты PNG, источников и журналов с неизменяемым manifest."""
    return hashlib.sha256(raw).hexdigest()


def blob_id(raw: bytes) -> str:
    """Git blob включает заголовок типа/длины, в отличие от обычного SHA файла."""
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def blobs(commit: str) -> dict[str, str]:
    """Читает полный runtime/asset tree; QA не подменяет production-файлы оверлеями."""
    result = {}
    for entry in shared.git("ls-tree", "-rz", commit, "--", *PRODUCTION).split(b"\0"):
        if not entry:
            continue
        meta, name = entry.split(b"\t", 1)
        mode, kind, oid = meta.decode().split()
        if kind != "blob" or mode not in ("100644", "100755"):
            raise ValueError("unexpected production entry")
        result[name.decode()] = oid
    if len(result) < 3000:
        raise ValueError("incomplete production export")
    return result


def check_export(project: Path, expected: dict[str, str]) -> None:
    """Проверяет действительные экспортированные bytes до/после каждого движка."""
    for name, oid in expected.items():
        path = project / name
        if path.is_symlink() or not path.is_file() or blob_id(path.read_bytes()) != oid:
            raise ValueError("exported production differs: " + name)


def expected_frames(baseline: bool) -> set[str]:
    """Старая main снимается без новых режимов; текущая — с двумя действительными контролями."""
    return {f"{case}-{mode}" for case in CASES for mode in (("palette",) if baseline else MODES)}


def artifacts() -> set[str]:
    """Полная матрица имён не выводится из потенциально усечённого source manifest."""
    result: set[str] = set()
    for label in ("baseline", "candidate"):
        for setup in (
            "import",
            "compile",
            "import-profile",
            "1152-profile",
            "1280-profile",
            "1152",
            "1280",
        ):
            result.update(f"{label}/{setup}{suffix}" for suffix in (".txt", ".launch.json"))
        result.add(label + "/production-blobs.json")
        for width in WIDTHS:
            prefix = f"{label}/{width}/"
            result.add(prefix + "capture.json")
            for name in expected_frames(label == "baseline"):
                result.update(prefix + name + suffix for suffix in (".png", "-hud.png"))
                if name.startswith("street-") and not name.endswith("reference"):
                    result.update(
                        prefix + name + "-" + target + "-hidden.png"
                        for target in ("hero", "threat")
                    )
            if label == "candidate":
                result.add(prefix + "street-dusk-palette-bad-hud.png")
                for step in ("both", "first-legacy", "second-night"):
                    result.update(prefix + f"twin-{step}-{index}.png" for index in range(2))
    return result


def need(condition: Any, message: str) -> None:
    """Любое нарушенное обязательство завершает reader отказом с конкретной причиной."""
    if not condition:
        raise ValueError(message)
