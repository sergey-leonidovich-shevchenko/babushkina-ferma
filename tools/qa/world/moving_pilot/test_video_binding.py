"""Run real substituted-video controls against a completed moving-pilot archive."""

from __future__ import annotations

import argparse
import json
import os
from collections.abc import Callable
from pathlib import Path
from shutil import copytree, ignore_patterns
from tempfile import TemporaryDirectory

from tools.qa.world.moving_pilot.collect import digest, require, video
from tools.qa.world.moving_pilot.verify import read_json, verify

LIVE = Path("1152/live")
STATIC = Path("1152/static")


def reject_modified_clip(
    source: Path,
    head: str,
    change: Callable[[Path], Path],
    expected_error: str,
) -> str:
    """Update the copied manifest too, so the test reaches the decoded-content check."""
    with TemporaryDirectory(dir=source.parent, prefix="video-binding-") as work:
        working = Path(work)
        replica = working / "evidence"
        copytree(source, replica, copy_function=os.link, ignore=ignore_patterns("userdata"))
        substitute = change(working)
        clip = replica / LIVE / "route.mp4"
        clip.unlink()
        clip.hardlink_to(substitute)
        manifest_path = replica / "source.json"
        manifest = read_json(manifest_path)
        manifest["artifacts"][f"{LIVE}/route.mp4"] = digest(clip.read_bytes())
        manifest_path.unlink()
        manifest_path.write_text(json.dumps(manifest), encoding="utf8")
        try:
            verify(replica, head)
        except ValueError as error:
            message = str(error)
            require(message.startswith(expected_error), f"wrong rejection: {message}")
            return message
        raise ValueError("substituted video was accepted")


def reordered_clip(source: Path, work: Path) -> Path:
    """Encode the same images as a new MP4 after reversing two adjacent motion frames."""
    frames = work / "frames"
    frames.mkdir()
    originals = sorted((source / LIVE / "frames").glob("*.png"))
    originals[0], originals[1] = originals[1], originals[0]
    for index, png in enumerate(originals):
        (frames / f"{index:04}.png").hardlink_to(png)
    video(work)
    return work / "route.mp4"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-head", required=True)
    arguments = parser.parse_args()
    source = arguments.output.resolve()
    head = arguments.expected_head
    wrong_mode = reject_modified_clip(
        source, head, lambda _work: source / STATIC / "route.mp4", "video mode mismatch"
    )
    wrong_order = reject_modified_clip(
        source, head, lambda work: reordered_clip(source, work), "video frame order mismatch"
    )
    print(json.dumps({"head": head, "wrong_mode": wrong_mode, "wrong_order": wrong_order}))


if __name__ == "__main__":
    main()
