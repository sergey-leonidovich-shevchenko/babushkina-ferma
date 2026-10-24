import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path
import unittest
from unittest.mock import patch
import redraw_observer
from redraw_compare import light_sampler


class FakeCounters:
    """Lifecycle fixture only; actual Mach counters are independently preserved in the campaign."""

    def snapshot(self, roles):
        now = time.monotonic_ns()
        return {
            "host_ns": now,
            "processes": {
                role: {
                    "pid": pid,
                    "available": True,
                    "timebase": [1, 1],
                    "cpu_ns": 0,
                    "query_begin_ns": now,
                    "query_end_ns": now + 1,
                }
                for role, pid in roles.items()
            },
        }


PROGRAM = """import json,sys,time
sys.stdout.buffer.write(b"PREFIX\\x1b[31mERROR: retained\\x1b[0m\\n");sys.stdout.flush()
print('PERF_CAPTURE '+json.dumps({'kind':'begin','time_us':1}),flush=True)
time.sleep(.02)
print('PERF_CAPTURE '+json.dumps({'kind':'end','time_us':2}),flush=True)
time.sleep(.02)
sys.exit(@CODE@)
"""


class ObserverTests(unittest.TestCase):
    def run_child(self, code, folder):
        with patch.object(redraw_observer, "Counters", FakeCounters):
            return redraw_observer.execute(
                [sys.executable, "-c", PROGRAM.replace("@CODE@", str(code))],
                Path.cwd(),
                folder,
                3,
            )

    def test_nonzero_status_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_child(7, Path(directory))
            self.assertEqual(result.returncode, 7)

    def test_raw_color_and_both_markers_survive(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            result = self.run_child(0, folder)
            self.assertIn(b"\x1b[31mERROR: retained\x1b[0m", result.stdout)
            self.assertEqual(result.stdout, (folder / "stdout.txt").read_bytes())
            observed = json.loads((folder / "observer.json").read_text())
            self.assertEqual(set(observed["markers"]), {"begin", "end"})

    def test_no_native_sampler_process(self):
        actual = subprocess.Popen
        with tempfile.TemporaryDirectory() as directory, patch.object(
            redraw_observer.subprocess, "Popen", wraps=actual
        ) as spawn:
            self.run_child(0, Path(directory))
            self.assertEqual(spawn.call_count, 1)

    def test_timeout_keeps_raw_and_explicit_failure(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(
            redraw_observer, "Counters", FakeCounters
        ):
            folder = Path(directory)
            with self.assertRaises(subprocess.TimeoutExpired) as caught:
                redraw_observer.execute(
                    [
                        sys.executable,
                        "-c",
                        'import time;print("before timeout",flush=True);time.sleep(10)',
                    ],
                    Path.cwd(),
                    folder,
                    0.2,
                )
            self.assertIn(b"before timeout", caught.exception.output)
            self.assertTrue(
                json.loads((folder / "observer.json").read_text())["watchdog"]
            )

    def test_light_sampler_has_no_method_or_stack_profiler(self):
        source = light_sampler("a" * 64)
        self.assertEqual(source.count(b"super._process(delta)"), 1)
        self.assertNotIn(b"DIAG_SPAN", source)
        self.assertNotIn(b"func _physics_process", source)

    def test_primary_cpu_hold_is_after_end_marker(self):
        source = light_sampler("a" * 64)
        self.assertLess(
            source.index(b'"kind": "end"'), source.index(b"OS.delay_msec(500)")
        )


if __name__ == "__main__":
    unittest.main()
