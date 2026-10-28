#!/usr/bin/env python3
"""Собирает настоящую игру в фиксированном окне; каждый normal/F10 повтор обязан пройти прежний бюджет50."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import sys
import shutil
import subprocess
from common.git import git_environment
import tempfile
import time
import uuid

from performance_protocol import (
    ROOT,
    PLAN,
    MeasurementError,
    digest,
    events,
    policy,
    validate,
)

SAMPLER = ROOT / "tools/performance_sampler.gd"


def host_load() -> dict:
    """Не выдаёт недоступную метрику фона за нулевую нагрузку."""
    try:
        return {"available": True, "load_average": list(os.getloadavg())}
    except (AttributeError, OSError):
        return {"available": False, "load_average": None}


def power_context() -> dict:
    """Только читает доступное питание/thermal; виртуальный runner не выдаётся за аппаратный допуск."""
    if sys.platform != "darwin":
        return {"available": False, "reason": "platform power query not available"}
    rows = {}
    for key, option in [("power", "batt"), ("thermal", "therm")]:
        try:
            result = subprocess.run(
                ["/usr/bin/pmset", "-g", option],
                capture_output=True,
                text=True,
                timeout=3,
            )
            rows[key] = {
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
            }
        except (OSError, subprocess.TimeoutExpired) as exc:
            rows[key] = {"available": False, "error": str(exc)}
    return {"available": True, "queries": rows}


def runtime_sources(project: Path) -> dict:
    """Связывает результат с фактическим игровым кодом, а не только названием ветки."""
    files = [project / "main.tscn", project / "project.godot"]
    files += sorted((project / "scripts").rglob("*.gd"))
    return {str(p.relative_to(project)): digest(p.read_bytes()) for p in files}


def asset_state(project: Path) -> dict:
    """Фиксирует Git-дерево и точные изменённые assets без повторного хеширования всего каталога."""
    tree = subprocess.check_output(
        ["git", "rev-parse", "HEAD:assets"], cwd=project, text=True, env=git_environment()
    ).strip()
    changed = (
        subprocess.check_output(
            ["git", "diff", "HEAD", "--name-only", "-z", "--", "assets"], cwd=project, env=git_environment()
        )
        .decode("utf-8")
        .split("\0")
    )
    untracked = (
        subprocess.check_output(
            ["git", "ls-files", "--others", "--exclude-standard", "-z", "--", "assets"],
            cwd=project, env=git_environment(),
        )
        .decode("utf-8")
        .split("\0")
    )
    return {
        "git_tree_sha1": tree,
        "worktree_files": {
            name: (
                digest((project / name).read_bytes())
                if (project / name).is_file()
                else None
            )
            for name in sorted(set(changed + untracked) - {""})
        },
    }


def revision(project: Path) -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=project, text=True, env=git_environment()
    ).strip()


def execute_engine(command: list[str], project: Path, seconds: int):
    """Сохраняет реальный exit status и объединённое сырьё без shell/local, скрывающего ошибку."""
    return subprocess.run(
        command,
        cwd=project,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=seconds,
    )


def capture(
    project: Path, folder: Path, mode: str, godot: str, original: bool = False
) -> dict:
    """Исполняет точную main-сцену с единственным QA-наследником и сохраняет даже неуспешное сырьё."""
    plan = policy()
    project, folder = project.resolve(), folder.resolve()
    executable = shutil.which(godot) or str(Path(godot).resolve())
    if folder.exists():
        raise MeasurementError(
            "fresh output required; failed attempts must not be overwritten"
        )
    folder.mkdir(parents=True)
    scene = (project / "main.tscn").read_bytes()
    source_path = b'path="res://scripts/game.gd"'
    if scene.count(source_path) != 1:
        raise MeasurementError("unexpected actual scene entry")
    expected = {
        "sampler_sha256": digest(SAMPLER.read_bytes()),
        "scene_sha256": digest(scene),
        "plan_sha256": digest(PLAN.read_bytes()),
    }
    profile = "Codex-Performance-" + uuid.uuid4().hex
    before = runtime_sources(project)
    assets_before = asset_state(project)
    (project / "tmp").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="performance-entry-", dir=project / "tmp"
    ) as temp:
        entry = Path(temp)
        (entry / ".gdignore").touch()
        (entry / "sampler.gd").write_bytes(SAMPLER.read_bytes())
        (folder / "sampler-source.gd.txt").write_bytes(
            (entry / "sampler.gd").read_bytes()
        )
        (folder / "plan-copy.json").write_bytes(PLAN.read_bytes())
        relative = "res://" + (entry / "sampler.gd").relative_to(project).as_posix()
        actual_scene = scene.replace(source_path, ('path="' + relative + '"').encode())
        (entry / "main.tscn").write_bytes(actual_scene)
        (folder / "entry-scene.txt").write_bytes(actual_scene)
        command = [
            executable,
            "--headless",
            "--path",
            str(project),
            "res://" + (entry / "main.tscn").relative_to(project).as_posix(),
            "--max-fps",
            "60",
            "--print-fps",
        ]
        if original:
            command += ["--quit-after", "480"]
        command += [
            "--",
            "--autoplay",
            "--perf-profile=" + profile,
            "--perf-plan=" + str(PLAN),
            "--perf-mode=" + mode,
        ]
        if mode == "f10":
            command.append("--benchmark-debug-overlay")
        if original:
            command.append("--perf-original480")
        context = {
            "schema": 1,
            "purpose": (
                "original480_diagnostic" if original else "fixed_window_headless_gate"
            ),
            "project": str(project),
            "revision": revision(project),
            "mode": mode,
            "utc": datetime.now(timezone.utc).isoformat(),
            "profile": profile,
            "command": command,
            "expected": expected,
            "sources": before,
            "assets": assets_before,
            "engine_file_sha256": (
                digest(Path(executable).read_bytes())
                if Path(executable).is_file()
                else None
            ),
            "platform": platform.platform(),
            "machine": platform.machine(),
            "cpus": os.cpu_count(),
            "host_load_before": host_load(),
            "power_before": power_context(),
        }
        started = time.monotonic_ns()
        timed_out = False
        try:
            result = execute_engine(command, project, plan["watchdog_seconds"])
            raw, code = result.stdout, result.returncode
        except subprocess.TimeoutExpired as exc:
            raw, code, timed_out = exc.stdout or b"", -9, True
        except OSError as exc:
            raw, code = str(exc).encode("utf-8"), 127
        context.update(
            {
                "wall_elapsed_us": (time.monotonic_ns() - started) // 1000,
                "returncode": code,
                "timed_out": timed_out,
                "host_load_after": host_load(),
                "power_after": power_context(),
                "stdout_sha256": digest(raw),
                "sources_unchanged": runtime_sources(project) == before
                and asset_state(project) == assets_before,
            }
        )
        (folder / "stdout.txt").write_bytes(raw)
        (folder / "context.json").write_text(json.dumps(context, indent=2) + "\n")
    try:
        if timed_out:
            raise MeasurementError("process_timeout")
        if not context["sources_unchanged"]:
            raise MeasurementError("runtime_sources_changed_during_measurement")
        if original:
            rows = events(raw, code)
            ready = [row for row in rows if row["kind"] == "ready"]
            ends = [row for row in rows if row["kind"] == "original_end"]
            if len(ready) != 1 or len(ends) != 1:
                raise MeasurementError("missing_original_probe_markers")
            measured = {
                "purpose": "original480_diagnostic_not_gate_acceptance",
                "valid_diagnostic": True,
                "ready": ready[0],
                "end": ends[0],
                "project_fps_samples": raw.count(b"Project FPS:"),
                "wall_elapsed_us": context["wall_elapsed_us"],
            }
        else:
            measured = validate(raw, code, mode, expected)
            if measured["profile"] != profile:
                raise MeasurementError("isolated_profile_mismatch")
            if context["wall_elapsed_us"] < plan["warmup_usec"] + plan["window_usec"]:
                raise MeasurementError("process_shorter_than_fixed_window")
    except MeasurementError as exc:
        measured = {
            "mode": mode,
            "valid": False,
            "budget_passed": False,
            "average_fps": None,
            "status": str(exc),
        }
    (folder / "result.json").write_text(json.dumps(measured, indent=2) + "\n")
    return measured


def main() -> None:
    """Основной gate никогда не сокращает число режимов/повторов и не подменяет плохой результат диагностикой."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".ci/performance-gate")
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument(
        "--godot",
        default=os.environ.get(
            "FARM_GODOT_BIN", str(ROOT / "tools/Godot.app/Contents/MacOS/Godot")
        ),
    )
    parser.add_argument(
        "--single",
        choices=["normal", "f10"],
        help="diagnostic capture, never a full gate",
    )
    parser.add_argument(
        "--original",
        action="store_true",
        help="original480 timing/config diagnostic only",
    )
    args = parser.parse_args()
    plan = policy()
    if os.environ.get("FARM_MIN_FPS", "50") != "50":
        raise SystemExit("PERFORMANCE INVALID: fixed budget50 cannot be overridden")
    if args.output.exists():
        raise SystemExit("PERFORMANCE INVALID: new output directory required")
    args.output.mkdir(parents=True)
    cases = []
    for repeat in range(
        1 if args.single or args.original else plan["repeats_per_mode"]
    ):
        modes = [args.single] if args.single else ["normal", "f10"]
        if repeat % 2:
            modes.reverse()
        for mode in modes:
            folder = args.output / (str(repeat + 1) + "-" + mode)
            result = capture(args.project, folder, mode, args.godot, args.original)
            cases.append(
                {
                    "repeat": repeat + 1,
                    "mode": mode,
                    "folder": folder.name,
                    "result": result,
                }
            )
            print("PERFORMANCE RESULT: " + json.dumps(cases[-1]), flush=True)
    complete = not args.single and not args.original and len(cases) == 6
    passed = all(
        c["result"].get("valid") and c["result"].get("budget_passed") for c in cases
    )
    summary = {
        "schema": 1,
        "purpose": "full_gate" if complete else "diagnostic_not_full_gate",
        "plan_sha256": digest(PLAN.read_bytes()),
        "complete": complete,
        "budget_passed": passed if complete else False,
        "cases": cases,
    }
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    if args.original:
        raise SystemExit(
            0 if all(c["result"].get("valid_diagnostic") for c in cases) else 1
        )
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
