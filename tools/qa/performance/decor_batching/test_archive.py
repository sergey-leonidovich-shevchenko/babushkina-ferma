"""Offline archive controls. Reused VPERF-003 timing rows are never VPERF-006 measurements."""

from __future__ import annotations

import csv
import gzip
import itertools
import shutil
import tempfile
import unittest
import zipfile
from collections.abc import Callable
from pathlib import Path

from tools.qa.performance.decor_batching import native_contract as contract
from tools.qa.performance.decor_batching import native_verify as native
from tools.qa.performance.decor_batching import verify as geometry
from tools.qa.performance.decor_batching.archive_fixture import (
    BOOTSTRAP,
    PRESET,
    command,
    receipt,
    write_fixed,
)
from tools.qa.performance.pass_cost import contract as shared

HISTORICAL = shared.ROOT / "docs/reports/visual-overhaul/vperf-003/native-ci-01"
ZIP_SHA = "93e06ae81338473fffe99a2ed959896494b2edbf9cada33b635038bca6b9c2b7"


def unpack_historical(root: Path) -> Path:
    archive = root / "historical.zip"
    with archive.open("wb") as target:
        for index in range(4):
            with (HISTORICAL / f"artifact.zip.part-{index:03}").open("rb") as part:
                shutil.copyfileobj(part, target)
    if shared.digest(archive) != ZIP_SHA:
        raise ValueError("accepted VPERF-003 ZIP differs")
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(root)
    return root / "evidence"


def write_warm(root: Path, historical: Path) -> None:
    old_pass = dict(zip(geometry.VARIANTS, ("baseline", "grass", "water"), strict=True))
    batch_nodes = dict(zip(geometry.VARIANTS, (0, 1, 10), strict=True))
    for run, variant, seconds in contract.schedule():
        if not seconds:
            continue
        destination = root / run / variant
        shutil.copytree(historical / run / old_pass[variant], destination)
        data = shared.read(destination / "run.json")
        data["pass"] = "baseline"
        for phase in ("initial", "final"):
            data[phase].update(
                {key: True for key in shared.VARIANTS[1:]},
                decor=variant,
                decor_preset=PRESET,
                vsync=1,
                decor_terrain=BOOTSTRAP["after"],
            )
        shared.write(destination / "run.json", data)
        receipt(
            destination,
            data,
            variant,
            [
                *command("warm_capture.gd"),
                "--output=/archive-control",
                f"--profile={data['profile']}",
                "--pass=baseline",
                f"--seconds={seconds}",
            ],
        )
        write_cache(destination, data["first_draw"]["draw_id"])
        shared.write(
            destination / "trace-origin.json",
            {
                "pid": data["pid"],
                "profile": data["profile"],
                "batch_nodes": batch_nodes[variant],
                "raw_sha256": contract.trace_digests(destination),
                "bootstrap": BOOTSTRAP,
            },
        )


def write_cache(destination: Path, first_draw: int) -> None:
    with (
        gzip.open(destination / "frames.csv.gz", "rt", newline="") as frames,
        gzip.open(destination / "terrain-cache.csv.gz", "wt", newline="") as cache,
    ):
        draws = csv.DictReader(frames)
        writer = csv.writer(cache)
        writer.writerow(contract.CACHE_FIELDS)
        counters = tuple(BOOTSTRAP["after"][field] for field in contract.CACHE_COUNTERS)
        writer.writerow((first_draw, 1, *counters))
        writer.writerows((row["draw_id"], 1, *counters) for row in draws)


def manifest(root: Path) -> None:
    head = geometry.BASE
    shared.write(
        root / "source.json",
        {
            "task": contract.TASK,
            "complete": True,
            "head": head,
            "tree": shared.tree(head),
            "schedule": contract.schedule(),
            "renderer": contract.RENDERER,
            "inputs": contract.inputs(head),
            "engine_sha256": "0" * 64,
            "runner_id": "1",
            "runner_attempt": "1",
            "files": contract.inventory(root),
        },
    )


def rotate(root: Path) -> None:
    """Rotate the complete bundles and rewrite all old label fields."""
    parent = root / "repeat-1"
    paths = [parent / variant for variant in geometry.VARIANTS]
    extra = parent / "_rotate"
    paths[0].rename(extra)
    for previous, following in itertools.pairwise(paths):
        following.rename(previous)
    extra.rename(paths[-1])
    for folder in paths:
        run = shared.read(folder / "run.json")
        for phase in ("initial", "final"):
            run[phase]["decor"] = folder.name
        shared.write(folder / "run.json", run)
        launch = shared.read(folder / "launch.json")
        launch["variant"] = folder.name
        shared.write(folder / "launch.json", launch)


def replace_trace(root: Path) -> None:
    parent = root / "long-cycle"
    shutil.copyfile(parent / "spatial_batches/frames.csv.gz", parent / "baseline/frames.csv.gz")


def swap_fixed_for_every_variant(root: Path, first: str, second: str) -> None:
    for variant in geometry.VARIANTS:
        folder = root / "fixed" / variant
        left, right = folder / first, folder / second
        before, after = left.read_bytes(), right.read_bytes()
        if before == after:
            raise ValueError("PNG swap fixture must have distinct images")
        left.write_bytes(after)
        right.write_bytes(before)


def swap_local_terrain(root: Path) -> None:
    swap_fixed_for_every_variant(
        root, "flower_crossing_cell-terrain.png", "empty_patch-terrain.png"
    )


def swap_bench_order(root: Path) -> None:
    swap_fixed_for_every_variant(root, "bench-behind.png", "bench-ahead.png")


def replace_variant_window(root: Path) -> None:
    fixed = root / "fixed"
    shutil.copyfile(
        fixed / "one_batch/flower_crossing_cell.png", fixed / "baseline/flower_crossing_cell.png"
    )


def reuse_frame_event(root: Path) -> None:
    path = root / "fixed/baseline/fixed.json"
    data = shared.read(path)
    cases = data["cases"]
    cases["flower_crossing_cell"]["frame"]["draw_id"] = cases["full_rebuild"]["frame"]["draw_id"]
    shared.write(path, data)


def misalign_entry_cache(root: Path) -> None:
    """Add the same refresh at both boundaries so the old delta-only comparison sees no change."""
    path = root / "repeat-1/one_batch/run.json"
    run = shared.read(path)
    for phase in ("initial", "final"):
        terrain = run[phase]["decor_terrain"]
        for name in ("requests", "revision", "full_paints"):
            terrain[name] += 1
    shared.write(path, run)


def truncate(root: Path) -> None:
    folder = root / "long-cycle/baseline"
    path = folder / "frames.csv.gz"
    with gzip.open(path, "rt", newline="") as stream:
        rows = list(csv.reader(stream))
    retained = rows[:-120]
    with gzip.open(path, "wt", newline="") as stream:
        csv.writer(stream).writerows(retained)
    run = shared.read(folder / "run.json")
    run["draw_count"] = run["retained_interval_count"] = len(retained) - 1
    shared.write(folder / "run.json", run)
    origin_file = folder / "trace-origin.json"
    origin = shared.read(origin_file)
    origin["raw_sha256"] = contract.trace_digests(folder)
    shared.write(origin_file, origin)


def insert_false_cache_event(root: Path) -> None:
    path = root / "repeat-1/baseline/trace-origin.json"
    origin = shared.read(path)
    data = shared.read(path.parent / "run.json")
    origin["events"] = [
        {
            "draw_id": data["first_draw"]["draw_id"] + 2,
            "revision": data["initial"]["decor_terrain"]["revision"],
            "terrain_ready": False,
        }
    ]
    shared.write(path, origin)


def drop_cache_row(root: Path) -> None:
    folder = root / "repeat-1/baseline"
    path = folder / "terrain-cache.csv.gz"
    with gzip.open(path, "rt", newline="") as stream:
        rows = list(csv.reader(stream))
    del rows[6]
    replace_cache_trace(folder, rows)


def forge_readiness(root: Path) -> None:
    folder = root / "repeat-1/baseline"
    with gzip.open(folder / "terrain-cache.csv.gz", "rt", newline="") as stream:
        rows = list(csv.reader(stream))
    with gzip.open(folder / "frames.csv.gz", "rt", newline="") as stream:
        frames = (row for row in csv.DictReader(stream) if row["draw_id"] != rows[-1][0])
        slowest = sorted(frames, key=lambda row: float(row["interval_ms"]))
    draws = {row["draw_id"] for row in slowest[-186:]}
    for row in rows[1:]:
        if row[0] in draws:
            row[1] = "0"
    replace_cache_trace(folder, rows)


def replace_cache_trace(folder: Path, rows: list[list[str]]) -> None:
    with gzip.open(folder / "terrain-cache.csv.gz", "wt", newline="") as stream:
        csv.writer(stream).writerows(rows)
    origin_file = folder / "trace-origin.json"
    origin = shared.read(origin_file)
    origin["raw_sha256"] = contract.trace_digests(folder)
    shared.write(origin_file, origin)


class ArchiveReaderTest(unittest.TestCase):
    def test_rehashed_permutations_and_truncated_tail(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vperf006-archive-test-") as directory:
            root = Path(directory).resolve()
            historical = unpack_historical(root)
            original = root / "control"
            original.mkdir()
            for name in ("engine-version.txt", "import.txt"):
                shutil.copyfile(historical / name, original / name)
            shared.write(original / "plan.json", contract.plan())
            write_fixed(original, historical)
            write_warm(original, historical)
            manifest(original)
            report = native.verify(original, geometry.BASE)
            self.assertEqual(len(report["warm"]["runs"]["long-cycle"]), 3)
            faults: tuple[tuple[Callable[[Path], None], str], ...] = (
                (rotate, "trace capture group count differs"),
                (replace_trace, "raw trace differs from capture"),
                (misalign_entry_cache, "bootstrap did not reach the recorded cache entry"),
                (insert_false_cache_event, "unexpected fields in raw trace receipt"),
                (drop_cache_row, "terrain state must cover every native draw exactly once"),
                (forge_readiness, "warm cache readiness contradicts refresh counters"),
                (
                    swap_local_terrain,
                    "PNG bytes differ from capture: baseline/flower_crossing_cell",
                ),
                (swap_bench_order, "PNG bytes differ from capture: baseline/bench-behind"),
                (
                    replace_variant_window,
                    "PNG bytes differ from capture: baseline/flower_crossing_cell",
                ),
                (reuse_frame_event, "fixed frame events are reused or out of order"),
                (truncate, "not the final native draw"),
            )
            for tamper, reason in faults:
                with self.subTest(tamper=tamper.__name__):
                    changed = root / tamper.__name__
                    shutil.copytree(original, changed)
                    tamper(changed)
                    manifest(changed)
                    with self.assertRaisesRegex(ValueError, reason):
                        native.verify(changed, geometry.BASE)


if __name__ == "__main__":
    unittest.main()
