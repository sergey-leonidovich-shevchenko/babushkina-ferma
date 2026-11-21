"""Проверяет фактические native capture, полные состояния, HUD и независимые viewport."""

from __future__ import annotations

import math
from typing import Any

from tools.qa.world.lighting.daycycle import contract as c
from tools.qa.world.lighting.daycycle import pixels
from tools.qa.world.lighting.daycycle.evidence import Evidence


def capture(store: Evidence, source: dict[str, Any], label: str, width: int) -> dict[str, Any]:
    """Проверяет фактический запуск официального движка, все состояния и несокращённые CPU samples."""
    prefix = f"{label}/{width}/"
    data: dict[str, Any] = store.document(prefix + "capture.json")
    run = source["variants"][label]["runs"][str(width)]
    launch = store.document(f"{label}/{width}.launch.json")
    c.need(
        launch["complete"]
        and launch["exit_code"] == 0
        and launch["command"][3:] == run["arguments"],
        "actual native launch differs",
    )
    log = store.read(f"{label}/{width}.txt").decode()
    c.need(
        "Godot Engine v4.7.1.stable.official.a13da4feb" in log
        and not any(s in log for s in ("SCRIPT ERROR", "ERROR:", "Parse Error")),
        "native engine log differs",
    )
    c.need(
        data["task"] == "VLIGHT-003" and data["engine"] == "4.7.1-stable (official)",
        "actual engine/task differs",
    )
    c.need(
        data["display"] == "X11" and data["renderer"] == "gl_compatibility",
        "actual native renderer differs",
    )
    c.need(
        data["size"] == [width, width * 9 // 16] and not data["failures"],
        "native size/failures differ",
    )
    c.need(
        data["profile"] == run["profile"]
        and data["user_dir"].endswith("/" + run["profile"])
        and run["profile"].startswith("Codex-VLIGHT-003-"),
        "effective profile differs",
    )
    c.need(
        data["arguments"] == run["arguments"][run["arguments"].index("--") + 1 :],
        "actual native arguments differ",
    )
    c.need(
        data["gpu_time_measured"] is False and data["hardware_fps_acceptance"] is False,
        "false GPU/FPS claim",
    )
    c.need(
        data["baseline"] == (label == "baseline")
        and set(data["frames"]) == c.expected_frames(label == "baseline"),
        "frame matrix differs",
    )
    for name, row in data["frames"].items():
        c.need(
            row["file"] == name + ".png" and row["hud"] == name + "-hud.png",
            "frame/HUD filename differs",
        )
        c.need(row["before"] == row["after"], "draw mutated full state")
        c.need(
            len(row["draws"]) >= 2
            and all(
                d["equal"] and d["geometry_equal"] and d["before"] == d["after"]
                for d in row["draws"]
            ),
            "production callback mutated state",
        )
        image = store.image(prefix + row["file"], data["size"])
        layer = store.image(prefix + row["hud"], data["size"])
        pixels.hud(image, layer)
        c.need(
            row["before"]["geometry"]["physics_processing"] is False, "capture simulation is moving"
        )
        case, mode = name.rsplit("-", 1)
        minute = c.MINUTES[case.rsplit("-", 1)[1]]
        c.need(row["before"]["geometry"]["minutes"] == minute, "actual calendar minute differs")
        c.need(
            row["before"]["geometry"]["seed"] == c.SEED
            and row["before"]["save"]["world_loot_seed"] == c.SEED,
            "actual fixed seed differs",
        )
        c.need(row["before"]["legacy"] == (mode == "legacy"), "legacy flag differs")
        expected_location = (
            "cottage_interior"
            if case.startswith("home-")
            else ("village_market" if case.startswith("market-") else "overworld")
        )
        c.need(
            row["before"]["geometry"]["location"] == expected_location
            and row["before"]["geometry"]["day"] == (5 if case == "eclipse-night" else 2),
            "actual scene/day differs",
        )
        c.need(
            row["before"]["reference"]
            == (mode == "reference" and expected_location == "overworld"),
            "reference mode differs",
        )
        if case.startswith("street-"):
            pixels.geometry(row)
            if mode != "reference":
                c.need(
                    row["hidden"]
                    == {
                        target: name + "-" + target + "-hidden.png" for target in ("hero", "threat")
                    },
                    "independent target witnesses differ",
                )
    c.need(len(data["costs"]) == 9, "three repeats of each cost mode required")
    seen = set()
    for row in data["costs"]:
        key = (row["mode"], row["repeat"])
        c.need(
            key not in seen and row["mode"] in c.MODES and row["repeat"] in range(3),
            "cost repeat matrix differs",
        )
        seen.add(key)
        c.need(row["before"] == row["after"] and row["warmup"] == 20, "timing state/warmup differs")
        # У старого Git есть один визуальный dusk witness; все три timed режима
        # всё равно обязаны иметь его настоящую сцену и собственные реальные флаги.
        visual_mode = "palette" if label == "baseline" else row["mode"]
        visual = data["frames"]["street-dusk-" + visual_mode]["before"]
        c.need(
            all(row["before"][field] == visual[field] for field in ("geometry", "owner"))
            and row["before"]["legacy"] == (row["mode"] == "legacy")
            and row["before"]["reference"] == (row["mode"] == "reference"),
            "timed scene/mode differs from validated dusk visual context",
        )
        # Save сравнивается внутри timed before/after выше: подготовка предыдущих сцен
        # может законно отличать его от более раннего visual save.
        c.need(row["engine_max_fps"] == 0 and row["vsync"] == 0, "timing cap/vsync differs")
        for field in ("draw_us", "frame_us"):
            c.need(
                len(row[field]) == 60
                and all(type(v) in (int, float) and math.isfinite(v) and v > 0 for v in row[field]),
                "invalid/truncated native timing samples",
            )
        observations = row["observations"]
        c.need(len(observations) == 60, "truncated native frame observations")
        for index, sample in enumerate(observations):
            c.need(
                sample["window"] == data["size"]
                and sample["visible"] is True
                and type(sample["focused"]) is bool,
                "native frame window/visibility differs",
            )
            c.need(
                sample["engine_max_fps"] == 0 and sample["vsync"] == 0,
                "native frame cap/vsync differs",
            )
            if index:
                prior = observations[index - 1]
                c.need(
                    sample["process_frame"] > prior["process_frame"]
                    and sample["tick_us"] - prior["tick_us"] == row["frame_us"][index],
                    "native frame counter/timestamp did not advance",
                )
    return data


def twins(store: Evidence, width: int, data: dict[str, Any]) -> None:
    """Неизменённый соседний framebuffer побайтно сохраняется при локальном времени/откате."""
    rows = data["twins"]
    c.need(set(rows) == {"both", "first-legacy", "second-night"}, "twin matrix differs")
    for step, pair in rows.items():
        c.need(
            len(pair) == 2
            and pair[0]["before"]["owner"]["viewport"] != pair[1]["before"]["owner"]["viewport"],
            "shared viewport owner",
        )
        for index, row in enumerate(pair):
            c.need(
                row["file"] == f"twin-{step}-{index}.png"
                and row["size"] == ([1152, 648] if index == 0 else [960, 540]),
                "twin file/size differs",
            )
            c.need(
                row["before"] == row["after"] and row["png_error"] == 0, "twin state/image failure"
            )
            expected_minute = 1140 if index == 0 else (1320 if step == "second-night" else 720)
            c.need(
                row["before"]["geometry"]["minutes"] == expected_minute
                and row["before"]["legacy"] == (index == 0 and step != "both"),
                "twin calendar/flag differs",
            )

    def image(step: str, index: int) -> Any:
        row = rows[step][index]
        return store.image(f"candidate/{width}/" + row["file"], row["size"])

    c.need(
        pixels.equal(image("both", 1), image("first-legacy", 1)),
        "legacy color leaked to neighbouring viewport",
    )
    c.need(
        not pixels.equal(image("both", 0), image("first-legacy", 0)),
        "legacy flag had no local effect",
    )
    c.need(
        pixels.equal(image("first-legacy", 0), image("second-night", 0)),
        "calendar color leaked to neighbouring viewport",
    )
    c.need(
        not pixels.equal(image("first-legacy", 1), image("second-night", 1)),
        "second calendar had no local effect",
    )
