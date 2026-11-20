"""Публикует проверенные сводки и все три повторения без фильтрации отрицательных разниц."""

from __future__ import annotations

import argparse
import csv
import io
import json
import statistics
from pathlib import Path
from typing import Any

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison.verify import REPORT, verify


def summarize(native: Path, output: Path) -> dict[str, Any]:
    """Числа берутся из native reader; ручной выбор хранится отдельным явным полем."""
    result = verify(native, current=True)
    source = json.loads((native / "source.json").read_bytes())
    result["source_commit"] = source["commit"]
    result["native_source_sha256"] = shared.digest((native / "source.json").read_bytes())
    first_run = next(iter(source["runs"].values()))
    raw_output = next(
        value.removeprefix("--output=")
        for value in first_run["arguments"]
        if value.startswith("--output=")
    )
    result["measured_series"] = Path(raw_output).parent.parent.name
    result["rejected_previous_series"] = ["A: window resize", "B: missed production ground offset"]
    frame_count = sum(len(run["frames"]) for run in result["results"].values())
    cost_count = sum(len(run["costs"]) for run in result["results"].values())
    png_names = [
        name
        for run in source["runs"].values()
        for name in run["artifacts"]
        if name.endswith(".png")
    ]
    roots = sum(
        name
        in [
            "frames/viewport-both-local.png",
            "frames/viewport-left-off.png",
            "frames/viewport-right-off.png",
        ]
        for name in png_names
    )
    counts: dict[str, Any] = {
        "world_png": frame_count,
        "hud_png": sum(name.endswith("-hud.png") for name in png_names),
        "target_png": len(png_names) - frame_count * 2 - roots,
        "root_composite_png": roots,
        "total_png": len(png_names),
        "cost_rows": cost_count,
        "cpu_samples": cost_count * 90,
        "frame_samples": cost_count * 90,
        "exported_production_blobs": len(json.loads((native / "exported-blobs.json").read_bytes())),
        "qa_inputs": len(source["qa_inputs"]),
    }
    result["counts"] = counts
    result["decision"] = {
        "method": "cached production color mesh for the small stationary lantern halo",
        "status": "author decision; independent PR acceptance pending",
        "basis": [
            "warm controlled emission in the existing artwork",
            "no added lighting texture or PointLight/Occluder nodes in production",
            "real-time PCF5 shadow works in QA but needs authored production geometry and material/pass ownership",
            "no robust speed winner in the small measured differences",
        ],
        "limits": [
            "no runtime lighting migration",
            "no hardware FPS or GPU-time acceptance",
            "no other VLIGHT card or whole VMAP acceptance",
        ],
    }
    result["analysed_by_sha256"] = {
        p.name: shared.digest(p.read_bytes())
        for p in sorted(Path(__file__).parent.glob("*.py"))
        if not p.name.startswith("test_")
    }
    rows = []
    aggregates = []
    for width, run in result["results"].items():
        for row in run["costs"]:
            off = next(
                r
                for r in run["costs"]
                if r["room"] == row["room"] and r["repeat"] == row["repeat"] and r["mode"] == "off"
            )
            rows.append(
                {
                    "width": int(width),
                    **row,
                    "draw_delta_off_us": row["draw_median_us"] - off["draw_median_us"],
                    "frame_delta_off_us": row["frame_median_us"] - off["frame_median_us"],
                }
            )
        for room in ["west-lamp", "home"]:
            for mode in ["off", "mask", "local", "shadow"]:
                group = [r for r in run["costs"] if r["room"] == room and r["mode"] == mode]
                aggregates.append(
                    {
                        "width": int(width),
                        "room": room,
                        "mode": mode,
                        "median_of_repeat_draw_medians_us": statistics.median(
                            r["draw_median_us"] for r in group
                        ),
                        "median_of_repeat_frame_medians_us": statistics.median(
                            r["frame_median_us"] for r in group
                        ),
                        "repeat_frame_median_range_us": [
                            min(r["frame_median_us"] for r in group),
                            max(r["frame_median_us"] for r in group),
                        ],
                    }
                )
    result["aggregates"] = aggregates
    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=list(rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    (output / "costs.csv").write_text(buffer.getvalue())
    (output / "results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    return counts


def main() -> None:
    """Запись только по явному --write; обычный verifier не переписывает отчёты."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", type=Path, default=REPORT)
    parser.add_argument("--output", type=Path, default=REPORT.parent)
    parser.add_argument("--write", action="store_true", required=True)
    args = parser.parse_args()
    print(json.dumps(summarize(args.native, args.output), indent=2))


if __name__ == "__main__":
    main()
