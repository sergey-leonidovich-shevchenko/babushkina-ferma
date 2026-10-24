import unittest
from pathlib import Path
from causal_process import Usage, ticks_ns, cpu_window
from causal_sampler import generate
import ctypes

ROOT = next(
    p for p in Path(__file__).resolve().parents if (p / "project.godot").is_file()
)


def snapshot(cpu=0, pid=10, start=100, stop=110, available=True):
    return {
        "processes": {
            "game": {
                "cpu_ns": cpu,
                "pid": pid,
                "timebase": [125, 3],
                "query_begin_ns": start,
                "query_end_ns": stop,
                "available": available,
            }
        }
    }


class CounterTests(unittest.TestCase):
    def test_native_layout_matches_public_v2_header(self):
        self.assertEqual(ctypes.sizeof(Usage), 160)
        self.assertEqual(Usage.user.offset, 16)
        self.assertEqual(Usage.disk_write.offset, 152)

    def test_nonidentity_mach_timebase(self):
        self.assertEqual(ticks_ns(9, 125, 3), 375)
        self.assertEqual(ticks_ns(10, 125, 3), 416)

    def test_invalid_timebase(self):
        for args in [(1, 1, 0), (1, 0, 1), (-1, 1, 1)]:
            with self.assertRaises(ValueError):
                ticks_ns(*args)

    def test_cpu_is_not_clamped_to_wall(self):
        row = cpu_window(snapshot(), snapshot(cpu=400, start=200, stop=210))
        self.assertEqual(row["wall_bounds_ns"], [90, 110])
        self.assertGreater(row["cpu_to_wall_bounds"][0], 1)

    def test_missing_is_not_zero(self):
        self.assertEqual(
            cpu_window(snapshot(available=False), snapshot(start=200)),
            {"available": False},
        )

    def test_changed_process_rejected(self):
        with self.assertRaises(ValueError):
            cpu_window(snapshot(), snapshot(pid=20, start=200))

    def test_nonmonotonic_rejected(self):
        with self.assertRaises(ValueError):
            cpu_window(snapshot(cpu=10), snapshot(cpu=0, start=200))


class GeneratorTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / "tools/performance_sampler.gd").read_bytes()

    def test_actual_super_called_once(self):
        text, background, methods = generate(ROOT, self.source, 60, "a" * 64)
        self.assertEqual(text.count(b"super._process(delta)"), 1)
        self.assertEqual(text.count(b"super._physics_process(delta)"), 1)
        self.assertEqual(background.count(b"super._draw()"), 1)
        self.assertIn("draw_ui", methods["draw_methods"])

    def test_cpu_boundary_precedes_dump(self):
        text = generate(ROOT, self.source, 60, "a" * 64)[0].decode()
        self.assertLess(text.index('"kind": "end"'), text.index("\tdiag_flush()"))
        self.assertIn("OS.delay_msec(500)", text)

    def test_caps_distinct(self):
        cap60 = generate(ROOT, self.source, 60, "a" * 64)[0]
        cap0 = generate(ROOT, self.source, 0, "a" * 64)[0]
        self.assertIn(b'"fixed_window_headless_gate"', cap60)
        self.assertNotIn(b'"fixed_window_headless_gate"', cap0)
        self.assertIn(b"causal_uncapped_diagnostic", cap0)

    def test_source_mismatch_rejected(self):
        with self.assertRaises(ValueError):
            generate(
                ROOT,
                self.source.replace(b"Engine.max_fps = 60", b"Engine.max_fps = 61"),
                60,
                "a" * 64,
            )

    def test_unplanned_cap_rejected(self):
        with self.assertRaises(ValueError):
            generate(ROOT, self.source, 120, "a" * 64)

    def test_canonical_remains_unchanged(self):
        generate(ROOT, self.source, 0, "a" * 64)
        self.assertEqual(
            self.source, (ROOT / "tools/performance_sampler.gd").read_bytes()
        )


if __name__ == "__main__":
    unittest.main()
