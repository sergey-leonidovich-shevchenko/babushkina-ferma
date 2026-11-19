"""Снимает световой аудит в отдельных production/control проектах и собственных профилях."""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.world.lighting import contract
from tools.qa.world.lighting.inventory import inventory

GD_FILES = tuple(
    contract.PREFIX + name
    for name in (
        "light_probe.gd",
        "inventory_game.gd",
        "inventory_cases.gd",
        "inventory_capture.gd",
        "inventory_viewports.gd",
    )
)
QA_INPUTS = tuple(value for name in GD_FILES for value in (name, name + ".uid")) + tuple(
    contract.PREFIX + name for name in ("__init__.py", "contract.py", "collect.py", "inventory.py")
)


def write(path: Path, value: Any) -> None:
    """Перезапись разрешена только manifest текущей собственной незавершённой серии."""
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def godot() -> Path:
    """Использует установленный официальный движок, не загружает исполняемые файлы."""
    value = os.environ.get("FARM_GODOT_BIN")
    engine = Path(value) if value else contract.ROOT / "tools/Godot.app/Contents/MacOS/Godot"
    if not engine.is_file() or not os.access(engine, os.X_OK):
        raise ValueError("FARM_GODOT_BIN must point to installed Godot")
    return engine.resolve()


def busy() -> list[str]:
    """Не накладывает собственный процесс на существующую игровую или QA-сессию."""
    result = []
    for row in subprocess.check_output(["ps", "-axo", "pid=,comm="], text=True).splitlines():
        values = row.split(None, 1)
        if len(values) == 2 and Path(values[1]).name == "Godot":
            result.append(values[0])
    return result


def stop_owned(engine: Path, profile: str) -> None:
    """При таймауте закрывает только известный движок с нашим случайным UUID-профилем."""
    for row in subprocess.check_output(["ps", "-axo", "pid=,command="], text=True).splitlines():
        values = row.split(None, 1)
        if len(values) != 2 or not values[1].startswith(str(engine) + " "):
            continue
        tokens = values[1][len(str(engine)) :].split()
        if "--" in tokens and tokens[tokens.index("--") + 1 :].count("--profile=" + profile) == 1:
            os.kill(int(values[0]), signal.SIGTERM)


def execute(
    engine: Path, project: Path, arguments: list[str], log: Path, timeout: int = 360
) -> int:
    """Сохраняет реальные argv/exit/log и ограничивает только собственный дочерний запуск."""
    if busy() or log.exists():
        raise ValueError("free Godot slot and fresh log required")
    command = [str(engine), "--path", str(project), "--log-file", str(log), *arguments]
    native = "--headless" not in arguments
    if native:
        command = ["open", "-n", "-W", "-a", str(engine.parents[2]), "--args", *command[1:]]
    receipt = {"command": command, "project": str(project), "status": "running"}
    write(log.with_suffix(".launch.json"), receipt)
    with log.with_suffix(".stdout.txt").open("x") as output:
        try:
            result = subprocess.run(
                command, stdout=output, stderr=subprocess.STDOUT, timeout=timeout, check=False
            )
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            profiles = [
                value.removeprefix("--profile=")
                for value in arguments
                if value.startswith("--profile=")
            ]
            if native and len(profiles) == 1:
                stop_owned(engine, profiles[0])
            write(log.with_suffix(".launch.json"), {**receipt, "status": "interrupted"})
            raise
    write(
        log.with_suffix(".launch.json"),
        {**receipt, "status": "exited", "exit_code": result.returncode},
    )
    text = log.read_text(errors="replace")
    if result.returncode or any(
        value in text
        for value in ("SCRIPT ERROR", "Parse Error", "ERROR:", "Failed to load script")
    ):
        raise ValueError("engine failure; partial evidence retained: " + str(log))
    return result.returncode


def prepare(folder: Path, engine: Path, commit: str) -> dict[str, Any]:
    """Экспортирует настоящий Git tree; пять известных draw-вызовов меняются только в control-copy."""
    archive = folder / "project.tar"
    with archive.open("xb") as stream:
        subprocess.run(
            ["git", "--no-replace-objects", "-C", str(contract.ROOT), "archive", commit],
            stdout=stream,
            env=git_environment(),
            check=True,
        )
    production = folder / "production-project"
    production.mkdir()
    subprocess.run(["tar", "-xf", str(archive), "-C", str(production)], check=True)
    archive.unlink()
    inputs = {}
    for name in QA_INPUTS:
        source = contract.ROOT / name
        if not source.is_file():
            raise ValueError("import QA scripts and generated UID before capture: " + name)
        raw = source.read_bytes()
        destination = production / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
        frozen = folder / "inputs" / name
        frozen.parent.mkdir(parents=True, exist_ok=True)
        frozen.write_bytes(raw)
        inputs[name] = contract.digest(raw)
    profile = "Codex-VLIGHT-001-import-" + uuid.uuid4().hex
    (production / "override.cfg").write_text(
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'
        + profile
        + '"\n'
    )
    execute(engine, production, ["--headless", "--editor", "--quit"], folder / "import.txt", 900)
    control = folder / "control-project"
    subprocess.run(["cp", "-cR", str(production), str(control)], check=True)
    overlays = {}
    for name in contract.SOURCES:
        raw = (production / name).read_bytes()
        changed = contract.instrument(name, raw)
        (control / name).write_bytes(changed)
        target = folder / "overlays" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(changed)
        overlays[name] = {"source": contract.digest(raw), "instrumented": contract.digest(changed)}
    # Editor import сканирует файлы, но не гарантирует загрузку всех не-глобальных scripts.
    # Обе действительные цепочки preload проверяются до открытия нативного окна.
    for name, project in (("production", production), ("control", control)):
        execute(
            engine,
            project,
            [
                "--headless",
                "--check-only",
                "--script",
                "res://" + contract.PREFIX + "inventory_capture.gd",
            ],
            folder / ("compile-" + name + ".txt"),
        )
    source_inventory = inventory(commit)
    write(folder / "inventory.json", source_inventory)
    return {
        "schema": 1,
        "task": "VLIGHT-001",
        "commit": commit,
        "scripts_tree": contract.git("rev-parse", commit + ":scripts").decode().strip(),
        "asset_tree": contract.git("rev-parse", commit + ":assets/game").decode().strip(),
        "source_state": "committed production plus explicitly frozen QA inputs",
        "qa_inputs": inputs,
        "overlays": overlays,
        "inventory_sha256": contract.digest((folder / "inventory.json").read_bytes()),
        "import_profile": profile,
        "complete": False,
        "performance_eligible": False,
        "runs": {},
        "setup_artifacts": {
            path.name: contract.digest(path.read_bytes())
            for label in ("import", "compile-production", "compile-control")
            for path in (
                folder / (label + ".txt"),
                folder / (label + ".stdout.txt"),
                folder / (label + ".launch.json"),
            )
        },
    }


def check_exported_inputs(folder: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    """Editor/native не должны переписать реальные render/QA-входы экспортированных проектов."""
    source_inventory = json.loads((folder / "inventory.json").read_text())
    results = {}
    for label in ("production", "control"):
        expected = {name: row["sha256"] for name, row in source_inventory["sources"].items()}
        expected.update(manifest["qa_inputs"])
        if label == "control":
            expected.update(
                {name: row["instrumented"] for name, row in manifest["overlays"].items()}
            )
        actual = {
            name: contract.digest((folder / (label + "-project") / name).read_bytes())
            for name in expected
        }
        if actual != expected:
            raise ValueError("exported render/QA inputs changed: " + label)
        results[label] = actual
    return results


def collect(output: Path, widths: list[int], variants: list[str]) -> None:
    """Неполная диагностическая матрица помечается явно и не получает приёмку."""
    if sys.platform != "darwin":
        raise ValueError("native capture requires macOS; archived verification is cross-platform")
    engine, commit = godot(), contract.head()
    if busy():
        raise ValueError("another Godot process is running")
    folder = contract.fresh_output(output)
    manifest = prepare(folder, engine, commit)
    manifest["exported_inputs"] = check_exported_inputs(folder, manifest)
    manifest["diagnostic"] = widths != list(contract.WIDTHS) or variants != list(contract.VARIANTS)
    write(folder / "source.json", manifest)
    for width in widths:
        for variant in variants:
            key = f"{width}-{variant}"
            target = folder / key
            target.mkdir()
            project = folder / (
                "production-project" if variant == "production" else "control-project"
            )
            profile = "Codex-VLIGHT-001-" + uuid.uuid4().hex
            arguments = [
                "--windowed",
                "--resolution",
                f"{width}x{width * 9 // 16}",
                "--rendering-method",
                "gl_compatibility",
                "--audio-driver",
                "Dummy",
                "--script",
                "res://" + contract.PREFIX + "inventory_capture.gd",
                "--",
                "--output=" + str(target / "frames"),
                "--profile=" + profile,
                "--variant=" + variant,
            ]
            if width == 1280:
                arguments.append("--wide")
            print("LIGHT NATIVE:", key, flush=True)
            code = execute(engine, project, arguments, target / "engine.txt")
            capture = json.loads((target / "frames/capture.json").read_text())
            if code or capture["failures"] or set(capture["frames"]) != contract.FRAME_IDS:
                raise ValueError("native matrix incomplete: " + key)
            if variant == "on" and (
                len(capture["costs"]) != 12
                or any(len(row["samples_us"]) < 60 for row in capture["costs"])
                or capture["viewports"].get("failures") != []
                or set(capture["viewports"].get("records", {}))
                != {"both-on", "west-off", "home-off"}
            ):
                raise ValueError("native CPU/viewport matrix incomplete: " + key)
            manifest["runs"][key] = {
                "profile": profile,
                "arguments": arguments,
                "launcher_exit_code": code,
                "artifacts": {
                    str(path.relative_to(target)): contract.digest(path.read_bytes())
                    for path in target.rglob("*")
                    if path.is_file()
                },
            }
            if check_exported_inputs(folder, manifest) != manifest["exported_inputs"]:
                raise ValueError("exported project changed during native capture")
            write(folder / "source.json", manifest)
    if contract.head() != commit or any(
        contract.digest((contract.ROOT / name).read_bytes()) != value
        for name, value in manifest["qa_inputs"].items()
    ):
        raise ValueError("source changed during capture; incomplete evidence retained")
    manifest["complete"] = True
    write(folder / "source.json", manifest)


def main() -> None:
    """Один размер или вариант разрешён только для отладки, не для окончательной приёмки."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--width", choices=contract.WIDTHS, type=int)
    parser.add_argument("--variant", choices=contract.VARIANTS)
    args = parser.parse_args()
    collect(
        args.output,
        [args.width] if args.width else list(contract.WIDTHS),
        [args.variant] if args.variant else list(contract.VARIANTS),
    )


if __name__ == "__main__":
    main()
