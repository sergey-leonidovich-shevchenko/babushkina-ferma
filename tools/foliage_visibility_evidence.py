"""Чтение VFOLIAGE-010: целостность файлов и декодирование первичных RGBA."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "docs/reports/visual-overhaul/vfoliage-010"
ROUTES = ("left", "right", "top", "bottom", "chunk", "bush")
MODES = ("normal", "low", "offscreen", "returned")


def require(condition: bool, message: str) -> None:
    """Прерывает проверку с предметной причиной; отказ не превращается в пустой результат."""
    if not condition:
        raise ValueError(message)


def read(path: Path) -> dict:
    """Читает сохранённый JSON без изменения его байтов."""
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    """Вычисляет SHA256 фактического файла, не доверяя подписи в соседнем manifest."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Frames:
    """Читает первичные lossless-кадры; MP4 и thumbnail не используются как pixel oracle."""

    def __init__(self, root: Path):
        self.root = root
        storage_path = root / "storage.json"
        self.storage = read(storage_path) if storage_path.exists() else None
        self.cache: dict[str, Image.Image] = {}
        if self.storage:
            timing = self.storage
            require(
                timing["view_fps"] == 24
                and timing["simulation_hz"] == 120
                and timing["steps_per_frame"] == 2
                and timing["slowdown"] == 2.5,
                "video timing metadata",
            )
            for name, expected in self.storage["archives"].items():
                require(digest(root / name) == expected, "archive SHA: " + name)

    def image(self, name: str) -> Image.Image:
        """Декодирует конкретный RGBA и сверяет сохранённые ключевые PNG с архивом."""
        path = self.root / name
        if not self.storage or name not in self.storage["frames"]:
            require(path.exists(), "missing native PNG: " + name)
            return Image.open(path).convert("RGBA")

        row = self.storage["frames"][name]
        key = row["archive"]
        if key not in self.cache:
            self.cache[key] = Image.open(self.root / key)
        archive = self.cache[key]
        require(archive.n_frames == 36, "archive frame count")
        archive.seek(row["frame"])
        result = archive.convert("RGBA")
        require(
            hashlib.sha256(result.tobytes()).hexdigest() == row["rgba_sha256"],
            "archived RGBA SHA",
        )
        if row["kept_png"]:
            require(
                path.exists() and digest(path) == row["png_sha256"],
                "retained PNG SHA",
            )
            png = Image.open(path).convert("RGBA")
            require(png.tobytes() == result.tobytes(), "PNG/archive exact decode")
        return result


def verify_artifacts(root: Path, source: dict, frames: Frames) -> None:
    """Проверяет SHA первичных файлов, включая PNG, сохранённые в lossless-архиве."""
    for name, expected in source["artifacts"].items():
        path = root / name
        if path.exists():
            require(digest(path) == expected, "artifact SHA: " + name)
            continue
        archived = frames.storage and frames.storage["frames"].get(name)
        require(
            archived and archived["png_sha256"] == expected,
            "missing original artifact: " + name,
        )


def verify_viewing(root: Path) -> None:
    """Сверяет производные MP4 для просмотра, не подменяя ими lossless-доказательства."""
    viewing = read(root / "viewing.json")
    expected = [(width, route) for width in (1152, 1280) for route in ROUTES]
    actual = [(clip["width"], clip["route"]) for clip in viewing["clips"]]
    require(
        viewing["primary_pixel_oracle"] is False and actual == expected,
        "viewing clips matrix",
    )
    for clip in viewing["clips"]:
        metadata = clip["metadata"]
        require(
            metadata["frames"] == 36
            and metadata["fps"] == 24
            and metadata["duration"] == 1.5
            and metadata["width"] == clip["width"]
            and metadata["height"] == clip["width"] * 9 // 16,
            "viewing clip timing/dimensions",
        )
        for name, expected_sha in clip["files"].items():
            require(digest(root / name) == expected_sha, "viewing clip SHA")


def verify_pixels(frames: Frames, prefix: str, row: dict, width: int) -> None:
    """Проверяет RGBA и маркер только после дешёвого отказа по ошибочным метаданным."""
    image = frames.image(prefix + row["image"])
    require(
        image.size == tuple(row["size"])
        and hashlib.sha256(image.tobytes()).hexdigest() == row["rgba_sha256"],
        "native RGBA SHA",
    )
    marker = 0
    for bit in range(16):
        x = int((bit * 72 + 36) * width / 1152)
        color = image.getpixel((x, 2))
        require(
            color in ((255, 255, 255, 255), (255, 0, 255, 255)),
            "invalid native marker pixel",
        )
        marker |= (color == (255, 255, 255, 255)) << bit
    require(marker == row["serial"], "stale native marker")
