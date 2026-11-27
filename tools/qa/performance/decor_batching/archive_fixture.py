"""Synthetic fixed frames and metadata for the offline archive reader control."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from tools.qa.performance.decor_batching import native_contract as contract
from tools.qa.performance.decor_batching import native_verify as native
from tools.qa.performance.decor_batching import verify as geometry
from tools.qa.performance.pass_cost import contract as shared

PRESET = {
    "ground_split": True,
    "local_terrain_updates": True,
    "water_bottom_trim_decks": True,
    "water_surface_trim_decks": True,
    "window_mode": 0,
}


def command(script: str) -> list[str]:
    return [
        "godot",
        "--display-driver",
        "x11",
        "--windowed",
        "--resolution",
        "1152x648",
        "--rendering-method",
        "gl_compatibility",
        "--audio-driver",
        "Dummy",
        "--script",
        f"res://{contract.DIRECTORY}/{script}",
        "--",
    ]


def receipt(folder: Path, run: native.Data, variant: str, args: list[str]) -> None:
    shared.write(
        folder / "launch.json",
        {
            "pid": run["pid"],
            "profile": run["profile"],
            "variant": variant,
            "exit_code": 0,
            "timeout": False,
            "command": args,
        },
    )


def fixed_state(spec: native.Data) -> native.Data:
    x, y = spec["player"]
    day = spec.get("day", 1)
    state = {
        "window": list(geometry.WINDOW),
        "framebuffer": list(geometry.WINDOW),
        "player": [x, y],
        "camera": list(native.warm.projected_camera(x, y)),
        "focus": True,
        "zoom_percent": 120,
        "terrain_ready": True,
        "day": day,
        "minutes": 780,
        "seed": 20261015,
        "light_standard": True,
        "reduced_motion": True,
        "reference_effects": False,
        "physics_processing": False,
        "vsync_requested": 1,
        "vsync": 1,
        "preset": PRESET,
        "season": "winter" if day == 22 else "spring",
    }
    if "prop" in spec:
        state.update(
            prop_anchor=spec["anchor"],
            prop_front=spec["front"],
            hero_body=[x - 25, y - 84, 50, 83],
            sprite=[x - 35, y - 45, 70, 45],
        )
    if day == 22:
        state["winter_batches"] = []
    return state


def fixed_samples(spec: native.Data) -> list[native.Data]:
    full = spec["phase"] == "full_refresh"
    local = spec["phase"] == "local_refresh"
    steps = {
        "requests": int(full),
        "revision": int(full or local),
        "full_paints": int(full),
        "local_paints": int(local),
    }
    samples = []
    for index in range(contract.REPETITIONS):
        start = 10000 * index + 1
        repaint = spec["repaint"] or list(geometry.WORLD)
        before = {
            key: BOOTSTRAP["after"][key] + index * increase for key, increase in steps.items()
        }
        after = {key: value + steps[key] for key, value in before.items()}
        samples.append(
            {
                "before": {**before, "last_completed": repaint if index else list(geometry.WORLD)},
                "after": {**after, "last_completed": repaint},
                "previous_draw_usec": start,
                "requested_usec": start + 1,
                "submitted_usec": start + 2,
                "presented_usec": start + 5000,
                "draw_calls": 30,
                "terrain_draw_calls": 15 if full or local else None,
                "static_bytes": 1024,
                "texture_bytes": 512,
            }
        )
    return samples


START_CACHE: native.Data = {
    "revision": 1,
    "requests": 1,
    "full_paints": 1,
    "local_paints": 0,
    "last_completed": list(geometry.WORLD),
}
BOOTSTRAP: dict[str, native.Data] = {
    "before": START_CACHE,
    "requested": {**START_CACHE, "revision": 2, "requests": 2},
    "after": {**START_CACHE, "revision": 2, "requests": 2, "full_paints": 2},
}


def write_frame(
    folder: Path,
    label: str,
    variant: str,
    draw_id: int,
    camera: list[float],
    revision: int,
    window: Image.Image,
    terrain: Image.Image | None = None,
) -> native.Data:
    # Fixtures vary between views. The per-variant one-code RGB change stays within the paired gate.
    colors = {"baseline": 24, "one_batch": 25, "spatial_batches": 23}
    hashes = {}
    for kind, image in (("window", window), ("terrain", terrain)):
        if image is None:
            continue
        image.putpixel((0, 0), (40 + draw_id, 30, 34, 255))
        image.putpixel((1, 0), (colors[variant], 30, 34, 255))
        filename = f"{label}-terrain.png" if kind == "terrain" else f"{label}.png"
        path = folder / filename
        image.save(path)
        hashes[kind] = shared.digest(path)
    return {
        "view": label,
        "variant": variant,
        "draw_id": draw_id,
        "usec": draw_id * 200_000,
        "camera": camera,
        "terrain_revision": revision,
        "sha256": hashes,
    }


def write_fixed(root: Path, historical: Path) -> None:
    plan = contract.plan()
    replay = geometry.replay(geometry.flowers())
    run = shared.read(historical / "repeat-1/baseline/run.json")
    display = {key: run[key] for key in ("display", "driver", "adapter", "engine_build")}
    window = Image.new("RGBA", geometry.WINDOW, (24, 30, 34, 255))
    terrain = Image.new("RGBA", geometry.WORLD[2:], (24, 30, 34, 255))
    for index, variant in enumerate(geometry.VARIANTS, 1):
        folder = root / "fixed" / variant
        folder.mkdir(parents=True)
        data: native.Data = {
            **display,
            "complete": True,
            "variant": variant,
            "pid": 99990 + index,
            "profile": f"Codex-VPERF-003-{index:032x}",
            "bootstrap": BOOTSTRAP,
            "cases": {},
            "overlap": {},
        }
        draw = 0
        for spec in plan["cases"]:
            draw += 1
            label = spec["id"]
            state = fixed_state(spec)
            samples = fixed_samples(spec)
            revision = samples[-1]["after"]["revision"]
            frame = write_frame(
                folder, label, variant, draw, state["camera"], revision, window, terrain
            )
            data["cases"][label] = {
                "state": state,
                "geometry": replay[label][variant],
                "samples": samples,
                "frame": frame,
            }
        for spec in plan["overlap"]:
            draw += 1
            label = spec["id"]
            state = fixed_state(spec)
            frame = write_frame(folder, label, variant, draw, state["camera"], draw, window)
            data["overlap"][label] = {"state": state, "frame": frame}
        if variant == "baseline":
            camera: list[float] = [648, 466]
            data.update(negative_hero_body=[1103, 652, 50, 83], negative_camera=camera)
            wrong = window.copy()
            wrong.putpixel((576, 300), (250, 30, 34, 255))
            data["negative_frames"] = {
                label: write_frame(folder, label, variant, draw + step, camera, draw, image)
                for step, (label, image) in enumerate(
                    (("flower-order-correct", window), ("flower-order-wrong", wrong)), 1
                )
            }
        shared.write(folder / "fixed.json", data)
        receipt(folder, data, variant, command("fixed_capture.gd"))
        for name in ("stdout.txt", "engine.log", "cpu-rss.json"):
            (folder / name).touch()
