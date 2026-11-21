"""Экспортирует все сырые samples и описательную статистику целого production draw."""

from __future__ import annotations

import argparse
import csv
import io
import json
import math
import statistics
from pathlib import Path
from typing import Any

from tools.qa.world.lighting.daycycle import contract as c
from tools.qa.world.lighting.daycycle.evidence import Evidence
from tools.qa.world.lighting.daycycle.verify import REPORT, verify


def summary(values: list[float]) -> dict[str, float]:
    """p95 — nearest rank; исходные значения остаются без удаления или сглаживания."""
    return {
        "median_us": statistics.median(values),
        "p95_us": sorted(values)[math.ceil(len(values) * 0.95) - 1],
    }


def data(native: Path) -> tuple[dict[str, Any], str]:
    """Читает реальный capture, не считает wall-интервалы аппаратным FPS или GPU-временем."""
    store = Evidence(native)
    source_raw = store.read("source.json")
    result: dict[str, Any] = {
        "task": "VLIGHT-003",
        "native_head": json.loads(source_raw)["head"],
        "source_sha256": c.digest(source_raw),
        "samples": 0,
        "hardware_fps_acceptance": False,
        "p95_method": "nearest rank",
        "whole_draw_cpu_submission": True,
        "results": {},
    }
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(
        [
            "variant",
            "width",
            "mode",
            "repeat",
            "index",
            "draw_submission_us",
            "frame_interval_us",
            "process_frame",
            "tick_us",
            "visible",
            "focused",
        ]
    )
    for label in ("baseline", "candidate"):
        for width in c.WIDTHS:
            capture = store.document(f"{label}/{width}/capture.json")
            key = label + "/" + str(width)
            result["results"][key] = {
                "adapter": capture["adapter"],
                "display": capture["display"],
                "renderer": capture["renderer"],
                "vsync_driver_warning": "Could not set V-Sync"
                in store.read(f"{label}/{width}.txt").decode(),
                "modes": {},
            }
            for row in capture["costs"]:
                for index, (draw, frame, observation) in enumerate(
                    zip(row["draw_us"], row["frame_us"], row["observations"], strict=True)
                ):
                    writer.writerow(
                        [
                            label,
                            width,
                            row["mode"],
                            row["repeat"],
                            index,
                            draw,
                            frame,
                            observation["process_frame"],
                            observation["tick_us"],
                            observation["visible"],
                            observation["focused"],
                        ]
                    )
                    result["samples"] += 1
            for mode in c.MODES:
                rows = sorted(
                    (row for row in capture["costs"] if row["mode"] == mode),
                    key=lambda row: row["repeat"],
                )
                result["results"][key]["modes"][mode] = {
                    "draw": summary([value for row in rows for value in row["draw_us"]]),
                    "frame": summary([value for row in rows for value in row["frame_us"]]),
                    "repeat_draw_medians_us": [statistics.median(row["draw_us"]) for row in rows],
                }
    return result, output.getvalue()


def check(native: Path, output: Path) -> None:
    """Сверяет опубликованные таблицы с каждым исходным значением неизменённого capture."""
    result, csv_text = data(native)
    c.need(
        json.loads((output / "metrics.json").read_bytes()) == result,
        "derived native metrics differ",
    )
    c.need((output / "samples.csv").read_text() == csv_text, "raw native CSV differs")


def main() -> None:
    """Перед экспортом проверяет весь пакет; результаты записывает в новую внешнюю папку."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", type=Path, default=REPORT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    verify(args.native)
    if args.check:
        check(args.native, args.output)
    else:
        output = c.shared.fresh_output(args.output)
        result, csv_text = data(args.native)
        (output / "metrics.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n"
        )
        (output / "samples.csv").write_text(csv_text)
        check(args.native, output)
    print("DAYCYCLE METRICS: raw samples and summaries match")


if __name__ == "__main__":
    main()
