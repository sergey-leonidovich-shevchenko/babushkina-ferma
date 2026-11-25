"""Сверяет кадры, видео, реальные переходы и результаты обоих профилей VRELEASE-003."""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
from pathlib import Path
from typing import Any, cast

from PIL import Image, ImageChops

from tools.qa.world.lighting.contract import git
from tools.qa.world.moving_pilot.collect import (
    FIXTURE,
    MODES,
    TASK,
    WIDTHS,
    digest,
    require,
    source_inputs,
)

Row = dict[str, Any]
ROUTE = (
    "idle",
    "grass",
    "bank",
    "bridge-approach",
    "bridge-north",
    "bridge-rail",
    "bridge-crossing",
    "pause",
    "resume",
    "teleport-menu-cottage_interior",
    "teleport-arrival-cottage_interior",
    "interior",
    "exit-door",
    "outside",
    "enter-door",
    "returned-interior",
    "teleport-menu-overworld",
    "teleport-arrival-overworld",
    "returned-overworld",
    "legacy-interior",
    "legacy-exit",
    "rollback-on",
    "rollback-off",
    "rollback-restored",
)
LANDINGS = {
    "teleport-arrival-cottage_interior": "cottage_interior",
    "outside": "overworld",
    "returned-interior": "cottage_interior",
    "teleport-arrival-overworld": "overworld",
    "legacy-interior": "cottage_interior",
    "rollback-on": "overworld",
}

PAIR_FIELDS = (
    "label",
    "tick",
    "location",
    "player",
    "ground",
    "facing",
    "camera",
    "zoom",
    "minutes",
    "hp",
    "save_sha256",
)


def paired_trace(rows: list[Row]) -> list[tuple[Any, ...]]:
    return [tuple(row[key] for key in PAIR_FIELDS) for row in rows]


def read_json(path: Path) -> Any:
    return json.loads(path.read_bytes())


def image(path: Path, size: tuple[int, int]) -> Image.Image:
    with Image.open(path) as png:
        require(png.format == "PNG" and png.size == size, f"unexpected framebuffer {path}")
        return cast(Image.Image, png.convert("RGB"))


def regional_difference(folder: Path, rows: list[Row], size: tuple[int, int], key: str) -> bool:
    x, y, w, h = rows[0]["regions"][key]
    box = (math.ceil(x), math.ceil(y), math.floor(x + w), math.floor(y + h))
    require(
        0 <= box[0] < box[2] <= size[0] and 0 <= box[1] < box[3] <= size[1],
        f"{key} geometry outside framebuffer: {box}",
    )
    require(
        all(row["regions"][key] == rows[0]["regions"][key] for row in rows), f"{key} camera moved"
    )
    first = image(folder / rows[0]["file"], size).crop(box)
    return any(
        ImageChops.difference(first, image(folder / r["file"], size).crop(box)).getbbox()
        for r in rows[1:]
    )


def verify_video(folder: Path, size: tuple[int, int], count: int) -> None:
    stdout = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-count_frames",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height,r_frame_rate,nb_read_frames",
            "-of",
            "json",
            str(folder / "route.mp4"),
        ],
        timeout=120,
    )
    entries = json.loads(stdout)["streams"]
    require(len(entries) == 1, "expected one video stream")
    stream = entries[0]
    require(
        (stream["width"], stream["height"]) == size
        and stream["r_frame_rate"] == "10/1"
        and int(stream["nb_read_frames"]) == count,
        "video geometry, rate or decoded frame count differs",
    )


def verify_run(
    folder: Path, width: int, mode: str, profile: str, legacy_sha: str
) -> tuple[list[Row], dict[str, bool]]:
    capture = read_json(folder / "capture.json")
    size = (width, width * 9 // 16)
    require(
        capture["task"] == TASK
        and capture["schema"] == 1
        and capture["mode"] == mode
        and capture["profile"] == profile
        and re.fullmatch(rf"Codex-{TASK}-{width}-{mode}-[0-9a-f]{{32}}", profile)
        and capture["display"] == "X11"
        and capture["rendering_method"] == "gl_compatibility"
        and capture["engine"] == "4.7.1-stable (official)"
        and tuple(capture["window"]) == size
        and capture["seed"] == 20261015
        and capture["physics_hz"] == 30
        and capture["video_hz"] == 10
        and not capture["errors"]
        and capture["legacy_valid"]
        and capture["legacy_sha256"] == legacy_sha,
        f"invalid capture metadata: {width}/{mode}",
    )
    rows: list[Row] = capture["frames"]
    require(
        tuple(dict.fromkeys(row["label"] for row in rows)) == ROUTE, "incomplete or unordered route"
    )
    groups = {label: [r for r in rows if r["label"] == label] for label in ROUTE}
    for index, row in enumerate(rows):
        require(row["file"] == f"frames/{index:04}.png", "frame index differs")
        require(row["native_draws"] >= 2, "stale native capture")
        if index:
            require(row["tick"] >= rows[index - 1]["tick"], "simulation trace moved backwards")
        image(folder / row["file"], size)
    require(len(list((folder / "frames").glob("*.png"))) == len(rows), "unexpected PNG")
    verify_video(folder, size, len(rows))
    for label, world in LANDINGS.items():
        require(all(row["location"] == world for row in groups[label]), f"wrong world: {label}")
    require(
        all(
            row["teleport_open"]
            for label in ROUTE
            if label.startswith("teleport-menu-")
            for row in groups[label]
        )
        and all(
            not groups[label][0]["teleport_open"]
            for label in LANDINGS
            if label.startswith("teleport-arrival-")
        ),
        "teleport modal did not close at the destination",
    )
    for label in ("idle", "pause"):
        require(len(groups[label]) >= 10, f"too few {label} frames")
    pause = groups["pause"]
    frozen = ("world_seconds", "water_phase", "minutes", "player", "camera", "save_sha256")
    require(
        all(r["paused"] and all(r[k] == pause[0][k] for k in frozen) for r in pause),
        "pause advanced the world or changed the save",
    )
    resume = groups["resume"][0]
    elapsed = (resume["tick"] - pause[-1]["tick"]) / 30
    expected_seconds = pause[-1]["world_seconds"] + (elapsed if mode == "live" else 0.0)
    require(
        not resume["paused"]
        and math.isclose(resume["world_seconds"], expected_seconds, abs_tol=1e-8)
        and math.isclose(resume["minutes"] - pause[-1]["minutes"], elapsed, abs_tol=1e-8),
        "pause did not resume normally",
    )
    crossing_labels = ("bridge-north", "bridge-rail", "bridge-crossing")
    walk_labels = ("idle", "grass", "bank", "bridge-approach", *crossing_labels)
    walk = [row for label in walk_labels for row in groups[label]]
    require(
        all(row["location"] == "overworld" and row["hp"] == walk[0]["hp"] for row in walk),
        "the outdoor walk experienced combat or an unexpected transition",
    )
    crossing = [row for label in crossing_labels for row in groups[label]]
    require(
        sum(bool(row["bridge_deck"] and row["rail_split"]) for row in crossing) >= 8
        and crossing[-1]["player"][1] - crossing[0]["player"][1] > 190,
        "hero did not pass the bridge in the foreground-rail route",
    )
    require(
        any(
            row["bridge_deck"]
            and row["rail_split"]
            and row["facing"] == [-1, 0]
            and 1578 <= row["ground"][0] <= 1583
            for row in groups["bridge-rail"]
        ),
        "hero did not face the foreground rail at the edge of the passage",
    )
    rollback = [groups[f"rollback-{state}"][0] for state in ("on", "off", "restored")]
    require([r["modern"] for r in rollback] == [True, False, True], "visual rollback flag")
    for key in ("location", "player", "ground", "camera", "zoom", "minutes", "save_sha256"):
        require(all(r[key] == rollback[0][key] for r in rollback), f"rollback changed {key}")
    initial, disabled, restored = [image(folder / row["file"], size) for row in rollback]
    require(
        ImageChops.difference(initial, disabled).getbbox(), "rollback did not reach native pixels"
    )
    require(
        ImageChops.difference(initial, restored).getbbox() is None,
        "restore differs in native pixels",
    )
    idle = groups["idle"]
    grass = regional_difference(folder, idle, size, "grass")
    water = regional_difference(folder, idle, size, "water")
    if mode == "live":
        require(
            grass and water and all(r["grass"]["active"] and r["water_animated"] for r in idle),
            "live water or grass did not render native motion",
        )
    else:
        require(
            not grass
            and not water
            and all(
                r["grass"]["active"] == 0 and r["water_visible"] and not r["water_animated"]
                for r in idle
            ),
            "stationary fallback still animates or hides the water layer",
        )
    return rows, {"grass_moves": grass, "water_moves": water, "rollback_pixels_restored": True}


def verify(folder: Path, head: str) -> dict[str, Any]:
    source = read_json(folder / "source.json")
    require(
        source["task"] == TASK
        and source["schema"] == 1
        and source["complete"]
        and source["head"] == head
        and source["tree"] == git("rev-parse", head + "^{tree}").decode().strip()
        and source["version"] == git("show", head + ":VERSION").decode().strip()
        and source["inputs"] == source_inputs(head),
        "archive does not match the declared Git revision",
    )
    files = {
        str(path.relative_to(folder)): digest(path.read_bytes())
        for path in folder.rglob("*")
        if path.is_file()
        and path.name != "source.json"
        and not path.is_relative_to(folder / "userdata")
    }
    require(files == source["artifacts"], "missing or changed archive member")
    require(
        set(source["runs"]) == {f"{w}/{m}" for w in WIDTHS for m in MODES}, "incomplete mode matrix"
    )
    legacy_sha = digest(git("show", f"{head}:{FIXTURE}"))
    result = {}
    for width in WIDTHS:
        modes = {}
        for mode in MODES:
            key = f"{width}/{mode}"
            profiles = source["runs"][key]
            require(profiles["capture"] == key + "/capture.json", "unexpected capture path")
            rows, pixels = verify_run(folder / key, width, mode, profiles["profile"], legacy_sha)
            modes[mode] = rows
            result[key] = {"frames": len(rows), **pixels}
        require(
            paired_trace(modes["live"]) == paired_trace(modes["static"]),
            f"live and static route, camera, or save differs at {width}",
        )
    return {
        "task": TASK,
        "head": head,
        "tree": source["tree"],
        "version": source["version"],
        "native_routes": result,
        "paired_camera_and_save": True,
        "performance_eligible": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-head", required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.output, args.expected_head), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
