"""Отделяет проверку закреплённых source/argv от анализа пикселей и времени фонаря."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison import contract, exports
from tools.qa.world.lighting.comparison.collect import input_paths
from tools.qa.world.lighting.verify import config_without_version


def check(folder: Path, source: dict[str, Any], current: bool) -> None:
    """История сверяется с Git, current дополнительно требует прежних рабочих render/QA-байтов."""
    if source["task"] != "VLIGHT-002" or source["commit"] != contract.BASE:
        raise ValueError("comparison source commit/task")
    for key, path in [("scripts_tree", "scripts"), ("assets_tree", "assets/game")]:
        if source[key] != shared.git("rev-parse", contract.BASE + ":" + path).decode().strip():
            raise ValueError("production tree mismatch")
    if set(source["qa_inputs"]) != set(input_paths()):
        raise ValueError("QA input inventory")
    for name, digest in source["qa_inputs"].items():
        raw = (folder / "inputs" / name).read_bytes()
        if shared.digest(raw) != digest:
            raise ValueError("frozen QA bytes: " + name)
        if (
            not name.startswith(contract.PREFIX)
            and shared.git("show", contract.BASE + ":" + name) != raw
        ):
            raise ValueError("shared QA differs from accepted Git: " + name)
        if current and (contract.ROOT / name).read_bytes() != raw:
            raise ValueError("current QA differs: " + name)
    if set(source["overlays"]) != set(contract.OVERLAYS):
        raise ValueError("overlay inventory")
    for name, row in source["overlays"].items():
        raw = shared.git("show", contract.BASE + ":" + name)
        instrumented = contract.instrument(name, raw)
        if row != {"source": shared.digest(raw), "instrumented": shared.digest(instrumented)}:
            raise ValueError("overlay source/result SHA")
        if (folder / "overlays" / name).read_bytes() != instrumented:
            raise ValueError("actual overlay differs")
    blob_bytes = (folder / "exported-blobs.json").read_bytes()
    if (
        shared.digest(blob_bytes) != source["exported_blobs_sha256"]
        or json.loads(blob_bytes) != exports.expected_blobs()
    ):
        raise ValueError("actual exported production blob inventory")
    expected_setup = {
        label + suffix
        for label in ["import", "compile"]
        for suffix in [".txt", ".stdout.txt", ".launch.json"]
    }
    if set(source["setup_artifacts"]) != expected_setup:
        raise ValueError("setup artifact inventory")
    for name, digest in source["setup_artifacts"].items():
        if shared.digest((folder / name).read_bytes()) != digest:
            raise ValueError("setup artifact hash")
    if current:
        check_current(source)


def check_current(source: dict[str, Any]) -> None:
    """Разрешает только согласованные version metadata, а не изменения рендера или assets."""
    for key, path in [("scripts_tree", "scripts"), ("assets_tree", "assets/game")]:
        if shared.git("rev-parse", "HEAD:" + path).decode().strip() != source[key]:
            raise ValueError("current production tree changed")
    if shared.git(
        "diff", "HEAD", "--name-only", "--", "scripts", "assets/game", "main.tscn"
    ) or shared.git("ls-files", "--others", "--exclude-standard", "--", "scripts", "assets/game"):
        raise ValueError("uncommitted production changes")
    for name in ["main.tscn", "project.godot"]:
        before = shared.git("show", contract.BASE + ":" + name)
        after = (contract.ROOT / name).read_bytes()
        if name == "project.godot":
            before, _ = config_without_version(before)
            after, version = config_without_version(after)
            if (contract.ROOT / "VERSION").read_text().strip() != version:
                raise ValueError("project/version metadata disagree")
        if before != after:
            raise ValueError("current render configuration changed")


def launch(
    run: dict[str, Any], document: dict[str, Any], capture: dict[str, Any], width: int
) -> None:
    """Проверяет фактическую open/Godot границу и user argv, а не только текст в manifest."""
    profile = run["profile"]
    if not re.fullmatch(r"Codex-VLIGHT-002-[0-9a-f]{32}", profile):
        raise ValueError("native UUID profile")
    project = Path(document["project"])
    if not project.is_absolute() or project.name != "project":
        raise ValueError("native project boundary")
    expected = [
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
        "--output=" + str(project.parent / str(width) / "frames"),
        "--profile=" + profile,
    ]
    if width == 1280:
        expected.append("--wide")
    command = document["command"]
    if (
        len(command) < 11
        or command[:4] != ["open", "-n", "-W", "-a"]
        or command[5:8] != ["--args", "--path", str(project)]
    ):
        raise ValueError("native open/engine argv boundary")
    if (
        Path(command[4]).name != "Godot.app"
        or command[8:10] != ["--log-file", str(project.parent / str(width) / "engine.txt")]
        or command[10:] != expected
    ):
        raise ValueError("native actual engine argv")
    if (
        run["arguments"] != expected
        or capture["user_arguments"] != expected[expected.index("--") + 1 :]
    ):
        raise ValueError("native run/user argv")
    if document["status"] != "exited" or document["exit_code"] != 0 or run["exit_code"] != 0:
        raise ValueError("native launcher failed")
