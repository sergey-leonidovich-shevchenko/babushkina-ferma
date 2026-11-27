"""Collect the VPERF-006 paired X11 protocol on the remote GitHub runner."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any

from tools.qa.performance.decor_batching import native_contract as contract
from tools.qa.performance.decor_batching import native_verify as reader
from tools.qa.performance.decor_batching.verify import VARIANTS
from tools.qa.performance.pass_cost import collect as shared
from tools.qa.performance.pass_cost import contract as c


def capture(
    engine: Path,
    project: Path,
    folder: Path,
    runtime: Path,
    variant: str,
    seconds: int,
    plan: Path,
) -> None:
    folder.mkdir(parents=True)
    runtime.mkdir()
    profile = "Codex-VPERF-003-" + uuid.uuid4().hex
    environment = shared.runner_environment(runtime)
    environment["VPERF006_VARIANT"] = variant
    shared.override(project, profile)
    captured = runtime / "capture"
    script = "warm_capture.gd" if seconds else "fixed_capture.gd"
    arguments = (
        [f"--output={captured}", f"--profile={profile}", "--pass=baseline", f"--seconds={seconds}"]
        if seconds
        else [str(captured), profile, str(plan)]
    )
    command = [
        str(engine),
        "--path",
        str(project),
        "--display-driver",
        "x11",
        "--windowed",
        "--resolution",
        "1152x648",
        "--rendering-method",
        "gl_compatibility",
        "--audio-driver",
        "Dummy",
        "--log-file",
        str(folder / "engine.log"),
        "--script",
        f"res://{contract.DIRECTORY}/{script}",
        "--",
        *arguments,
    ]
    samples = []
    receipt: dict[str, Any] = {
        "command": command,
        "profile": profile,
        "variant": variant,
        "timeout": False,
    }
    with (
        (folder / "stdout.txt").open("x") as stream,
        subprocess.Popen(command, env=environment, stdout=stream, stderr=subprocess.STDOUT) as proc,
    ):
        receipt["pid"] = proc.pid
        deadline = time.monotonic() + (seconds * 1.75 + 60 if seconds else 180)
        while proc.poll() is None:
            try:
                samples.append(shared.process_sample(proc.pid))
            except (ProcessLookupError, FileNotFoundError):
                break
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                receipt["timeout"] = True
                proc.kill()
                break
            try:
                proc.wait(timeout=min(5.0 if seconds else 0.25, remaining))
            except subprocess.TimeoutExpired:
                continue
        receipt["exit_code"] = proc.wait()
    c.write(folder / "launch.json", receipt)
    c.write(
        folder / "cpu-rss.json",
        {
            "clock_ticks_per_second": os.sysconf("SC_CLK_TCK"),
            "page_size": os.sysconf("SC_PAGE_SIZE"),
            "samples": samples,
        },
    )
    if captured.is_dir():
        for item in captured.iterdir():
            shutil.move(item, folder / item.name)
    for name in ("frames", "trajectory"):
        shared.compress_csv(folder / (name + ".csv"))
    stdout = (folder / "stdout.txt").read_text(errors="replace")
    c.require(
        receipt["exit_code"] == 0
        and not receipt["timeout"]
        and not any(mark in stdout for mark in ("SCRIPT ERROR", "ERROR:", "Parse Error")),
        f"capture rejected ({folder.parent.name}/{variant}):\n{stdout[-4000:]}",
    )


def collect(path: Path) -> None:
    c.require(
        sys.platform == "linux"
        and os.environ.get("GITHUB_ACTIONS") == "true"
        and bool(os.environ.get("DISPLAY")),
        "native collection requires the remote GitHub Actions Linux/X11 runner",
    )
    head = c.git("rev-parse", "HEAD").decode().strip()
    c.require(head == os.environ.get("VPERF006_EXPECTED_HEAD"), "exact head required")
    c.require(not c.git("status", "--porcelain", "--untracked-files=all"), "clean source required")
    inputs = contract.inputs(head)
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    version = subprocess.check_output([str(engine), "--version"], text=True).strip()
    c.require(version.startswith(shared.PINNED_ENGINE), "pinned Godot 4.7.1 required")
    output = shared.fresh_output(path)
    (output / "engine-version.txt").write_text(version + "\n")
    c.write(output / "plan.json", contract.plan())
    source = {
        "task": contract.TASK,
        "head": head,
        "tree": c.tree(head),
        "host": shared.host(),
        "renderer": contract.RENDERER,
        "engine_sha256": c.digest(engine),
        "runner_id": os.environ["GITHUB_RUN_ID"],
        "runner_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
        "inputs": inputs,
        "schedule": contract.schedule(),
        "complete": False,
    }
    c.write(output / "source.json", source)
    with tempfile.TemporaryDirectory(prefix="vperf-006-project-") as directory:
        temp = Path(directory)
        project = temp / "project"
        shared.export_project(head, project)
        shared.import_project(engine, project, temp / "import", output, c.TASK)
        for run, variant, seconds in contract.schedule():
            print(f"VPERF-006 {run}/{variant} ({seconds}s route)", flush=True)
            capture(
                engine,
                project,
                output / run / variant,
                temp / f"{run}-{variant}",
                variant,
                seconds,
                output / "plan.json",
            )
            if run == "fixed" and variant == VARIANTS[-1]:
                reader.fixed(output, version)
                print("VPERF-006 fixed X11 pairs passed", flush=True)
    c.write(
        output / "source.json", {**source, "files": contract.inventory(output), "complete": True}
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    try:
        collect(parser.parse_args().output)
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
