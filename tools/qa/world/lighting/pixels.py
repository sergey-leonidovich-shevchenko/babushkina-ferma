"""Проверяет настоящие PNG, отдельный HUD и независимость двух native render target."""

from __future__ import annotations

import io
import math
import statistics
from typing import Any, cast

from PIL import Image, ImageChops, ImageDraw

from tools.qa.world.lighting.storage import Artifacts


def picture(artifacts: Artifacts, name: str, size: tuple[int, int]) -> Image.Image:
    """Размер проверяется по заголовку до выделения RGBA-буфера."""
    with Image.open(io.BytesIO(artifacts.read(name))) as image:
        if image.format != "PNG" or image.size != size:
            raise ValueError("native PNG dimensions/format: " + name)
        return cast(Image.Image, image.convert("RGBA"))


def changed_mask(left: Image.Image, right: Image.Image) -> Image.Image:
    """Не теряет малые RGB-разности при округлении яркости или одинаковой alpha."""
    channels = ImageChops.difference(left, right).split()
    result = channels[0]
    for channel in channels[1:]:
        result = ImageChops.lighter(result, channel)
    return result.point(lambda value: 255 if value else 0)


def state_check(frame: dict[str, Any], label: str) -> None:
    """Сравнивает сами snapshots, а не только положительные флаги, записанные producer."""
    if frame["before"] != frame["after"]:
        raise ValueError(label + ": saved state changed")
    if len(frame["draws"]) != 2:
        raise ValueError(label + ": two real callbacks required")
    for draw in frame["draws"]:
        if not draw["equal"] or not draw["geometry_equal"]:
            raise ValueError(label + ": draw changed state/geometry")
        if draw["before"] != draw["after"] or draw["geometry_before"] != draw["geometry_after"]:
            raise ValueError(label + ": inconsistent draw snapshots")


def compare_frame(
    artifacts: Artifacts, width: int, name: str, captures: dict[str, Any]
) -> dict[str, Any]:
    """Прибор on обязан совпасть с production; off меняет только заявленные области света."""
    size = (width, width * 9 // 16)
    images = {
        variant: picture(artifacts, f"{width}-{variant}/frames/{name}.png", size)
        for variant in captures
    }
    baseline = captures["production"]["frames"][name]
    hud = picture(artifacts, f"{width}-production/frames/{name}-hud.png", size)
    baseline_hud = hud.tobytes()
    histogram = hud.getchannel("A").histogram()
    if histogram[0] == 0 or histogram[255] == 0:
        raise ValueError(name + ": native transparent HUD target required")
    if images["production"].tobytes() != images["on"].tobytes():
        raise ValueError(name + ": instrumentation changed production RGBA")
    # Прозрачный HUD сам по себе не доказывает порядок слоёв полного production-кадра.
    # В непрозрачных областях UI нижний мир не должен просвечивать при on/off.
    opaque_hud = hud.getchannel("A").point(lambda value: 255 if value == 255 else 0)
    difference = ImageChops.difference(images["on"], images["off"])
    hud_max = max(
        cast(tuple[int, int], ImageChops.multiply(channel, opaque_hud).getextrema())[1]
        for channel in difference.split()
    )
    if hud_max > 1:
        raise ValueError(name + ": lighting contaminated opaque HUD in full production frame")
    for variant, capture in captures.items():
        frame = capture["frames"][name]
        state_check(frame, name + ":" + variant)
        if frame["snapshot"] != baseline["snapshot"] or frame["before"] != baseline["before"]:
            raise ValueError(name + ": comparison scene/camera/state differs")
        hud = picture(artifacts, f"{width}-{variant}/frames/{name}-hud.png", size)
        if frame["hud"]["before"] != frame["hud"]["after"]:
            raise ValueError(name + ": HUD mutated save")
        if hud.tobytes() != baseline_hud:
            raise ValueError(name + ": lighting contaminated HUD RGBA")
    enabled = captures["on"]["frames"][name]["calls"]
    disabled = captures["off"]["frames"][name]["calls"]
    if [(row["owner"], row["rect"]) for row in enabled] != [
        (row["owner"], row["rect"]) for row in disabled
    ]:
        raise ValueError(name + ": light geometry changed across modes")
    allowed = Image.new("L", size)
    painter = ImageDraw.Draw(allowed)
    for row in enabled:
        if row["off"]:
            raise ValueError(name + ": enabled call was disabled")
        values = row["rect"]
        if len(values) != 4 or not all(math.isfinite(value) for value in values):
            raise ValueError("invalid light bounds")
        x, y, w, h = values
        painter.rectangle(
            (math.floor(x) - 2, math.floor(y) - 2, math.ceil(x + w) + 2, math.ceil(y + h) + 2),
            fill=255,
        )
    if any(not row["off"] for row in disabled):
        raise ValueError(name + ": off switch did not reach a light call")
    mask = changed_mask(images["on"], images["off"])
    if ImageChops.multiply(mask, ImageChops.invert(allowed)).getbbox() is not None:
        raise ValueError(name + ": off changed pixels outside lighting bounds")
    changed = size[0] * size[1] - mask.histogram()[0]
    is_day_exterior = name.endswith("-720") and not name.startswith("home-")
    if (changed == 0) != is_day_exterior:
        raise ValueError(name + ": missing light effect or unrelated daytime change")
    return {
        "id": name,
        "changed_pixels": changed,
        "light_calls": len(enabled),
        "production_equal": True,
        "HUD_equal": True,
        "opaque_HUD_max_delta": hud_max,
    }


def state_paths(left: Any, right: Any, prefix: str = "") -> list[str]:
    """Показывает различие прогретого CPU-контекста и раннего кадра, не скрывая поля save."""
    if left == right:
        return []
    if isinstance(left, dict) and isinstance(right, dict):
        result = []
        for key in sorted(set(left) | set(right)):
            path = prefix + ("." if prefix else "") + key
            if key not in left or key not in right:
                result.append(path)
            else:
                result.extend(state_paths(left[key], right[key], path))
        return result
    return [prefix]


def costs(capture: dict[str, Any]) -> dict[str, Any]:
    """Возвращает измеренную разницу CPU submission; отрицательная/шумная разница не скрывается."""
    rows = capture["costs"]
    expected = {
        (group, repeat, off)
        for group in ("west-lamp", "home")
        for repeat in (1, 2, 3)
        for off in (False, True)
    }
    if len(rows) != 12 or {(row["group"], row["repeat"], row["off"]) for row in rows} != expected:
        raise ValueError("CPU on/off repeat inventory")
    samples: dict[tuple[str, bool], list[int]] = {}
    saved: dict[str, Any] = {}
    for row in rows:
        values = row["samples_us"]
        frame_id = row["group"] + ("-1320" if row["group"] == "west-lamp" else "-720")
        saved.setdefault(row["group"], row["before"])
        if row["before"] != saved[row["group"]]:
            raise ValueError("CPU on/off/repeat saved state differs")
        if (
            row["snapshot"] != row["snapshot_after"]
            or row["snapshot"] != capture["frames"][frame_id]["snapshot"]
        ):
            raise ValueError("CPU sample camera/configuration differs")
        if (
            row["before"] != row["after"]
            or len(values) < 60
            or any(type(value) is not int or value < 0 for value in values)
        ):
            raise ValueError("invalid actual CPU sample/state")
        samples.setdefault((row["group"], row["off"]), []).extend(values)
    result = {}
    for group in ("west-lamp", "home"):
        on, off = samples[group, False], samples[group, True]
        on_median, off_median = statistics.median(on), statistics.median(off)
        repeats = []
        for repeat in (1, 2, 3):
            pair = {
                row["off"]: statistics.median(row["samples_us"])
                for row in rows
                if row["group"] == group and row["repeat"] == repeat
            }
            repeats.append(
                {
                    "repeat": repeat,
                    "on_median_us": pair[False],
                    "off_median_us": pair[True],
                    "delta_us": pair[False] - pair[True],
                }
            )
        result[group] = {
            "on_median_us": on_median,
            "off_median_us": off_median,
            "delta_us": on_median - off_median,
            "samples": [len(on), len(off)],
            "repeats": repeats,
            "paired_saved_state_equal": True,
            "camera_equal_to_visual_frame": True,
            "visual_frame_save_delta": state_paths(
                capture["frames"][group + ("-1320" if group == "west-lamp" else "-720")]["before"],
                saved[group],
            ),
        }
    return result


def viewports(artifacts: Artifacts, width: int, capture: dict[str, Any]) -> dict[str, Any]:
    """Отключение одного настоящего canvas не должно менять второй framebuffer или save."""
    twin = capture["viewports"]
    if twin["failures"] or set(twin["records"]) != {"both-on", "west-off", "home-off"}:
        raise ValueError("native viewport matrix incomplete")
    rows = twin["records"]
    images: dict[tuple[str, int], Image.Image] = {}
    baseline = rows["both-on"]["states"]
    if any(
        baseline[0]["owner"][key] == baseline[1]["owner"][key]
        for key in ("viewport", "game", "background")
    ):
        raise ValueError("two independent viewport owners required")
    for index, (location, minutes) in enumerate((("overworld", 1320), ("cottage_interior", 720))):
        saved = baseline[index]["before"]
        if saved["location"] != location or saved["minutes"] != minutes or saved["day"] != 2:
            raise ValueError("independent viewport scenes/clocks required")
    for mode, row in rows.items():
        if len(row["states"]) != 2:
            raise ValueError("two viewport images required")
        picture(artifacts, f"{width}-on/frames/{row['composite']}", (width, width * 9 // 16))
        for index, state in enumerate(row["states"]):
            state_check(state, mode + ":" + str(index))
            owner = state["owner"]
            if set(owner) != {"game", "viewport", "background"} or any(
                type(value) is not int or value <= 0 for value in owner.values()
            ):
                raise ValueError("invalid viewport owner token")
            if state["before"] != baseline[index]["before"] or owner != baseline[index]["owner"]:
                raise ValueError("viewport save/identity changed")
            if (
                state["snapshot"] != state["snapshot_after"]
                or state["snapshot"] != baseline[index]["snapshot"]
            ):
                raise ValueError("viewport camera/configuration changed")
            expected_off = mode == ("west-off" if index == 0 else "home-off")
            if state["off"] != expected_off or any(
                call["viewport"] != owner["viewport"] or call["off"] != expected_off
                for call in state["calls"]
            ):
                raise ValueError("light switch leaked between canvases")
            size = (width, width * 9 // 16) if index == 0 else (960, 540)
            images[mode, index] = picture(artifacts, f"{width}-on/frames/{state['file']}", size)
    for mode, changed in (("west-off", 0), ("home-off", 1)):
        for index in (0, 1):
            equal = images["both-on", index].tobytes() == images[mode, index].tobytes()
            if equal != (index != changed):
                raise ValueError("native viewport isolation failure: " + mode)
    return {"states": 6, "independent_targets": True, "both_directions_equal": True}
