"""Читает связанный с Git нативный архив VSHADOW-010; не запускает и не исправляет игру."""

from __future__ import annotations

import argparse
import io
import json
import re
from pathlib import Path
from typing import Any

from PIL import Image

from tools.qa.world.shadows.contract import (
    FRAME_IDS,
    QA_INPUTS,
    ROOT,
    RUNTIME,
    SOURCES,
    VARIANTS,
    digest,
    git,
    instrument,
)
from tools.qa.world.shadows.pixels import compare
from tools.qa.world.shadows.storage import artifact_bytes, validate_storage

DEFAULT = ROOT / "docs/reports/visual-overhaul/vshadow-010/native-current"


def read(path: Path) -> dict[str, Any]:
    """Отказывает до сравнения картинок при неправильном JSON-контейнере."""
    value = json.loads(artifact_bytes(path))
    if not isinstance(value, dict):
        raise ValueError("JSON object required: " + str(path))
    return value


def require(condition: bool, message: str) -> None:
    """Не использует отключаемый Python assert для контракта приёмки."""
    if not condition:
        raise ValueError(message)


def provenance(folder: Path, diagnostic: bool, check_current: bool = False) -> dict[str, Any]:
    """Сверяет overlay с закреплённым source, а не с текущей изменяемой рабочей копией."""
    source = read(folder / "source.json")
    require(source["schema"] == 1 and source["task"] == "VSHADOW-010", "wrong task/schema")
    require(source["complete"] is True, "incomplete capture")
    require(source["performance_eligible"] is False, "not a performance campaign")
    require(
        bool(re.fullmatch(r"Codex-VSHADOW-010-import-[0-9a-f]{32}", source["import_profile"])),
        "import profile",
    )
    require(
        set(source["setup_artifacts"]) == {"import.txt", "import.stdout.txt", "import.launch.json"},
        "import inventory",
    )
    for name, expected in source["setup_artifacts"].items():
        require(digest(artifact_bytes(folder / name)) == expected, "import artifact hash")
    imported = read(folder / "import.launch.json")
    require(imported["status"] == "exited" and imported["exit_code"] == 0, "import failed")
    require(
        not any(
            value in artifact_bytes(folder / "import.txt").decode()
            for value in ("ERROR:", "SCRIPT ERROR", "Parse Error")
        ),
        "import error",
    )
    commit = source["commit"]
    require(bool(re.fullmatch("[0-9a-f]{40}", commit)), "full commit required")
    for key, tree in (("asset_tree", "assets/game"), ("scripts_tree", "scripts")):
        require(
            source[key] == git("rev-parse", commit + ":" + tree).decode().strip(),
            "pinned tree mismatch",
        )
    runtime = source.get("runtime_overlays", {})
    state = source.get("source_state", "committed")
    require(state in ("committed", "working-tree"), "unknown source state")
    require(
        set(runtime) == (set(RUNTIME) if state == "working-tree" else set()),
        "runtime overlay inventory",
    )
    for relative, hashes in runtime.items():
        require(digest(git("show", commit + ":" + relative)) == hashes["base"], "runtime base hash")
        require(
            digest((folder / "candidate" / relative).read_bytes()) == hashes["candidate"],
            "runtime candidate hash",
        )
    if check_current:
        changed = (
            git("diff", commit, "--name-only", "--", "scripts", "assets/game", "main.tscn")
            .decode()
            .splitlines()
        )
        require(
            set(changed).issubset(RUNTIME), "current production differs outside runtime candidate"
        )
        base_config = git("show", commit + ":project.godot")
        current_config = (ROOT / "project.godot").read_bytes()
        require(
            re.sub(rb"^config/version=.*$", b"config/version=<metadata>", base_config, flags=re.M)
            == re.sub(
                rb"^config/version=.*$", b"config/version=<metadata>", current_config, flags=re.M
            ),
            "current project settings mismatch",
        )
        for relative in RUNTIME:
            expected = (
                runtime[relative]["candidate"]
                if runtime
                else digest(git("show", commit + ":" + relative))
            )
            require(
                digest((ROOT / relative).read_bytes()) == expected,
                "current runtime candidate mismatch",
            )
    require(set(source["qa_inputs"]) == set(QA_INPUTS), "QA input inventory")
    for relative, expected in source["qa_inputs"].items():
        require(relative.startswith("tools/qa/world/shadows/"), "unexpected QA input")
        require(".." not in Path(relative).parts, "unsafe QA path")
        require(digest((folder / "inputs" / relative).read_bytes()) == expected, "QA input hash")
        if check_current:
            require(digest((ROOT / relative).read_bytes()) == expected, "current QA input mismatch")
    require(set(source["overlays"]) == set(SOURCES), "overlay inventory")
    for relative, hashes in source["overlays"].items():
        original = git("show", commit + ":" + relative)
        overlay = (folder / "overlays" / relative).read_bytes()
        require(digest(original) == hashes["source"], "source hash")
        require(digest(overlay) == hashes["instrumented"], "overlay hash")
        require(overlay == instrument(relative, original), "unexpected instrumentation")
    widths = sorted({int(key.split("-", 1)[0]) for key in source["runs"]})
    require(
        widths == [1152, 1280] or diagnostic and widths in ([1152], [1280]), "both widths required"
    )
    require(
        set(source["runs"]) == {f"{width}-{variant}" for width in widths for variant in VARIANTS},
        "run inventory",
    )
    validate_storage(folder, source)
    return source


def capture(folder: Path, key: str, run: dict[str, Any]) -> dict[str, Any]:
    """Проверяет видимое окно, изоляцию профиля и оба настоящих draw callback каждого кадра."""
    width_text, variant = key.split("-", 1)
    width = int(width_text)
    size = [width, width * 9 // 16]
    require(run["launcher_exit_code"] == 0, "launcher failed")
    require(bool(re.fullmatch(r"Codex-VSHADOW-010-[0-9a-f]{32}", run["profile"])), "QA profile")
    for relative, expected in run["artifacts"].items():
        require(
            not Path(relative).is_absolute() and ".." not in Path(relative).parts, "unsafe artifact"
        )
        require(digest(artifact_bytes(folder / key / relative)) == expected, "artifact hash")
    required = {"engine.txt", "engine.stdout.txt", "engine.launch.json", "frames/capture.json"}
    required.update("frames/" + frame + ".png" for frame in FRAME_IDS)
    required.update("frames/loot-source-" + kind + ".png" for kind in ("apple", "stone", "wood"))
    require(set(run["artifacts"]) == required, "artifact inventory")
    log = artifact_bytes(folder / key / "engine.txt").decode()
    require(not any(v in log for v in ("ERROR:", "SCRIPT ERROR", "Parse Error")), "engine error")
    data = read(folder / key / "frames/capture.json")
    require(data["task"] == "VSHADOW-010" and data["variant"] == variant, "capture identity")
    require(data["profile"] == run["profile"], "capture profile mismatch")
    require(Path(data["user_dir"]).name == run["profile"], "user directory mismatch")
    require(data["failures"] == [] and data["performance_eligible"] is False, "capture failed")
    require(
        data["display"] != "headless" and data["renderer"] == "gl_compatibility", "native renderer"
    )
    require(
        data["engine"] == "4.7.1-stable (official)"
        and "Godot Engine v4.7.1.stable.official.a13da4feb" in log,
        "official engine required",
    )
    require(data["low_processor_usage_mode"] is False, "idle rendering can skip presents")
    arguments = run["arguments"]
    expected_user = [
        next(value for value in arguments if value.startswith("--output=")),
        "--profile=" + run["profile"],
        "--variant=" + variant,
    ]
    if width == 1280:
        expected_user.append("--wide")
    if variant == "off":
        expected_user.append("--without-contacts")
    require(data["user_arguments"] == expected_user, "actual user arguments mismatch")
    require(
        arguments
        == [
            "--windowed",
            "--resolution",
            f"{width}x{size[1]}",
            "--rendering-method",
            "gl_compatibility",
            "--audio-driver",
            "Dummy",
            "--script",
            "res://tools/qa/world/shadows/readability_capture.gd",
            "--",
            *expected_user,
        ],
        "unexpected engine arguments",
    )
    launch = read(folder / key / "engine.launch.json")
    require(launch["status"] == "exited" and launch["exit_code"] == 0, "incomplete launch receipt")
    command = launch["command"]
    require(
        command[:4] == ["open", "-n", "-W", "-a"] and command[5] == "--args", "native macOS launch"
    )
    require(
        command[6:10]
        == [
            "--path",
            launch["project"],
            "--log-file",
            str(Path(expected_user[0].removeprefix("--output=")).parent / "engine.txt"),
        ],
        "launch project/log mismatch",
    )
    require(command[10:] == arguments, "actual engine arguments mismatch")
    require(set(data["frames"]) == FRAME_IDS, "frame inventory")
    for frame_id, frame in data["frames"].items():
        require(frame["size"] == size and frame["window"] == size, "wrong frame size")
        require(frame["visible"] is True and frame["bloom"] is False, "hidden window/bloom")
        require(frame["before"] == frame["after"], "drawing mutated save")
        require(len(frame["draws"]) == 2, "two draw callbacks required")
        for draw in frame["draws"]:
            require(draw["before"] == draw["after"] and draw["equal"] is True, "draw mutated save")
            require(draw["geometry_before"] == draw["geometry_after"], "draw moved geometry")
        snapshot = frame["snapshot"]
        require(
            snapshot["walkable"] == "walkable" and not snapshot["physics_processing"],
            "moving/blocked point",
        )
        require(snapshot["minutes"] == int(frame_id.rsplit("-", 1)[1]), "wrong clock")
        require(
            snapshot["seed"] == 20261015 and frame["before"]["world_loot_seed"] == 20261015,
            "wrong deterministic seed",
        )
        require(len(frame["loot"]) == 3, "three real loot fixtures required")
        keys = [(entry["owner"], *entry["world"]) for entry in frame["contacts"]]
        require(len(keys) == len(set(keys)), "duplicate contact draw at the same world bounds")
    return data


def verify(folder: Path, diagnostic: bool = False, check_current: bool = False) -> dict[str, Any]:
    """Проверяет всю матрицу, включая пиксельное равенство production и прозрачного прибора."""
    source = provenance(folder, diagnostic, check_current)
    captures = {key: capture(folder, key, run) for key, run in source["runs"].items()}
    results = {}
    widths = sorted({int(key.split("-", 1)[0]) for key in captures})
    for width in widths:
        sources = {}
        for kind, entry in captures[f"{width}-on"]["loot_sources"].items():
            require(entry["file"] == "loot-source-" + kind + ".png", "unsafe loot source")
            with Image.open(
                io.BytesIO(artifact_bytes(folder / f"{width}-on/frames" / entry["file"]))
            ) as raw:
                sources[kind] = raw.convert("RGBA")
        require(set(sources) == {"apple", "stone", "wood"}, "loot source inventory")
        for frame_id in sorted(FRAME_IDS):
            frames = {v: captures[f"{width}-{v}"]["frames"][frame_id] for v in VARIANTS}
            for frame in frames.values():
                require(
                    frame["snapshot"] == frames["on"]["snapshot"],
                    "paired geometry/climate mismatch",
                )
            for variant, frame in frames.items():
                if variant != "production":
                    require(
                        frame["contacts"] == frames["on"]["contacts"],
                        "paired contact geometry mismatch",
                    )
                state = dict(frame["before"])
                baseline = dict(frames["on"]["before"])
                if variant == "no-loot":
                    state["drops"] = []
                    baseline["drops"] = []
                require(state == baseline, "paired save state mismatch")
            images = {}
            for variant in VARIANTS:
                path = folder / f"{width}-{variant}" / "frames" / (frame_id + ".png")
                with Image.open(io.BytesIO(artifact_bytes(path))) as raw:
                    images[variant] = raw.convert("RGBA")
            results[f"{width}-{frame_id}"] = compare(images, frames["on"], sources)
    return {
        "task": "VSHADOW-010",
        "commit": source["commit"],
        "source_state": source.get("source_state", "committed"),
        "runtime_overlay_sha256": digest(
            json.dumps(source.get("runtime_overlays", {}), sort_keys=True).encode()
        ),
        "checked_current_candidate": check_current,
        "acceptance_eligible": not diagnostic and widths == [1152, 1280],
        "performance_eligible": False,
        "results": results,
    }


def main() -> None:
    """Диагностический один размер никогда не становится полной приёмкой."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT)
    parser.add_argument("--diagnostic", action="store_true")
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            verify(args.input, args.diagnostic, args.check_current_candidate),
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
