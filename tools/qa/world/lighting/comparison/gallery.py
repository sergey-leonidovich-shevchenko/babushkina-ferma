"""Собирает диагностические листы из native PNG; исходные кадры не редактирует."""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageDraw, ImageFont

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison.storage import Evidence
from tools.qa.world.lighting.comparison.verify import REPORT


def build(native: Path, output: Path, font_path: Path) -> dict[str, Any]:
    """Выходные координаты и native crop сохраняются, чтобы проверить каждый фрагмент."""
    names = ["comparison.png", "overview.png", "viewports.png", "gallery.json"]
    if any((output / name).exists() for name in names):
        raise ValueError("fresh gallery outputs required")
    source = json.loads((native / "source.json").read_bytes())
    store = Evidence(native, source)
    capture = json.loads(store.read("1152", "frames/capture.json"))
    font = ImageFont.truetype(str(font_path), 18)
    small = ImageFont.truetype(str(font_path), 14)
    placements = []

    def read(case: str) -> tuple[Image.Image, str]:
        name = "frames/" + capture["frames"][case]["file"]
        raw = store.read("1152", name)
        with Image.open(io.BytesIO(raw)) as image:
            return image.convert("RGB"), shared.digest(raw)

    sheet = Image.new("RGB", (1168, 840), "#f5ecd3")
    draw = ImageDraw.Draw(sheet)
    draw.text(
        (24, 15), "Один фонарь · нативные фрагменты ×2 · Compatibility", font=font, fill="#493c2b"
    )
    labels = ["Выключено", "Общая маска", "PointLight2D", "PointLight2D + тень"]
    for row, room in enumerate(["west-lamp", "home"]):
        draw.text(
            (24, 55 + row * 385),
            "Улица · 22:00" if row == 0 else "Существующий дом · 22:00",
            font=font,
            fill="#493c2b",
        )
        for column, mode in enumerate(["off", "mask", "local", "shadow"]):
            case = f"{room}-1320-{mode}"
            image, sha = read(case)
            center = capture["frames"][case]["light"]["center"]
            left, top = round(center[0]) - 64, round(center[1]) - 64
            rectangle = (left, top, left + 128, top + 160)
            picture = image.crop(rectangle).resize((256, 320), Image.Resampling.NEAREST)
            x, y = 24 + column * 286, 103 + row * 385
            draw.text((x, y - 23), labels[column], font=small, fill="#493c2b")
            sheet.paste(picture, (x, y))
            placements.append(
                {
                    "output": "comparison.png",
                    "case": case,
                    "source_sha256": sha,
                    "source_rect": list(rectangle),
                    "destination": [x, y, 256, 320],
                    "scale": 2,
                    "resampling": "nearest; diagnostic enlargement",
                }
            )
    sheet.save(output / "comparison.png")
    sheet = Image.new("RGB", (1200, 1030), "#f5ecd3")
    draw = ImageDraw.Draw(sheet)
    draw.text(
        (24, 12),
        "День / сумерки / ночь · два способа на прежних материалах",
        font=font,
        fill="#493c2b",
    )
    for row, (room, mode) in enumerate(
        [("west-lamp", "mask"), ("west-lamp", "local"), ("home", "mask"), ("home", "local")]
    ):
        y = 64 + row * 238
        for column, (minute, label) in enumerate(
            [(720, "12:00"), (1140, "19:00"), (1320, "22:00")]
        ):
            case = f"{room}-{minute}-{mode}"
            image, sha = read(case)
            x = 16 + column * 396
            draw.text((x, y - 20), f"{room} · {mode} · {label}", font=small, fill="#493c2b")
            sheet.paste(image.resize((384, 216), Image.Resampling.LANCZOS), (x, y))
            placements.append(
                {
                    "output": "overview.png",
                    "case": case,
                    "source_sha256": sha,
                    "source_rect": [0, 0, 1152, 648],
                    "destination": [x, y, 384, 216],
                    "scale": 1 / 3,
                    "resampling": "lanczos; overview only",
                }
            )
    sheet.save(output / "overview.png")
    raw = store.read("1152", "frames/viewport-both-local.png")
    (output / "viewports.png").write_bytes(raw)
    document = {
        "task": "VLIGHT-002",
        "source_commit": source["commit"],
        "font_sha256": shared.digest(font_path.read_bytes()),
        "placements": placements,
        "byte_exact_viewport_source": "1152/frames/viewport-both-local.png",
        "outputs": {
            name: shared.digest((output / name).read_bytes())
            for name in names
            if name.endswith(".png")
        },
    }
    (output / "gallery.json").write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")
    check(native, output)
    return document


def check(native: Path, output: Path) -> None:
    """Каждый блок — ровно объявленный native crop; подпись не может перекрыть его пиксели."""
    source = json.loads((native / "source.json").read_bytes())
    store = Evidence(native, source)
    capture = json.loads(store.read("1152", "frames/capture.json"))
    document = json.loads((output / "gallery.json").read_bytes())
    expected_sizes = {
        "comparison.png": (1168, 840),
        "overview.png": (1200, 1030),
        "viewports.png": (1152, 648),
    }
    if set(document["outputs"]) != set(expected_sizes) or len(document["placements"]) != 20:
        raise ValueError("gallery inventory")
    for name, digest in document["outputs"].items():
        raw = (output / name).read_bytes()
        if shared.digest(raw) != digest:
            raise ValueError("gallery output hash")
        with Image.open(io.BytesIO(raw)) as image:
            if image.size != expected_sizes[name]:
                raise ValueError("gallery output size")
    for row in document["placements"]:
        original = store.read("1152", "frames/" + capture["frames"][row["case"]]["file"])
        if shared.digest(original) != row["source_sha256"]:
            raise ValueError("gallery native source hash")
        x, y, width, height = row["destination"]
        resampling = (
            Image.Resampling.NEAREST
            if row["output"] == "comparison.png"
            else Image.Resampling.LANCZOS
        )
        with Image.open(io.BytesIO(original)) as image:
            expected = (
                image.convert("RGB").crop(row["source_rect"]).resize((width, height), resampling)
            )
        with Image.open(output / row["output"]) as image:
            actual = image.convert("RGB").crop((x, y, x + width, y + height))
        if ImageChops.difference(actual, expected).getbbox() is not None:
            raise ValueError("gallery changed native pixels or overlaid a label")
    if (output / "viewports.png").read_bytes() != store.read(
        "1152", "frames/viewport-both-local.png"
    ):
        raise ValueError("viewport gallery is not byte-exact native")


def main() -> None:
    """Шрифт задаётся явно; построение листа не запускает Godot и не меняет native ZIP."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", type=Path, default=REPORT)
    parser.add_argument("--output", type=Path, default=REPORT.parent)
    parser.add_argument("--font", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.native, args.output, args.font), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
