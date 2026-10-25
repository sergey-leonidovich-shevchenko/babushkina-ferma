"""Дешёвые проверки нативного окна, движения, состояния и счётчиков VFOLIAGE-010."""
from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path
import re

from foliage_visibility_evidence import MODES, ROUTES, read, require


@dataclass
class WindowEvidence:
    """Хранит проверенные метаданные одного окна до начала декодирования изображений."""

    width: int
    capture: dict
    rows: list[dict]
    pairs: list[tuple[dict, dict]]
    costs: dict[str, dict]
    root_calls: list[int]

    @property
    def prefix(self) -> str:
        """Даёт путь кадров этого окна внутри неизменного native-архива."""
        return f"{self.width}/native/"


def verify_window_identity(root: Path, run: dict, capture: dict) -> None:
    """Отклоняет ошибочный процесс, backend, геометрию и startup без чтения пикселей."""
    width = run["width"]
    require(
        run["exit"] == 0
        and not run["timeout"]
        and not run["engine_errors"]
        and run["capture_complete"]
        and not run["capture_errors"],
        "failed native wrapper",
    )
    require(
        capture["complete"]
        and not capture["errors"]
        and capture["display"] != "headless"
        and capture["profile"] == run["profile"]
        and capture["width"] == width,
        "native identity/completion",
    )
    log = (root / str(width) / "engine.txt").read_text()
    clean = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", log)
    require(
        not re.search(r"^\s*(ERROR:|SCRIPT ERROR:)|Parse Error", clean, re.M),
        "engine errors in raw log",
    )
    require("Compatibility" in log and "OpenGL" in log, "actual native rendering backend")
    probes = capture["startup"]
    require(bool(probes), "native startup geometry")
    last = probes[-1]
    require(
        2000 <= last["ms"] < 7000
        and last["focused"]
        and last["windowed"]
        and last["window"] == last["image"] == [width, width * 9 // 16],
        "native startup geometry",
    )


def verify_records(capture: dict, width: int) -> dict[tuple[str, str, int], dict]:
    """Проверяет полную матрицу, present, чистоту draw и предел ресурсов до decode."""
    require([route["id"] for route in capture["routes"]] == list(ROUTES), "route identity/order")
    expected = [
        (route, mode, index)
        for route in ROUTES
        for index in range(36)
        for mode in (
            ["full", "culled", "unculled"] if index in (0, 17, 35) else ["full"]
        )
    ]
    expected += [("cost", mode, 0) for mode in MODES]
    rows = capture["records"]
    require(
        [(row["route"], row["mode"], row["index"]) for row in rows] == expected
        and len(rows) == 256,
        "complete native frame matrix",
    )
    by_key = {}
    for index, row in enumerate(rows):
        require(
            row["serial"] == index + 1
            and row["focused"]
            and row["windowed"]
            and row["size"] == [width, width * 9 // 16]
            and row["presents"] >= 2
            and row["drawn_frames"] >= 2,
            "fresh/focused/windowed frame",
        )
        require(
            row["draws"]
            and all(
                draw["serial"] == row["serial"]
                and draw["save_before"] == draw["save_after"] == row["save_sha256"]
                for draw in row["draws"]
            ),
            "draw purity/serial",
        )
        budget = row["budget"]
        stats = budget["statistics"]
        require(
            stats["owners"] == stats["builds"] == 1
            and stats["groups"] == 2
            and 0 <= stats["active"] <= 8,
            "bounded foliage resources",
        )
        require(
            budget["target_size"] == [768, 384]
            and budget["nominal_target_rgba8_bytes"] == 1179648,
            "native target payload/scale",
        )
        by_key[row["route"], row["mode"], row["index"]] = row
    return by_key


def verify_routes(capture: dict, by_key: dict) -> list[tuple[dict, dict]]:
    """Проверяет движение и одинаковое состояние culling-пар; RGB сравнивается позже."""
    pairs = []
    for route in capture["routes"]:
        first = by_key[route["id"], "full", 0]
        last = by_key[route["id"], "full", 35]
        if route.get("camera_only"):
            end = [
                route["camera_start"][axis] + route["direction"][axis] * 126
                for axis in range(2)
            ]
            require(
                math.dist(last["state"]["camera"], end) < 0.01
                and first["state"]["camera"] != last["state"]["camera"],
                "camera pan endpoint",
            )
            require(
                first["state"]["player"] == last["state"]["player"],
                "camera pan must not fake hero travel",
            )
        else:
            end = [
                route["start"][axis] + route["direction"][axis] * 126
                for axis in range(2)
            ]
            require(math.dist(last["state"]["player"], end) < 0.01, "actual hero movement endpoint")
            if route["id"] == "chunk":
                require(
                    math.floor(first["state"]["player"][0] / 384) == 4
                    and math.floor(last["state"]["player"][0] / 384) == 5,
                    "actual chunk boundary crossed",
                )
        for index in (0, 17, 35):
            a = by_key[route["id"], "culled", index]
            b = by_key[route["id"], "unculled", index]
            require(
                a["state"] == b["state"] and a["save_sha256"] == b["save_sha256"],
                "culling pair state/camera/uniforms",
            )
            pairs.append((a, b))
    return pairs


def verify_costs(by_key: dict) -> dict[str, dict]:
    """Различает обычную работу target и сохранённые старые счётчики отключённой цели."""
    costs = {mode: by_key["cost", mode, 0]["budget"] for mode in MODES}
    require(len({row["target_id"] for row in costs.values()}) == 1, "cost modes rebuild target")
    for mode, row in costs.items():
        if mode in ("normal", "returned"):
            require(
                row["target_draw_calls_last_frame"] == 2
                and row["target_primitives_last_frame"] == 192
                and row["statistics"]["active"] > 0,
                "production canvas budget",
            )
        else:
            require(
                row["target_update_mode"] == 0
                and row["statistics"]["active"] == row["statistics"]["recovery_active"] == 0,
                "inactive work not disabled",
            )
    return costs


def verify_window_metadata(root: Path, run: dict) -> WindowEvidence:
    """Завершает все дешёвые проверки окна перед любым декодированием его кадров."""
    width = run["width"]
    capture = read(root / str(width) / "native/capture.json")
    verify_window_identity(root, run, capture)
    by_key = verify_records(capture, width)
    pairs = verify_routes(capture, by_key)
    costs = verify_costs(by_key)
    rows = capture["records"]
    return WindowEvidence(
        width=width,
        capture=capture,
        rows=rows,
        pairs=pairs,
        costs=costs,
        root_calls=[row["budget"]["root_draw_calls"] for row in rows],
    )
