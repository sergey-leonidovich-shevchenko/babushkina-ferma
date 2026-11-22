"""Проверяет реальные исходники, целые PNG, обратимость и независимость visual rollback."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from tools.qa.world.rollback import contract as c
from tools.qa.world.weather.verify import Evidence


def check_run(store: Evidence, folder: str, candidate: bool, width: int) -> dict[str, str]:
    """Сопоставляет реальный framebuffer с состоянием игры и эффективным terrain canvas."""
    run = store.document(folder + "capture.json")
    c.need(run["task"] == "VCOMPAT-010" and not run["errors"], "failed native capture")
    c.need(
        run["display"] == "X11"
        and run["renderer"] == "gl_compatibility"
        and run["engine"] == "4.7.1-stable (official)",
        "not pinned native engine",
    )
    c.need(
        run["window"] == [width, width * 9 // 16] and run["performance_eligible"] is False,
        "wrong window or FPS claim",
    )
    c.need(
        re.fullmatch(r"Codex-VCOMPAT-010-[0-9a-f]{32}", run["profile"]) is not None,
        "wrong native profile",
    )
    c.need(run["user_dir"].endswith("/" + run["profile"]), "effective userdata differs")
    rows = run["frames"]
    c.need(
        len(rows) == len(c.FRAME_IDS) and {row["id"] for row in rows} == c.FRAME_IDS,
        "incomplete frame matrix",
    )
    frames = {row["id"]: row for row in rows}
    images = {}
    for name, row in frames.items():
        c.need(
            row["file"] == name + ".png" and row["visible"] is True, "aliased or invisible frame"
        )
        c.need(
            row["window"] == [width, width * 9 // 16] and row["draws"] >= 2,
            "missing window/callbacks",
        )
        size = (640, 360) if name.startswith(("twin-", "startup-")) else (width, width * 9 // 16)
        images[name] = c.digest(store.image(folder, row, size))
        state = row["before"]
        c.need(type(state["master"]) is bool, "master flag is not a bool")
        c.need(
            set(state["terrain"]) == set(c.TERRAIN_FLAGS)
            and all(type(value) is bool for value in state["terrain"].values()),
            "incomplete effective terrain flags",
        )
        c.need(
            state["processing"] is False and state["reference_mode"] is False,
            "simulation moving or narrow reference substitute",
        )
        owner = state["owner"]
        c.need(
            owner["game"] == state["game_id"]
            and owner["viewport"] == state["viewport_id"]
            and owner["background"] == state["background_id"],
            "wrong viewport owner",
        )
        c.need(state["save"]["location"] == state["location"], "save belongs to another world")
        c.need(
            type(state["save"].get("world_loot_seed")) is int
            and state["save"]["world_loot_seed"] == c.SEED,
            "capture lost the fixed world seed: " + name,
        )
        if state["location"] == "overworld" and candidate and state["master"] is False:
            c.need(
                all(value is False for value in state["terrain"].values()),
                "master off did not restore whole terrain",
            )
            c.need(state["water_layer"] is False, "new water layer survives rollback")
    for camera in c.CAMERAS:
        keys = [camera + "-" + suffix for suffix in ("on", "off", "restore")]
        states = [frames[key]["before"] for key in keys]
        c.need(
            [value["master"] for value in states] == [True, False, True], "wrong toggle sequence"
        )
        for field in ("save", "camera", "player", "location", "owner"):
            c.need(
                states[0][field] == states[1][field] == states[2][field],
                "rollback mutated " + field,
            )
        c.need(images[keys[0]] == images[keys[2]], "new visual version does not restore exactly")
        if candidate:
            c.need(
                images[keys[0]] != images[keys[1]],
                "off merely changed metadata without changing native output",
            )
        else:
            c.need(
                images[keys[0]] == images[keys[1]],
                "baseline no longer reproduces unwired master flag",
            )
            c.need(
                states[0]["terrain"] == states[1]["terrain"],
                "unexpected baseline terrain implementation",
            )
        if camera == "west-bank":
            c.need(
                states[0]["wind"]["active"] > 0 and states[2]["wind"]["active"] > 0,
                "missing real wind shader path",
            )
            c.need(
                states[1]["wind"]["active"] == 0 if candidate else states[1]["wind"]["active"] > 0,
                "wind fallback did not follow the master",
            )
    c.need(
        images["repeat-before"] == images["repeat-after"], "repeated rollback leaves stale output"
    )
    c.need(
        images["old-interior-on"] == images["old-interior-off"],
        "first-map flag changed the existing interior",
    )
    legacy = frames["old-interior-on"]["before"]["save"]
    c.need(
        legacy["coins"] == 41 and legacy["counts"]["wood"] == 14 and legacy["counts"]["apple"] == 2,
        "old slot progress changed",
    )
    c.need(
        images["twin-0-0"] == images["twin-1-1"] and images["twin-0-1"] == images["twin-1-0"],
        "one viewport changed its neighbor",
    )
    if candidate:
        c.need(
            images["twin-0-0"] != images["twin-0-1"],
            "twins did not have independent visual versions",
        )
    c.need(
        frames["twin-0-0"]["before"]["owner"] != frames["twin-0-1"]["before"]["owner"],
        "twins share owner token",
    )
    for name, expected in (("startup-on", True), ("startup-off", False)):
        state = frames[name]["before"]
        c.need(
            state["master_metadata"] is False
            and state["project_flag"] is expected
            and state["master"] is expected,
            "cold start substituted a local override",
        )
    c.need(
        images["startup-on"] == images["twin-0-0"] and images["startup-off"] == images["twin-0-1"],
        "cold project flag differs from real runtime rollback",
    )
    return images


def compare_gameplay(store: Evidence, width: int) -> None:
    """Сначала сверяет весь игровой ввод вариантов, даже когда разный лут не попал в кадр."""
    variants = {
        label: {
            row["id"]: row["before"]
            for row in store.document(f"{label}/{width}/capture.json")["frames"]
        }
        for label in ("baseline", "candidate")
    }
    for name in sorted(c.FRAME_IDS):
        for field in ("save", "camera", "player", "location"):
            c.need(
                variants["baseline"][name][field] == variants["candidate"][name][field],
                "baseline/candidate gameplay differs: " + name + "/" + field,
            )


def current_candidate(source: dict[str, Any], store: Evidence) -> None:
    """Позднейшие отчётные коммиты могут менять только SemVer, сохраняя весь снятый runtime/QA."""
    c.need(
        not c.git("status", "--porcelain", "--untracked-files=all"), "current candidate is dirty"
    )
    old = c.blobs(source["head"])
    now = c.blobs("HEAD")
    c.need(set(old) == set(now), "current runtime file set differs")
    pattern = rb'(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$'
    for name in old:
        if name == "VERSION":
            c.need(
                re.fullmatch(rb"[0-9]+\.[0-9]+\.[0-9]+\n?", c.git("show", "HEAD:VERSION"))
                is not None,
                "invalid SemVer",
            )
        elif name == "project.godot":
            before = c.git("show", source["head"] + ":" + name)
            after = c.git("show", "HEAD:" + name)
            c.need(
                len(re.findall(pattern, before)) == len(re.findall(pattern, after)) == 1,
                "missing project SemVer",
            )
            c.need(
                re.sub(pattern, b"<version>", before) == re.sub(pattern, b"<version>", after),
                "project changed beyond metadata",
            )
            c.need(
                re.findall(pattern, after)[0] == c.git("show", "HEAD:VERSION").strip(),
                "current project/VERSION disagree",
            )
        else:
            c.need(old[name] == now[name], "current runtime drift: " + name)
    for name in c.INPUTS:
        c.need(
            (c.ROOT / name).read_bytes() == store.read("inputs/" + name),
            "current QA drift: " + name,
        )


def check_launch(store: Evidence, name: str, label: str) -> None:
    """Сверяет реальный exit/log и effective userdata каждого импорта и нативного процесса."""
    launch = store.document(name)
    c.need(launch["complete"] is True and launch["exit_code"] == 0, "native launch failed")
    command = launch["command"]
    c.need(
        len(command) > 3
        and command[1] == "--path"
        and Path(command[2]).name == "project"
        and Path(command[2]).parent.name == label,
        "launch belongs to another project",
    )
    log = store.read(name.removesuffix(".launch.json") + ".txt").decode()
    c.need(
        not any(mark in log for mark in ("ERROR:", "SCRIPT ERROR", "Parse Error")),
        "engine log reports failure",
    )
    if name.endswith("-profile.launch.json"):
        profile = command[-1]
        c.need(
            re.fullmatch(r"Codex-VCOMPAT-010-[0-9a-f]{32}", profile) is not None
            and log.rstrip().endswith("/" + profile),
            "effective import/native profile differs",
        )


def verify(output: Path, expected_head: str, current: bool = False) -> dict[str, Any]:
    """Не доверяет счётчикам producer: проверяет Git closure, каждый файл и все пиксельные пары."""
    store = Evidence(output)
    source = store.document("source.json")
    c.need(
        source["hardware_fps_acceptance"] is False, "rollback evidence cannot accept hardware FPS"
    )
    c.need(set(source["variants"]) == {"baseline", "candidate"}, "source variant set differs")
    c.need(
        source["schema"] == 1 and source["task"] == "VCOMPAT-010" and source["complete"] is True,
        "incomplete source manifest",
    )
    c.need(source["head"] == expected_head and source["base"] == c.BASE, "wrong source head/base")
    c.need(re.fullmatch(r"[0-9a-f]{40}", expected_head) is not None, "full exact head required")
    c.git("merge-base", "--is-ancestor", c.BASE, expected_head)
    c.need(set(source["inputs"]) == set(c.INPUTS), "incomplete QA closure")
    for name, sha in source["inputs"].items():
        raw = store.read("inputs/" + name)
        c.need(
            c.digest(raw) == sha and raw == c.git("show", expected_head + ":" + name),
            "QA source differs: " + name,
        )
    c.need(set(source["artifacts"]) == c.artifacts(), "incomplete artifacts")
    for name, sha in source["artifacts"].items():
        c.need(c.digest(store.read(name)) == sha, "artifact changed: " + name)
    runs = {}
    profiles = []
    for label, commit in (("baseline", c.BASE), ("candidate", expected_head)):
        variant = source["variants"][label]
        c.need(
            variant["commit"] == commit
            and variant["tree"] == c.git("rev-parse", commit + "^{tree}").decode().strip(),
            "variant Git differs",
        )
        c.need(
            store.document(label + "/production-blobs.json") == c.blobs(commit),
            "production closure differs",
        )
        for name in c.artifacts():
            if name.startswith(label + "/") and name.endswith(".launch.json"):
                check_launch(store, name, label)
        for width in c.WIDTHS:
            folder = f"{label}/{width}/"
            run = store.document(folder + "capture.json")
            c.need(
                run["profile"] == variant["runs"][str(width)]["profile"],
                "launch/capture profile mismatch",
            )
            arguments = variant["runs"][str(width)]["arguments"]
            launch = store.document(f"{label}/{width}.launch.json")
            c.need(
                launch["command"][3:] == arguments and "--headless" not in arguments,
                "native command differs from recorded run",
            )
            c.need(
                arguments.count("--profile=" + run["profile"]) == 1
                and arguments.count("--windowed") == 1
                and arguments[arguments.index("--script") + 1]
                == "res://" + c.PREFIX + "capture.gd",
                "native argv/profile/script differs",
            )
            log = store.read(f"{label}/{width}.txt").decode().splitlines()
            c.need(
                all(log.count("ROLLBACK FRAME " + name) == 1 for name in c.FRAME_IDS),
                "capture log lacks the complete frame matrix",
            )
            profiles.append(run["profile"])
            runs[label, width] = check_run(store, folder, label == "candidate", width)
    c.need(len(set(profiles)) == 4, "reused userdata")
    for width in c.WIDTHS:
        compare_gameplay(store, width)
        for name in sorted(c.FRAME_IDS):
            if (
                name.endswith("-on")
                or name.endswith("-restore")
                or name in ("repeat-before", "repeat-after", "twin-0-0", "twin-1-1")
            ):
                c.need(
                    runs["baseline", width][name] == runs["candidate", width][name],
                    "default rendering changed: " + name,
                )
    if current:
        current_candidate(source, store)
    return {
        "task": "VCOMPAT-010",
        "head": expected_head,
        "native_png": 4 * len(c.FRAME_IDS),
        "runs": 4,
        "reversible": True,
        "baseline_unwired_reproduced": True,
        "performance_eligible": False,
    }


def main() -> None:
    """Проверяет fresh output либо неизменённый распакованный CI-архив без запуска игры."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(verify(args.output, args.expected_head, args.check_current_candidate), indent=2)
    )


if __name__ == "__main__":
    main()
