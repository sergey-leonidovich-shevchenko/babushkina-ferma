"""Frozen before/after schedule: primary canonical gate plus a separate instrumented causal cohort."""

from pathlib import Path
import argparse
from datetime import datetime, timezone
import hashlib
import json
import sys
import time

ROOT = next(
    p for p in Path(__file__).resolve().parents if (p / "project.godot").is_file()
)
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(
    0,
    str(
        ROOT
        / "docs/reports/visual-overhaul/vfoliage-006/causal-investigation/instrumentation"
    ),
)
import performance_gate as gate
from causal_capture import capture as profile_capture
from redraw_observer import execute


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


META = """
func review_settings() -> Dictionary:
\treturn {"plan_sha256":"@PLAN@","display":DisplayServer.get_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"method":RenderingServer.get_current_rendering_method(),"render_loop":RenderingServer.render_loop_enabled,"max_fps":Engine.max_fps,"low_processor_usage_mode":OS.low_processor_usage_mode,"idle_sleep_usec":OS.low_processor_usage_mode_sleep_usec,"delta_smoothing":OS.delta_smoothing,"time_scale":Engine.time_scale,"physics_ticks_per_second":Engine.physics_ticks_per_second,"max_physics_steps_per_frame":Engine.max_physics_steps_per_frame,"tree_paused":get_tree().paused,"process_enabled":is_processing(),"physics_enabled":is_physics_processing(),"window_available":false,"focus":null,"vsync":null,"location":current_location,"player":[player.x,player.y],"camera":[camera_offset.x,camera_offset.y]}
"""


def light_sampler(plan_sha):
    text = (ROOT / "tools/performance_sampler.gd").read_text()
    old = "func perf_emit(value: Dictionary) -> void:\n\tprint(PREFIX, JSON.stringify(value))"
    new = (
        old
        + '\n\tif value.kind in ["ready","begin","end"]: print("REVIEW_SETTINGS ",JSON.stringify({"marker":value.kind,"settings":review_settings()}))'
    )
    assert text.count(old) == 1
    # After the canonical end marker: host snapshots CPU before child exit; no dump/timer in window.
    quit_line = "\tperf_finished = true\n\tget_tree().quit(0)"
    assert text.count(quit_line) == 1
    text = text.replace(old, new).replace(
        quit_line, "\tperf_finished = true\n\tOS.delay_msec(500)\n\tget_tree().quit(0)"
    )
    return (text + META.replace("@PLAN@", plan_sha)).encode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    plan_sha = digest(args.plan)
    assert not args.output.exists(), "fresh campaign output required"
    assert gate.revision(args.before) == plan["before_commit"]
    assert (
        gate.revision(ROOT) == plan["before_commit"]
    )  # Candidate is a declared worktree delta until final commit.
    assert digest(Path(args.godot)) == plan["engine_file_sha256"]
    for name, wanted in plan["candidate_runtime_delta"].items():
        assert (
            digest(ROOT / name) == wanted["after"]
            and digest(args.before / name) == wanted["before"]
        )
    args.output.mkdir()
    sample = args.plan.parent / "primary-sampler.gd.txt"
    assert sample.read_bytes() == light_sampler(plan_sha)
    gate.SAMPLER = sample
    frozen = {
        name: digest(Path(__file__).parent / name)
        for name in ["redraw_compare.py", "redraw_observer.py"]
    }
    manifest = {
        "plan_sha256": plan_sha,
        "start_utc": datetime.now(timezone.utc).isoformat(),
        "tools_sha256": frozen,
        "cases": [],
        "complete": False,
        "before_sources": gate.runtime_sources(args.before),
        "candidate_sources": gate.runtime_sources(ROOT),
    }
    write(args.output / "manifest.json", manifest)
    time.sleep(plan["settle_seconds"])
    for index, case in enumerate(plan["order"]):
        assert digest(args.plan) == plan_sha
        assert all(digest(Path(__file__).parent / k) == v for k, v in frozen.items())
        cohort, target, mode = case
        project = ROOT if target == "after" else args.before
        assert (
            gate.runtime_sources(project)
            == manifest["candidate_sources" if target == "after" else "before_sources"]
        )
        folder = args.output / f"{index+1:02d}-{cohort}-{target}-{mode}"
        if cohort == "primary":
            gate.execute_engine = lambda command, project, seconds: execute(
                command, project, folder, seconds
            )
            measured = gate.capture(project, folder, mode, args.godot)
        else:
            measured = profile_capture(project, folder, mode, 60, args.godot, plan_sha)[
                "measurement"
            ]
        row = {
            "folder": folder.name,
            "cohort": cohort,
            "target": target,
            "mode": mode,
            "result": measured,
        }
        manifest["cases"].append(row)
        write(args.output / "manifest.json", manifest)
        print(json.dumps(row), flush=True)
        time.sleep(plan["between_seconds"])
    manifest["complete"] = True
    manifest["end_utc"] = datetime.now(timezone.utc).isoformat()
    write(args.output / "manifest.json", manifest)


if __name__ == "__main__":
    main()
