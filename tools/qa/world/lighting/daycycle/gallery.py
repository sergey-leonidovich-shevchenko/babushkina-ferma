"""Собирает и проверяет листы только из неизменённых native-пикселей VLIGHT-003."""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont

from tools.qa.world.lighting.daycycle import contract as c
from tools.qa.world.lighting.daycycle.evidence import Evidence
from tools.qa.world.lighting.daycycle.verify import REPORT


def plan(store: Evidence) -> dict[str, dict[str, Any]]:
    """Закрепляет роли before/after, четыре часа и две независимые камеры, без resize."""
    result: dict[str, dict[str, Any]] = {}
    result["comparison.png"] = {
        "size": [1152, 1392],
        "placements": [
            {
                "source": label + "/1152/street-dusk-palette.png",
                "crop": [0, 0, 1152, 648],
                "at": [0, 40 + index * 704, 1152, 648],
                "label": text,
            }
            for index, (label, text) in enumerate(
                (
                    ("baseline", "До · принятая main · сумерки"),
                    ("candidate", "После · календарная палитра · сумерки"),
                )
            )
        ],
    }
    result["cycle.png"] = {
        "size": [1456, 936],
        "placements": [
            {
                "source": "candidate/1152/street-" + case + "-palette.png",
                "crop": [240, 120, 960, 540],
                "at": [(index % 2) * 736, 40 + (index // 2) * 476, 720, 420],
                "label": text,
            }
            for index, (case, text) in enumerate(
                (
                    ("dawn", "Рассвет · 06:00"),
                    ("day", "День · 12:00"),
                    ("dusk", "Сумерки · 19:00"),
                    ("night", "Ночь · 22:00"),
                )
            )
        ],
    }
    capture = store.document("candidate/1152/capture.json")
    placements = []
    for row, (step, labels) in enumerate(
        (
            ("both", ("A · сумерки", "B · день")),
            ("first-legacy", ("A · прежний цвет", "B · день без изменений")),
            ("second-night", ("A · цвет без изменений", "B · ночь")),
        )
    ):
        for index in (0, 1):
            width = capture["twins"][step][index]["size"][0]
            placements.append(
                {
                    "source": "candidate/1152/twin-" + step + "-" + str(index) + ".png",
                    "crop": [width // 2 - 225, 100, width // 2 + 225, 400],
                    "at": [index * 466, 40 + row * 356, 450, 300],
                    "label": labels[index],
                }
            )
    result["viewports.png"] = {"size": [916, 1052], "placements": placements}
    return result


def font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """Подписи лежат за пределами native-областей и не являются игровым текстом."""
    for name in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(name, 20)
        except OSError:
            pass
    return ImageFont.load_default()


def build(native: Path, output: Path) -> None:
    """Копирует выбранные прямоугольники буквально; игровые PNG и пакеты не переписываются."""
    output = c.shared.fresh_output(output)
    store = Evidence(native)
    source_raw = store.read("source.json")
    source = json.loads(source_raw)
    specification = plan(store)
    manifest: dict[str, Any] = {
        "task": "VLIGHT-003",
        "native_head": source["head"],
        "native_source_sha256": c.digest(source_raw),
        "generator_sha256": c.digest(Path(__file__).read_bytes()),
        "figures": specification,
        "outputs": {},
    }
    caption_font = font()
    for name, figure in specification.items():
        canvas = Image.new("RGBA", tuple(figure["size"]), (244, 234, 211, 255))
        draw = ImageDraw.Draw(canvas)
        for row in figure["placements"]:
            raw = store.read(row["source"])
            c.need(
                c.digest(raw) == source["artifacts"][row["source"]], "native source hash differs"
            )
            with Image.open(io.BytesIO(raw)) as original:
                tile = original.convert("RGBA").crop(tuple(row["crop"]))
            x, y, width, height = row["at"]
            c.need(tile.size == (width, height), "gallery would resize native pixels")
            canvas.paste(tile, (x, y))
            draw.text((x + 12, y - 31), row["label"], font=caption_font, fill=(73, 55, 37, 255))
        canvas.save(output / name)
        manifest["outputs"][name] = c.digest((output / name).read_bytes())
    (output / "gallery.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    check(native, output)


def check(native: Path, output: Path) -> None:
    """Проверяет канонические источники, размеры и каждый RGBA native crop после публикации."""
    store = Evidence(native)
    source_raw = store.read("source.json")
    source = json.loads(source_raw)
    manifest = json.loads((output / "gallery.json").read_bytes())
    specification = plan(store)
    c.need(
        manifest["task"] == "VLIGHT-003"
        and manifest["native_head"] == json.loads(source_raw)["head"]
        and manifest["native_source_sha256"] == c.digest(source_raw),
        "gallery native provenance differs",
    )
    c.need(
        manifest["figures"] == specification and set(manifest["outputs"]) == set(specification),
        "gallery source/placement plan differs",
    )
    for name, figure in specification.items():
        raw = (output / name).read_bytes()
        c.need(c.digest(raw) == manifest["outputs"][name], "gallery output hash differs")
        with Image.open(output / name) as opened:
            c.need(
                opened.format == "PNG" and list(opened.size) == figure["size"],
                "gallery PNG/size differs",
            )
            canvas = opened.convert("RGBA")
        for row in figure["placements"]:
            x, y, width, height = row["at"]
            native_raw = store.read(row["source"])
            c.need(
                c.digest(native_raw) == source["artifacts"][row["source"]],
                "gallery native source hash differs",
            )
            with Image.open(io.BytesIO(native_raw)) as opened:
                expected = opened.convert("RGBA").crop(tuple(row["crop"]))
            actual = canvas.crop((x, y, x + width, y + height))
            c.need(
                actual.size == expected.size and actual.tobytes() == expected.tobytes(),
                "gallery changed native pixels",
            )


def main() -> None:
    """Построение требует новой внешней папки; check ничего не меняет."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", type=Path, default=REPORT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        check(args.native, args.output)
    else:
        build(args.native, args.output)
    print("DAYCYCLE GALLERY: native pixels match")


if __name__ == "__main__":
    main()
