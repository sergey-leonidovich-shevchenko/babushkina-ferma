"""Публикует все фактические CPU/frame samples без округления или FPS-приёмки."""

from __future__ import annotations

import argparse
import csv
import io
import json
import statistics
from pathlib import Path
from typing import Any

from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality.evidence import Evidence


def extract(native: Path) -> tuple[str, dict[str, Any]]:
    """Берёт каждый из 1440 samples исходного capture, включая все три повторения."""
    store = Evidence(native)
    source = store.document("source.json")
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(
        [
            "variant",
            "width",
            "mode",
            "repeat",
            "index",
            "draw_us",
            "frame_us",
            "process_frame",
            "tick_us",
            "visible",
            "focused",
            "max_fps",
            "vsync",
        ]
    )
    groups: dict[str, Any] = {}
    count = 0
    for label in ("baseline", "candidate"):
        groups[label] = {}
        for width in c.WIDTHS:
            data = store.document(f"{label}/{width}/capture.json")
            modes: dict[str, list[dict[str, Any]]] = {}
            for row in data["costs"]:
                modes.setdefault(row["mode"], []).append(row)
                for index, (draw, observed) in enumerate(
                    zip(row["draw_us"], row["observations"], strict=True)
                ):
                    writer.writerow(
                        [
                            label,
                            width,
                            row["mode"],
                            row["repeat"],
                            index,
                            draw,
                            observed["frame_us"],
                            observed["process_frame"],
                            observed["tick_us"],
                            observed["visible"],
                            observed["focused"],
                            observed["engine_max_fps"],
                            observed["vsync"],
                        ]
                    )
                    count += 1
            groups[label][str(width)] = {}
            for mode, rows in modes.items():
                samples = [value for row in rows for value in row["draw_us"]]
                repeated = [statistics.median(row["draw_us"]) / 1000 for row in rows]
                groups[label][str(width)][mode] = {
                    "samples": len(samples),
                    "median_draw_ms": statistics.median(samples) / 1000,
                    "repeat_median_draw_ms": repeated,
                    "repeat_min_max_ms": [min(repeated), max(repeated)],
                }
    text = output.getvalue()
    c.need(count == 1440, "complete raw sample count differs")
    return text, {
        "schema": 1,
        "task": "VLIGHT-010",
        "head": source["head"],
        "native_source_sha256": c.digest(store.read("source.json")),
        "samples": count,
        "sample_csv_sha256": c.digest(text.encode()),
        "groups": groups,
        "gpu_time_measured": False,
        "hardware_fps_acceptance": False,
        "context": "Fixed pose/clock, paused simulation, X11 llvmpipe. Whole root CPU draw; no PNG readback in timed interval. Not hardware performance acceptance.",
    }


def check(native: Path, output: Path) -> None:
    """Сверяет CSV и все производные числа с настоящими capture, а не своим manifest."""
    text, result = extract(native)
    c.need((output / "samples.csv").read_bytes() == text.encode(), "raw published samples differ")
    c.need(json.loads((output / "metrics.json").read_bytes()) == result, "published metrics differ")


def main() -> None:
    """Создание требует новой внешней папки; --check ничего не изменяет."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        check(args.native, args.output)
    else:
        folder = c.shared.fresh_output(args.output)
        text, result = extract(args.native)
        (folder / "samples.csv").write_bytes(text.encode())
        (folder / "metrics.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n"
        )
        check(args.native, folder)
    print("LIGHT QUALITY METRICS: all 1440 actual samples match")


if __name__ == "__main__":
    main()
