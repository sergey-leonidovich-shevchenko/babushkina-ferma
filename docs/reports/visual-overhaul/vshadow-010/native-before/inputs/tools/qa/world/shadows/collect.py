"""Снимает исходный кадр и три контроля в собственных QA-проектах и профилях."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import uuid
from pathlib import Path

from tools.common.git import git_environment
from tools.qa.world.shadows.contract import (
    PREFIX,
    QA_INPUTS,
    ROOT,
    SOURCES,
    VARIANTS,
    digest,
    fresh_output,
    git,
    head,
    instrument,
)


def write(path: Path, value: object) -> None:
    """Пишет только в уже выделенный собственный каталог."""
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def godot() -> Path:
    """Использует уже установленный движок проекта, без загрузки и установки программ."""
    configured = os.environ.get("FARM_GODOT_BIN")
    candidate = Path(configured) if configured else ROOT / "tools/Godot.app/Contents/MacOS/Godot"
    if not candidate.is_file() or not os.access(candidate, os.X_OK):
        raise ValueError("FARM_GODOT_BIN must point to installed Godot")
    return candidate.resolve()


def busy() -> list[str]:
    """Не запускает второй движок поверх чужой игровой или QA-сессии."""
    rows = subprocess.check_output(["ps", "-axo", "pid=,comm="], text=True).splitlines()
    return [
        row.split(None, 1)[0]
        for row in rows
        if len(row.split(None, 1)) == 2 and Path(row.split(None, 1)[1]).name == "Godot"
    ]


def execute(
    engine: Path, project: Path, arguments: list[str], log: Path, timeout: int = 240
) -> int:
    """Ограничивает время только собственного дочернего процесса и сохраняет полный журнал."""
    if busy():
        raise ValueError("another Godot process is running")
    command = [str(engine), "--path", str(project), "--log-file", str(log), *arguments]
    native = "--headless" not in arguments
    if native:
        command = ["open", "-n", "-W", "-a", str(engine.parents[2]), "--args", *command[1:]]
    if log.exists():
        raise ValueError("fresh engine log required")
    receipt = {"command": command, "project": str(project), "status": "running"}
    write(log.with_suffix(".launch.json"), receipt)
    with log.with_suffix(".stdout.txt").open("x") as stream:
        try:
            result = subprocess.run(
                command, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout, check=False
            )
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            if native:
                profiles = [
                    x.removeprefix("--profile=") for x in arguments if x.startswith("--profile=")
                ]
                if len(profiles) == 1:
                    stop_owned_native(engine, profiles[0])
            receipt["status"] = "interrupted"
            write(log.with_suffix(".launch.json"), receipt)
            raise
    write(
        log.with_suffix(".launch.json"),
        {**receipt, "status": "exited", "exit_code": result.returncode},
    )
    return result.returncode


def stop_owned_native(engine: Path, profile: str) -> None:
    """Закрывает только тот экземпляр известного движка, которому передан наш UUID-профиль."""
    rows = subprocess.check_output(["ps", "-axo", "pid=,command="], text=True).splitlines()
    for row in rows:
        fields = row.split(None, 1)
        if len(fields) != 2 or not fields[1].startswith(str(engine) + " "):
            continue
        tokens = fields[1][len(str(engine)) :].split()
        if "--" in tokens and tokens[tokens.index("--") + 1 :].count("--profile=" + profile) == 1:
            os.kill(int(fields[0]), signal.SIGTERM)


def check_log(path: Path) -> None:
    """Ошибка движка не превращается в успешную приёмку из-за exit code 0."""
    text = path.read_text(errors="replace")
    if any(
        marker in text
        for marker in ("SCRIPT ERROR", "Parse Error", "ERROR:", "Failed to load script")
    ):
        raise ValueError("engine error in " + str(path))


def prepare(folder: Path, engine: Path, commit: str) -> dict[str, object]:
    """Создаёт каноническую копию Git и добавляет только явно сохранённые QA-входы."""
    archive = folder / "project.tar"
    with archive.open("xb") as stream:
        subprocess.run(
            ["git", "-C", str(ROOT), "archive", commit],
            stdout=stream,
            check=True,
            env=git_environment(),
        )
    project = folder / "production-project"
    project.mkdir()
    subprocess.run(["tar", "-xf", str(archive), "-C", str(project)], check=True)
    archive.unlink()
    inputs: dict[str, str] = {}
    for relative in QA_INPUTS:
        source = ROOT / relative
        if not source.is_file():
            raise ValueError("import QA scripts first: " + relative)
        destination = project / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        stored = folder / "inputs" / relative
        stored.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, stored)
        inputs[relative] = digest(source.read_bytes())
    import_profile = "Codex-VSHADOW-010-import-" + uuid.uuid4().hex
    (project / "override.cfg").write_text(
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'
        + import_profile
        + '"\n'
    )
    imported = execute(
        engine, project, ["--headless", "--editor", "--quit"], folder / "import.txt", timeout=900
    )
    check_log(folder / "import.txt")
    if imported:
        raise ValueError("isolated import failed")
    controls = folder / "control-project"
    subprocess.run(["cp", "-cR", str(project), str(controls)], check=True)
    overlays = {}
    for name in SOURCES:
        original = project / name
        raw = original.read_bytes()
        changed = instrument(name, raw)
        (controls / name).write_bytes(changed)
        stored = folder / "overlays" / name
        stored.parent.mkdir(parents=True, exist_ok=True)
        stored.write_bytes(changed)
        overlays[name] = {"source": digest(raw), "instrumented": digest(changed)}
    return {
        "schema": 1,
        "task": "VSHADOW-010",
        "commit": commit,
        "asset_tree": git("rev-parse", commit + ":assets/game").decode().strip(),
        "scripts_tree": git("rev-parse", commit + ":scripts").decode().strip(),
        "qa_inputs": inputs,
        "overlays": overlays,
        "import_profile": import_profile,
        "setup_artifacts": {
            path.name: digest(path.read_bytes())
            for path in (
                folder / "import.txt",
                folder / "import.stdout.txt",
                folder / "import.launch.json",
            )
        },
        "runs": {},
        "complete": False,
        "performance_eligible": False,
    }


def collect(output: Path, widths: list[int]) -> None:
    """Фиксирует одинаковые настройки для production/on/off/no-loot без изменения рабочего проекта."""
    if sys.platform != "darwin":
        raise ValueError("native collector requires macOS; the archived reader is cross-platform")
    engine, commit = godot(), head()
    if busy():
        raise ValueError("another Godot process is running")
    folder = fresh_output(output)
    manifest = prepare(folder, engine, commit)
    write(folder / "source.json", manifest)
    for width in widths:
        for variant in VARIANTS:
            key = f"{width}-{variant}"
            run = folder / key
            run.mkdir()
            project = folder / (
                "production-project" if variant == "production" else "control-project"
            )
            profile = "Codex-VSHADOW-010-" + uuid.uuid4().hex
            arguments = [
                "--windowed",
                "--resolution",
                f"{width}x{width * 9 // 16}",
                "--rendering-method",
                "gl_compatibility",
                "--audio-driver",
                "Dummy",
                "--script",
                "res://" + PREFIX + "readability_capture.gd",
                "--",
                "--output=" + str(run / "frames"),
                "--profile=" + profile,
                "--variant=" + variant,
            ]
            if width == 1280:
                arguments.append("--wide")
            if variant == "off":
                arguments.append("--without-contacts")
            print("SHADOW READABILITY", key, flush=True)
            code = execute(engine, project, arguments, run / "engine.txt")
            check_log(run / "engine.txt")
            capture = json.loads((run / "frames/capture.json").read_text())
            if code or capture["failures"]:
                raise ValueError("native capture failed: " + key)
            runs = manifest["runs"]
            assert isinstance(runs, dict)
            runs[key] = {
                "launcher_exit_code": code,
                "profile": profile,
                "arguments": arguments,
                "artifacts": {
                    str(p.relative_to(run)): digest(p.read_bytes())
                    for p in run.rglob("*")
                    if p.is_file()
                },
            }
            write(folder / "source.json", manifest)
    manifest["complete"] = True
    inputs = manifest["qa_inputs"]
    if not isinstance(inputs, dict) or any(
        digest((ROOT / name).read_bytes()) != value for name, value in inputs.items()
    ):
        raise ValueError("QA source changed during capture")
    if head() != commit:
        raise ValueError("production source changed during capture")
    write(folder / "source.json", manifest)


def main() -> None:
    """Один размер — диагностический прогон; приёмка требует обеих штатных ширин."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--width", type=int, choices=(1152, 1280))
    args = parser.parse_args()
    collect(args.output, [args.width] if args.width else [1152, 1280])


if __name__ == "__main__":
    main()
