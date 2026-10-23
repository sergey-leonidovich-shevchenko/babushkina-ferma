#!/usr/bin/env python3
"""Повреждает копии настоящего trace; missing/invalid/process и настоящая малая скорость различаются."""

from copy import deepcopy
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from performance_protocol import (
    ROOT,
    PREFIX,
    MeasurementError,
    digest,
    events,
    validate,
)
from performance_gate import capture, SAMPLER
from performance_protocol import PLAN

FIXTURE = ROOT / "tests/fixtures/performance_gate"


def encoded(rows):
    return ("\n".join(PREFIX + json.dumps(row) for row in rows) + "\n").encode()


class ProtocolTests(unittest.TestCase):
    """Эталон взят из реального normal 10-секундного опыта; игровые данные и архивы не меняются."""

    def setUp(self):
        manifest = json.loads((FIXTURE / "fixture.json").read_text())
        for name, sha in manifest["files"].items():
            self.assertEqual(digest((FIXTURE / name).read_bytes()), sha)
        self.raw = (FIXTURE / "stdout.txt").read_bytes()
        self.context = json.loads((FIXTURE / "context.json").read_text())
        self.expected = self.context["expected"]
        self.assertEqual(
            digest((FIXTURE / "sampler-source.gd.txt").read_bytes()),
            self.expected["sampler_sha256"],
        )
        self.assertEqual(
            digest((FIXTURE / "plan-copy.json").read_bytes()),
            self.expected["plan_sha256"],
        )
        self.rows = events(self.raw, 0)

    def check_invalid(self, rows=None, pattern=".*", raw=None, code=0, mode="normal"):
        with self.assertRaisesRegex(MeasurementError, pattern):
            validate(
                (
                    raw
                    if raw is not None
                    else encoded(self.rows if rows is None else rows)
                ),
                code,
                mode,
                self.expected,
            )

    def test_actual_capture_independently_recomputed(self):
        result = validate(self.raw, 0, "normal", self.expected)
        frozen = json.loads((FIXTURE / "result.json").read_text())
        self.assertEqual(result, frozen)
        self.assertEqual(result["window_frames"], 555)
        self.assertEqual(result["average_fps"], 55.5)

    def test_empty_output_is_missing_not_zero(self):
        self.check_invalid(raw=b"", pattern="missing_measurements")

    def test_legacy_fps_lines_are_not_a_valid_window(self):
        self.check_invalid(raw=b"Project FPS: 60\n", pattern="missing_measurements")

    def test_malformed_json_is_not_dropped(self):
        self.check_invalid(
            raw=self.raw + b"PERF_CAPTURE {broken}\n", pattern="invalid_protocol"
        )

    def test_duplicate_json_keys_are_corruption(self):
        self.check_invalid(
            raw=self.raw + b'PERF_CAPTURE {"kind":"frame","kind":"end"}\n',
            pattern="invalid_protocol",
        )

    def test_nonzero_exit_wins_over_good_samples(self):
        self.check_invalid(raw=self.raw, code=42, pattern="process_error: 42")

    def test_engine_error_wins_over_good_samples(self):
        self.check_invalid(
            raw=b"ERROR: failed resource\n" + self.raw, pattern="engine_error"
        )

    def test_ansi_colored_engine_error_rejects_real_good_trace(self):
        self.check_invalid(
            raw=b"\x1b[1;31mERROR:\x1b[0m failed resource\n" + self.raw,
            pattern="engine_error",
        )

    def test_indented_engine_error_rejects_real_good_trace(self):
        self.check_invalid(
            raw=b"  ERROR: failed resource\n" + self.raw, pattern="engine_error"
        )

    def test_ansi_and_indent_cannot_hide_other_existing_engine_errors(self):
        for error in [
            b"\t \x1b[31mER\x1b[0mROR: failed resource",
            b"  \x1b[1mSCRIPT ERROR:\x1b[0m failed script",
            b"  \x1b[31mParse Error\x1b[0m: failed parse",
            b"progress\r \x1b[31mERROR:\x1b[0m failed resource",
            b"\x1b]8;;https://example.invalid\x1b\\  ERROR: failed resource",
            b"\x1b]unterminated\nERROR: failed resource\n\x07",
        ]:
            with self.subTest(error=error):
                self.check_invalid(raw=error + b"\n" + self.raw, pattern="engine_error")

    def test_ansi_normalization_does_not_rewrite_protocol_records(self):
        raw = self.raw.replace(b"PERF_CAPTURE ", b"\x1b[32mPERF_CAPTURE ", 1)
        self.check_invalid(raw=raw, pattern="missing_or_duplicate_window")

    def test_benign_ansi_output_preserves_original_good_trace(self):
        raw = b"\x1b[32mINFO: capture starting\x1b[0m\n" + self.raw
        fingerprint = digest(raw)
        self.assertEqual(events(raw, 0), self.rows)
        self.assertEqual(validate(raw, 0, "normal", self.expected)["average_fps"], 55.5)
        self.assertEqual(digest(raw), fingerprint)

    def test_no_end_marker_is_incomplete(self):
        self.check_invalid(self.rows[:-1], "missing_or_duplicate_window")

    def test_missing_second_is_not_averaged_away(self):
        rows = [r for r in self.rows if not (r["kind"] == "sample" and r["index"] == 3)]
        self.check_invalid(rows, "missing_complete")

    def test_missing_callback_is_detected(self):
        del self.rows[8]
        self.check_invalid(self.rows, "missing_callbacks")

    def test_changed_clock_and_window_are_rejected(self):
        self.rows[-1]["time_us"] = self.rows[1]["time_us"] + 9_000_000
        self.check_invalid(self.rows, "window_too_short")

    def test_short_warmup_is_rejected(self):
        self.rows[0]["time_us"] = self.rows[1]["time_us"] - 1
        self.check_invalid(self.rows, "warmup_too_short")

    def test_poststartup_cap_and_actual_mode_are_required(self):
        self.rows[0]["cap_after"] = 0
        self.check_invalid(self.rows, "configuration")
        self.rows[0]["cap_after"] = 60
        self.rows[0]["debug"] = True
        self.check_invalid(self.rows, "configuration")

    def test_changed_midwindow_cap_is_rejected(self):
        self.rows[4]["cap"] = 0
        self.check_invalid(self.rows, "cap_changed")

    def test_engine_and_identity_are_fixed(self):
        self.rows[0]["engine_hash"] = "0" * 40
        self.check_invalid(self.rows, "configuration")
        self.rows[0]["engine_hash"] = self.context.get(
            "engine_hash", "a13da4feb8d8aefc283c3763d33a2f170a18d541"
        )
        self.rows[0]["scene_sha256"] = "0" * 64
        self.check_invalid(self.rows, "configuration")

    def test_original_probe_cannot_pass_the_gate(self):
        self.rows[0]["purpose"] = "original480_diagnostic"
        self.check_invalid(self.rows, "configuration")

    def test_fake_fast_sample_is_recomputed_from_callbacks(self):
        sample = next(r for r in self.rows if r["kind"] == "sample")
        sample["fps"] = 999
        self.check_invalid(self.rows, "sample_differs")

    def test_nonfinite_and_wrong_type_data_are_invalid(self):
        self.rows[3]["time_us"] = float("nan")
        self.check_invalid(self.rows, "invalid_integer")
        self.rows[3]["time_us"] = "1234"
        self.check_invalid(self.rows, "invalid_integer")

    def test_repeated_or_reordered_records_are_rejected(self):
        self.rows.insert(2, deepcopy(self.rows[0]))
        self.check_invalid(self.rows, "duplicate_window")

    def stalled_window(self, one_frame=False):
        """Логическая копия реального trace моделирует полный stall; это проверка протокола, не аппаратный опыт."""
        ready, begin, end = (
            deepcopy(self.rows[0]),
            deepcopy(self.rows[1]),
            deepcopy(self.rows[-1]),
        )
        closing = deepcopy(next(r for r in self.rows if r["kind"] == "frame"))
        closing.update(
            time_us=end["time_us"],
            frame=begin["frame"] + (2 if one_frame else 1),
            engine_frame=99999,
        )
        frames = []
        if one_frame:
            frame = deepcopy(closing)
            frame.update(
                time_us=begin["time_us"] + 500000,
                frame=begin["frame"] + 1,
                engine_frame=99998,
            )
            frames.append(frame)
        end.update(
            frame=closing["frame"], window_frames=1 if one_frame else 0, average_fps=60
        )
        samples = [deepcopy(r) for r in self.rows if r["kind"] == "sample"]
        for row in samples:
            row["frames"] = 1 if one_frame and row["index"] == 0 else 0
            row["fps"] = float(row["frames"])
        return [ready, begin, *frames, closing, *samples, end]

    def test_observed_zero_is_valid_but_fails_budget(self):
        result = validate(encoded(self.stalled_window()), 0, "normal", self.expected)
        self.assertTrue(result["valid"])
        self.assertFalse(result["budget_passed"])
        self.assertEqual(result["average_fps"], 0)
        self.assertEqual(result["status"], "budget_exceeded")

    def test_slow_intervals_are_not_censored_or_replaced_by_reported_average(self):
        result = validate(
            encoded(self.stalled_window(True)), 0, "normal", self.expected
        )
        self.assertEqual(result["samples"], [1] + [0] * 9)
        self.assertEqual(result["average_fps"], 0.1)
        self.assertFalse(result["budget_passed"])

    def test_configuration_keys_cannot_be_overridden_by_caller(self):
        with self.assertRaisesRegex(MeasurementError, "expected_identity"):
            validate(self.raw, 0, "normal", {**self.expected, "cap_after": 0})

    def test_policy_cannot_lower_budget_or_remove_repeats(self):
        """Проверяет только копию; зафиксированный план опыта остаётся неизменным."""
        from performance_protocol import policy

        for key, value in [
            ("minimum_fps", 49),
            ("repeats_per_mode", 1),
            ("minimum_valid_samples", 9),
        ]:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as temp:
                data = json.loads(PLAN.read_text())
                data[key] = value
                path = Path(temp) / "plan.json"
                path.write_text(json.dumps(data))
                with patch("performance_protocol.PLAN", path):
                    with self.assertRaisesRegex(
                        MeasurementError, "fixed performance policy"
                    ):
                        policy()


class ProcessTests(unittest.TestCase):
    """Драйвер проверяется на сбоях процесса; настоящий Godot здесь повторно не запускается."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="farm-perf-negative-")
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name) / "capture"
        mocked_power = patch(
            "performance_gate.power_context",
            return_value={"available": False, "reason": "unit fixture"},
        )
        mocked_power.start()
        self.addCleanup(mocked_power.stop)

    def run_failure(self, returned=None, error=None):
        with patch(
            "performance_gate.execute_engine", return_value=returned, side_effect=error
        ):
            return capture(ROOT, self.output, "normal", "/not-a-real-test-executable")

    def test_process_error_is_not_replaced_with_fps_zero(self):
        result = self.run_failure(
            SimpleNamespace(stdout=b"failure-output", returncode=42)
        )
        self.assertEqual((self.output / "stdout.txt").read_bytes(), b"failure-output")
        self.assertIsNone(result["average_fps"])
        self.assertIn("process_error: 42", result["status"])

    def test_colored_and_indented_errors_keep_exact_raw_bytes_and_sha(self):
        raw = (
            b"  \x1b[31mERROR:\x1b[0m failed resource\n"
            + (FIXTURE / "stdout.txt").read_bytes()
        )
        result = self.run_failure(SimpleNamespace(stdout=raw, returncode=0))
        self.assertEqual((self.output / "stdout.txt").read_bytes(), raw)
        context = json.loads((self.output / "context.json").read_text())
        self.assertEqual(context["stdout_sha256"], digest(raw))
        self.assertEqual(result["status"], "engine_error")
        self.assertIsNone(result["average_fps"])
        self.assertFalse(result["valid"])
        self.assertFalse(result["budget_passed"])

    def test_launch_error_is_preserved(self):
        result = self.run_failure(error=OSError("test launch failed"))
        self.assertIn("process_error: 127", result["status"])
        self.assertIsNone(result["average_fps"])

    def test_timeout_preserves_partial_raw_output(self):
        result = self.run_failure(
            error=subprocess.TimeoutExpired("godot", 60, output=b"partial-data")
        )
        self.assertEqual((self.output / "stdout.txt").read_bytes(), b"partial-data")
        self.assertEqual(result["status"], "process_timeout")
        self.assertIsNone(result["average_fps"])

    def test_successful_process_without_measurements_is_missing(self):
        result = self.run_failure(SimpleNamespace(stdout=b"", returncode=0))
        self.assertIn("missing_measurements", result["status"])
        self.assertFalse(result["valid"])

    def test_ready_trace_cannot_be_replayed_as_a_fast_fresh_process(self):
        """Корректные логические timestamps не заменяют реальные13сек wall time процесса."""

        def replay(command, project, seconds):
            rows = events((FIXTURE / "stdout.txt").read_bytes(), 0)
            profile = next(
                v.split("=", 1)[1] for v in command if v.startswith("--perf-profile=")
            )
            rows[0].update(
                profile=profile,
                sampler_sha256=digest(SAMPLER.read_bytes()),
                scene_sha256=digest((ROOT / "main.tscn").read_bytes()),
                plan_sha256=digest(PLAN.read_bytes()),
            )
            return SimpleNamespace(stdout=encoded(rows), returncode=0)

        with patch("performance_gate.execute_engine", side_effect=replay):
            result = capture(ROOT, self.output, "normal", "/not-a-real-test-executable")
        self.assertEqual(result["status"], "process_shorter_than_fixed_window")
        self.assertIsNone(result["average_fps"])


if __name__ == "__main__":
    unittest.main()
