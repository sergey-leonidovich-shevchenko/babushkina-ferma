"""VPERF-003: одинаковые сцена, физические шаги и источник сравнения."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

from tools.common.git import git_environment

ROOT = Path(__file__).resolve().parents[4]
TASK = "VPERF-003"
VARIANTS = ("baseline", "water", "grass", "shadows", "light", "ui")
RUNS = (("repeat-1", 30), ("repeat-2", 30), ("repeat-3", 30), ("long-cycle", 600))
ROUTE = "docs/reports/visual-overhaul/vbase-001/native/run-1/native.json"
CAPTURE = "tools/qa/performance/pass_cost/capture.gd"
FRAME_FIELDS = (
    "usec",
    "interval_ms",
    "draw_id",
    "process_id",
    "physics_tick",
    "draw_calls",
    "static_bytes",
    "texture_bytes",
    "engine_process_ms",
    "engine_physics_ms",
    "render_ground_x",
    "render_ground_y",
    "render_camera_x",
    "render_camera_y",
)
ROUTE_FIELDS = ("tick", "target", "x", "y", "camera_x", "camera_y", "minutes")
RUN_FILES = (
    "run.json",
    "launch.json",
    "cpu-rss.json",
    "before.png",
    "after.png",
    "trajectory.csv.gz",
    "frames.csv.gz",
    "save-before.json",
    "save-after.json",
    "engine.log",
    "stdout.txt",
)


def schedule() -> tuple[tuple[str, str, int], ...]:
    """Чередует место вариантов в серии; все они последовательно идут на одном runner."""
    orders = (VARIANTS, VARIANTS[2:] + VARIANTS[:2], VARIANTS[4:] + VARIANTS[:4], VARIANTS)
    return tuple(
        (run, variant, seconds)
        for (run, seconds), order in zip(RUNS, orders, strict=True)
        for variant in order
    )


def expected_files() -> set[str]:
    """Полнота определяется контрактом, а не списком из проверяемого manifest."""
    return {f"{run}/{variant}/{file}" for run, variant, _ in schedule() for file in RUN_FILES} | {
        "engine-version.txt",
        "import.txt",
    }


def require(condition: object, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def git(*args: str) -> bytes:
    return subprocess.check_output(
        ["git", "--no-replace-objects", "-C", str(ROOT), *args],
        env=git_environment(),
    )


def tree(commit: str) -> str:
    require(re.fullmatch(r"[0-9a-f]{40}", commit), "expected full Git SHA")
    return git("rev-parse", commit + "^{tree}").decode().strip()


def read(path: Path) -> Any:
    return json.loads(path.read_text())


def write(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n")


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def ordinary_file(folder: Path, name: str) -> Path:
    path = folder / name
    require(path.is_file() and path.resolve() == path, f"missing or redirected file: {name}")
    return path
