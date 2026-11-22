"""Снимает настоящие baseline/candidate VLIGHT-010 только удалённым Linux/X11."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.weather.collect import execute, write


def profile(engine: Path, project: Path, log: Path) -> str:
    """Startup override защищает ранний журнал; фактический OS userdata проверяется отдельно."""
    selected = "Codex-VLIGHT-010-" + uuid.uuid4().hex
    (project / "override.cfg").write_text(
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'
        + selected
        + '"\n'
    )
    execute(
        engine,
        project,
        ["--headless", "--script", "res://" + c.PREFIX + "profile.gd", "--", selected],
        log,
    )
    c.need(log.read_text().rstrip().endswith("/" + selected), "effective OS userdata differs")
    return selected


def variant(
    folder: Path, engine: Path, commit: str, inputs: dict[str, bytes], baseline: bool
) -> dict[str, Any]:
    """Добавляет только QA-наблюдателей к полному Git-экспорту; production bytes неизменны."""
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
        path = project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    expected = c.blobs(commit)
    c.check_export(project, expected)
    import_profile = profile(engine, project, folder / "import-profile.txt")
    execute(engine, project, ["--headless", "--editor", "--quit"], folder / "import.txt")
    execute(
        engine,
        project,
        ["--headless", "--check-only", "--script", "res://" + c.PREFIX + "capture.gd"],
        folder / "compile.txt",
    )
    runs = {}
    for width in c.WIDTHS:
        selected = profile(engine, project, folder / f"{width}-profile.txt")
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
            "--profile=" + selected,
        ]
        if width == 1280:
            args.append("--wide")
        if baseline:
            args.append("--baseline")
        c.check_export(project, expected)
        execute(engine, project, args, folder / f"{width}.txt")
        c.check_export(project, expected)
        c.need(
            all((project / name).read_bytes() == raw for name, raw in inputs.items()),
            "QA inputs changed during capture",
        )
        runs[str(width)] = {"profile": selected, "arguments": args}
    write(folder / "production-blobs.json", expected)
    return {
        "commit": commit,
        "tree": c.shared.git("rev-parse", commit + "^{tree}").decode().strip(),
        "import_profile": import_profile,
        "runs": runs,
    }


def collect(output: Path) -> None:
    """Отказывает до запуска движка и создания output на macOS, dirty source или неверном SHA."""
    c.need(
        sys.platform == "linux" and bool(os.environ.get("DISPLAY")),
        "native evidence requires remote Linux X11",
    )
    head = c.shared.git("rev-parse", "HEAD").decode().strip()
    c.need(head == os.environ.get("VLIGHT_QUALITY_EXPECTED_HEAD"), "exact head environment differs")
    c.need(
        not c.shared.git("status", "--porcelain", "--untracked-files=all"),
        "clean Git source required",
    )
    inputs = {name: c.shared.git("show", head + ":" + name) for name in c.INPUTS}
    c.need(
        all((c.ROOT / name).read_bytes() == raw for name, raw in inputs.items()),
        "producer input bytes are not committed",
    )
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    folder = c.shared.fresh_output(output)
    for name, raw in inputs.items():
        path = folder / "inputs" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    source: dict[str, Any] = {
        "schema": 1,
        "task": "VLIGHT-010",
        "base": c.BASE,
        "head": head,
        "complete": False,
        "inputs": {name: c.digest(raw) for name, raw in inputs.items()},
        "variants": {},
        "hardware_fps_acceptance": False,
    }
    write(folder / "source.json", source)
    for label, commit in (("baseline", c.BASE), ("candidate", head)):
        source["variants"][label] = variant(
            folder / label, engine, commit, inputs, label == "baseline"
        )
        write(folder / "source.json", source)
    source["artifacts"] = {
        name: c.digest((folder / name).read_bytes()) for name in sorted(c.artifacts())
    }
    source["complete"] = True
    write(folder / "source.json", source)
    print("LIGHT QUALITY COLLECT: complete; exact head", head)


def main() -> None:
    """CLI не предоставляет локального GUI или headless-обхода настоящей нативной приёмки."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    try:
        collect(parser.parse_args().output)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(2, str(error) + "\n")


if __name__ == "__main__":
    main()
