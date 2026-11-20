"""Сверяет PNG, отдельный HUD и независимые native render targets."""

from __future__ import annotations

import io
import json
from functools import cache
from typing import Any, cast

from PIL import Image, ImageChops

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison import contract
from tools.qa.world.lighting.comparison.assertions import require
from tools.qa.world.lighting.comparison.storage import Evidence


def image(raw: bytes, size: tuple[int, int]) -> Image.Image:
    """PNG проверяется по реальному формату/размеру и возвращает полный RGBA."""
    with Image.open(io.BytesIO(raw)) as source:
        require(source.format == "PNG" and source.size == size, "native PNG size/format")
        return cast(Image.Image, source.convert("RGBA"))


def channel_max(channel: Image.Image) -> int:
    """У канала L ровно одна пара extrema; RGB/alpha обрабатываются независимо."""
    return int(cast(tuple[float, float], channel.getextrema())[1])


def max_difference(a: Image.Image, b: Image.Image) -> int:
    """Учитывает каждый RGB и alpha канал, включая полностью прозрачные пиксели."""
    return max(channel_max(channel) for channel in ImageChops.difference(a, b).split())


@cache
def emitter_offset() -> tuple[float, float]:
    """Берёт фактическую опору/стекло неизменённого source-profile из принятого Git."""
    profile = json.loads(
        shared.git("show", contract.BASE + ":assets/game/locations/overworld/lamps/profile.json")
    )["views"]["south"]
    offsets = tuple(
        (float(profile["emitter"][i]) - float(profile["anchor"][i])) * 0.25 for i in range(2)
    )
    return offsets[0], offsets[1]


def light_geometry(light: dict[str, Any], context: dict[str, Any]) -> None:
    """Проверяет опору реального корпуса, а не одинаковую ошибку обеих световых реализаций."""
    ground = [768, 576] if context["location"] == "overworld" else [646, 470]
    require(light["ground"] == ground, "production lamp ground including renderer offset")
    require(light.get("production_ground_offset") == [0, 24], "actual production ground offset")
    offset = emitter_offset()
    emitter = [ground[i] + offset[i] for i in range(2)]
    expected = [(emitter[i] - context["camera"][i]) * context["zoom"] for i in range(2)]
    # Vector2/Transform2D используют float32; допуск относится только к координате, не к PNG.
    require(
        all(abs(a - b) < 0.001 for a, b in zip(light["center"], expected, strict=True)),
        "emitter projection does not match actual body",
    )


def frames(store: Evidence, key: str, capture: dict[str, Any]) -> list[dict[str, Any]]:
    """Сравнивает реальные изображения, камеру, saves и отдельный HUD всех режимов."""
    width = int(key)
    size = (width, width * 9 // 16)
    records = capture["frames"]
    require(set(records) == contract.FRAME_IDS, "frame matrix")
    summaries = []
    texture_rids = set()
    for room in contract.ROOMS:
        for minute in contract.MINUTES:
            prefix = f"{room}-{minute}-"
            baseline = records[prefix + "off"]
            off = image(store.read(key, "frames/" + baseline["file"]), size)
            baseline_hud = image(store.read(key, "frames/" + baseline["hud_file"]), size)
            for mode in contract.MODES:
                row = records[prefix + mode]
                require(
                    row["visible"] and row["focused"] and row["window"] == list(size),
                    "native frame visibility/focus/window",
                )
                for context_name in ["world_context", "hud_context"]:
                    context = row["before"][context_name]
                    require(
                        context["minutes"] == minute
                        and context["day"] == 2
                        and context["seed"] == 20261015,
                        "actual scene time/day/seed",
                    )
                    require(
                        context["weather"] == "clear" and not context["physics_processing"],
                        "actual frozen scene/weather",
                    )
                require(
                    row["before"] == row["after"] == baseline["before"],
                    "frame save/context changed",
                )
                require(
                    len(row["draws"]) == 2
                    and all(r["equal"] and r["geometry_equal"] for r in row["draws"]),
                    "actual draw callbacks",
                )
                light = row["light"]
                light_geometry(light, row["before"]["world_context"])
                require(
                    light["mode"] == mode
                    and light["center"] == baseline["light"]["center"]
                    and light["radius"] == baseline["light"]["radius"],
                    "light mode/geometry",
                )
                require(
                    light["enabled"] == (mode in ["local", "shadow"] and minute != 720),
                    "actual light enabled",
                )
                require(light["shadow_enabled"] == (mode == "shadow"), "actual shadow flag")
                require(
                    light["texture"] == [256, 256] and light["light_canvas_layer_range"] == [0, 0],
                    "texture/layer config",
                )
                texture_rids.add(light["texture_rid"])
                actual = image(store.read(key, "frames/" + row["file"]), size)
                hud = image(store.read(key, "frames/" + row["hud_file"]), size)
                require(max_difference(hud, baseline_hud) == 0, "HUD-only RGBA changed")
                opaque = baseline_hud.getchannel("A").point(lambda a: 255 if a == 255 else 0)
                difference = ImageChops.difference(actual, off)
                for channel in difference.split():
                    require(
                        channel_max(ImageChops.multiply(channel, opaque)) <= 1,
                        "full-frame opaque HUD changed",
                    )
                maximum = max_difference(actual, off)
                if minute == 720:
                    require(maximum == 0, "disabled daytime light changes pixels")
                elif mode != "off":
                    require(maximum > 0, "claimed enabled light has no actual pixel effect")
                summaries.append(
                    {
                        "case": prefix + mode,
                        "max_channel_difference_from_off": maximum,
                        "difference_bounds": difference.convert("RGB").getbbox(),
                    }
                )
    require(len(texture_rids) == 1, "light texture recreated between cases")
    return summaries


def viewports(store: Evidence, key: str, capture: dict[str, Any]) -> dict[str, Any]:
    """Выключение источника меняет только его настоящий независимый render target."""
    rows = capture["viewports"]
    require(set(rows) == {"both-local", "left-off", "right-off"}, "viewport control matrix")
    sizes = [(int(key), int(key) * 9 // 16), (960, 540)]
    reference = []
    for index, size in enumerate(sizes):
        row = rows["both-local"]["items"][index]
        reference.append(image(store.read(key, "frames/" + row["file"]), size))
    result = {}
    for mode, record in rows.items():
        require(len(record["items"]) == 2, "two viewport targets required")
        differences = []
        for index, size in enumerate(sizes):
            row = record["items"][index]
            light_geometry(row["light"], row["before"]["world_context"])
            require(
                row["size"] == list(size)
                and row["png_error"] == 0
                and row["before"] == row["after"],
                "viewport native target/state",
            )
            require(
                row["before"] == rows["both-local"]["items"][index]["before"],
                "viewport control changed scene",
            )
            actual = image(store.read(key, "frames/" + row["file"]), size)
            maximum = max_difference(actual, reference[index])
            own_off = mode == ("left-off" if index == 0 else "right-off")
            require(
                (maximum > 0) == own_off,
                "light leaked between viewports or no actual source effect",
            )
            differences.append(maximum)
        image(store.read(key, "frames/" + record["composite"]), sizes[0])
        result[mode] = {"max_difference": differences}
    return result
