"""Frozen serial causal campaign; all child outputs retained, no retry selection or production writes."""

from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import uuid
from causal_process import Counters, cpu_window
from causal_sampler import generate

ROOT = next(
    p for p in Path(__file__).resolve().parents if (p / "project.godot").is_file()
)
sys.path.insert(0, str(ROOT / "tools"))
from performance_gate import asset_state, power_context, revision, runtime_sources
from performance_protocol import PLAN, events, validate


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def observe(command, project, folder):
    counters = Counters()
    process = subprocess.Popen(
        command, cwd=project, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    owned = {"runner": os.getpid(), "game": process.pid}
    samples, markers, receipt, profiler = [], {}, [], {}
    stop = threading.Event()
    sample_job = None

    def monitor():
        nonlocal sample_job
        due = None
        while not stop.is_set():
            samples.append(counters.snapshot(dict(owned)))
            if "begin" in markers and due is None:
                due = markers["begin"]["host_ns"] + 500_000_000
            if due and time.monotonic_ns() >= due and not profiler:
                profiler.update(
                    {"requested_ns": time.monotonic_ns(), "target_pid": process.pid}
                )
                handle = (folder / "native-sample-launch.txt").open("wb")
                sample_job = subprocess.Popen(
                    [
                        "/usr/bin/sample",
                        str(process.pid),
                        "3",
                        "10",
                        "-file",
                        str(folder / "native-sample.txt"),
                    ],
                    stdout=handle,
                    stderr=subprocess.STDOUT,
                )
                handle.close()
                owned["sample"] = sample_job.pid
                profiler["pid"] = sample_job.pid
            if (
                sample_job
                and sample_job.poll() is not None
                and "returncode" not in profiler
            ):
                profiler.update(
                    {
                        "returncode": sample_job.returncode,
                        "finished_ns": time.monotonic_ns(),
                    }
                )
                owned.pop("sample", None)
            stop.wait(0.02)

    thread = threading.Thread(target=monitor)
    thread.start()
    timed_out = threading.Event()

    def watchdog():
        if process.poll() is None:
            timed_out.set()
            process.kill()  # Only this freshly launched, owned child.

    timer = threading.Timer(60, watchdog)
    timer.start()
    try:
        with (folder / "stdout.txt").open("wb") as raw:
            for line in process.stdout:
                received = time.monotonic_ns()
                raw.write(line)
                if line.startswith(b"PERF_CAPTURE "):
                    try:
                        row = json.loads(line[len(b"PERF_CAPTURE ") :])
                        receipt.append(
                            {
                                "host_ns": received,
                                "kind": row["kind"],
                                "game_us": row.get("time_us"),
                            }
                        )
                        if row["kind"] in ("begin", "end"):
                            markers[row["kind"]] = counters.snapshot(dict(owned))
                    except (ValueError, KeyError) as exc:
                        receipt.append({"error": repr(exc), "host_ns": received})
        code = process.wait()
    finally:
        timer.cancel()
        stop.set()
        thread.join()
        if sample_job:
            sample_job.wait(timeout=10)
            profiler.setdefault("returncode", sample_job.returncode)
    result = {
        "pid": process.pid,
        "returncode": code,
        "watchdog": timed_out.is_set(),
        "samples": samples,
        "markers": markers,
        "receipt": receipt,
        "profiler": profiler,
    }
    if set(markers) == {"begin", "end"}:
        result["cpu_window"] = cpu_window(markers["begin"], markers["end"])
    write(folder / "observer.json", result)
    return result


def capture(project, folder, mode, cap, executable, plan_sha):
    folder.mkdir()
    scene = (project / "main.tscn").read_bytes()
    before, assets = runtime_sources(project), asset_state(project)
    sampler, background, methods = generate(
        project, (ROOT / "tools/performance_sampler.gd").read_bytes(), cap, plan_sha
    )
    profile = "Codex-Performance-" + uuid.uuid4().hex
    entry = project / "tmp" / ("causal-entry-" + profile[-32:])
    entry.mkdir(parents=True)
    (entry / ".gdignore").touch()
    (entry / "sampler.gd").write_bytes(sampler)
    (entry / "background.gd").write_bytes(background)
    relative = "res://" + entry.relative_to(project).as_posix()
    replacements = {
        b"res://scripts/game.gd": (relative + "/sampler.gd").encode(),
        b"res://scripts/world_background.gd": (relative + "/background.gd").encode(),
    }
    actual = scene
    for old, new in replacements.items():
        if actual.count(old) != 1:
            raise ValueError("unexpected actual scene")
        actual = actual.replace(old, new)
    (entry / "main.tscn").write_bytes(actual)
    for name, data in [
        ("sampler.gd.txt", sampler),
        ("background.gd.txt", background),
        ("scene.tscn.txt", actual),
        ("gate-plan.json", PLAN.read_bytes()),
    ]:
        (folder / name).write_bytes(data)
    command = [
        executable,
        "--headless",
        "--path",
        str(project),
        relative + "/main.tscn",
        "--max-fps",
        str(cap),
        "--print-fps",
        "--",
        "--autoplay",
        "--perf-profile=" + profile,
        "--perf-plan=" + str(PLAN),
        "--perf-mode=" + mode,
    ]
    if mode == "f10":
        command.append("--benchmark-debug-overlay")
    expected = {
        "sampler_sha256": sha(sampler),
        "scene_sha256": sha(scene),
        "plan_sha256": sha(PLAN.read_bytes()),
    }
    context = {
        "purpose": "causal_instrumented_not_admission",
        "project": str(project),
        "revision": revision(project),
        "mode": mode,
        "cap": cap,
        "causal_plan_sha256": plan_sha,
        "expected": expected,
        "profile": profile,
        "utc": datetime.now(timezone.utc).isoformat(),
        "command": command,
        "sources": before,
        "assets": assets,
        "methods": methods,
        "power_before": power_context(),
    }
    write(folder / "context.json", context)
    observation = observe(command, project, folder)
    raw = (folder / "stdout.txt").read_bytes()
    context.update(
        {
            "returncode": observation["returncode"],
            "stdout_sha256": sha(raw),
            "power_after": power_context(),
            "sources_unchanged": before == runtime_sources(project),
            "assets_unchanged": assets == asset_state(project),
        }
    )
    try:
        if cap == 60:
            context["measurement"] = validate(
                raw, observation["returncode"], mode, expected
            )
        else:
            rows = events(raw, observation["returncode"])
            begins, ends = [r for r in rows if r["kind"] == "begin"], [
                r for r in rows if r["kind"] == "end"
            ]
            if len(begins) != 1 or len(ends) != 1 or rows[0]["cap_after"] != 0:
                raise ValueError("missing uncapped diagnostic window")
            start = begins[0]["time_us"]
            finishes = [
                r
                for r in rows
                if r["kind"] == "frame" and start < r["time_us"] < start + 10_000_000
            ]
            context["measurement"] = {
                "diagnostic_only": True,
                "window_frames": len(finishes),
                "average_fps": len(finishes) / 10,
                "budget_applicable": False,
            }
    except ValueError as exc:
        context["measurement"] = {"valid": False, "error": str(exc)}
    write(folder / "context.json", context)
    return context


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    plan_sha = sha(args.plan.read_bytes())
    if args.output.exists():
        raise ValueError("fresh campaign directory required; never overwrite attempts")
    if revision(ROOT) != plan["head"] or revision(args.base) != plan["base"]:
        raise ValueError("pinned revision differs")
    if sha(Path(args.godot).read_bytes()) != plan["engine_file_sha256"]:
        raise ValueError("engine executable differs")
    args.output.mkdir()
    source = {
        name: sha((Path(__file__).parent / name).read_bytes())
        for name in ["causal_capture.py", "causal_sampler.py", "causal_process.py"]
    }
    manifest = {
        "plan_sha256": plan_sha,
        "tool_sources": source,
        "start_utc": datetime.now(timezone.utc).isoformat(),
        "own_qa_completed": True,
        "initial_power": power_context(),
        "cases": [],
        "complete": False,
    }
    write(args.output / "manifest.json", manifest)
    (args.output / "plan.json").write_bytes(args.plan.read_bytes())
    # Fixed settle begins after imports/check-only/own QA have completed, not after observing FPS.
    time.sleep(plan["settle_seconds"])
    for index, case in enumerate(plan["order"]):
        if (
            any(
                sha((Path(__file__).parent / name).read_bytes()) != value
                for name, value in source.items()
            )
            or sha(args.plan.read_bytes()) != plan_sha
        ):
            raise ValueError("frozen plan/tools changed")
        target, mode, cap = case
        project = ROOT if target == "head" else args.base
        folder = args.output / f"{index + 1:02d}-{target}-{mode}-cap{cap}"
        value = capture(project, folder, mode, cap, args.godot, plan_sha)
        row = {
            "folder": folder.name,
            "target": target,
            "mode": mode,
            "cap": cap,
            "measurement": value["measurement"],
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
