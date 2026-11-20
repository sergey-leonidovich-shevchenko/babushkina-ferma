"""Снимает одно нативное сравнение фонаря в новой Git-копии с отдельным профилем."""

from __future__ import annotations

import argparse
import json
import subprocess
import uuid
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.world.lighting import collect as inventory_collect
from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison import contract, exports


def write(path: Path, value: Any) -> None:
    """Только собственный manifest незавершённой новой серии допускает обновление."""
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def input_paths() -> tuple[str, ...]:
    """Перечисляет собственные входы и каждую общую QA-зависимость отдельно от runtime tree."""
    paths = list(contract.GDSCRIPTS)
    paths += [name + ".uid" for name in contract.GDSCRIPTS]
    paths += [
        contract.PREFIX + name
        for name in ("__init__.py", "contract.py", "collect.py", "exports.py")
    ]
    paths += list(inventory_collect.QA_INPUTS)
    paths += [
        "tools/qa/world/render_order_game.gd",
        "tools/qa/world/render_order_game.gd.uid",
        "tools/qa/camera/visual_camera_points.gd",
        "docs/reports/visual-overhaul/vbase-003/camera-points.json",
    ]
    return tuple(sorted(set(paths)))


def frozen_inputs(project: Path, folder: Path) -> dict[str, str]:
    """Связывает собственный прибор и общие действительные зависимости с исходными байтами."""
    result = {}
    for name in input_paths():
        raw = (contract.ROOT / name).read_bytes()
        for target in (project / name, folder / "inputs" / name):
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        result[name] = shared.digest(raw)
    return result


def prepare(output: Path, engine: Path) -> tuple[Path, dict[str, Any]]:
    """Экспортирует принятый Git; две правки существуют только в disposable-проекте."""
    if shared.git(
        "diff",
        contract.BASE,
        "--name-only",
        "--",
        "scripts",
        "assets/game",
        "main.tscn",
        "project.godot",
        "VERSION",
    ):
        raise ValueError("comparison requires unchanged accepted production")
    project = output / "project"
    project.mkdir()
    archive = output / "project.tar"
    with archive.open("xb") as stream:
        subprocess.run(
            ["git", "--no-replace-objects", "-C", str(contract.ROOT), "archive", contract.BASE],
            stdout=stream,
            env=git_environment(),
            check=True,
        )
    subprocess.run(["tar", "-xf", str(archive), "-C", str(project)], check=True)
    archive.unlink()
    inputs = frozen_inputs(project, output)
    overlays = {}
    for name in contract.OVERLAYS:
        raw = (project / name).read_bytes()
        changed = contract.instrument(name, raw)
        (project / name).write_bytes(changed)
        target = output / "overlays" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(changed)
        overlays[name] = {"source": shared.digest(raw), "instrumented": shared.digest(changed)}
    profile = "Codex-VLIGHT-002-import-" + uuid.uuid4().hex
    (project / "override.cfg").write_text(
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'
        + profile
        + '"\n'
    )
    inventory_collect.execute(
        engine, project, ["--headless", "--editor", "--quit"], output / "import.txt", 900
    )
    inventory_collect.execute(
        engine,
        project,
        ["--headless", "--check-only", "--script", "res://" + contract.PREFIX + "capture.gd"],
        output / "compile.txt",
    )
    return project, {
        "schema": 1,
        "task": "VLIGHT-002",
        "commit": contract.BASE,
        "scripts_tree": shared.git("rev-parse", contract.BASE + ":scripts").decode().strip(),
        "assets_tree": shared.git("rev-parse", contract.BASE + ":assets/game").decode().strip(),
        "qa_inputs": inputs,
        "overlays": overlays,
        "import_profile": profile,
        "complete": False,
        "runs": {},
        "hardware_fps_acceptance": False,
    }


def collect(output: Path, widths: list[int]) -> None:
    """Отказ при существующем каталоге предшествует любому запуску движка."""
    folder = shared.fresh_output(output)
    engine = inventory_collect.godot()
    if inventory_collect.busy():
        raise ValueError("Godot is already running; new output retained")
    project, manifest = prepare(folder, engine)
    export_blobs = exports.check(project)
    write(folder / "exported-blobs.json", export_blobs)
    manifest["exported_blobs_sha256"] = shared.digest((folder / "exported-blobs.json").read_bytes())
    manifest["setup_artifacts"] = {
        path.name: shared.digest(path.read_bytes())
        for label in ("import", "compile")
        for path in (
            folder / (label + ".txt"),
            folder / (label + ".stdout.txt"),
            folder / (label + ".launch.json"),
        )
    }
    write(folder / "source.json", manifest)
    for width in widths:
        target = folder / str(width)
        target.mkdir()
        profile = "Codex-VLIGHT-002-" + uuid.uuid4().hex
        arguments = [
            "--windowed",
            "--resolution",
            f"{width}x{width * 9 // 16}",
            "--rendering-method",
            "gl_compatibility",
            "--audio-driver",
            "Dummy",
            "--script",
            "res://" + contract.PREFIX + "capture.gd",
            "--",
            "--output=" + str(target / "frames"),
            "--profile=" + profile,
        ]
        if width == 1280:
            arguments.append("--wide")
        code = inventory_collect.execute(engine, project, arguments, target / "engine.txt", 900)
        capture = json.loads((target / "frames/capture.json").read_bytes())
        if code or capture["failures"] or set(capture["frames"]) != contract.FRAME_IDS:
            raise ValueError("incomplete comparison matrix; raw retained")
        manifest["runs"][str(width)] = {
            "profile": profile,
            "arguments": arguments,
            "exit_code": code,
            "artifacts": {
                str(path.relative_to(target)): shared.digest(path.read_bytes())
                for path in target.rglob("*")
                if path.is_file()
            },
        }
        if exports.check(project) != export_blobs:
            raise ValueError("exported inputs changed during native capture")
        for name, digest in manifest["qa_inputs"].items():
            if shared.digest((project / name).read_bytes()) != digest:
                raise ValueError("exported QA input changed during capture: " + name)
        write(folder / "source.json", manifest)
    manifest["complete"] = widths == list(contract.WIDTHS)
    write(folder / "source.json", manifest)


def main() -> None:
    """Одиночная ширина остаётся диагностикой, а не полной приёмкой."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--width", choices=contract.WIDTHS, type=int)
    args = parser.parse_args()
    collect(args.output, [args.width] if args.width else list(contract.WIDTHS))


if __name__ == "__main__":
    main()
