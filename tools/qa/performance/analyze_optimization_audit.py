"""Читает сырые нативные кадры; никогда не принимает средний headless FPS за доказательство плавности."""
import argparse
import json
import math
from pathlib import Path

from tools.common.paths import project_root
from tools.common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
FOLDER = ROOT / "docs/reports/optimization-audit-2026-10-14"


def statistics(values):
    """Считает хвост задержек и сохраняет одиночные зависания в результате."""
    if not values or any(not isinstance(x, (int, float)) or not math.isfinite(x) or x <= 0 for x in values):
        raise ValueError("Expected positive finite native draw intervals")
    ordered = sorted(values)
    return dict(count=len(values), mean_ms=sum(values)/len(values),
                p95_ms=ordered[math.floor((len(values)-1)*.95)],
                p99_ms=ordered[math.floor((len(values)-1)*.99)], max_ms=max(values),
                over33=sum(x > 33.333 for x in values), over100=sum(x > 100 for x in values))


def analyze_native(data, expected_size=(3584, 2240), minimum_samples=3600):
    """Разделяет нарушение бюджета и пригодность прогона для приёмки оптимизации."""
    reasons = []
    if data.get("pause_on_focus_loss", False) is not False:
        reasons.append("focus_pause_not_disabled")
    values = data.get("draw_intervals_ms", [])
    if not values or data.get("display_server") == "headless":
        return dict(admission="INVALID", reasons=["missing_native_draw_samples"], budget="UNMEASURED")
    stats = statistics(values)
    if stats["count"] < minimum_samples:
        reasons.append("short_run")
    boss = "phase" in data and "peak_minions" in data
    if boss:
        if data.get("peak_minions") != 4 or len(data.get("attacks", [])) != 4:
            reasons.append("incomplete_boss_load")
    elif not data.get("route_finished"):
        reasons.append("unfinished_route")
    actual_size = data.get("display_window_size", data.get("window_size", []))
    if tuple(actual_size) != expected_size:
        reasons.append("wrong_window_size")
    focus = data.get("audit_focus_draws")
    if not focus:
        reasons.append("focus_not_tracked_per_draw")
    elif focus.get("unfocused", 0) or focus.get("focused", 0) < stats["count"]:
        reasons.append("unfocused_draws")
    if len(data.get("audit_windows", {})) != 1:
        reasons.append("window_stability_not_confirmed")
    if data.get("audit_instrumented", "cpu_samples" in data):
        reasons.append("instrumentation_present")
    if not data.get("user_saves_unchanged"):
        reasons.append("test_save_fingerprint_failed")
    limit = 20 if data.get("mode") == "f10" else 18.5
    violations = []
    if stats["p95_ms"] > limit:
        violations.append("p95")
    if stats["p99_ms"] > 25:
        violations.append("p99")
    if stats["over33"]/stats["count"] > .001:
        violations.append("slow_frame_ratio")
    if stats["over100"]:
        violations.append("stall_over100")
    return dict(admission="DIAGNOSTIC" if reasons else "ACCEPTABLE_RUN", reasons=reasons,
                budget="FAIL" if violations else "WITHIN_BUDGET", violations=violations, draw=stats,
                expected_size=list(expected_size), actual_size=actual_size,
                note="Acceptance still requires three comparable repeats and functional checks.")


def summarize(folder=FOLDER):
    """Собирает компактную сводку, не перезаписывая первичные нативные записи."""
    native = {}
    for path in sorted((folder / "native").rglob("*.json")):
        data = json.loads(path.read_text())
        if "draw_intervals_ms" in data:
            native[str(path.relative_to(folder))] = analyze_native(data)
    sweeps = {}
    for path in sorted(folder.glob("sweep*/metrics.json")):
        data = json.loads(path.read_text())
        rows = []
        for case in data["cases"]:
            rows.append(dict(case=case["case"], location=case["location"], actual_location=case["actual_location"],
                             first_ms=case["first_present_ms"], command_ms=case["command_ms"],
                             draw=statistics(case["intervals_ms"]), cpu_ms=case["cpu_ms"],
                             simulation_minutes=case["simulation_minutes"]))
        sweeps[str(path.relative_to(folder))] = dict(window=data["window"], focused_at_finish=data["focused"],
            startup_load_ms=data["scene_load_ms"], startup_ready_ms=data["instantiate_ready_ms"],
            warmup=data["after_warmup"], end=data["after_sweep"], cases=rows,
            note="Short instrumented smoke per state, not completed 320-case acceptance; safe direct placement is not an actual doorway transition.")
    context_path = folder/"context.json"
    context = json.loads(context_path.read_text()) if context_path.exists() else {"baseline_revision":"unrecorded"}
    result = dict(schema=1, context=context, native=native, sweeps=sweeps)
    (folder / "summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--folder", type=Path, default=FOLDER)
    result = summarize(parser.parse_args().folder)
    print(json.dumps({"native_runs":len(result["native"]), "sweeps":len(result["sweeps"])}, ensure_ascii=False))
