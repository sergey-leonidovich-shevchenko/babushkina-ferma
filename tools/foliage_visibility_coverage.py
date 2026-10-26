"""Независимый пересчёт coverage и проверка пиксельных culling-пар VFOLIAGE-010."""
from __future__ import annotations

from collections import Counter
import math

from foliage_visibility_evidence import Frames, require
from foliage_visibility_window import WindowEvidence


def verify_bounds(row: dict) -> None:
    """Проверяет реальные AABB обеих групп на полный консервативный ход каждого растения."""
    scale = row["scale"]
    require(
        [group["kind"] for group in row["bounds"]] == ["reeds", "grass"],
        "both native bounds groups required",
    )
    for group in row["bounds"]:
        bounds = group["aabb"]
        indices = range(6) if group["kind"] == "reeds" else range(6, 8)
        for index in indices:
            lo = [
                (index % 4 * 96 + 12 - 5.71) * scale,
                (index // 4 * 96 + 12 - 4.36) * scale,
            ]
            hi = [
                (index % 4 * 96 + 84 + 5.71) * scale,
                (index // 4 * 96 + 84 + 4.36) * scale,
            ]
            require(
                all(
                    bounds["position"][axis] <= lo[axis]
                    and bounds["position"][axis] + bounds["size"][axis] >= hi[axis]
                    for axis in (0, 1)
                ),
                "native MultiMesh AABB clips swept geometry",
            )


def verify_coverage(frames: Frames, window: WindowEvidence) -> list[dict]:
    """Калибрует 0/1/2 и пересчитывает фрагменты, наложения и лимиты двенадцати target."""
    rows = window.capture["coverage"]
    require(len(rows) == 13 and rows[0]["calibration"], "coverage matrix/calibration")
    expected = [
        (scale, [x, y])
        for scale in (1, 2, 4)
        for x, y in ((-1, -1), (1, -1), (-1, 1), (1, 1))
    ]
    require(
        [(row["scale"], row["extreme"]) for row in rows[1:]] == expected,
        "all extreme/DPI combinations",
    )
    # Неверные bounds отклоняются до дорогостоящего decode, сохраняя все прежние критерии.
    for row in rows[1:]:
        verify_bounds(row)
    calibration = frames.image(window.prefix + rows[0]["image"])
    require(
        [calibration.getpixel(point) for point in ((64, 64), (8, 8), (24, 24))]
        == [(0, 0, 0, 0), (1, 0, 0, 255), (2, 0, 0, 255)],
        "additive 0/1/2 calibration",
    )
    summaries = []
    for row in rows[1:]:
        scale = row["scale"]
        image = frames.image(window.prefix + row["image"])
        require(image.size == (384 * scale, 192 * scale), "coverage dimensions")
        counts = Counter(image.tobytes()[::4])
        fragments = sum(value * count for value, count in counts.items())
        covered = image.width * image.height - counts[0]
        require(
            fragments == row["fragments"]
            and covered == row["covered_pixels"]
            and max(counts) == row["maximum"] == 1,
            "independent coverage count/no overlap",
        )
        require(
            0 < fragments <= 8 * 72 * scale * math.ceil((72 + 4.36) * scale),
            "fragment fill budget",
        )
        require(
            row["draw_calls"] == 2
            and row["primitives"] == 192
            and row["nominal_rgba8_bytes"] == image.width * image.height * 4,
            "coverage canvas/payload budget",
        )
        summaries.append(
            {
                "scale": scale,
                "extreme": row["extreme"],
                "fragments": fragments,
                "fill_ratio": fragments / (image.width * image.height),
                "maximum": max(counts),
            }
        )
    return summaries


def verify_pairs(frames: Frames, window: WindowEvidence) -> int:
    """Сравнивает каждый RGBA ниже служебной полосы при уже проверенном одинаковом state."""
    for a, b in window.pairs:
        aa = frames.image(window.prefix + a["image"])
        bb = frames.image(window.prefix + b["image"])
        crop = (0, 8, window.width, aa.height)
        require(
            aa.crop(crop).tobytes() == bb.crop(crop).tobytes(),
            "culling changes visible RGBA",
        )
    return len(window.pairs)
