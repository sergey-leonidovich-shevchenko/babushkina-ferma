"""Сравнивает нативные кадры VSHADOW-002 при неизменных камерах и профилях."""

import argparse
import json
from collections import Counter
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

WINDOW = (1152, 648)
FOOTPRINTS = {
    "hero": (20, 10, 20, 10),
    "table": (55, 24, 55, 14),
    "post": (16, 11, 16, 11),
    "tree": (38, 13, 38, 15),
}
SUBJECTS = {"farm": "table", "street": "post", "grove": "tree"}
MIN_PIXELS = {"hero": 120, "table": 190, "post": 45, "tree": 130}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def contact_box(kind: str, anchor: list[float]) -> tuple[int, int, int, int]:
    x, y = map(round, anchor)
    left, top, right, bottom = FOOTPRINTS[kind]
    return (x - left, y - top, x + right, y + bottom)


def verify_pair(before: Path, after: Path) -> dict:
    baseline = json.loads((before / "capture.json").read_text(encoding="utf-8"))
    candidate = json.loads((after / "capture.json").read_text(encoding="utf-8"))
    require(baseline == candidate, "camera, lighting, motion, engine or game state changed")
    require(candidate["task"] == "VSHADOW-002" and not candidate["failures"], "failed capture")
    require(candidate["display"] != "headless", "native display is mandatory")
    require(candidate["motion"] in {"normal", "reduced"}, "invalid motion profile")
    expected = {f"{spot}-{minute}" for spot in SUBJECTS for minute in (720, 1140)}
    require(set(candidate["frames"]) == expected, "frame coverage differs")
    measurements = {}
    for frame_id, metadata in sorted(candidate["frames"].items()):
        require(metadata["window"] == list(WINDOW) and metadata["size"] == list(WINDOW), frame_id)
        require(metadata["zoom"] == 1.2 and metadata["callbacks"] == 2, frame_id)
        require(
            metadata["save_unchanged"] and metadata["snapshot"]["walkable"] == "walkable", frame_id
        )
        require(metadata["reduced_motion"] == (candidate["motion"] == "reduced"), frame_id)
        require(metadata["snapshot"]["location"] == "overworld", frame_id)
        require(metadata["snapshot"]["minutes"] == int(frame_id.split("-")[1]), frame_id)
        with (
            Image.open(before / f"{frame_id}.png") as source,
            Image.open(after / f"{frame_id}.png") as updated,
        ):
            require(source.size == updated.size == WINDOW, frame_id)
            channels = ImageChops.difference(source.convert("RGB"), updated.convert("RGB")).split()
        changes = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
        allowed = Image.new("L", WINDOW, 0)
        mask = ImageDraw.Draw(allowed)
        visible: Counter[str] = Counter()
        for contact in metadata["contacts_in_world"]:
            kind = contact["kind"]
            box = contact_box(kind, contact["anchor"])
            if box[2] <= 0 or box[3] <= 0 or box[0] >= WINDOW[0] or box[1] >= WINDOW[1]:
                continue
            visible[kind] += 1
            mask.rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=255)
        require(
            ImageChops.subtract(changes, allowed).getbbox() is None,
            f"{frame_id} changed outside contact areas",
        )
        subject = SUBJECTS[frame_id.split("-")[0]]
        require(visible[subject] >= 1, f"{frame_id} has no {subject} in view")
        if subject == "tree":
            require(visible["tree"] >= 3, f"{frame_id} lacks neighbouring trees")
        pixels = {}
        for kind in ("hero", subject):
            box = contact_box(kind, metadata["anchors"][kind])
            require(
                0 <= box[0] < box[2] <= WINDOW[0] and 0 <= box[1] < box[3] <= WINDOW[1], frame_id
            )
            patch = changes.crop(box)
            count = patch.width * patch.height - patch.histogram()[0]
            require(count >= MIN_PIXELS[kind], f"{frame_id} {kind} only changed {count} pixels")
            pixels[kind] = count
        measurements[frame_id] = {
            "visible": dict(visible),
            "contact_pixels": pixels,
            "changed_pixels": changes.width * changes.height - changes.histogram()[0],
        }
    return {"motion": candidate["motion"], "frames": measurements}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    arguments = parser.parse_args()
    try:
        print(
            json.dumps(verify_pair(arguments.before, arguments.after), indent=2, ensure_ascii=False)
        )
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"VSHADOW-002: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
