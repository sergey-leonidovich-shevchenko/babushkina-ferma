"""Снимает нативные маски и парные тайминги в новом X11 GitHub Actions runner."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

from tools.qa.performance.overdraw import contract as c
from tools.qa.performance.overdraw.verify import check_views
from tools.qa.performance.pass_cost import collect as shared
from tools.qa.performance.pass_cost import contract as base
from tools.qa.performance.pass_cost.verify import inspect


def diagnostic(engine: Path, project: Path, output: Path, runtime: Path) -> None:
    runtime.mkdir()
    profile = f"Codex-{c.TASK}-" + uuid.uuid4().hex
    shared.override(project, profile)
    command = [
        str(engine),
        "--path",
        str(project),
        "--windowed",
        "--resolution",
        "1152x648",
        "--rendering-method",
        "gl_compatibility",
        "--audio-driver",
        "Dummy",
        "--log-file",
        str(output / "views-engine.log"),
        "--script",
        "res://" + c.DIAGNOSTIC,
        "--",
        "--output=" + str(output / "views"),
        "--profile=" + profile,
    ]
    stdout = output / "views-stdout.txt"
    with stdout.open("x") as stream:
        result = subprocess.run(
            command,
            env=shared.runner_environment(runtime),
            stdout=stream,
            stderr=subprocess.STDOUT,
            timeout=240,
            check=False,
        )
    base.write(
        output / "views-launch.json",
        {"command": command, "profile": profile, "exit_code": result.returncode},
    )
    base.require(
        result.returncode == 0 and "ERROR:" not in stdout.read_text(errors="replace"),
        "static views failed; inspect preserved stdout",
    )


def collect(path: Path) -> None:
    base.require(
        sys.platform == "linux"
        and os.getenv("GITHUB_ACTIONS") == "true"
        and bool(os.getenv("DISPLAY")),
        "native collection requires remote GitHub Actions Linux/X11",
    )
    head = base.git("rev-parse", "HEAD").decode().strip()
    base.require(head == os.getenv("VPERF_PASS_EXPECTED_HEAD"), "exact head required")
    base.require(
        not base.git("status", "--porcelain", "--untracked-files=all"), "clean source required"
    )
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    output = shared.fresh_output(path)
    version = subprocess.check_output([str(engine), "--version"], text=True).strip()
    base.require(version.startswith(shared.PINNED_ENGINE), "pinned Godot 4.7.1 required")
    (output / "engine-version.txt").write_text(version + "\n")
    source = {
        "task": c.TASK,
        "schema": 1,
        "head": head,
        "tree": base.tree(head),
        "host": shared.host(),
        "runner_id": os.getenv("GITHUB_RUN_ID"),
        "runner_attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
        "engine_sha256": base.digest(engine),
        "route_sha256": base.digest(base.ROOT / base.ROUTE),
        "schedule": c.schedule(),
        "views": c.CASES,
        "complete": False,
    }
    base.write(output / "source.json", source)
    route = base.read(base.ROOT / base.ROUTE)
    with tempfile.TemporaryDirectory(prefix="vperf-004-project-") as directory:
        runtime = Path(directory)
        project = runtime / "project"
        shared.export_project(head, project)
        shared.import_project(engine, project, runtime / "import", output, c.TASK)
        diagnostic(engine, project, output, runtime / "views")
        print(check_views(output), flush=True)
        for run, variant, seconds in c.schedule():
            work = runtime / f"{run}-{variant}"
            work.mkdir()
            target = output / run / variant
            print(f"VPERF-004 {run}/{variant} {seconds}s simulation", flush=True)
            shared.capture(
                engine, project, target, work, variant, seconds, task=c.TASK, script=c.CAPTURE
            )
            inspect(target, variant, seconds, route, version, task=c.TASK)
    source["artifacts"] = {
        name: base.digest(base.ordinary_file(output, name)) for name in sorted(c.expected_files())
    }
    source["complete"] = True
    base.write(output / "source.json", source)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    try:
        collect(parser.parse_args().output)
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
