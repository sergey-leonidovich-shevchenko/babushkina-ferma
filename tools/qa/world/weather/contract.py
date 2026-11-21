"""Фиксирует исходную Git-версию, две камеры и полную последовательность осадков."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

from tools.common.git import git_environment
from tools.common.paths import project_root

ROOT = project_root(__file__)
BASE = "0ca4eb345933d2766b340f3d79ea45fb4f38cf5b"
PREFIX = "tools/qa/world/weather/"
WIDTHS = (1152, 1280)
SEED = 20261015
WEATHERS = ("clear", "rain", "snow", "storm")
STEPS = (
    "full",
    "cold",
    "pause-a",
    "pause-b",
    "resume",
    "reduced-a",
    "reduced-b",
    "interior",
    "return",
)
FRAME_IDS = {f"{weather}-{step}" for weather in WEATHERS for step in STEPS}
GD = tuple(PREFIX + name + ".gd" for name in ("game", "scenarios", "profile", "capture"))
INPUTS = (
    tuple(path for name in GD for path in (name, name + ".uid"))
    + (
        "tools/qa/camera/visual_camera_points.gd",
        "docs/reports/visual-overhaul/vbase-003/camera-points.json",
        ".github/workflows/vweather-001.yml",
        "tools/run.py",
        "tools/common/git.py",
        "tools/common/paths.py",
        "tools/common/launch.py",
    )
    + tuple(PREFIX + name for name in ("__init__.py", "contract.py", "collect.py", "verify.py"))
)
PRODUCTION = ("scripts", "assets/game", "main.tscn", "project.godot", "VERSION")


def need(condition: bool, message: str) -> None:
    """Повреждение или неполнота блокирует reader независимо от записанных счётчиков."""
    if not condition:
        raise ValueError(message)


def git(*args: str) -> bytes:
    """Читает собственную настоящую историю, не принимая foreign index/config/replace refs."""
    return subprocess.check_output(
        ["git", "--no-replace-objects", "-C", str(ROOT), *args], env=git_environment()
    )


def digest(raw: bytes) -> str:
    """Связывает исходники и readback с точными байтами."""
    return hashlib.sha256(raw).hexdigest()


def blobs(commit: str) -> dict[str, str]:
    """Инвентаризирует весь runtime и игровой art, отдельно от добавленных QA-наблюдателей."""
    result = {}
    for row in git("ls-tree", "-rz", commit, "--", *PRODUCTION).split(b"\0"):
        if row:
            meta, path = row.split(b"\t", 1)
            mode, kind, oid = meta.decode().split()
            need(kind == "blob" and mode in ("100644", "100755"), "unexpected runtime entry")
            result[path.decode()] = oid
    need(len(result) > 3000, "incomplete runtime inventory")
    return result


def check_export(project: Path, expected: dict[str, str]) -> None:
    """Импорт или QA не может заменить ни один исходный production blob."""
    for name, oid in expected.items():
        raw = (project / name).read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        need(actual == oid, "export changed production: " + name)


def artifacts() -> set[str]:
    """Требует каждую съёмку и каждый реальный launch/log, а не произвольный список producer."""
    result = set()
    for variant in ("baseline", "candidate"):
        result.add(variant + "/production-blobs.json")
        for label in (
            "import-profile",
            "import",
            "compile",
            "1152-profile",
            "1280-profile",
            "1152",
            "1280",
        ):
            result.update(f"{variant}/{label}{suffix}" for suffix in (".txt", ".launch.json"))
        for width in WIDTHS:
            folder = f"{variant}/{width}/"
            result.add(folder + "capture.json")
            result.update(folder + name + ".png" for name in FRAME_IDS)
            result.update(
                folder + f"twin-{step}-{index}.png" for step in range(2) for index in range(2)
            )
    return result
