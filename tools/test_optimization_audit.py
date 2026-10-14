"""Поведенческие проверки измерителя, генератора матрицы и статического графа ресурсов."""
import json
import struct
import tempfile
import unittest
from pathlib import Path

from analyze_optimization_audit import analyze_native, statistics
from build_optimization_matrix import build_rows, write_artifacts
from optimization_asset_audit import audit


class OptimizationAuditTest(unittest.TestCase):
    def native(self):
        """Возвращает малую известную трассу с полным контекстом принятого стенда."""
        return dict(draw_intervals_ms=[16, 17, 18], mode="normal", route_finished=True,
                    window_size=[3584, 2240], audit_focus_draws=dict(focused=3, unfocused=0),
                    audit_windows={"(3584, 2240)":3}, audit_instrumented=False, user_saves_unchanged=True)

    def test_single_stall_is_never_hidden_by_average(self):
        data = self.native(); data["draw_intervals_ms"] = [16]*1000+[1200]
        result = analyze_native(data)
        self.assertEqual(result["budget"], "FAIL")
        self.assertIn("stall_over100", result["violations"])
        self.assertEqual(result["draw"]["max_ms"], 1200)

    def test_context_rejects_false_acceptance(self):
        for field, value, reason in [("route_finished",False,"unfinished_route"),
             ("window_size",[1152,648],"wrong_window_size"),
             ("audit_focus_draws",dict(focused=2,unfocused=1),"unfocused_draws"),
             ("audit_instrumented",True,"instrumentation_present"),
             ("user_saves_unchanged",False,"test_save_fingerprint_failed")]:
            with self.subTest(field=field):
                data = self.native(); data[field] = value
                self.assertIn(reason, analyze_native(data, minimum_samples=3)["reasons"])

    def test_process_frames_and_headless_are_not_rendered_frames(self):
        self.assertEqual(analyze_native(dict(frame_intervals_ms=[16]*4000))["admission"], "INVALID")
        data = self.native(); data["display_server"] = "headless"
        self.assertEqual(analyze_native(data)["admission"], "INVALID")

    def test_short_and_untracked_runs_are_diagnostic(self):
        data = self.native(); data.pop("audit_focus_draws")
        result = analyze_native(data)
        self.assertEqual(result["admission"], "DIAGNOSTIC")
        self.assertIn("short_run", result["reasons"])
        self.assertIn("focus_not_tracked_per_draw", result["reasons"])

    def test_known_percentiles_and_invalid_samples(self):
        result = statistics(list(range(1,101)))
        self.assertEqual((result["p95_ms"],result["p99_ms"],result["max_ms"]),(95,99,100))
        for invalid in [[],[0],[float("nan")],[-1]]:
            with self.assertRaises(ValueError): statistics(invalid)

    def test_sufficient_known_run_can_be_accepted_but_not_entire_epic(self):
        result = analyze_native(self.native(),minimum_samples=3)
        self.assertEqual(result["admission"], "ACCEPTABLE_RUN")
        self.assertEqual(result["budget"], "WITHIN_BUDGET")
        self.assertIn("three", result["note"])

    def test_matrix_is_unique_specific_and_explicitly_unexecuted(self):
        rows = build_rows()
        self.assertEqual(len(rows), 320)
        self.assertEqual(len({x["id"] for x in rows}), 320)
        self.assertEqual(len({x["procedure"] for x in rows}), 320)
        self.assertEqual({x["status"] for x in rows}, {"PLANNED"})
        for row in rows:
            self.assertTrue(row["ticket"].startswith("OPT-"))
            self.assertTrue(row["metric"] and row["expected"] and row["protocol"])

    def test_generated_artifacts_match_the_matrix(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp); rows = write_artifacts(folder)
            self.assertEqual(json.loads((folder/"checks.json").read_text()), rows)
            self.assertIn("PERF-20-16", (folder/"index.html").read_text())
            self.assertEqual(len((folder/"checks.csv").read_text(encoding="utf-8-sig").splitlines()),321)
            committed = Path(__file__).resolve().parents[1]/"docs/epics/optimization-2026-10"
            for name in ["checks.json", "checks.csv", "index.html"]:
                self.assertEqual((folder/name).read_bytes(), (committed/name).read_bytes())
            epic = (committed/"README.md").read_text()
            for ticket in {row["ticket"] for row in rows}:
                self.assertIn("### "+ticket+" ·", epic)

    def test_static_graph_counts_shared_preload_once_and_skips_dynamic_load(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/"main.tscn").write_text('[ext_resource path="res://game.gd"]')
            (root/"game.gd").write_text('const A=preload("res://a.png")\nconst B=preload("res://a.png")\nvar x=load("res://absent.png")\nvar path="res://%s.png"')
            (root/"a.png").write_bytes(b"\x89PNG\r\n\x1a\n"+b"\0"*8+struct.pack(">II",64,160))
            result = audit(root)
            self.assertEqual(result["texture_count"],1)
            self.assertEqual(result["rgba8_estimate"],64*160*4)


if __name__ == "__main__":
    unittest.main()
