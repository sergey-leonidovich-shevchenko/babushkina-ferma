"""Сверяет actual framebuffer, полный save, независимых владельцев и действительные режимы."""

from __future__ import annotations

from typing import Any

from PIL import Image

from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality import pixels, readings
from tools.qa.world.lighting.quality.evidence import Evidence


def same_game(left: dict[str, Any], right: dict[str, Any]) -> None:
    """Различаться могут только private render-profile и identity другого процесса."""
    for field in ("save", "geometry", "seed", "entities"):
        c.need(left[field] == right[field], "full cross-profile gameplay differs: " + field)


def state(value: dict[str, Any], case: str, mode: str) -> None:
    """Часы, seed, полный save и owner читаются из действительной fixture, а не имени PNG."""
    room, time = case.split("-")
    minutes = {"day": 720, "dusk": 1140, "night": 1320}[time]
    location = "overworld" if room == "street" else "cottage_interior"
    c.need(
        value["profile"] == mode and value["seed"] == c.SEED,
        "effective light profile or seed differs",
    )
    c.need(
        value["save"]["world_loot_seed"] == c.SEED and value["geometry"]["seed"] == c.SEED,
        "saved/geometry seed differs",
    )
    c.need(
        value["save"]["minutes"] == value["geometry"]["minutes"] == minutes
        and value["save"]["day"] == 2,
        "actual calendar differs",
    )
    c.need(
        value["save"]["location"] == value["geometry"]["location"] == location
        and value["geometry"]["weather"] == "clear",
        "actual room/weather differs",
    )
    owner = value["owner"]
    c.need(
        set(owner) == {"game", "viewport", "background"}
        and len(set(owner.values())) == 3
        and all(isinstance(x, int) and x > 0 for x in owner.values()),
        "actual viewport owner missing/aliased",
    )


def capture(store: Evidence, source: dict[str, Any], label: str, width: int) -> dict[str, Any]:
    """Проверяет каждую настоящую пару; один зелёный screenshot не закрывает всю матрицу."""
    baseline = label == "baseline"
    prefix = f"{label}/{width}/"
    data = store.document(prefix + "capture.json")
    run = source["variants"][label]["runs"][str(width)]
    size = [width, width * 9 // 16]
    c.need(
        data["schema"] == 1
        and data["task"] == "VLIGHT-010"
        and data["baseline"] is baseline
        and not data["failures"],
        "native capture failed/incomplete",
    )
    c.need(
        data["engine"] == c.ENGINE
        and data["display"] == "X11"
        and data["renderer"] == "gl_compatibility"
        and bool(data["adapter"]),
        "actual renderer/official engine differs",
    )
    c.need(
        data["size"] == size
        and data["profile"] == run["profile"]
        and data["user_dir"].endswith("/" + run["profile"]),
        "actual size or userdata differs",
    )
    c.need(
        data["arguments"] == run["arguments"][run["arguments"].index("--") + 1 :],
        "actual engine user arguments differ",
    )
    c.need(
        data["gpu_time_measured"] is False and data["hardware_fps_acceptance"] is False,
        "unmeasured hardware/GPU acceptance",
    )
    c.need(set(data["frames"]) == c.frame_ids(baseline), "complete native frame matrix differs")
    signals: dict[str, Any] = {}
    last_frame, last_tick = -1, -1
    for case in c.CASES:
        reference = data["frames"][case + "-standard"]
        reference_hud = store.image(prefix + case + "-standard-hud.png", size)
        for mode in ("standard",) if baseline else c.MODES:
            name = case + "-" + mode
            row = data["frames"][name]
            c.need(
                row["file"] == name + ".png" and row["hud"] == name + "-hud.png",
                "frame filename does not match its case",
            )
            state(row["before"], case, mode)
            c.need(row["before"] == row["after"], "draw changed full actual state")
            same_game(reference["before"], row["before"])
            observed = row["observation"]
            c.need(
                observed["window"] == size
                and observed["visible"] is True
                and observed["focused"] is True,
                "physical frame came from inactive/resized window",
            )
            c.need(
                observed["process_frame"] > last_frame and observed["tick_us"] > last_tick,
                "capture reused a physical frame or nonadvancing clock",
            )
            last_frame, last_tick = observed["process_frame"], observed["tick_us"]
            c.need(
                len(row["draws"]) >= 2
                and all(
                    x["equal"] is True
                    and x["geometry_equal"] is True
                    and x["before"] == x["after"] == row["before"]["save"]
                    for x in row["draws"]
                ),
                "actual production draw changed gameplay",
            )
            draw_frames = [x["process_frame"] for x in row["draws"]]
            c.need(
                all(a < b for a, b in zip(draw_frames, draw_frames[1:], strict=False))
                and draw_frames[-1] <= last_frame,
                "actual observed draws did not advance before readback",
            )
            pixels.geometry(row, case)
            root, hud = (
                store.image(prefix + row["file"], size),
                store.image(prefix + row["hud"], size),
            )
            pixels.hud(root, hud)
            c.need(pixels.equal(reference_hud, hud), "profile changed actual same-time HUD")
            c.need(set(row["hidden"]) == set(c.TARGETS), "target controls incomplete")
            values = {}
            for target in c.TARGETS:
                expected = name + f"-{target}-hidden.png"
                c.need(row["hidden"][target] == expected, "wrong target-hidden frame")
                values[target] = pixels.target(
                    root, store.image(prefix + expected, size), row["targets"][target]["native"]
                )
            signals[name] = values
        if not baseline:
            standard = store.image(prefix + case + "-standard.png", size)
            low = store.image(prefix + case + "-low.png", size)
            off = store.image(prefix + case + "-off.png", size)
            if not case.endswith("day"):
                c.need(
                    not pixels.equal(standard, low) and not pixels.equal(low, off),
                    "low/off profiles did not change real lit pixels",
                )
            for target in c.TARGETS:
                c.need(
                    signals[case + "-low"][target] >= 0.75 * signals[case + "-standard"][target]
                    and signals[case + "-off"][target]
                    >= 0.75 * signals[case + "-standard"][target],
                    "low/off lost native target signal: " + case + "/" + target,
                )
    if baseline:
        c.need(
            data["restores"] == {} and data["twins"] == {},
            "baseline cannot claim new profile controls",
        )
    else:
        c.need(set(data["restores"]) == set(c.CASES), "standard return matrix incomplete")
        for case, row in data["restores"].items():
            state(row["before"], case, "standard")
            same_game(row["before"], data["frames"][case + "-standard"]["before"])
            c.need(
                row["before"] == row["after"] and row["file"] == case + "-restored.png",
                "return changed gameplay or file",
            )
            c.need(
                pixels.equal(
                    store.image(prefix + row["file"], size),
                    store.image(prefix + case + "-standard.png", size),
                ),
                "restoring standard did not return exact RGBA",
            )
        twins(store, data["twins"], prefix)
        bad = data["frames"]["street-dusk-standard"]
        c.need(
            bad["bad_hud"] == "street-dusk-standard-bad-hud.png",
            "native HUD negative control missing",
        )
        rejected = False
        try:
            pixels.hud(
                store.image(prefix + bad["bad_hud"], size), store.image(prefix + bad["hud"], size)
            )
        except ValueError:
            rejected = True
        c.need(rejected, "actual bad-HUD control was not rejected")
    for row in data["costs"]:
        state(row["before"], "street-night", row["mode"])
        same_game(data["costs"][0]["before"], row["before"])
    return {
        "capture": data,
        "signals": signals,
        "costs": readings.check(data["costs"], baseline, width),
    }


def twins(store: Evidence, rows: dict[str, Any], prefix: str) -> None:
    """Смена одного viewport не перекрашивает соседа; возврат точен в обоих framebuffer."""
    c.need(set(rows) == set(c.TWINS), "twin steps incomplete")
    sizes = [[1152, 648], [960, 540]]
    profiles = {
        "standard": ["standard", "standard"],
        "first-low": ["low", "standard"],
        "second-off": ["low", "off"],
        "restored": ["standard", "standard"],
    }
    for step in c.TWINS:
        c.need(len(rows[step]) == 2, "actual twin count differs")
        c.need(
            rows[step][0]["before"]["owner"]["viewport"]
            != rows[step][1]["before"]["owner"]["viewport"],
            "twin viewports alias",
        )
        for index, row in enumerate(rows[step]):
            state(
                row["before"], "street-night" if index == 0 else "home-night", profiles[step][index]
            )
            c.need(
                row["before"] == row["after"]
                and row["png_error"] == 0
                and row["size"] == sizes[index]
                and row["file"] == f"twin-{step}-{index}.png",
                "twin save/file/size differs",
            )
            same_game(row["before"], rows["standard"][index]["before"])

    def image(step: str, index: int) -> Image.Image:
        """Читает ровно соответствующий framebuffer независимого владельца."""
        return store.image(prefix + rows[step][index]["file"], sizes[index])

    c.need(
        pixels.equal(image("standard", 1), image("first-low", 1)),
        "first profile leaked to second viewport",
    )
    c.need(
        pixels.equal(image("first-low", 0), image("second-off", 0)),
        "second profile leaked to first viewport",
    )
    c.need(
        not pixels.equal(image("standard", 0), image("first-low", 0))
        and not pixels.equal(image("standard", 1), image("second-off", 1)),
        "twin light controls did not change actual pixels",
    )
    c.need(
        all(pixels.equal(image("standard", i), image("restored", i)) for i in range(2)),
        "twin return RGBA differs",
    )
