"""Проверяет полную нативную световую матрицу и её закреплённые Git/QA-источники."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, cast

from tools.qa.world.lighting import contract, pixels
from tools.qa.world.lighting.collect import QA_INPUTS
from tools.qa.world.lighting.inventory import INPUTS, inventory
from tools.qa.world.lighting.storage import SETUP, Artifacts

DEFAULT = contract.ROOT / "docs/reports/visual-overhaul/vlight-001/native"
OWNERS = {row[0] for rows in contract.CALLS.values() for row in rows}
SHARED_QA = (
    "tools/qa/camera/visual_camera_points.gd",
    "tools/qa/world/render_order_game.gd",
    "tools/qa/world/render_order_game.gd.uid",
    "docs/reports/visual-overhaul/vbase-003/camera-points.json",
)


def config_without_version(raw: bytes) -> tuple[bytes, str]:
    """Только SemVer метаданных исключается из текущего render-сравнения; весь остальной config точный."""
    pattern = rb'^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$'
    matches = list(re.finditer(pattern, raw, re.MULTILINE))
    if len(matches) != 1:
        raise ValueError("one explicit project version required")
    version = matches[0].group(1).decode()
    return re.sub(pattern, b'config/version="<version-metadata>"', raw, flags=re.MULTILINE), version


def source_check(folder: Path, source: dict[str, Any], current: bool) -> dict[str, Any]:
    """История остаётся историей; current дополнительно проверяет рабочие render/QA-байты."""
    commit = source["commit"]
    if not re.fullmatch("[0-9a-f]{40}", commit):
        raise ValueError("full source commit required")
    for tree, path in (("scripts_tree", "scripts"), ("asset_tree", "assets/game")):
        if source[tree] != contract.git("rev-parse", commit + ":" + path).decode().strip():
            raise ValueError("pinned runtime tree mismatch")
    raw_inventory = (folder / "inventory.json").read_bytes()
    if contract.digest(raw_inventory) != source["inventory_sha256"]:
        raise ValueError("inventory artifact SHA")
    expected_inventory = inventory(commit)
    if json.loads(raw_inventory) != expected_inventory:
        raise ValueError("inventory differs from pinned production sources")
    expected_exports = {}
    for label in ("production", "control"):
        expected = {name: row["sha256"] for name, row in expected_inventory["sources"].items()}
        expected.update(source["qa_inputs"])
        if label == "control":
            expected.update({name: row["instrumented"] for name, row in source["overlays"].items()})
        expected_exports[label] = expected
    if source["exported_inputs"] != expected_exports:
        raise ValueError("exported production/control input SHA mismatch")
    if set(source["qa_inputs"]) != set(QA_INPUTS) or set(source["overlays"]) != set(
        contract.SOURCES
    ):
        raise ValueError("QA/overlay input inventory")
    for name, sha in source["qa_inputs"].items():
        if contract.digest((folder / "inputs" / name).read_bytes()) != sha:
            raise ValueError("frozen QA input changed: " + name)
        if current and contract.digest((contract.ROOT / name).read_bytes()) != sha:
            raise ValueError("current QA input differs: " + name)
    for name in contract.SOURCES:
        raw = contract.git("show", commit + ":" + name)
        changed = contract.instrument(name, raw)
        if source["overlays"][name] != {
            "source": contract.digest(raw),
            "instrumented": contract.digest(changed),
        }:
            raise ValueError("overlay SHA mismatch")
        if (folder / "overlays" / name).read_bytes() != changed:
            raise ValueError("unexpected runtime overlay")
    shared = {}
    archived = folder / "base-qa"
    locations = (
        (archived,)
        if archived.is_dir()
        else (folder / "production-project", folder / "control-project")
    )
    for name in SHARED_QA:
        captured_dependency = contract.git("show", commit + ":" + name)
        for project in locations:
            if (project / name).read_bytes() != captured_dependency:
                raise ValueError("shared QA dependency differs from captured Git: " + name)
        if current and (contract.ROOT / name).read_bytes() != captured_dependency:
            raise ValueError("current shared QA dependency changed: " + name)
        shared[name] = contract.digest(captured_dependency)
    delta: dict[str, Any] = {
        "captured_commit": commit,
        "current_checked": current,
        "shared_QA_inputs": shared,
    }
    if not current:
        return delta
    for path, tree in (("scripts", "scripts_tree"), ("assets/game", "asset_tree")):
        if contract.git("rev-parse", "HEAD:" + path).decode().strip() != source[tree]:
            raise ValueError("current runtime tree differs: " + path)
    tracked = contract.git(
        "diff", "HEAD", "--name-only", "--", "scripts", "assets/game", "main.tscn"
    )
    untracked = contract.git(
        "ls-files", "--others", "--exclude-standard", "--", "scripts", "assets/game"
    )
    if tracked or untracked:
        raise ValueError("uncommitted production changes are outside this audit")
    for name in INPUTS:
        captured = contract.git("show", commit + ":" + name)
        now = (contract.ROOT / name).read_bytes()
        if name == "project.godot":
            left, captured_version = config_without_version(captured)
            right, current_version = config_without_version(now)
            if left != right or (contract.ROOT / "VERSION").read_text().strip() != current_version:
                raise ValueError("render configuration changed beyond version metadata")
            delta["project_versions"] = {
                "captured": captured_version,
                "current": current_version,
                "metadata_only_delta": captured_version != current_version,
            }
        elif now != captured:
            raise ValueError("current render input differs: " + name)
    return delta


def run_check(artifacts: Artifacts, key: str, run: dict[str, Any]) -> dict[str, Any]:
    """Проверяет действительные argv, журналы, PNG и snapshots вместо доверия exit code."""
    width_text, variant = key.split("-", 1)
    width = int(width_text)
    profile = run["profile"]
    if not re.fullmatch(r"Codex-VLIGHT-001-[0-9a-f]{32}", profile):
        raise ValueError("isolated native UUID profile required")
    expected_files = {
        "engine.txt",
        "engine.stdout.txt",
        "engine.launch.json",
        "frames/capture.json",
    }
    expected_files.update(
        "frames/" + name + suffix for name in contract.FRAME_IDS for suffix in (".png", "-hud.png")
    )
    if variant == "on":
        expected_files.update(
            "frames/viewport-" + mode + suffix
            for mode in ("both-on", "west-off", "home-off")
            for suffix in (".png", "-0.png", "-1.png")
        )
    if set(run["artifacts"]) != expected_files or run["launcher_exit_code"] != 0:
        raise ValueError("native artifact/exit inventory")
    for name, sha in run["artifacts"].items():
        if contract.digest(artifacts.read(key + "/" + name)) != sha:
            raise ValueError("native artifact SHA: " + name)
    capture = cast(dict[str, Any], json.loads(artifacts.read(key + "/frames/capture.json")))
    launch = json.loads(artifacts.read(key + "/engine.launch.json"))
    log = artifacts.read(key + "/engine.txt").decode(errors="replace")
    if any(
        marker in log
        for marker in ("SCRIPT ERROR", "Parse Error", "ERROR:", "Failed to load script")
    ):
        raise ValueError("engine error in native evidence")
    if "LIGHT INVENTORY NATIVE: 9 cases" not in log:
        raise ValueError("completed native controller marker required")
    project = Path(launch["project"])
    expected_project = "production-project" if variant == "production" else "control-project"
    if not project.is_absolute() or project.name != expected_project:
        raise ValueError("native project boundary")
    external_root = project.parent
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
        "--output=" + str(external_root / key / "frames"),
        "--profile=" + profile,
        "--variant=" + variant,
    ]
    if width == 1280:
        arguments.append("--wide")
    command = launch["command"]
    if (
        command[:4] != ["open", "-n", "-W", "-a"]
        or not Path(command[4]).is_absolute()
        or Path(command[4]).suffix != ".app"
    ):
        raise ValueError("native application launcher required")
    expected = [
        *command[:5],
        "--args",
        "--path",
        str(project),
        "--log-file",
        str(external_root / key / "engine.txt"),
        *arguments,
    ]
    if (
        command != expected
        or arguments != run["arguments"]
        or launch["status"] != "exited"
        or launch["exit_code"] != 0
    ):
        raise ValueError("actual native argv or exit mismatch")
    user_arguments = arguments[arguments.index("--") + 1 :]
    if (
        capture["user_arguments"] != user_arguments
        or capture["profile"] != profile
        or Path(capture["user_dir"]).name != profile
    ):
        raise ValueError("native user directory or script argv mismatch")
    if (
        capture["task"] != "VLIGHT-001"
        or capture["variant"] != variant
        or capture["failures"]
        or capture["performance_eligible"]
    ):
        raise ValueError("native capture failed or makes an FPS claim")
    if (
        not capture["engine"].startswith("4.7.1")
        or "official" not in capture["engine"]
        or capture["display"] == "headless"
        or capture["renderer"] != "gl_compatibility"
    ):
        raise ValueError("pinned native Compatibility engine required")
    if set(capture["frames"]) != contract.FRAME_IDS or capture["window"] != [
        width,
        width * 9 // 16,
    ]:
        raise ValueError("native frame inventory/window")
    for name, frame in capture["frames"].items():
        pixels.state_check(frame, key + ":" + name)
        if (
            frame["bloom"]
            or not frame["visible"]
            or frame["window"] != capture["window"]
            or frame["size"] != capture["window"]
        ):
            raise ValueError("native frame configuration")
        snapshot = frame["snapshot"]
        if (
            snapshot["day"] != 2
            or snapshot["weather"] != "clear"
            or snapshot["walkable"] != "walkable"
            or snapshot["physics_processing"]
        ):
            raise ValueError("native scene control or navigation failed")
        if snapshot["minutes"] != int(name.rsplit("-", 1)[1]):
            raise ValueError("native clock differs")
        if snapshot["location"] != (
            "cottage_interior" if name.startswith("home-") else "overworld"
        ):
            raise ValueError("native location differs")
        if snapshot["zoom"] != (1.0 if name.startswith("home-") else 1.2):
            raise ValueError("native zoom differs")
        if (
            frame["hud"]["file"] != name + "-hud.png"
            or frame["hud"]["before"] != frame["hud"]["after"]
        ):
            raise ValueError("native HUD control")
        for row in frame["calls"]:
            if row["owner"] not in OWNERS or row["off"] != (variant == "off"):
                raise ValueError("unexpected lighting owner/switch")
        if variant == "production" and frame["calls"]:
            raise ValueError("unmodified production unexpectedly instrumented")
        size = (width, width * 9 // 16)
        pixels.picture(artifacts, key + "/frames/" + name + ".png", size)
        pixels.picture(artifacts, key + "/frames/" + name + "-hud.png", size)
    if variant != "on" and (capture["costs"] or capture["viewports"]):
        raise ValueError("unexpected extra native controls")
    return capture


def setup_check(artifacts: Artifacts, source: dict[str, Any]) -> None:
    """Нулевой exit без двух фактических check-only не подтверждает компиляцию QA."""
    if set(source["setup_artifacts"]) != SETUP or not re.fullmatch(
        r"Codex-VLIGHT-001-import-[0-9a-f]{32}", source["import_profile"]
    ):
        raise ValueError("import and both semantic preflights required")
    for name, sha in source["setup_artifacts"].items():
        raw = artifacts.read(name)
        if (
            contract.digest(raw) != sha
            or name.endswith(".txt")
            and any(marker in raw for marker in (b"SCRIPT ERROR", b"Parse Error", b"ERROR:"))
        ):
            raise ValueError("setup SHA/compiler failure")
    for label in ("import", "compile-production", "compile-control"):
        launch = json.loads(artifacts.read(label + ".launch.json"))
        project = Path(launch["project"])
        command = launch["command"]
        project_name = "control-project" if label == "compile-control" else "production-project"
        arguments = (
            ["--headless", "--editor", "--quit"]
            if label == "import"
            else [
                "--headless",
                "--check-only",
                "--script",
                "res://" + contract.PREFIX + "inventory_capture.gd",
            ]
        )
        if (
            not project.is_absolute()
            or project.name != project_name
            or not command
            or not Path(command[0]).is_absolute()
            or Path(command[0]).name != "Godot"
        ):
            raise ValueError("semantic preflight project/engine boundary")
        if (
            command
            != [
                command[0],
                "--path",
                str(project),
                "--log-file",
                str(project.parent / (label + ".txt")),
                *arguments,
            ]
            or launch["status"] != "exited"
            or launch["exit_code"] != 0
        ):
            raise ValueError("actual semantic preflight argv/exit")


def verify(
    folder: Path = DEFAULT, current: bool = False, diagnostic: bool = False
) -> dict[str, Any]:
    """Только обе ширины и все три режима дают адресную приёмку этой матрицы."""
    source = json.loads((folder / "source.json").read_text())
    if (
        source["schema"] != 1
        or source["task"] != "VLIGHT-001"
        or not source["complete"]
        or source["performance_eligible"]
    ):
        raise ValueError("incomplete/incorrect lighting evidence")
    all_keys = {f"{width}-{variant}" for width in contract.WIDTHS for variant in contract.VARIANTS}
    runs = source["runs"]
    if not runs or not set(runs).issubset(all_keys):
        raise ValueError("unexpected native run")
    full = set(runs) == all_keys and not source["diagnostic"]
    if not full and not diagnostic:
        raise ValueError("diagnostic series is not acceptance eligible")
    provenance = source_check(folder, source, current)
    artifacts = Artifacts(folder, source)
    setup_check(artifacts, source)
    captures = {key: run_check(artifacts, key, run) for key, run in runs.items()}
    comparisons, cpu, twins = {}, {}, {}
    if full:
        for width in contract.WIDTHS:
            group = {variant: captures[f"{width}-{variant}"] for variant in contract.VARIANTS}
            comparisons[str(width)] = [
                pixels.compare_frame(artifacts, width, name, group)
                for name in sorted(contract.FRAME_IDS)
            ]
            cpu[str(width)] = pixels.costs(group["on"])
            twins[str(width)] = pixels.viewports(artifacts, width, group["on"])
    return {
        "task": "VLIGHT-001",
        "analysis_sources": {
            contract.PREFIX + name: contract.digest((Path(__file__).parent / name).read_bytes())
            for name in ("verify.py", "pixels.py", "storage.py")
        },
        "acceptance_eligible": full,
        "native_world_frames": 9 * len(runs),
        "native_HUD_frames": 9 * len(runs),
        "provenance": provenance,
        "comparisons": comparisons,
        "CPU_submission": cpu,
        "viewports": twins,
        "hardware_FPS_accepted": False,
        "whole_map_accepted": False,
    }


def main() -> None:
    """Исторический reader не требует старых рабочих байтов; current включается отдельно."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT)
    parser.add_argument("--check-current-candidate", action="store_true")
    parser.add_argument("--diagnostic", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            verify(args.input, args.check_current_candidate, args.diagnostic),
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
