"""Полная матрица VLIGHT-010 и точные Git-входы без runtime-оверлеев."""

from __future__ import annotations

from typing import Any

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.daycycle.contract import blobs as blobs
from tools.qa.world.lighting.daycycle.contract import check_export as check_export
from tools.qa.world.lighting.daycycle.contract import digest as digest

ROOT = shared.ROOT
BASE = "e0d393034f36bc4ba27329cd9e4e0b09c3a157d1"
PREFIX = "tools/qa/world/lighting/quality/"
WIDTHS = (1152, 1280)
SEED = 20261015
CASES = tuple(f"{room}-{time}" for room in ("street", "home") for time in ("day", "dusk", "night"))
MODES = ("standard", "low", "off")
TARGETS = ("door", "enemy", "resource")
TWINS = ("standard", "first-low", "second-off", "restored")
ENGINE = "4.7.1-stable (official)"
BANNER = "Godot Engine v4.7.1.stable.official.a13da4feb"
GD = tuple(
    PREFIX + name + ".gd"
    for name in ("game", "cases", "capture", "profile", "measure", "viewports")
)
SHARED_GD = (
    "tools/qa/world/lighting/inventory_cases.gd",
    "tools/qa/world/lighting/inventory_game.gd",
    "tools/qa/world/lighting/light_probe.gd",
    "tools/qa/world/render_order_game.gd",
    "tools/qa/camera/visual_camera_points.gd",
)
PY = tuple(
    PREFIX + name + ".py"
    for name in (
        "__init__",
        "contract",
        "collect",
        "evidence",
        "verify",
        "provenance",
        "pixels",
        "readings",
        "checks",
    )
)
INPUTS = (
    tuple(path for name in GD for path in (name, name + ".uid"))
    + SHARED_GD
    + tuple(name + ".uid" for name in SHARED_GD if not name.endswith("visual_camera_points.gd"))
    + PY
    + (
        "docs/reports/visual-overhaul/vbase-003/camera-points.json",
        ".github/workflows/vlight-010.yml",
        "tools/run.py",
        "tools/common/__init__.py",
        "tools/common/git.py",
        "tools/common/launch.py",
        "tools/common/paths.py",
        "tools/qa/__init__.py",
        "tools/qa/world/__init__.py",
        "tools/qa/world/lighting/__init__.py",
        "tools/qa/world/lighting/contract.py",
        "tools/qa/world/lighting/daycycle/__init__.py",
        "tools/qa/world/lighting/daycycle/contract.py",
        "tools/qa/world/weather/__init__.py",
        "tools/qa/world/weather/collect.py",
        "tools/qa/world/weather/contract.py",
    )
)


def need(condition: Any, message: str) -> None:
    """Нарушенное обязательство не заменяется предупреждением или частичной приёмкой."""
    if not condition:
        raise ValueError(message)


def frame_ids(baseline: bool) -> set[str]:
    """Старая main имеет только настоящий standard, текущая — все три действительных режима."""
    return {f"{case}-{mode}" for case in CASES for mode in (("standard",) if baseline else MODES)}


def artifacts() -> set[str]:
    """Полный ожидаемый набор не выводится из потенциально усечённого source manifest."""
    result: set[str] = set()
    for label in ("baseline", "candidate"):
        for setup in (
            "import-profile",
            "import",
            "compile",
            "1152-profile",
            "1152",
            "1280-profile",
            "1280",
        ):
            result.update(f"{label}/{setup}{suffix}" for suffix in (".txt", ".launch.json"))
        result.add(label + "/production-blobs.json")
        for width in WIDTHS:
            prefix = f"{label}/{width}/"
            result.add(prefix + "capture.json")
            for frame in frame_ids(label == "baseline"):
                result.update(prefix + frame + suffix for suffix in (".png", "-hud.png"))
                result.update(prefix + frame + f"-{target}-hidden.png" for target in TARGETS)
            if label == "candidate":
                result.add(prefix + "street-dusk-standard-bad-hud.png")
                result.update(prefix + case + "-restored.png" for case in CASES)
                result.update(
                    prefix + f"twin-{step}-{index}.png" for step in TWINS for index in range(2)
                )
    return result
