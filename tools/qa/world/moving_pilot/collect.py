"""Записывает маршрут VRELEASE-003 на удалённом Linux/X11 из точного Git checkout."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

from tools.qa.world.lighting.contract import ROOT, git
from tools.qa.world.lighting.daycycle.contract import blobs, check_export, digest
from tools.qa.world.weather.collect import execute, write

TASK = "VRELEASE-003"
PREFIX = "tools/qa/world/moving_pilot/"
FIXTURE = "tests/fixtures/saves/v1-core.json"
PROFILE_SCRIPT = "tools/qa/world/rollback/profile.gd"
WORKFLOW = ".github/workflows/vrelease-003.yml"
WIDTHS = (1152, 1280)
MODES = ("live", "static")
INPUTS = (
    PREFIX + "capture.gd",
    PREFIX + "collect.py",
    PREFIX + "verify.py",
    WORKFLOW,
    PROFILE_SCRIPT,
    "tools/qa/camera/visual_camera_points.gd",
    "docs/reports/visual-overhaul/vbase-003/camera-points.json",
    FIXTURE,
)


def require(condition: Any, message: str) -> None:
    if not condition:
        raise ValueError(message)


def source_inputs(head: str) -> dict[str, str]:
    return {path: digest(git("show", f"{head}:{path}")) for path in INPUTS}


def assert_source(head: str) -> None:
    require(git("rev-parse", "HEAD").decode().strip() == head, "exact expected HEAD required")
    require(
        not git("status", "--porcelain", "--untracked-files=no"),
        "tracked checkout must match the recorded Git revision",
    )


def write_profile(profile: str) -> bytes:
    return (
        f'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="{profile}"\n'
    ).encode()


def video(folder: Path) -> None:
    subprocess.run(
        [
            "ffmpeg",
            "-nostdin",
            "-v",
            "error",
            "-n",
            "-framerate",
            "10",
            "-i",
            str(folder / "frames/%04d.png"),
            "-map_metadata",
            "-1",
            "-an",
            "-c:v",
            "libx264",
            "-crf",
            "18",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            str(folder / "route.mp4"),
        ],
        check=True,
        timeout=240,
    )


def run_profile(
    engine: Path, output: Path, width: int, mode: str, override: Path
) -> dict[str, str]:
    parent = output / str(width)
    parent.mkdir(exist_ok=True)
    profile = f"Codex-{TASK}-{width}-{mode}-{uuid.uuid4().hex}"
    body = write_profile(profile)
    with override.open("xb") as f:
        f.write(body)
    try:
        probe = parent / f"{mode}-profile.txt"
        execute(
            engine,
            ROOT,
            ["--headless", "--script", f"res://{PROFILE_SCRIPT}", "--", profile],
            probe,
        )
        require(probe.read_text().rstrip().endswith("/" + profile), "effective profile differs")
        if (width, mode) == (WIDTHS[0], MODES[0]):
            execute(engine, ROOT, ["--headless", "--editor", "--quit"], output / "import.txt")
        folder = parent / mode
        arguments = [
            "--windowed",
            "--resolution",
            f"{width}x{width * 9 // 16}",
            "--rendering-method",
            "gl_compatibility",
            "--audio-driver",
            "Dummy",
            "--script",
            "res://" + PREFIX + "capture.gd",
            "--",
            "--output=" + str(folder),
            "--profile=" + profile,
            "--mode=" + mode,
        ]
        if width == 1280:
            arguments.append("--wide")
        execute(engine, ROOT, arguments, parent / f"{mode}.txt")
    finally:
        require(override.read_bytes() == body, "owned startup override changed")
        override.unlink()
    video(folder)
    return {"profile": profile, "capture": f"{width}/{mode}/capture.json"}


def collect(output: Path, head: str) -> None:
    require(sys.platform == "linux" and os.environ.get("DISPLAY"), "remote Linux X11 required")
    assert_source(head)
    output = output.resolve()
    require(
        not output.is_relative_to(ROOT) and not output.exists() and output.parent.is_dir(),
        "fresh external output with existing parent required",
    )
    override = ROOT / "override.cfg"
    require(not override.exists() and not override.is_symlink(), "startup override already exists")
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    production = blobs(head)
    check_export(ROOT, production)
    output.mkdir()
    # XDG переадресует даже первую проверку движка в отдельную директорию CI.
    old_data_home = os.environ.get("XDG_DATA_HOME")
    os.environ["XDG_DATA_HOME"] = str(output / "userdata")
    manifest: dict[str, Any] = {
        "task": TASK,
        "schema": 1,
        "head": head,
        "tree": git("rev-parse", f"{head}^{{tree}}").decode().strip(),
        "version": git("show", f"{head}:VERSION").decode().strip(),
        "inputs": source_inputs(head),
        "complete": False,
        "runs": {},
    }
    write(output / "source.json", manifest)
    try:
        for width in WIDTHS:
            for mode in MODES:
                manifest["runs"][f"{width}/{mode}"] = run_profile(
                    engine, output, width, mode, override
                )
                write(output / "source.json", manifest)
    finally:
        if old_data_home is not None:
            os.environ["XDG_DATA_HOME"] = old_data_home
        else:
            os.environ.pop("XDG_DATA_HOME", None)
    assert_source(head)
    check_export(ROOT, production)
    manifest["artifacts"] = {
        str(path.relative_to(output)): digest(path.read_bytes())
        for path in sorted(output.rglob("*"))
        if path.is_file()
        and path.name != "source.json"
        and not path.is_relative_to(output / "userdata")
    }
    manifest["complete"] = True
    write(output / "source.json", manifest)
    print(f"{TASK}: {len(manifest['runs'])} native routes for {head}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-head", required=True)
    args = parser.parse_args()
    collect(args.output, args.expected_head)


if __name__ == "__main__":
    main()
