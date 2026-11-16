"""Verify and package the native VSHORE-005 water comparison."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, cast

from imageio_ffmpeg import read_frames, write_frames  # type: ignore[import-untyped]
from PIL import Image, ImageChops, ImageDraw, ImageStat

from tools.common.history import read_git_blob
from tools.common.paths import project_root
from tools.qa.world.water_chunk_seam import digest, require

ROOT = project_root(__file__)
REPORT = ROOT / "docs/reports/visual-overhaul/vshore-005/native"
SIZE = (1152, 648)
CASES = ("seam", "river", "pond")
PROFILES = ("static", "normal", "low", "later", "low-later")
CHECKS = {
    "production_split",
    "production_update",
    "pause_no_publish",
    "pause_same_phase",
    "resume_publish",
    "resume_advance",
    "resume_phase_changed",
    "uniform_only",
    "reduced_motion_uses_static",
    "reference_uses_static",
    "unsplit_has_no_second_surface",
    "direct_has_no_second_surface",
    "save_equal",
}
WITNESSES = (0, 59, 60, 119)


def pixels(folder: Path, row: dict[str, Any], filename: str) -> Image.Image:
    """Read one expected PNG and verify both provenance and framebuffer size."""
    path = (folder / filename).resolve()
    require(path.is_relative_to(folder) and row["file"] == filename, "unexpected capture path")
    require(digest(path) == row["sha256"], f"PNG digest: {filename}")
    with Image.open(path) as image:
        require(image.size == SIZE and image.format == "PNG", f"frame format: {filename}")
        return cast(Image.Image, image.convert("RGB"))


def project(rect: tuple[float, ...], row: dict[str, Any]) -> tuple[int, int, int, int]:
    """Convert the half-open world rectangle to pixel-center bounds."""
    x, y, width, height = rect
    camera_x, camera_y = row["camera"]
    zoom = row["zoom"]
    return (
        math.ceil((x - camera_x) * zoom - 0.5),
        math.ceil((y - camera_y) * zoom - 0.5),
        math.ceil((x + width - camera_x) * zoom - 0.5),
        math.ceil((y + height - camera_y) * zoom - 0.5),
    )


def water_mask(cells: list[list[int]], row: dict[str, Any]) -> Image.Image:
    """Project authoritative wet cells, including water beneath the bridges."""
    mask = Image.new("L", SIZE)
    draw = ImageDraw.Draw(mask)
    for cell_x, cell_y in cells:
        x, y, right, bottom = project((cell_x * 24, cell_y * 24, 24, 24), row)
        draw.rectangle((x, y, right - 1, bottom - 1), fill=255)
    return mask


def difference(before: Image.Image, after: Image.Image) -> Image.Image:
    """Return the largest absolute RGB difference at each pixel."""
    red, green, blue = ImageChops.difference(before, after).split()
    return ImageChops.lighter(ImageChops.lighter(red, green), blue)


def compare_stills(folder: Path, capture: dict[str, Any]) -> dict[str, Any]:
    """Check phase movement without changing the dry world, bridge deck or water silhouette."""
    rows = capture["frames"]
    expected = {f"{case}-{profile}" for case in CASES for profile in PROFILES}
    require(set(rows) == expected | {"seam-wrapped", "seam-camera-shift"}, "still coverage")
    metrics: dict[str, Any] = {}
    for case in CASES:
        baseline = rows[f"{case}-static"]
        static = pixels(folder, baseline, f"{case}-static.png")
        mask = water_mask(capture["water_cells"], baseline)
        dry = ImageChops.invert(mask)
        images = {}
        for profile in PROFILES[1:]:
            name = f"{case}-{profile}"
            row = rows[name]
            require(row["camera"] == baseline["camera"] and row["zoom"] == 1.2, f"camera: {name}")
            images[profile] = pixels(folder, row, name + ".png")
            delta = difference(static, images[profile])
            histogram = delta.histogram()
            count = sum(histogram[1:])
            limit = max(level for level, frequency in enumerate(histogram) if frequency)
            require(count > 1000 and 0 < limit <= 18, f"missing or excessive ripple: {name}")
            require(
                ImageChops.multiply(delta, dry).getbbox() is None, f"dry terrain changed: {name}"
            )
            for x, y, width, height in capture["bridge_rects"]:
                deck = x + width / 4, y + height / 4, width / 2, height / 2
                require(delta.crop(project(deck, row)).getbbox() is None, f"bridge changed: {name}")
            metrics[name] = {"changed_pixels": count, "max_rgb_delta": limit}
        for profile, later in (("normal", "later"), ("low", "low-later")):
            delta = difference(images[profile], images[later])
            count = sum(delta.histogram()[1:])
            require(count > 1000, f"{case}: {profile} does not move")
            metrics[f"{case}-{profile}"]["animated_pixels"] = count
    normal = pixels(folder, rows["seam-normal"], "seam-normal.png")
    wrapped = pixels(folder, rows["seam-wrapped"], "seam-wrapped.png")
    mask = water_mask(capture["water_cells"], rows["seam-normal"])
    require(ImageChops.multiply(difference(normal, wrapped), mask).getbbox() is None, "phase wrap")
    shifted = pixels(folder, rows["seam-camera-shift"], "seam-camera-shift.png")
    require(
        difference(normal.crop((88, 275, 144, 306)), shifted.crop((40, 275, 96, 306))).getbbox()
        is None,
        "same world patch must keep its texture when camera moves 40 world pixels",
    )
    return metrics


def encode(raw: Path, destination: Path, motion: list[dict[str, Any]]) -> None:
    """Produce the short camera video after validating every original native PNG."""
    require(not destination.exists(), "diagnostic video already exists")
    with TemporaryDirectory(dir=destination.parent) as temporary:
        path = Path(temporary) / destination.name
        writer = write_frames(
            str(path),
            SIZE,
            fps=30,
            codec="libx264",
            quality=6,
            macro_block_size=1,
            ffmpeg_log_level="error",
        )
        writer.send(None)
        try:
            for index, row in enumerate(motion):
                writer.send(pixels(raw, row, f"frames/{index:04d}.png").tobytes())
        finally:
            writer.close()
        require(path.stat().st_size > 0, "empty diagnostic video")
        verify_video(path, destination.parent, motion)
        destination.hardlink_to(path)


def verify_video(video: Path, folder: Path, motion: list[dict[str, Any]]) -> None:
    """Match the first and last frames of each shot to retained native originals."""
    reader = read_frames(str(video), pix_fmt="rgb24")
    try:
        meta = next(reader)
        require(meta["size"] == SIZE and meta["fps"] == 30, "video profile")
        count = 0
        for index, bytes_ in enumerate(reader):
            if index in WITNESSES:
                native = pixels(folder, motion[index], f"frames/{index:04d}.png")
                decoded = Image.frombytes("RGB", SIZE, bytes_)
                mean = max(ImageStat.Stat(ImageChops.difference(native, decoded)).mean)
                require(mean <= 6.0, f"video source mismatch: {index}")
            count += 1
        require(count == 120, "decoded video frame count")
    finally:
        reader.close()


def main() -> None:
    """Verify a committed report or regenerate its diagnostic video from local raw captures."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder", type=Path, default=REPORT)
    parser.add_argument("--raw", type=Path)
    parser.add_argument("--commit")
    arguments = parser.parse_args()
    folder = arguments.folder.resolve()
    capture = json.loads((folder / "capture.json").read_text())
    require(capture["task"] == "VSHORE-005" and capture["display"] != "headless", "native capture")
    require(capture["renderer"] == "gl_compatibility" and capture["size"] == list(SIZE), "renderer")
    require(capture["checks"] == dict.fromkeys(CHECKS, True), "native runtime checks")
    require(
        len(capture["water_cells"]) == 550 and len(capture["bridge_rects"]) == 2,
        "first location water coverage",
    )
    require(len(capture["motion"]) == 120, "native motion coverage")
    require(len({frame["sha256"] for frame in capture["motion"]}) == 120, "unique native frames")
    for index, frame in enumerate(capture["motion"]):
        x, y = frame["camera"]
        local = index % 60
        progress = local / 59
        expected = (1368, 618) if index < 60 else (268 + 204 * progress, 88 + 20 * progress)
        require(
            math.isclose(x, expected[0], abs_tol=0.001)
            and math.isclose(y, expected[1], abs_tol=0.001)
            and math.isclose(frame["seconds"], 1.25 + local / 30)
            and frame["zoom"] == 1.2
            and frame["file"] == f"frames/{index:04d}.png",
            f"motion path and phase: {index}",
        )
    require(
        len(capture["sources"]) == 17
        and {
            "scripts/presentation/village_water_surface.gdshader",
            "scripts/presentation/village_water_surface.gd",
            "scripts/world_background.gd",
            "scripts/game_core.gd",
            "tools/qa/world/water_surface_capture.gd",
        }.issubset(capture["sources"]),
        "capture source coverage",
    )
    for path, sha in capture["sources"].items():
        source = (ROOT / path).resolve()
        require(source.is_relative_to(ROOT), "capture source outside project")
        if arguments.commit:
            read_git_blob(ROOT, path, arguments.commit, sha)
        else:
            require(digest(source) == sha, f"capture source differs: {path}")
    metrics = compare_stills(folder, capture)
    opening = pixels(folder, capture["motion"][0], "frames/0000.png")
    closing = pixels(folder, capture["motion"][59], "frames/0059.png")
    delta = difference(opening, closing)
    pond = water_mask(capture["water_cells"], capture["motion"][0])
    require(sum(delta.histogram()[1:]) > 1000, "locked camera water did not move")
    require(
        ImageChops.multiply(delta, ImageChops.invert(pond)).getbbox() is None,
        "locked camera dry pixels changed",
    )
    if arguments.raw:
        encode(arguments.raw.resolve(), folder / "camera-pan.mp4", capture["motion"])
    else:
        verify_video(folder / "camera-pan.mp4", folder, capture["motion"])
    print(json.dumps(metrics, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
