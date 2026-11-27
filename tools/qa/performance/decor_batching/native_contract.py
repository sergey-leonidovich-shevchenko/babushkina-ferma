"""Independent schedule, capture points and file layout for VPERF-006."""

from __future__ import annotations

import gzip
import hashlib
from pathlib import Path
from typing import Any

from tools.qa.performance.decor_batching import verify as geometry
from tools.qa.performance.pass_cost import contract as shared

TASK = "VPERF-006"
DIRECTORY = "tools/qa/performance/decor_batching"
REPETITIONS = 12
RENDERER = "X11 / gl_compatibility / Mesa llvmpipe"
PINNED_INPUTS = (geometry.MAP_SOURCE, "scripts/systems/village_layout_system.gd", shared.ROUTE)
TRACE_NAMES = ("frames", "trajectory", "terrain-cache")
CACHE_FIELDS = ("draw_id", "revision", "terrain_ready")


def plan() -> dict[str, Any]:
    """The clipped natural camera of edge views has several possible player positions."""
    positions = {
        "empty_patch": (2088, 1296),
        "east_view": (1955, 655),
        "north_view": (1128, 96),
    }
    overlap = [
        {
            "id": f"{kind}-{side}",
            "player": [x, y + offset],
            "day": 1,
            "prop": kind,
            "position": [x, y],
            "anchor": [x, y + 24],
            "front": side == "behind",
        }
        for kind, x, y in (("bench", 1176, 792), ("board", 1656, 528))
        for side, offset in (("behind", 8), ("ahead", 24))
    ]
    overlap.append({"id": "winter", "player": [1128, 744], "day": 22})
    return {
        "repetitions": REPETITIONS,
        "cases": [
            {
                "id": label,
                "phase": case.phase,
                "camera": list(case.camera),
                "player": list(positions.get(label, (case.camera[0] + 480, case.camera[1] + 270))),
                "repaint": list(case.repaint) if case.repaint else None,
            }
            for label, case in geometry.CASES.items()
        ],
        "overlap": overlap,
    }


def schedule() -> list[list[Any]]:
    variants = geometry.VARIANTS
    fixed = [["fixed", variant, 0] for variant in variants]
    warm = [
        [run, variant, seconds]
        for index, (run, seconds) in enumerate(shared.RUNS)
        for variant in (variants[index % len(variants) :] + variants[: index % len(variants)])
    ]
    return fixed + warm


def expected_files() -> set[str]:
    fixed = {
        "fixed.json",
        "launch.json",
        "cpu-rss.json",
        "engine.log",
        "stdout.txt",
        *(f"{case}{suffix}.png" for case in geometry.CASES for suffix in ("", "-terrain")),
        *(f"{spec['id']}.png" for spec in plan()["overlap"]),
    }
    files = {"plan.json", "engine-version.txt", "import.txt"}
    for run, variant, seconds in schedule():
        names = (
            (*shared.RUN_FILES, "trace-origin.json", "terrain-cache.csv.gz") if seconds else fixed
        )
        files.update(f"{run}/{variant}/{name}" for name in names)
    files.update(f"fixed/baseline/flower-order-{order}.png" for order in ("correct", "wrong"))
    return files


def inputs(head: str) -> dict[str, str]:
    """Ensures the compared commit has the original accepted map placements and route."""
    digests = {}
    for filename in PINNED_INPUTS:
        payload = shared.git("show", f"{head}:{filename}")
        shared.require(
            payload == shared.git("show", f"{geometry.BASE}:{filename}"),
            f"accepted input differs: {filename}",
        )
        digests[filename] = hashlib.sha256(payload).hexdigest()
    return digests


def inventory(folder: Path) -> dict[str, str]:
    files = expected_files()
    actual = {str(path.relative_to(folder)) for path in folder.rglob("*") if path.is_file()}
    shared.require(actual - {"source.json"} == files, "incomplete or unexpected native files")
    return {name: shared.digest(shared.ordinary_file(folder, name)) for name in sorted(files)}


def trace_digests(folder: Path) -> dict[str, str]:
    """Matches the engine receipt over the CSV bytes before gzip packaging."""
    digests = {}
    for name in TRACE_NAMES:
        with gzip.open(folder / f"{name}.csv.gz", "rb") as stream:
            digests[name] = hashlib.file_digest(stream, "sha256").hexdigest()
    return digests
