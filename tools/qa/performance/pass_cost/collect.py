"""Собирает реплики VPERF-003 в отдельном Linux/X11 runner с программным GL."""

from __future__ import annotations

import argparse
import gzip
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.performance.pass_cost import contract as c
from tools.qa.performance.pass_cost.verify import deltas, inspect

PINNED_ENGINE = "4.7.1.stable.official"


def fresh_output(path: Path) -> Path:
    output = path.absolute()
    c.require(
        output.resolve() == output
        and not output.exists()
        and output.parent.is_dir()
        and output != c.ROOT
        and c.ROOT not in output.parents,
        "fresh external output with existing parent required",
    )
    output.mkdir()
    return output


def runner_environment(folder: Path) -> dict[str, str]:
    environment = git_environment()
    for suffix in ("DATA", "CONFIG", "CACHE"):
        path = folder / suffix.lower()
        path.mkdir()
        environment[f"XDG_{suffix}_HOME"] = str(path)
    environment["LIBGL_ALWAYS_SOFTWARE"] = "1"
    return environment


def export_project(head: str, project: Path) -> None:
    """Разворачивает полное дерево Git без рабочего индекса, пользовательских файлов и патчей."""
    project.mkdir()
    with subprocess.Popen(
        ["git", "--no-replace-objects", "-C", str(c.ROOT), "archive", head],
        stdout=subprocess.PIPE,
        env=git_environment(),
    ) as archive:
        assert archive.stdout is not None
        result = subprocess.run(
            ["tar", "-xf", "-", "-C", str(project)],
            stdin=archive.stdout,
            check=False,
        )
        archive.stdout.close()
        c.require(result.returncode == 0 and archive.wait() == 0, "Git export failed")


def override(project: Path, profile: str) -> None:
    (project / "override.cfg").write_text(
        f'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="{profile}"\n'
    )


def process_sample(pid: int) -> dict[str, int]:
    """Сохраняет показатели процесса Linux по тикам CPU и резидентным страницам ядра."""
    observed = time.time_ns()
    suffix = Path(f"/proc/{pid}/stat").read_text().rsplit(") ", 1)[1].split()
    return {
        "utc_ns": observed,
        "user_ticks": int(suffix[11]),
        "system_ticks": int(suffix[12]),
        "resident_pages": int(suffix[21]),
    }


def host() -> dict[str, Any]:
    cpu = next(
        (
            line.partition(":")[2].strip()
            for line in Path("/proc/cpuinfo").read_text().splitlines()
            if line.startswith("model name")
        ),
        platform.processor(),
    )
    pages = os.sysconf("SC_PHYS_PAGES")
    page_size = os.sysconf("SC_PAGE_SIZE")
    return {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "cpu_model": cpu,
        "logical_cpu_count": os.cpu_count(),
        "ram_bytes": pages * page_size,
    }


def compress_csv(path: Path) -> None:
    if path.is_file():
        with (
            path.open("rb") as source,
            path.with_suffix(".csv.gz").open("xb") as packed,
            gzip.GzipFile(filename="", mode="wb", fileobj=packed, mtime=0) as target,
        ):
            shutil.copyfileobj(source, target)
        path.unlink()


def capture(
    engine: Path,
    project: Path,
    target: Path,
    runtime: Path,
    variant: str,
    seconds: int,
    *,
    task: str = c.TASK,
    script: str = c.CAPTURE,
) -> None:
    """Запускает ровно один процесс и сохраняет сырые выводы, включая отказы и тайм-ауты."""
    target.parent.mkdir(parents=True, exist_ok=True)
    target.mkdir()
    profile = f"Codex-{task}-" + uuid.uuid4().hex
    environment = runner_environment(runtime)
    override(project, profile)
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
        str(target / "engine.log"),
        "--script",
        "res://" + script,
        "--",
        "--output=" + str(runtime / "capture"),
        "--profile=" + profile,
        "--pass=" + variant,
        "--seconds=" + str(seconds),
    ]
    samples = []
    receipt: dict[str, Any] = {"command": command, "profile": profile, "timeout": False}
    with (target / "stdout.txt").open("x") as stream:
        with subprocess.Popen(
            command,
            env=environment,
            stdout=stream,
            stderr=subprocess.STDOUT,
        ) as process:
            receipt["pid"] = process.pid
            deadline = time.monotonic() + seconds * 1.75 + 60
            while process.poll() is None:
                try:
                    samples.append(process_sample(process.pid))
                except ProcessLookupError:
                    break
                except FileNotFoundError:
                    break
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    receipt["timeout"] = True
                    process.kill()
                    break
                try:
                    process.wait(timeout=min(5.0, remaining))
                except subprocess.TimeoutExpired:
                    continue
            receipt["exit_code"] = process.wait()
    c.write(target / "launch.json", receipt)
    c.write(
        target / "cpu-rss.json",
        {
            "clock_ticks_per_second": os.sysconf("SC_CLK_TCK"),
            "page_size": os.sysconf("SC_PAGE_SIZE"),
            "samples": samples,
        },
    )
    captured = runtime / "capture"
    if captured.is_dir():
        for path in captured.iterdir():
            shutil.move(path, target / path.name)
    for name in ("frames", "trajectory"):
        compress_csv(target / (name + ".csv"))
    output = (target / "stdout.txt").read_text(errors="replace")
    c.require(
        receipt["exit_code"] == 0
        and not receipt["timeout"]
        and not any(mark in output for mark in ("SCRIPT ERROR", "ERROR:", "Parse Error")),
        f"capture rejected: {target.parent.name}/{variant}",
    )


def collect(path: Path) -> None:
    c.require(
        sys.platform == "linux"
        and os.environ.get("GITHUB_ACTIONS") == "true"
        and bool(os.environ.get("DISPLAY")),
        "native collection requires remote GitHub Actions Linux/X11",
    )
    head = c.git("rev-parse", "HEAD").decode().strip()
    c.require(head == os.environ.get("VPERF_PASS_EXPECTED_HEAD"), "exact head required")
    c.require(not c.git("status", "--porcelain", "--untracked-files=all"), "clean source required")
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    output = fresh_output(path)
    version = subprocess.check_output([str(engine), "--version"], text=True).strip()
    c.require(version.startswith(PINNED_ENGINE), "pinned Godot 4.7.1 required")
    (output / "engine-version.txt").write_text(version + "\n")
    source: dict[str, Any] = {
        "schema": 1,
        "task": c.TASK,
        "head": head,
        "tree": c.tree(head),
        "host": host(),
        "renderer": "X11 / Mesa llvmpipe (software GL)",
        "engine_sha256": c.digest(engine),
        "runner_id": os.environ.get("GITHUB_RUN_ID"),
        "runner_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "route_sha256": c.digest(c.ROOT / c.ROUTE),
        "schedule": c.schedule(),
        "complete": False,
    }
    c.write(output / "source.json", source)
    route = c.read(c.ROOT / c.ROUTE)
    inspected: dict[str, dict[str, Any]] = {}
    with tempfile.TemporaryDirectory(prefix="vperf-003-project-") as directory:
        temporary = Path(directory)
        project = temporary / "project"
        export_project(head, project)
        import_project(engine, project, temporary / "import", output, c.TASK)
        for run, variant, seconds in c.schedule():
            runtime = temporary / (run + "-" + variant)
            runtime.mkdir()
            print(f"VPERF-003 {run}/{variant} {seconds}s simulation", flush=True)
            target = output / run / variant
            capture(engine, project, target, runtime, variant, seconds)
            _, metrics = inspect(target, variant, seconds, route, version)
            runs = inspected.setdefault(run, {})
            runs[variant] = metrics
            if "baseline" in runs:
                for name, stats in runs.items():
                    if name != "baseline":
                        deltas(runs["baseline"], stats)
    source["artifacts"] = {
        name: c.digest(c.ordinary_file(output, name)) for name in sorted(c.expected_files())
    }
    source["complete"] = True
    c.write(output / "source.json", source)


def import_project(engine: Path, project: Path, importing: Path, output: Path, task: str) -> None:
    """Импортирует ресурсы исходного дерева в новом профиле до измерений."""
    importing.mkdir()
    environment = runner_environment(importing)
    override(project, f"Codex-{task}-" + uuid.uuid4().hex)
    with (output / "import.txt").open("x") as stream:
        subprocess.run(
            [
                str(engine),
                "--headless",
                "--path",
                str(project),
                "--editor",
                "--quit",
                "--log-file",
                str(importing / "godot.log"),
            ],
            env=environment,
            stdout=stream,
            stderr=subprocess.STDOUT,
            timeout=600,
            check=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    try:
        collect(parser.parse_args().output)
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
