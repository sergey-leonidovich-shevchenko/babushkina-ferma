"""Снимает неизменённые baseline/candidate в новых Git-экспортах на удалённом X11."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.world.rollback import contract as c
from tools.qa.world.weather.collect import execute, write


def profile(engine: Path, project: Path, log: Path) -> str:
    """Сначала подтверждает effective userdata, не позволяя импорту открыть обычные слоты."""
    name = "Codex-VCOMPAT-010-" + uuid.uuid4().hex
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
    c.need(log.read_text().rstrip().endswith("/" + name), "effective userdata differs")
    return name


def variant(folder: Path, engine: Path, commit: str, inputs: dict[str, bytes]) -> dict[str, Any]:
    """QA добавляет только наблюдателей; production-исходники и данные строго сверяются с Git."""
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
            "QA changed during run",
        )
        runs[str(width)] = {"profile": name, "arguments": args}
    write(folder / "production-blobs.json", expected)
    return {
        "commit": commit,
        "tree": c.git("rev-parse", commit + "^{tree}").decode().strip(),
        "runs": runs,
    }


def collect(output: Path) -> None:
    """Требует удалённый Linux, exact head и новый внешний каталог до первого engine launch."""
    c.need(
        sys.platform == "linux" and bool(os.environ.get("DISPLAY")),
        "native capture requires remote Linux X11",
    )
    head, inputs = c.export_inputs()
    c.need(head == os.environ.get("VCOMPAT_EXPECTED_HEAD"), "exact expected head required")
    output = output.resolve()
    c.need(
        not output.is_relative_to(c.ROOT) and not output.exists() and output.parent.is_dir(),
        "fresh external output required",
    )
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    output.mkdir()
    for name, raw in inputs.items():
        path = output / "inputs" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    source: dict[str, Any] = {
        "schema": 1,
        "task": "VCOMPAT-010",
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
    print("ROLLBACK COLLECT: complete; head", head)


def main() -> None:
    """CLI не имеет локального GUI/headless обхода нативных требований."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    collect(parser.parse_args().output)


if __name__ == "__main__":
    main()
