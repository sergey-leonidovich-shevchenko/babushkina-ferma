"""Пересчитывает реальные интервалы хранилищ и отделяет короткие пробы от приёмки эпика."""
import argparse
import json
from pathlib import Path
from analyze_optimization_audit import statistics

from common.paths import project_root
from common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
FOLDER = ROOT / "docs/reports/storage-perf-2026-10-14"


def inspect(report, minimum=3600):
    """Проверяет полноту, паузу, фокус, геометрию и хвосты каждого сценария, сохраняя причины отказа."""
    result=[]
    for case in report.get("cases",[]):
        values=case.get("intervals_ms",[])
        if not values:
            result.append(dict(case=case.get("case"), admission="INVALID",reasons=["no_native_frames"]))
            continue
        data=statistics(values); reasons=[]; violations=[]
        if report.get("pause_on_focus_loss", False) is not False: reasons.append("focus_pause_not_disabled")
        if report.get("status")!="COMPLETE": reasons.append("incomplete_report")
        if not report.get("gpu"): reasons.append("native_gpu_not_recorded")
        if report.get("instrumented",True): reasons.append("instrumentation_present")
        if case.get("variant")!="full": reasons.append("diagnostic_variant")
        if len(values)<minimum: reasons.append("short_run")
        if len(values)!=case.get("frames"): reasons.append("frame_count_mismatch")
        focus=case.get("focus_draws",{})
        if focus.get("focused",0)<len(values) or focus.get("unfocused",0): reasons.append("focus_not_stable")
        windows=case.get("windows",{})
        if report.get("window")!=[3584,2240] or list(windows)!=[str(tuple(report.get("window",[])))] or sum(windows.values())<len(values): reasons.append("window_not_stable")
        if case.get("simulation_minutes")!=0: reasons.append("world_not_paused")
        if case.get("actual_location")!=case.get("location"): reasons.append("location_changed")
        if data["mean_ms"]>16.9: violations.append("mean")
        if data["p95_ms"]>18.5: violations.append("p95")
        if data["p99_ms"]>25: violations.append("p99")
        if data["over33"]/len(values)>.001: violations.append("slow_frame_ratio")
        if data["over100"]: violations.append("stall_over100")
        result.append(dict(case=case["case"],repeat=case.get("repeat"),variant=case.get("variant"),
            admission="DIAGNOSTIC" if reasons else "QUALIFIED_RUN",reasons=reasons,
            budget="FAIL" if violations else "WITHIN_BUDGET",violations=violations,draw=data,
            first_present_ms=case["first_present_ms"],cpu_ms=case.get("cpu_ms",{})))
    return result


def summarize(folder=FOLDER):
    """Сохраняет сравнимые серии и контрольные варианты отдельно, не объявляя закрытыми остальные сценарии OPT."""
    result={"schema":1,"scope":"Storage rendering iteration only; matrix OPT remains open.","runs":{}}
    for path in sorted(folder.glob("*/metrics.json")):
        report=json.loads(path.read_text())
        result["runs"][path.parent.name]={"status":report.get("status"),"window":report.get("window"),
            "instrumented":report.get("instrumented",True),"gpu":report.get("gpu"),
            "openings":report.get("openings",[]),"cases":inspect(report)}
    return result


if __name__=="__main__":
    parser=argparse.ArgumentParser(); parser.add_argument("--folder",type=Path,default=FOLDER)
    args=parser.parse_args(); output=summarize(args.folder)
    (args.folder/"summary.json").write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n")
    print("STORAGE PERF: recomputed",len(output["runs"]),"reports; no automatic epic closure")
