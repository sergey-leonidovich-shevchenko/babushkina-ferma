"""Проверяет нативное сравнение фонаря; диагностика не выдаётся за приёмку."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison import contract, pixels, provenance, timing
from tools.qa.world.lighting.comparison.assertions import require
from tools.qa.world.lighting.comparison.storage import Evidence

REPORT = contract.ROOT / "docs/reports/visual-overhaul/vlight-002/native"
BANNER = "Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org"


def verify(folder: Path, diagnostic: bool = False, current: bool = False) -> dict[str, Any]:
    """Успех диагностики явно отличается от полной матрицы и не закрывает карточку."""
    source = json.loads((folder / "source.json").read_bytes())
    require(bool(source["runs"]), "no completed native run")
    require(diagnostic or source["complete"], "incomplete native evidence")
    require(diagnostic or set(source["runs"]) == {"1152", "1280"}, "native width matrix")
    provenance.check(folder, source, current)
    store = Evidence(folder, source)
    results = {}
    for key, run in source["runs"].items():
        expected_files = {
            "engine.txt",
            "engine.stdout.txt",
            "engine.launch.json",
            "frames/capture.json",
        }
        expected_files.update(
            "frames/" + name + suffix
            for name in contract.FRAME_IDS
            for suffix in [".png", "-hud.png"]
        )
        expected_files.update(
            "frames/viewport-" + mode + suffix
            for mode in ["both-local", "left-off", "right-off"]
            for suffix in [".png", "-0.png", "-1.png"]
        )
        require(set(run["artifacts"]) == expected_files, "native artifact inventory")
        for name, expected in run["artifacts"].items():
            require(shared.digest(store.read(key, name)) == expected, "artifact hash: " + name)
        log = store.read(key, "engine.txt").decode()
        require(
            [line for line in log.splitlines() if line.startswith("Godot Engine")] == [BANNER],
            "official engine build banner",
        )
        require(
            not any(t in log for t in ["SCRIPT ERROR", "ERROR:", "Parse Error", "Failed to load"]),
            "native engine error log",
        )
        capture = json.loads(store.read(key, "frames/capture.json"))
        provenance.launch(run, json.loads(store.read(key, "engine.launch.json")), capture, int(key))
        require(
            capture["task"] == "VLIGHT-002" and capture["engine"] == "4.7.1-stable (official)",
            "engine/task",
        )
        require(
            capture["renderer"] == "gl_compatibility" and capture["display"] == "macOS",
            "actual native Compatibility",
        )
        require(
            capture["window"] == [int(key), int(key) * 9 // 16] and not capture["failures"],
            "window/native failure",
        )
        require(
            capture["profile"] == run["profile"]
            and capture["user_dir"].endswith("/" + run["profile"]),
            "isolated actual profile",
        )
        require(
            capture["gpu_time_measured"] is False and capture["hardware_fps_acceptance"] is False,
            "false GPU/FPS claim",
        )
        frame_results = pixels.frames(store, key, capture)
        require(
            capture["engine_max_fps"] == 0 and capture["vsync_mode"] == 0, "actual native cap/vsync"
        )
        results[key] = {
            "frames": frame_results,
            "costs": timing.costs(capture),
            "viewports": pixels.viewports(store, key, capture),
        }
    return {
        "task": "VLIGHT-002",
        "native_complete": not diagnostic,
        "hardware_fps_accepted": False,
        "results": results,
    }


def main() -> None:
    """Работает офлайн; новые измерения никогда не запускаются автоматически reader-командой."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=REPORT)
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
