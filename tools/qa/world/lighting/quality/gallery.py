"""Собирает и проверяет листы только из неизменённых native-пикселей VLIGHT-010."""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont

from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality.evidence import Evidence


def plan(store: Evidence) -> dict[str, dict[str, Any]]:
    """Сохраняет полные native-кадры и реальные viewport без resize и коррекции цвета."""
    result: dict[str, dict[str, Any]] = {}
    for room in ("street", "home"):
        result[room + "-profiles.png"] = {
            "size": [3488, 2096],
            "placements": [
                {
                    "source": f"candidate/1152/{room}-{time}-{mode}.png",
                    "crop": [0, 0, 1152, 648],
                    "at": [column * 1168, 40 + row * 704, 1152, 648],
                    "label": label + " · " + mode,
                }
                for row, (time, label) in enumerate(
                    (("day", "День"), ("dusk", "Сумерки"), ("night", "Ночь"))
                )
                for column, mode in enumerate(c.MODES)
            ],
        }
    result["comparison.png"] = {
        "size": [1152, 1392],
        "placements": [
            {
                "source": label + "/1152/street-night-" + mode + ".png",
                "crop": [0, 0, 1152, 648],
                "at": [0, 40 + index * 704, 1152, 648],
                "label": text,
            }
            for index, (label, mode, text) in enumerate(
                (
                    ("baseline", "standard", "До · принятая main · ночь"),
                    ("candidate", "low", "После · low · ночь"),
                )
            )
        ],
    }
    capture = store.document("candidate/1152/capture.json")
    placements = []
    for row, step in enumerate(c.TWINS):
        for index in (0, 1):
            width = capture["twins"][step][index]["size"][0]
            placements.append(
                {
                    "source": f"candidate/1152/twin-{step}-{index}.png",
                    "crop": [width // 2 - 225, 100, width // 2 + 225, 400],
                    "at": [index * 466, 40 + row * 356, 450, 300],
                    "label": f"{step} · viewport {index + 1}",
                }
            )
    result["viewports.png"] = {"size": [916, 1408], "placements": placements}
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
        "task": "VLIGHT-010",
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
        manifest["task"] == "VLIGHT-010"
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
    parser.add_argument("--native", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        check(args.native, args.output)
    else:
        build(args.native, args.output)
    print("LIGHT QUALITY GALLERY: native pixels match")


if __name__ == "__main__":
    main()
