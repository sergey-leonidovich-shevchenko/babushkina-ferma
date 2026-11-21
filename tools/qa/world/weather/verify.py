"""Проверяет реальные паузы/пиксели и Git происхождение до/после, без приёмки FPS."""

from __future__ import annotations

import argparse
import io
import json
import math
import re
from pathlib import Path
from typing import Any

from PIL import Image

from tools.qa.world.weather import contract as c


class Evidence:
    """Читает только обычные файлы внутри отдельного evidence-каталога."""

    def __init__(self, root: Path) -> None:
        """Корень должен существовать; symlink не становится источником подтверждения."""
        c.need(not root.is_symlink(), "symlink evidence root")
        self.root = root.resolve(strict=True)

    def read(self, name: str) -> bytes:
        """Отказывает абсолютным путям, traversal и symlink любого компонента."""
        path = Path(name)
        c.need(not path.is_absolute() and ".." not in path.parts, "unsafe artifact path")
        target = self.root / path
        c.need(target.resolve().is_relative_to(self.root), "artifact escaped evidence")
        c.need(
            not any(p.is_symlink() for p in (target, *target.parents) if p != self.root.parent),
            "symlink artifact",
        )
        return target.read_bytes()

    def document(self, name: str) -> Any:
        """JSON читается из того же проверенного источника, не из current working tree."""
        return json.loads(self.read(name))

    def image(self, folder: str, row: dict[str, Any], size: tuple[int, int]) -> bytes:
        """Подтверждает PNG/framebuffer и настоящий callback, возвращает полные RGBA."""
        c.need(
            row["png_error"] == 0 and type(row["draws"]) is int and row["draws"] > 0,
            "missing successful draw",
        )
        c.need(row["before"] == row["after"], "draw mutated gameplay/phase/camera")
        c.need(tuple(row["size"]) == size, "declared framebuffer size differs")
        image = Image.open(io.BytesIO(self.read(folder + row["file"])))
        c.need(image.format == "PNG" and image.size == size, "actual PNG/framebuffer differs")
        return image.convert("RGBA").tobytes()


def check_run(store: Evidence, folder: str, candidate: bool, width: int) -> dict[str, Any]:
    """Сравнивает wall-time пары; фиксированные метаданные без одинаковых PNG не принимаются."""
    run = store.document(folder + "capture.json")
    c.need(run["task"] == "VWEATHER-001" and run["schema"] == 1, "capture task differs")
    c.need(run["display"] == "X11" and run["renderer"] == "gl_compatibility", "not native X11")
    c.need(run["engine"] == "4.7.1-stable (official)", "engine differs")
    c.need(run["window"] == [width, width * 9 // 16], "physical window differs")
    c.need(
        run["profile"].startswith("Codex-VWEATHER-001-")
        and run["user_dir"].endswith("/" + run["profile"]),
        "effective native userdata differs",
    )
    frames = run["frames"]
    c.need(set(frames) == c.FRAME_IDS and set(run["twins"]) == {"0", "1"}, "capture matrix differs")
    images = {}
    for key, row in frames.items():
        c.need(row["file"] == key + ".png", "frame alias differs")
        images[key] = store.image(folder, row, (width, width * 9 // 16))
        c.need(
            row["before"]["save"]["world_loot_seed"] == c.SEED, "producer lost the fixed world seed"
        )
        phase = row["before"]["phase"]
        c.need(
            type(phase) in (float, int)
            and math.isfinite(phase)
            and (phase >= 0 if candidate else phase == -1),
            "invalid numeric clock phase",
        )
        c.need(row["wall_end_usec"] >= row["wall_start_usec"], "wall interval invalid")
        expected_world = "cottage_interior" if key.endswith("-interior") else "overworld"
        c.need(row["before"]["world"] == expected_world, "frame belongs to the wrong location")
        expected_zoom = 1.0 if expected_world == "cottage_interior" else 1.2
        c.need(math.isclose(row["before"]["zoom"], expected_zoom), "actual location camera differs")
    for weather in c.WEATHERS:
        a, b = (frames[f"{weather}-pause-{suffix}"] for suffix in ("a", "b"))
        c.need(
            b["wall_start_usec"] - a["wall_end_usec"] >= 120_000,
            "pause lacks real wall-time interval",
        )
        c.need(a["before"] == b["before"], "paused state changed between callbacks")
        c.need(
            a["before"]["weather"] == weather and a["before"]["paused"],
            "wrong weather or no actual pause",
        )
        if candidate:
            c.need(
                images[f"{weather}-pause-a"] == images[f"{weather}-pause-b"],
                "weather pixels moved while paused",
            )
            c.need(math.isclose(a["before"]["phase"], 0.04), "paused physical phase differs")
            c.need(
                math.isclose(frames[f"{weather}-resume"]["before"]["phase"], 0.06),
                "resume accumulated wall-time debt",
            )
            for suffix in ("a", "b"):
                row = frames[f"{weather}-reduced-{suffix}"]
                c.need(
                    row["before"]["reduced"] and math.isclose(row["before"]["phase"], 0.06),
                    "reduced motion advanced weather",
                )
            c.need(
                images[f"{weather}-reduced-a"] == images[f"{weather}-reduced-b"],
                "reduced weather pixels moved",
            )
            c.need(
                frames[f"{weather}-interior"]["before"]["world"] == "cottage_interior"
                and frames[f"{weather}-interior"]["before"]["phase"] == 0,
                "actual interior entry or clock reset missing",
            )
            c.need(
                frames[f"{weather}-return"]["before"]["world"] == "overworld"
                and frames[f"{weather}-return"]["before"]["phase"] == 0,
                "return revived old weather visit",
            )
            c.need(
                images[f"{weather}-cold"] == images[f"{weather}-return"],
                "destination retains old particle phase",
            )
            if weather != "clear":
                c.need(
                    images[f"{weather}-cold"] != images["clear-cold"], "precipitation draw is empty"
                )
                c.need(
                    images[f"{weather}-resume"] != images[f"{weather}-pause-a"],
                    "resumed precipitation is permanently frozen",
                )
        elif weather != "clear":
            c.need(
                images[f"{weather}-pause-a"] != images[f"{weather}-pause-b"],
                "baseline does not reproduce the wall-clock defect",
            )
    if candidate:
        c.need(
            images["storm-reduced-a"] == images["rain-reduced-a"],
            "reduced motion retained a storm flash",
        )
    twin_pixels = {}
    owners = []
    for step in ("0", "1"):
        rows = run["twins"][step]
        c.need(len(rows) == 2, "missing real second viewport")
        for index, row in enumerate(rows):
            c.need(row["file"] == f"twin-{step}-{index}.png", "twin filename differs")
            twin_pixels[step, index] = store.image(folder, row, (640, 360))
            if step == "0":
                owners.append(row["before"]["owner"])
            if candidate:
                expected = 0.02 if index == 0 else (0.04 if step == "0" else 0.06)
                c.need(
                    math.isclose(row["before"]["phase"], expected),
                    "viewport clock leaked into neighbour",
                )
    c.need(
        all(owners[0][key] != owners[1][key] for key in ("game", "viewport", "background")),
        "viewport owners are shared",
    )
    c.need(
        all(
            type(owner[key]) is int and owner[key] > 0
            for owner in owners
            for key in ("game", "viewport", "background")
        ),
        "invalid native owner identity",
    )
    if candidate:
        c.need(twin_pixels["0", 0] == twin_pixels["1", 0], "first paused viewport moved")
        c.need(
            twin_pixels["0", 1] != twin_pixels["1", 1],
            "second viewport failed to move independently",
        )
    return {"frames": len(frames), "twins": 4, "baseline_defect": not candidate}


def check_current(source: dict[str, Any], store: Evidence) -> None:
    """Текущий чистый кандидат может отличаться от снятого runtime только SemVer-метаданными."""
    c.need(
        not c.git("status", "--porcelain", "--untracked-files=all"),
        "clean current candidate required",
    )
    old = c.blobs(source["head"])
    now = c.blobs("HEAD")
    c.need(set(old) == set(now), "current runtime file set differs")
    pattern = rb'(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$'
    for name, oid in old.items():
        if name == "VERSION":
            raw = c.git("show", "HEAD:VERSION")
            c.need(
                re.fullmatch(rb"[0-9]+\.[0-9]+\.[0-9]+\n", raw) is not None,
                "invalid current SemVer",
            )
        elif name == "project.godot":
            before = c.git("show", source["head"] + ":" + name)
            after = c.git("show", "HEAD:" + name)
            versions_before = re.findall(pattern, before)
            versions_after = re.findall(pattern, after)
            c.need(
                len(versions_before) == len(versions_after) == 1,
                "one project SemVer required",
            )
            c.need(
                re.sub(pattern, b'config/version="<metadata>"', before)
                == re.sub(pattern, b'config/version="<metadata>"', after),
                "current project changed beyond SemVer",
            )
            c.need(
                versions_after[0] == c.git("show", "HEAD:VERSION").strip(),
                "current version/config disagree",
            )
        else:
            c.need(now[name] == oid, "current runtime differs: " + name)
    for name in c.INPUTS:
        c.need(
            (c.ROOT / name).read_bytes() == store.read("inputs/" + name),
            "current QA differs from capture: " + name,
        )


def verify(output: Path, expected_head: str | None = None, current: bool = False) -> dict[str, Any]:
    """Полный manifest проверяется против настоящей истории, а затем против поведения и пикселей."""
    store = Evidence(output)
    source = store.document("source.json")
    c.need(
        isinstance(source.get("head"), str)
        and re.fullmatch(r"[0-9a-f]{40}", source["head"]) is not None,
        "full captured head SHA required",
    )
    c.need(
        source["schema"] == 1 and source["task"] == "VWEATHER-001" and source["complete"] is True,
        "incomplete source",
    )
    c.need(
        source["base"] == c.BASE and source["hardware_fps_acceptance"] is False,
        "wrong base or FPS claim",
    )
    c.need(expected_head is None or source["head"] == expected_head, "captured head differs")
    c.need(
        set(source["inputs"]) == set(c.INPUTS) and set(source["artifacts"]) == c.artifacts(),
        "source closure differs",
    )
    for name, sha in source["inputs"].items():
        raw = store.read("inputs/" + name)
        c.need(
            c.digest(raw) == sha and raw == c.git("show", source["head"] + ":" + name),
            "QA bytes differ from captured Git: " + name,
        )
    for name, sha in source["artifacts"].items():
        c.need(c.digest(store.read(name)) == sha, "artifact hash differs: " + name)
    if current:
        check_current(source, store)
    c.need(set(source["variants"]) == {"baseline", "candidate"}, "variant matrix differs")
    results = {}
    profiles = []
    for label, commit in (("baseline", c.BASE), ("candidate", source["head"])):
        variant = source["variants"][label]
        c.need(
            variant["commit"] == commit
            and variant["tree"] == c.git("rev-parse", commit + "^{tree}").decode().strip(),
            "variant is not captured Git tree",
        )
        c.need(
            store.document(label + "/production-blobs.json") == c.blobs(commit),
            "runtime inventory differs",
        )
        c.need(set(variant["runs"]) == {str(width) for width in c.WIDTHS}, "width matrix differs")
        for name in (
            "import-profile",
            "import",
            "compile",
            "1152-profile",
            "1280-profile",
            "1152",
            "1280",
        ):
            launch = store.document(f"{label}/{name}.launch.json")
            text = store.read(f"{label}/{name}.txt").decode()
            c.need(launch["complete"] and launch["exit_code"] == 0, "failed native/setup launch")
            c.need(
                "Godot Engine v4.7.1.stable.official.a13da4feb" in text
                and not any(mark in text for mark in ("ERROR:", "SCRIPT ERROR", "Parse Error")),
                "engine error in native/setup log",
            )
            c.need(
                ("--headless" in launch["command"]) == (name not in ("1152", "1280")),
                "headless used as native evidence",
            )
        for width in c.WIDTHS:
            row = variant["runs"][str(width)]
            profile = row["profile"]
            profiles.append(profile)
            log = store.read(f"{label}/{width}-profile.txt").decode()
            c.need(log.rstrip().endswith("/" + profile), "OS profile probe differs")
            run = store.document(f"{label}/{width}/capture.json")
            c.need(run["profile"] == profile, "native profile does not match its probe")
            c.need(
                run["arguments"] == row["arguments"][row["arguments"].index("--") + 1 :],
                "actual native arguments differ",
            )
            launch = store.document(f"{label}/{width}.launch.json")
            c.need(launch["command"][3:] == row["arguments"], "native argv differs from launch")
            c.need(
                "--profile=" + profile in row["arguments"] and "--resolution" in row["arguments"],
                "missing native profile or window argv",
            )
            results[label, width] = check_run(
                store, f"{label}/{width}/", label == "candidate", width
            )
    c.need(len(set(profiles)) == 4, "native profiles reused")
    for width in c.WIDTHS:
        old = store.document(f"baseline/{width}/capture.json")["frames"]
        new = store.document(f"candidate/{width}/capture.json")["frames"]
        for weather in c.WEATHERS:
            for key in ("save", "world", "weather", "camera", "player", "zoom"):
                c.need(
                    old[f"{weather}-full"]["before"][key] == new[f"{weather}-full"]["before"][key],
                    "baseline/candidate scene or gameplay differs: " + key,
                )
    return {
        "task": "VWEATHER-001",
        "head": source["head"],
        "native_png": 160,
        "runs": len(results),
        "hardware_fps_acceptance": False,
    }


def main() -> None:
    """CLI принимает только фактически сохранённый архив; синтетический PASS не создаётся."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-head")
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            verify(args.output, args.expected_head, args.check_current_candidate),
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
