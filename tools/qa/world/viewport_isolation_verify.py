#!/usr/bin/env python3
"""Verify two native viewport worlds, exact source bytes and draw-state isolation."""

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageStat

from tools.common.paths import project_root

ROOT = project_root(__file__)
REPORT = ROOT / "docs/reports/visual-overhaul/vrender-009"
NATIVE = REPORT / "native"
CASES = ["same-camera", "game-moves", "editor-and-pause", "map-entry", "map-return"]
SOURCES = [
    "project.godot",
    "main.tscn",
    "scripts/core/game_bootstrap.gd",
    "scripts/core/game_preview_bootstrap.gd",
    "scripts/core/game_unhandled_input_router.gd",
    "scripts/game_core.gd",
    "scripts/presentation/post_motion_frame.gd",
    "scripts/presentation/village_ground_clock.gd",
    "scripts/presentation/viewport_world_context.gd",
    "scripts/presentation/village_terrain_canvas.gd",
    "scripts/systems/camera_system.gd",
    "scripts/systems/render_system.gd",
    "scripts/systems/world_projection_system.gd",
    "scripts/world_background.gd",
    "tests/suites/post_motion_frame_suite.gd",
    "tests/suites/viewport_world_context_suite.gd",
    "tools/qa/world/render_order_game.gd",
    "tools/qa/world/viewport_isolation_capture.gd",
    "tools/qa/world/viewport_isolation_review.gd",
    "tools/qa/world/viewport_isolation_verify.py",
]


def require(value: object, label: str) -> None:
    """Reject incomplete native evidence instead of repairing it."""
    if not value:
        raise ValueError(label)


def digest(path: Path) -> str:
    """Return an exact byte identity for source and image evidence."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def stable_image(path: Path, size: list[int]) -> dict[str, Any]:
    """Require an actual non-flat PNG with the declared dimensions."""
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        require(list(rgba.size) == size, f"image size: {path.name}")
        require(
            sum(ImageStat.Stat(rgba.convert("RGB")).var) > 120.0, f"non-flat image: {path.name}"
        )
    return {"file": path.name, "sha256": digest(path), "bytes": path.stat().st_size}


def with_pause_tutorial(snapshot: dict[str, Any]) -> dict[str, Any]:
    """Return the one expected persisted effect of manually opening pause."""
    expected: dict[str, Any] = json.loads(json.dumps(snapshot))
    expected["estate"]["expansion"]["first_chapter"]["events"]["pause_menu"] = True
    expected["tutorial"]["events"]["pause_menu"] = True
    return expected


def verify(report: Path = REPORT) -> dict[str, Any]:
    """Validate owners, same-camera baseline, independent mutations and exact render-only draws."""
    report = Path(report)
    native = report / "native"
    data = json.loads((native / "capture.json").read_text())
    require(data["task"] == "VRENDER-009" and len(data["base_commit"]) == 40, "capture identity")
    require(
        data["display"] != "headless" and not data["errors"], "native display and clean capture"
    )
    require(
        data["window"] == [1152, 648] and data["logical_viewport"] == [1152, 648],
        "exact viewport sizes",
    )
    require(
        data["coverage"]
        == [
            "hero",
            "bush",
            "rails",
            "foreground",
            "HUD",
            "manual-pause",
            "F12",
            "map-entry-return",
        ],
        "required visual route",
    )
    require([row["id"] for row in data["rows"]] == CASES, "ordered route")
    images = []
    tokens: dict[str, dict[str, int]] = {}
    for row in data["rows"]:
        require(row["composite_size"] == data["window"], "composite readback")
        images.append(
            stable_image(native / row["composite_file"], [int(value) for value in data["window"]])
        )
        require(len(row["states"]) == 2, "two states per case")
        for state in row["states"]:
            role = state["role"]
            token = state["owner"]
            require(set(token) == {"game", "viewport", "background"}, "bounded owner token")
            require(
                all(isinstance(value, int) and value > 0 for value in token.values()),
                "numeric owner ids",
            )
            require(state["frame_owner"] in [0, token["game"]], "frame belongs to viewport world")
            require(state["viewport_size"] == [1152.0, 648.0], "full source viewport")
            images.append(stable_image(native / state["viewport_file"], [1152, 648]))
            require(
                state["draws"]
                and all(
                    draw["equal"] and draw["geometry_equal"] and draw["queue_after"] == 0
                    for draw in state["draws"]
                ),
                "production draw is pure",
            )
            require(
                all(draw["before"] == draw["after"] == state["save"] for draw in state["draws"]),
                "full save snapshots around draw",
            )
            if role in tokens:
                require(tokens[role] == token, "stable owner across modes and maps")
            else:
                tokens[role] = token
        require(
            row["states"][0]["owner"]["game"] != row["states"][1]["owner"]["game"],
            "distinct game owners",
        )
        require(
            row["states"][0]["owner"]["viewport"] != row["states"][1]["owner"]["viewport"],
            "distinct viewport owners",
        )
    same, moved, modes, entered, returned = data["rows"]
    require(
        same["states"][0]["player"] == same["states"][1]["player"]
        and same["states"][0]["camera"] == same["states"][1]["camera"],
        "same-camera comparison",
    )
    require(
        same["states"][0]["seconds"] != same["states"][1]["seconds"], "independent initial time"
    )
    require(
        moved["states"][0]["player"] != same["states"][0]["player"]
        and moved["states"][1]["player"] == same["states"][1]["player"],
        "only game viewport moves",
    )
    require(
        modes["states"][0]["editor"] and modes["states"][1]["pause"],
        "actual editor and manual pause",
    )
    require(
        modes["states"][0]["seconds"] == moved["states"][0]["seconds"]
        and modes["states"][1]["seconds"] == moved["states"][1]["seconds"],
        "editor and pause freeze own clocks",
    )
    require(
        same["states"][1]["save"] == moved["states"][1]["save"],
        "game movement does not alter preview save",
    )
    require(
        modes["states"][1]["save"] == with_pause_tutorial(moved["states"][1]["save"]),
        "preview records only its own pause tutorial",
    )
    require(
        modes["states"][1]["save"] == entered["states"][1]["save"] == returned["states"][1]["save"],
        "game map transitions do not alter preview save",
    )
    require(
        entered["states"][0]["location"] == "village_market"
        and entered["states"][1]["location"] == "overworld",
        "isolated map entry",
    )
    require(
        returned["states"][0]["location"] == returned["states"][1]["location"] == "overworld",
        "actual map return",
    )
    source = {name: digest(ROOT / name) for name in SOURCES}
    tree_hash = hashlib.sha256(
        "\n".join(f"{name}:{source[name]}" for name in sorted(source)).encode()
    ).hexdigest()
    return {
        "task": "VRENDER-009",
        "base_commit": data["base_commit"],
        "configuration": {
            "window": data["window"],
            "logical_viewport": data["logical_viewport"],
            "cases": CASES,
            "camera_contract": data["camera_contract"],
            "display": data["display"],
            "engine": data["engine"],
        },
        "source_tree_sha256": tree_hash,
        "sources": source,
        "owners": tokens,
        "native_cases": len(data["rows"]),
        "production_draws": sum(
            len(state["draws"]) for row in data["rows"] for state in row["states"]
        ),
        "full_save_pairs": sum(
            len(state["draws"]) for row in data["rows"] for state in row["states"]
        ),
        "performance_eligible": False,
        "full_map_accepted": False,
        "images": images,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    arguments = parser.parse_args()
    result = verify()
    if arguments.write:
        REPORT.mkdir(parents=True, exist_ok=True)
        (REPORT / "summary.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n"
        )
    print(json.dumps(result, ensure_ascii=False, indent=2))
