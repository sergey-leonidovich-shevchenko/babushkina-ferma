"""Inventory startup PNGs and their import requests without loading the game."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any

from tools.common.paths import project_root
from tools.qa.performance.optimization_asset_audit import audit

ROOT = project_root(__file__)
INITIAL = "docs/epics/visual-overhaul-2026-10/evidence/native-1152.json"
CONTRACT = Path("docs/reports/visual-overhaul/vperf-001/native")
BUDGET = "docs/reports/visual-overhaul/vperf-002/budget.json"
PASS_COST = "docs/reports/visual-overhaul/vperf-003/native-ci-01/summary.json"
RUNS = ("repeat-1", "repeat-2", "repeat-3", "long-cycle")
IMPORT_OPTIONS = (
    "compress/mode",
    "compress/normal_map",
    "compress/channel_pack",
    "mipmaps/generate",
    "mipmaps/limit",
    "process/size_limit",
    "process/fix_alpha_border",
    "process/premult_alpha",
    "detect_3d/compress_to",
)
STATIONS = (
    "fruit_press",
    "fermenter",
    "preserver",
    "smoker",
    "loom",
    "tannery",
    "candlebench",
    "gardenbench",
)


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def import_settings(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    settings = dict(line.split("=", 1) for line in path.read_text().splitlines() if "=" in line)
    return {
        "sha256": sha256(path),
        "requested": {
            option: json.loads(settings[option]) for option in IMPORT_OPTIONS if option in settings
        },
    }


def png_texture(root: Path, relative: str) -> dict[str, Any]:
    path = root / relative
    with path.open("rb") as source:
        header = source.read(26)
    if len(header) != 26 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"missing PNG header: {relative}")
    width = int.from_bytes(header[16:20], "big")
    height = int.from_bytes(header[20:24], "big")
    return {
        "path": relative,
        "width": width,
        "height": height,
        "disk_bytes": path.stat().st_size,
        "rgba8_estimate": width * height * 4,
        "png_bit_depth": header[24],
        "png_color_type": header[25],
        "requested_import": import_settings(path.with_suffix(".png.import")),
    }


def historical(root: Path) -> dict[str, Any]:
    diagnostic = json.loads((root / INITIAL).read_bytes())
    contract = {}
    for run in RUNS:
        source = root / CONTRACT / run / "rows.csv.gz"
        config = json.loads((root / CONTRACT / run / "run.json").read_bytes())
        with gzip.open(source, "rt", encoding="utf-8", newline="") as stream:
            samples = [float(row["texture_bytes"]) for row in csv.DictReader(stream)]
        contract[run] = {
            "raw_source": str(source.relative_to(root)),
            "raw_sha256": sha256(source),
            "samples": len(samples),
            "texture_counter_min_bytes": min(samples),
            "texture_counter_max_bytes": max(samples),
            "camera": config["initial"]["camera"],
            "window": config["initial"]["window"],
            "adapter": config["adapter"],
        }
    return {
        "early_diagnostic": {
            "source": INITIAL,
            "sha256": sha256(root / INITIAL),
            "texture_counter_bytes": [run["texture_bytes"] for run in diagnostic["measurements"]],
            "adapter": diagnostic["adapter"],
            "window": diagnostic["window"],
            "render_target": diagnostic["render_pixels"],
            "paired_baseline_eligible": False,
        },
        "vperf_001": contract,
        "reference_configuration": {"source": BUDGET, "sha256": sha256(root / BUDGET)},
        "software_reference": {"source": PASS_COST, "sha256": sha256(root / PASS_COST)},
    }


def inventory(root: Path) -> dict[str, Any]:
    """Keep PNG storage, nominal RGBA8, and import metadata as different fields."""
    graph = audit(root)
    startup = [png_texture(root, row["path"]) for row in graph["textures"]]
    families: Counter[str] = Counter()
    for row in startup:
        family = "/".join(Path(row["path"]).parts[:3])
        families[family] += row["rgba8_estimate"]
    selected = [png_texture(root, f"assets/game/artisan/{kind}_atlas_a.png") for kind in STATIONS]
    selected_paths = {row["path"] for row in selected}
    return {
        "schema": 1,
        "task": "VPERF-005",
        "startup": {
            key: graph[key]
            for key in ("dependency_count", "texture_count", "rgba8_estimate", "texture_disk_bytes")
        },
        "startup_families_rgba8_bytes": dict(families.most_common()),
        "startup_pngs": startup,
        "artisan_station_atlases": selected,
        "selected_atlases_in_startup_graph": sorted(
            selected_paths.intersection(row["path"] for row in startup)
        ),
        "history": historical(root),
        "limits": graph["limitations"],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = inventory(args.root.resolve())
    with args.output.open("x", encoding="utf8") as target:
        json.dump(output, target, indent=2, ensure_ascii=False)
        target.write("\n")
    print(json.dumps(output["startup"]))


if __name__ == "__main__":
    main()
