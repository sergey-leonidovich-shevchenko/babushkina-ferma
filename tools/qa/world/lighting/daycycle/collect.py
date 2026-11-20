"""Нативный X11 producer VLIGHT-003: старый и текущий Git в новых внешних папках."""

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
from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.daycycle import contract as c


def write(path: Path, value: Any) -> None:
    """Обновляет только manifest собственного незавершённого нового прогона."""
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def busy() -> bool:
    """Фактический процесс Godot проверяется перед каждым запуском, включая Linux binary."""
    rows = subprocess.check_output(["ps", "-axo", "comm="], text=True).splitlines()
    return any(Path(row.strip()).name.lower().startswith("godot") for row in rows)


def execute(engine: Path, project: Path, arguments: list[str], log: Path) -> None:
    """Дочерний процесс без shell/open сохраняет реальные argv, stdout и exit, включая ошибки."""
    if busy() or log.exists():
        raise ValueError("free engine slot and fresh log required")
    command = [str(engine), "--path", str(project), *arguments]
    launch: dict[str, Any] = {"command": command, "project": str(project), "complete": False}
    write(log.with_suffix(".launch.json"), launch)
    with log.open("x") as stream:
        result = subprocess.run(
            command,
            stdout=stream,
            stderr=subprocess.STDOUT,
            env=git_environment(),
            timeout=900,
            check=False,
        )
    launch.update(complete=True, exit_code=result.returncode)
    write(log.with_suffix(".launch.json"), launch)
    text = log.read_text(errors="replace")
    if result.returncode or any(mark in text for mark in ("SCRIPT ERROR", "ERROR:", "Parse Error")):
        raise ValueError("engine failure; raw output retained: " + str(log))


def prepare(folder: Path, commit: str, inputs: dict[str, bytes]) -> tuple[Path, dict[str, str]]:
    """Git archive целиком; только отдельные QA inputs добавляются к неизменённому runtime."""
    project = folder / "project"
    project.mkdir()
    archive = folder / "project.tar"
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
        target = project / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    expected = c.blobs(commit)
    c.check_export(project, expected)
    return project, expected


def profile(engine: Path, project: Path, log: Path, label: str) -> str:
    """Подтверждает настоящий OS userdata до любого импорта/сцены в новом UUID-профиле."""
    name = "Codex-VLIGHT-003-" + label + "-" + uuid.uuid4().hex
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
    c.need(
        log.read_text().count("DAYCYCLE PROFILE: ") == 1
        and log.read_text().rstrip().endswith("/" + name),
        "effective import/native profile differs",
    )
    return name


def run_variant(
    folder: Path, engine: Path, commit: str, inputs: dict[str, bytes], baseline: bool
) -> dict[str, Any]:
    """У каждого импорта и native run собственный эффективный профиль; фазы последовательны."""
    folder.mkdir()
    project, expected = prepare(folder, commit, inputs)
    import_profile = profile(engine, project, folder / "import-profile.txt", "import")
    execute(engine, project, ["--headless", "--editor", "--quit"], folder / "import.txt")
    execute(
        engine,
        project,
        ["--headless", "--check-only", "--script", "res://" + c.PREFIX + "capture.gd"],
        folder / "compile.txt",
    )
    runs: dict[str, Any] = {}
    for width in c.WIDTHS:
        native_profile = profile(engine, project, folder / (str(width) + "-profile.txt"), "native")
        target = folder / str(width)
        arguments = [
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
            "--output=" + str(target),
            "--profile=" + native_profile,
        ]
        if width == 1280:
            arguments.append("--wide")
        if baseline:
            arguments.append("--baseline")
        c.check_export(project, expected)
        execute(engine, project, arguments, folder / (str(width) + ".txt"))
        c.check_export(project, expected)
        for name, raw in inputs.items():
            c.need((project / name).read_bytes() == raw, "exported QA changed: " + name)
        capture = json.loads((target / "capture.json").read_bytes())
        c.need(not capture["failures"], "native capture failures")
        runs[str(width)] = {"profile": native_profile, "arguments": arguments}
    write(folder / "production-blobs.json", expected)
    return {
        "commit": commit,
        "tree": shared.git("rev-parse", commit + "^{tree}").decode().strip(),
        "import_profile": import_profile,
        "runs": runs,
    }


def collect(output: Path) -> None:
    """Отказ на macOS/headless/грязном source предшествует запуску движка; raw не перезаписывается."""
    if sys.platform != "linux" or not os.environ.get("DISPLAY"):
        raise ValueError("native game evidence runs only on the remote Linux X11 stand")
    if busy():
        raise ValueError("Godot slot is busy")
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    head = shared.git("rev-parse", "HEAD").decode().strip()
    c.need(head == os.environ.get("VLIGHT_EXPECTED_HEAD"), "exact-head environment differs")
    c.need(
        not shared.git("status", "--porcelain", "--untracked-files=all"),
        "clean Git checkout required",
    )
    folder = shared.fresh_output(output)
    inputs = {name: (c.ROOT / name).read_bytes() for name in c.INPUTS}
    for name, raw in inputs.items():
        c.need(raw == shared.git("show", head + ":" + name), "QA input is not committed: " + name)
    for name, raw in inputs.items():
        target = folder / "inputs" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    manifest: dict[str, Any] = {
        "schema": 1,
        "task": "VLIGHT-003",
        "base": c.BASE,
        "head": head,
        "inputs": {name: c.digest(raw) for name, raw in inputs.items()},
        "complete": False,
        "variants": {},
        "hardware_fps_acceptance": False,
    }
    write(folder / "source.json", manifest)
    for label, commit in (("baseline", c.BASE), ("candidate", head)):
        manifest["variants"][label] = run_variant(
            folder / label, engine, commit, inputs, label == "baseline"
        )
        write(folder / "source.json", manifest)
    manifest["artifacts"] = {
        str(path.relative_to(folder)): c.digest(path.read_bytes())
        for label in ("baseline", "candidate")
        for path in (folder / label).rglob("*")
        if path.is_file() and "project" not in path.relative_to(folder / label).parts
    }
    manifest["complete"] = True
    write(folder / "source.json", manifest)
    print("DAYCYCLE COLLECT: complete; exact head", head)


def main() -> None:
    """Один CLI создаёт оба настоящих экспорта; частичный прогон не выдаётся за приёмку."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    collect(parser.parse_args().output)


if __name__ == "__main__":
    main()
