"""Отказы данных VPERF-003 проверяются отдельно от нативного запуска."""

from __future__ import annotations

import copy
import math
import tempfile
import unittest
from pathlib import Path
from typing import Any

from tools.qa.performance.pass_cost import contract as c
from tools.qa.performance.pass_cost import verify as reader


def frame_trace(
    intervals: list[float],
) -> tuple[list[tuple[float, ...]], dict[str, Any]]:
    start = 10_000_000
    first_draw = start + 10_000
    usec = first_draw
    rows: list[tuple[float, ...]] = []
    for index, interval in enumerate(intervals):
        usec += round(interval * 1000)
        tick = max(1, min(1800, round((usec - start) * 60 / 1e6)))
        rows.append((usec, interval, 200 + index, index + 1, tick, 30, 1024, 0, 7, 1))
    return rows, {
        "seconds": 30,
        "draw_count": len(rows),
        "retained_interval_count": len(rows),
        "sample_start_usec": start,
        "sample_end_usec": usec,
        "first_draw": {"usec": first_draw, "draw_id": 199, "process_id": 0, "physics_tick": 1},
        "final_draw": {
            "usec": usec,
            "draw_id": rows[-1][2],
            "process_id": rows[-1][3],
            "physics_tick": 1800,
        },
    }


class PassCostReaderTests(unittest.TestCase):
    def test_schedule_and_required_inputs(self) -> None:
        schedule = c.schedule()
        self.assertEqual(len(schedule), 24)
        self.assertEqual(len(set(schedule)), len(schedule))
        for run, seconds in c.RUNS:
            self.assertEqual(
                {(variant, time) for name, variant, time in schedule if name == run},
                {(variant, seconds) for variant in c.VARIANTS},
            )
        self.assertIn("long-cycle/light/frames.csv.gz", c.expected_files())
        self.assertEqual(len(c.expected_files()), 24 * len(c.RUN_FILES) + 2)

    def test_partial_package_is_rejected_before_reading_any_csv(self) -> None:
        head = c.git("rev-parse", "HEAD").decode().strip()
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)
            manifest = {
                "schema": 1,
                "task": c.TASK,
                "complete": True,
                "head": head,
                "tree": c.tree(head),
                "schedule": c.schedule(),
                "engine_sha256": "0" * 64,
                "artifacts": {},
                "route_sha256": c.digest(c.ROOT / c.ROUTE),
            }
            c.write(path / "source.json", manifest)
            with self.assertRaisesRegex(ValueError, "raw file set"):
                reader.verify(path, head)
            manifest["schedule"] = c.schedule()[:-1]
            c.write(path / "source.json", manifest)
            with self.assertRaisesRegex(ValueError, "complete source"):
                reader.verify(path, head)

    def test_complete_ticks_and_camera_are_checked_independently(self) -> None:
        route = c.read(c.ROOT / c.ROUTE)
        rows: list[tuple[float, ...]] = []
        position = route["route_start"]
        target = 0
        checkpoints = []
        for tick in range(1, 1801):
            goal = route["route_targets"][target]
            amount = min(1.0, 3.0 / max(math.dist(position, goal), 1))
            x, y = (base + (end - base) * amount for base, end in zip(position, goal, strict=True))
            camera = (max(0.0, min(x - 480, 1440)), max(0.0, min(y - 270, 828)))
            rows.append((tick, target, x, y, *camera, 1200 + tick / 60))
            position = (x, y)
            if math.dist(position, goal) <= 4:
                checkpoints.append([tick, target, [x, y], list(camera)])
                target = (target + 1) % 16
        metadata = {
            "seconds": 30,
            "tick_count": 1800,
            "checkpoints": checkpoints,
            "route_start_end": len(checkpoints) // 16,
        }
        reader.check_trajectory(rows, metadata, route)
        changed = rows.copy()
        changed[400] = (*changed[400][:4], changed[400][4] + 0.5, *changed[400][5:])
        with self.assertRaisesRegex(ValueError, "camera changed"):
            reader.check_trajectory(changed, metadata, route)
        with self.assertRaisesRegex(ValueError, "missing tick"):
            reader.check_trajectory(rows[:-1], metadata, route)

    def test_slow_frame_is_retained_and_missing_draw_rejected(self) -> None:
        rows, meta = frame_trace([29.59] * 1000 + [400.0])
        actual = reader.frames_summary(rows, meta)
        self.assertEqual(actual["frame_interval_ms"]["max"], 400.0)
        self.assertEqual(actual["intervals_over_33_4_ms"], 1)
        rows[500] = (*rows[500][:2], rows[500][2] + 1, *rows[500][3:])
        with self.assertRaisesRegex(ValueError, "out of order"):
            reader.frames_summary(rows, meta)

    def test_contiguous_prefix_cannot_discard_the_slow_tail_of_a_run(self) -> None:
        rows, metadata = frame_trace([20.0] * 350 + [229.0] * 99 + [319.0])
        complete = reader.frames_summary(rows, metadata)
        self.assertEqual(complete["frame_interval_ms"]["max"], 319.0)
        self.assertEqual(complete["frame_interval_ms"]["p95"], 229.0)
        self.assertEqual(complete["intervals_over_33_4_ms"], 100)
        prefix = rows[:350]
        self.assertEqual((prefix[-1][0] - metadata["sample_start_usec"]) / 1e6, 7.01)
        shortened = {**metadata, "draw_count": len(prefix), "retained_interval_count": len(prefix)}
        with self.assertRaisesRegex(ValueError, "not the final native draw"):
            reader.frames_summary(prefix, shortened)
        for field in metadata["final_draw"]:
            damaged = copy.deepcopy(metadata)
            damaged["final_draw"][field] += 1
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(ValueError, "not the final native draw"),
            ):
                reader.frames_summary(rows, damaged)

    def test_renderer_camera_must_derive_from_the_same_physical_route(self) -> None:
        start = (600.0, 555.0)
        route = [(1.0, 0.0, 602.0, 555.0), (2.0, 0.0, 602.0, 558.0)]
        frame = (0.0,) * 4 + (2.0,) + (0.0,) * 5
        ground = (602.0, 556.5)
        camera = reader.projected_camera(*ground)
        reader.check_render_camera([frame + ground + camera], route, start)
        with self.assertRaisesRegex(ValueError, "camera differs"):
            reader.check_render_camera([frame + ground + (camera[0] + 1, camera[1])], route, start)
        with self.assertRaisesRegex(ValueError, "rendered route differs"):
            reader.check_render_camera([frame + (600.0, 556.5) + camera], route, start)

    def test_cpu_and_rss_are_calculated_from_external_kernel_counters(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            file = Path(root) / "cpu-rss.json"
            samples = [
                {
                    "utc_ns": i * 10**9,
                    "user_ticks": i * 95,
                    "system_ticks": i * 5,
                    "resident_pages": 128 + i,
                }
                for i in range(0, 40, 5)
            ]
            data = {"clock_ticks_per_second": 100, "page_size": 4096, "samples": samples}
            c.write(file, data)
            actual = reader.cpu_and_rss(file, 0.0, 30.0)
            self.assertEqual(actual["mean_cpu_cores"], 1.0)
            self.assertEqual(actual["rss_bytes"]["max"], 153 * 4096)
            samples[4]["user_ticks"] = 0
            c.write(file, data)
            with self.assertRaisesRegex(ValueError, "went backwards"):
                reader.cpu_and_rss(file, 0.0, 30.0)

    def test_pair_rejects_save_or_camera_differences(self) -> None:
        baseline: dict[str, Any] = {
            "simulation": {"trajectory.csv.gz": "a1", "save-after.json": "b1"},
            "frame_interval_ms": dict.fromkeys(("p50", "p95", "p99", "max"), 25.0),
            "draw_calls": {"p50": 20},
            "process": {
                "mean_cpu_cores": 1.0,
                "rss_bytes": {"max": 4096},
            },
        }
        candidate = copy.deepcopy(baseline)
        candidate["frame_interval_ms"]["p95"] = 23.0
        observed = reader.deltas(baseline, candidate)
        self.assertEqual(observed["frame_interval_ms"]["p95"], 2.0)
        self.assertIsNone(observed["gpu_time_ms"])
        for file in baseline["simulation"]:
            candidate = copy.deepcopy(baseline)
            candidate["simulation"][file] = "c1"
            with self.assertRaisesRegex(ValueError, "drifted"):
                reader.deltas(baseline, candidate)


if __name__ == "__main__":
    unittest.main()
