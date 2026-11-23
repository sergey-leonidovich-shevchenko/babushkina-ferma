"""Независимый reader полной настоящей X11-серии VLIGHT-010; неполный пакет не принимается."""

from __future__ import annotations

import argparse
import json
import subprocess
import zipfile
from pathlib import Path
from typing import Any

from tools.qa.world.lighting.quality import checks, pixels, provenance
from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality.evidence import Evidence


def verify(output: Path, expected_head: str, current: bool = False) -> dict[str, Any]:
    """Проверяет исходники, все кадры/состояния и сырые измерения без модификации evidence."""
    store = Evidence(output)
    source = store.document("source.json")
    provenance.check(store, source, expected_head, current)
    rows: dict[str, Any] = {}
    for label in ("baseline", "candidate"):
        rows[label] = {}
        for width in c.WIDTHS:
            rows[label][str(width)] = checks.capture(store, source, label, width)
    for width in c.WIDTHS:
        key = str(width)
        baseline, current_row = rows["baseline"][key]["capture"], rows["candidate"][key]["capture"]
        size = [width, width * 9 // 16]
        for case in c.CASES:
            name = case + "-standard"
            old, new = baseline["frames"][name], current_row["frames"][name]
            checks.same_game(old["before"], new["before"])
            for suffix in (".png", "-hud.png", *(f"-{target}-hidden.png" for target in c.TARGETS)):
                c.need(
                    pixels.equal(
                        store.image(f"baseline/{width}/" + name + suffix, size),
                        store.image(f"candidate/{width}/" + name + suffix, size),
                    ),
                    "default standard differs from accepted same-camera pixels: " + name + suffix,
                )
        checks.same_game(baseline["costs"][0]["before"], current_row["costs"][0]["before"])
    return {
        "task": "VLIGHT-010",
        "base": c.BASE,
        "head": expected_head,
        "native_png": sum(name.endswith(".png") for name in c.artifacts()),
        "runs": 4,
        "default_standard_equal": True,
        "target_signal": {
            label: {width: row["signals"] for width, row in widths.items()}
            for label, widths in rows.items()
        },
        "world_luminance": {
            label: {width: row["luminance"] for width, row in widths.items()}
            for label, widths in rows.items()
        },
        "costs": {
            label: {width: row["costs"] for width, row in widths.items()}
            for label, widths in rows.items()
        },
        "gpu_time_measured": False,
        "hardware_fps_acceptance": False,
        "whole_location_accepted": False,
    }


def main() -> None:
    """Ожидаемый SHA обязателен; stdout — только фактическая сводка, исходные файлы не пишутся."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    try:
        result = verify(args.output, args.expected_head, args.check_current_candidate)
    except (
        ValueError,
        KeyError,
        IndexError,
        TypeError,
        OSError,
        subprocess.SubprocessError,
        zipfile.BadZipFile,
    ) as error:
        parser.exit(2, str(error) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
