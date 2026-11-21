"""Снимает baseline/candidate в новых Git-экспортах только на удалённом Linux X11."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.world.weather import contract as c


def write(path: Path, value: Any) -> None:
    """Обновляет только собственный незавершённый manifest; PNG и журналы не перезаписываются."""
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def execute(engine: Path, project: Path, args: list[str], log: Path) -> None:
    """Перед каждым дочерним запуском проверяет реальный свободный слот и сохраняет exit/log."""
    rows = subprocess.check_output(["ps", "-axo", "comm="], text=True).splitlines()
    c.need(
        not any(Path(row.strip()).name.lower().startswith("godot") for row in rows),
        "busy Godot slot",
    )
    c.need(not log.exists(), "fresh log required")
    command = [str(engine), "--path", str(project), *args]
    receipt: dict[str, Any] = {"command": command, "complete": False}
    write(log.with_suffix(".launch.json"), receipt)
    with log.open("x") as stream:
        run = subprocess.run(
            command,
            env=git_environment(),
            stdout=stream,
            stderr=subprocess.STDOUT,
            timeout=900,
            check=False,
        )
    receipt.update(complete=True, exit_code=run.returncode)
    write(log.with_suffix(".launch.json"), receipt)
    text = log.read_text(errors="replace")
    c.need(
        run.returncode == 0
        and not any(mark in text for mark in ("SCRIPT ERROR", "ERROR:", "Parse Error")),
        "engine failure: " + str(log),
    )


def profile(engine: Path, project: Path, log: Path) -> str:
    """Проверяет OS userdata до импорта и каждого native run, не используя обычные слоты."""
    name = "Codex-VWEATHER-001-" + uuid.uuid4().hex
    (project / "override.cfg").write_text(
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'
        + name
        + '"\n'
    )
    execute(
        engine,
        project,
        ["--headless", "--script", "res://" + c.PREFIX + "profile.gd", "--", name],
        log,
    )
    c.need(log.read_text().rstrip().endswith("/" + name), "effective profile differs")
    return name


def variant(folder: Path, engine: Path, commit: str, inputs: dict[str, bytes]) -> dict[str, Any]:
    """Production экспортируется из Git без инструментальных замен renderer или часов."""
    folder.mkdir()
    project = folder / "project"
    project.mkdir()
    archive = folder / "source.tar"
    with archive.open("xb") as stream:
        subprocess.run(
            ["git", "--no-replace-objects", "-C", str(c.ROOT), "archive", commit],
            env=git_environment(),
            stdout=stream,
            check=True,
        )
    subprocess.run(["tar", "-xf", str(archive), "-C", str(project)], check=True)
    archive.unlink()
    for name, raw in inputs.items():
        destination = project / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
    expected = c.blobs(commit)
    c.check_export(project, expected)
    profile(engine, project, folder / "import-profile.txt")
    execute(engine, project, ["--headless", "--editor", "--quit"], folder / "import.txt")
    execute(
        engine,
        project,
        ["--headless", "--check-only", "--script", "res://" + c.PREFIX + "capture.gd"],
        folder / "compile.txt",
    )
    runs = {}
    for width in c.WIDTHS:
        name = profile(engine, project, folder / f"{width}-profile.txt")
        args = [
            "--windowed",
            "--resolution",
            f"{width}x{width * 9 // 16}",
            "--rendering-method",
            "gl_compatibility",
            "--audio-driver",
            "Dummy",
            "--script",
            "res://" + c.PREFIX + "capture.gd",
            "--",
            "--output=" + str(folder / str(width)),
            "--profile=" + name,
        ]
        if width == 1280:
            args.append("--wide")
        c.check_export(project, expected)
        execute(engine, project, args, folder / f"{width}.txt")
        c.check_export(project, expected)
        c.need(
            all((project / path).read_bytes() == raw for path, raw in inputs.items()),
            "QA source changed",
        )
        runs[str(width)] = {"profile": name, "arguments": args}
    write(folder / "production-blobs.json", expected)
    return {
        "commit": commit,
        "tree": c.git("rev-parse", commit + "^{tree}").decode().strip(),
        "runs": runs,
    }


def collect(output: Path) -> None:
    """Проверяет среду и exact head до создания fresh output; частичный результат не принимается."""
    c.need(
        sys.platform == "linux" and bool(os.environ.get("DISPLAY")),
        "native game capture requires remote Linux X11",
    )
    head = c.git("rev-parse", "HEAD").decode().strip()
    c.need(head == os.environ.get("VWEATHER_EXPECTED_HEAD"), "exact expected head required")
    c.need(not c.git("status", "--porcelain", "--untracked-files=all"), "clean checkout required")
    output = output.resolve()
    c.need(
        output.is_absolute()
        and not output.is_relative_to(c.ROOT)
        and not output.exists()
        and output.parent.is_dir(),
        "fresh external output required",
    )
    inputs = {name: c.git("show", head + ":" + name) for name in c.INPUTS}
    c.need(
        all((c.ROOT / name).read_bytes() == raw for name, raw in inputs.items()),
        "committed QA required",
    )
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    output.mkdir()
    for name, raw in inputs.items():
        path = output / "inputs" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    source: dict[str, Any] = {
        "schema": 1,
        "task": "VWEATHER-001",
        "base": c.BASE,
        "head": head,
        "complete": False,
        "inputs": {name: c.digest(raw) for name, raw in inputs.items()},
        "variants": {},
        "hardware_fps_acceptance": False,
    }
    write(output / "source.json", source)
    for label, commit in (("baseline", c.BASE), ("candidate", head)):
        source["variants"][label] = variant(output / label, engine, commit, inputs)
        write(output / "source.json", source)
    source["artifacts"] = {
        name: c.digest((output / name).read_bytes()) for name in sorted(c.artifacts())
    }
    source["complete"] = True
    write(output / "source.json", source)
    print("WEATHER COLLECT: complete; head", head)


def main() -> None:
    """CLI не запускает игру на локальном Mac и не использует headless как нативный readback."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    collect(parser.parse_args().output)


if __name__ == "__main__":
    main()
