#!/usr/bin/env python3
"""Collect source-bound native VGROUND-002 comparisons without making FPS claims."""

from __future__ import annotations

if not __package__:
    from tools.common.launch import prepare_imports
    from tools.common.paths import project_root

    prepare_imports(project_root(__file__))

import argparse
import gzip
import hashlib
import json
import os
import shlex
import shutil
import signal
import subprocess
import sys
import time
import uuid
from pathlib import Path

from tools.qa.performance.perf_contract_collect import ROOT, command, context, sha, write
from tools.qa.world.source_inputs import historical_result, input_path

SOURCES = [
    ".github/workflows/vground-002.yml",
    "scripts/presentation/ground_color_patches.gd",
    "scripts/presentation/ground_color_patches.gd.uid",
    "scripts/presentation/meadow_ground.gd",
    "scripts/presentation/village_region_terrain.gd",
    "scripts/presentation/village_terrain_canvas.gd",
    "scripts/systems/village_map_data.gd",
    "scripts/systems/village_region_data.gd",
    "scripts/systems/village_terrain_renderer.gd",
    "scripts/world_background.gd",
    "tests/suites/architecture_suite.gd",
    "tests/suites/ground_color_patches_suite.gd",
    "tests/suites/ground_color_patches_suite.gd.uid",
    "tests/suites/meadow_ground_suite.gd",
    "tools/qa/ground/color_patch_board.gd",
    "tools/qa/ground/color_patch_capture.gd",
    "tools/qa/ground/color_patch_collect.py",
    "tools/qa/ground/test_color_patch_collect.py",
    "tools/qa/ground/test_color_patch_verify.py",
    "tools/qa/ground/color_patch_verify.py",
    "tools/qa/ground/color_patch_review.gd",
    "tools/qa/ground/road_network_board.gd",
    "tools/qa/ground/road_network_builder.gd",
    "tools/qa/camera/visual_camera_points.gd",
    "tools/qa/world/render_order_game.gd",
    "scripts/systems/world_farming_system.gd",
    "scripts/systems/navigation_system.gd",
    "scripts/systems/world_projection_system.gd",
    "scripts/systems/presentation_pose_system.gd",
    "assets/game/locations/overworld/modular/grass_painted_v2.png",
    "assets/game/locations/overworld/modular/grass_painted_v2.png.import",
    "assets/game/locations/overworld/modular/path_material_v1.png",
    "assets/game/locations/overworld/modular/path_material_v1.png.import",
    "assets/game/locations/overworld/ground_masks/main.res",
    "assets/game/locations/overworld/ground_masks/connectors.res",
    "assets/game/locations/overworld/axial_road_masks/main.res",
    "assets/game/locations/overworld/axial_road_masks/connectors.res",
    "assets/game/locations/overworld/road_network_masks/main.res",
    "assets/game/locations/overworld/road_network_masks/connectors.res",
    "assets/game/locations/overworld/plaza_masks/apron.res",
    "assets/game/locations/overworld/plaza_masks/contact.res",
    "assets/game/locations/overworld/plaza_masks/stone.res",
    "project.godot",
    "main.tscn",
]
OVERLAY = {
    ".github/workflows/vground-002.yml",
    "scripts/presentation/ground_color_patches.gd",
    "scripts/presentation/ground_color_patches.gd.uid",
    "scripts/presentation/meadow_ground.gd",
    "scripts/presentation/village_region_terrain.gd",
    "scripts/presentation/village_terrain_canvas.gd",
    "scripts/systems/village_map_data.gd",
    "scripts/systems/village_terrain_renderer.gd",
    "scripts/world_background.gd",
    "tests/suites/architecture_suite.gd",
    "tests/suites/ground_color_patches_suite.gd",
    "tests/suites/ground_color_patches_suite.gd.uid",
    "tests/suites/meadow_ground_suite.gd",
    "tools/qa/ground/color_patch_board.gd",
    "tools/qa/ground/color_patch_capture.gd",
    "tools/qa/ground/color_patch_collect.py",
    "tools/qa/ground/test_color_patch_collect.py",
    "tools/qa/ground/test_color_patch_verify.py",
    "tools/qa/ground/color_patch_verify.py",
    "tools/qa/ground/color_patch_review.gd",
    "assets/game/locations/overworld/ground_masks/main.res",
    "assets/game/locations/overworld/ground_masks/connectors.res",
    "assets/game/locations/overworld/axial_road_masks/main.res",
    "assets/game/locations/overworld/axial_road_masks/connectors.res",
    "assets/game/locations/overworld/road_network_masks/main.res",
    "assets/game/locations/overworld/road_network_masks/connectors.res",
    "assets/game/locations/overworld/plaza_masks/apron.res",
    "assets/game/locations/overworld/plaza_masks/contact.res",
    "assets/game/locations/overworld/plaza_masks/stone.res",
}


def godot_app() -> Path:
    """Resolve the shared native editor from a checkout or linked worktree."""
    explicit = os.environ.get("FARM_GODOT_APP")
    if explicit:
        candidate = Path(explicit).resolve()
    elif os.environ.get("FARM_GODOT_BIN"):
        candidate = Path(os.environ["FARM_GODOT_BIN"]).resolve().parents[2]
    elif (ROOT / "tools/Godot.app").exists():
        candidate = ROOT / "tools/Godot.app"
    else:
        common = Path(command(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"]))
        candidate = common.parent / "tools/Godot.app"
    if not (candidate / "Contents/MacOS/Godot").is_file():
        raise ValueError("native Godot application unavailable")
    return candidate


def godot_binary() -> Path:
    """Resolve the explicitly pinned engine on CI and the shared app in a macOS worktree."""
    explicit = os.environ.get("FARM_GODOT_BIN")
    if explicit:
        candidate = Path(explicit).resolve()
    elif sys.platform == "darwin":
        candidate = godot_app() / "Contents/MacOS/Godot"
    else:
        resolved = shutil.which("godot") or shutil.which("godot4")
        candidate = Path(resolved).resolve() if resolved else Path()
    if not candidate.is_file() or not os.access(candidate, os.X_OK):
        raise ValueError("native Godot binary unavailable")
    return candidate


def godot_jobs() -> list[str]:
    """Reject any competing engine by executable name on macOS and Linux."""
    raw = command(["ps", "-axo", "pid=,command="])
    if raw.startswith("UNAVAILABLE"):
        raise ValueError("process inventory unavailable")
    result = []
    for line in raw.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2:
            continue
        try:
            executable = Path(shlex.split(fields[1])[0]).name.lower()
        except ValueError:
            continue
        if "godot" in executable:
            result.append(line.strip())
    return result


def capture_pid(profile: str) -> int | None:
    """Find only this collector's uniquely tagged capture process."""
    raw = command(["ps", "-axo", "pid=,command="])
    for line in raw.splitlines():
        fields = line.strip().split(None, 1)
        if (
            len(fields) == 2
            and "--profile=" + profile in fields[1]
            and "color_patch_capture.gd" in fields[1]
        ):
            return int(fields[0])
    return None


def launch_arguments(target: Path, profile: str, width: int) -> list[str]:
    """Use macOS open locally and the pinned binary inside an isolated CI X server."""
    engine = [
        "--path",
        str(ROOT),
        "--windowed",
        "--rendering-method",
        "gl_compatibility",
        "--audio-driver",
        "Dummy",
        "--log-file",
        str(target / "engine.txt"),
        "--script",
        "res://tools/qa/ground/color_patch_capture.gd",
        "--",
        "--output=" + str(target / "native"),
        "--profile=" + profile,
    ]
    if width == 1280:
        engine.append("--wide")
    if sys.platform == "darwin":
        return ["open", "-n", "-W", "-a", str(godot_app()), "--args", *engine]
    if os.environ.get("CI") != "true":
        raise ValueError("non-macOS native capture is restricted to isolated CI")
    return [str(godot_binary()), *engine, "--virtual-display"]


def wait_for_capture(child: subprocess.Popen, target: Path, profile: str) -> int:
    """Wait for the uniquely tagged native child even when macOS open returns early."""
    deadline = time.monotonic() + 300
    started = time.monotonic()
    native_seen = False
    capture = target / "native/capture.json"
    while time.monotonic() < deadline:
        code = child.poll()
        # Linux CI launches the engine directly.  The capture document is written
        # shortly before Godot finishes, so only the reaped child's return code can
        # finish this wait.  Starting the next window earlier creates a false
        # "competing Godot" rejection and can hide a late non-zero exit.
        if sys.platform != "darwin":
            if code is not None:
                return code
            time.sleep(0.1)
            continue
        # macOS uses ``open -W``.  Its wrapper and the uniquely tagged Godot process
        # are separate lifecycles, so success requires both the wrapper's real code
        # and the disappearance of the owned engine.  Never synthesize code zero from
        # a ready JSON document while ``child.returncode`` is still unknown.
        pid = capture_pid(profile)
        native_seen = native_seen or pid is not None
        if code is not None and code != 0 and pid is None:
            return code
        if (
            capture.is_file()
            and code is not None
            and pid is None
            and (native_seen or time.monotonic() - started > 10)
        ):
            return code
        time.sleep(0.1)
    pid = capture_pid(profile)
    if pid:
        os.kill(pid, signal.SIGTERM)
    if child.poll() is None:
        child.terminate()
        child.wait(timeout=10)
    raise ValueError("own capture timed out")


def collect(folder: Path) -> None:
    """Freeze inputs and run two fresh, sequential, native QA windows."""
    if folder.exists() or godot_jobs():
        raise ValueError("unused output and no competing Godot required")
    changed = set(
        command(
            [
                "git",
                "diff",
                "HEAD",
                "--name-only",
                "--",
                "scripts",
                "tests",
                "tools/qa",
                "assets/game",
                "main.tscn",
            ]
        ).splitlines()
    )
    untracked = set(
        command(
            [
                "git",
                "ls-files",
                "--others",
                "--exclude-standard",
                "--",
                "scripts",
                "tests",
                "tools/qa",
                "assets/game",
            ]
        ).splitlines()
    )
    expected_head = os.environ.get("VGROUND_EXPECTED_HEAD", "").strip()
    head_commit = command(["git", "rev-parse", "HEAD"])
    exact_head = bool(expected_head)
    if exact_head and head_commit != expected_head:
        raise ValueError("checkout does not match expected PR head")
    checkout_status = command(["git", "status", "--porcelain=v1", "--untracked-files=all"]).strip()
    if exact_head and checkout_status:
        raise ValueError("exact-head collection requires a clean checkout")
    if not (changed | untracked) <= OVERLAY:
        raise ValueError("unrelated runtime or QA changes")
    folder.mkdir(parents=True)
    source = {
        "task": "VGROUND-002",
        "base_commit": head_commit,
        "head_commit": head_commit,
        "head_tree": command(["git", "rev-parse", "HEAD^{tree}"]),
        "expected_head": expected_head or None,
        "exact_head": exact_head,
        "complete": False,
        "sources": {},
        "base_sources": {},
        "head_sources": {},
        "artifacts": {},
    }
    for name in SOURCES:
        target = folder / "inputs" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(input_path(ROOT, name), target)
        source["sources"][name] = sha(target)
        historical = historical_result(ROOT, head_commit, name)
        historical_digest = (
            hashlib.sha256(historical.stdout).hexdigest() if historical.returncode == 0 else None
        )
        source["base_sources"][name] = historical_digest
        source["head_sources"][name] = historical_digest
        if exact_head and historical_digest != source["sources"][name]:
            raise ValueError("exact-head input differs from Git blob: " + name)
    write(folder / "source.json", source)
    for width in [1152, 1280]:
        if godot_jobs():
            raise ValueError("competing Godot appeared")
        target = folder / str(width)
        target.mkdir()
        profile = "Codex-VGROUND-002-" + uuid.uuid4().hex
        args = launch_arguments(target, profile, width)
        before = context()
        print("COLOR PATCH NATIVE", width, flush=True)
        with (target / "stdout.txt").open("w") as output:
            child = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
            code = wait_for_capture(child, target, profile)
        write(
            target / "environment.json",
            {
                "command": args,
                "profile": profile,
                "exit_code": code,
                "before": before,
                "after": context(),
            },
        )
        capture = target / "native/capture.json"
        payload = json.loads(capture.read_text()) if capture.is_file() else {}
        if code or payload.get("errors") or len(payload.get("rows", [])) != 30:
            raise ValueError("native capture incomplete")
        if (target / "native").exists():
            for path in (target / "native").iterdir():
                shutil.move(str(path), target / path.name)
            (target / "native").rmdir()
        for path in target.glob("*-draws.json"):
            with gzip.GzipFile(str(path) + ".gz", "wb", mtime=0) as stream:
                stream.write(path.read_bytes())
            path.unlink()
        source["artifacts"] = {
            str(path.relative_to(folder)): sha(path)
            for path in folder.rglob("*")
            if path.is_file() and path.name != "source.json" and "inputs" not in path.parts
        }
        write(folder / "source.json", source)
        if code or any(
            sha(input_path(ROOT, path)) != digest for path, digest in source["sources"].items()
        ):
            raise ValueError("capture failed or frozen input changed")
    source["complete"] = True
    write(folder / "source.json", source)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    collect(parser.parse_args().output.resolve())
