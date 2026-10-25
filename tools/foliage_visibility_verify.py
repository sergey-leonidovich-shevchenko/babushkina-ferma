#!/usr/bin/env python3
"""Проверка исторической серии VFOLIAGE-010; текущий кандидат проверяется отдельным флагом."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from foliage_visibility_coverage import verify_coverage, verify_pairs
from foliage_visibility_evidence import (
    REPORT,
    ROOT,
    Frames,
    require,
    verify_artifacts,
    verify_pixels,
    verify_viewing,
)
from foliage_visibility_provenance import BASE, verify_current_candidate, verify_history
from foliage_visibility_window import verify_window_metadata


def verify(
    root: Path,
    *,
    check_current_candidate: bool = False,
    candidate_root: Path = ROOT,
    report_dir: Path = REPORT,
) -> dict:
    """Сверяет происхождение, структуру и все пиксели, не принимая старую съёмку за новую."""
    source, plan = verify_history(root, report_dir)
    if check_current_candidate:
        verify_current_candidate(plan, candidate_root)

    frames = Frames(root)
    verify_viewing(root)
    verify_artifacts(root, source, frames)
    require(
        [run["width"] for run in source["runs"]] == [1152, 1280],
        "both native runs required",
    )
    # Метаданные обеих матриц проверяются раньше декодирования любого изображения.
    windows = [verify_window_metadata(root, run) for run in source["runs"]]
    result = {
        "task": "VFOLIAGE-010",
        "windows": [],
        "frames": 0,
        "exact_pairs": 0,
        "coverage_targets": 0,
        "fps_admitted": False,
        "historical_base": BASE,
        "current_candidate_checked": check_current_candidate,
    }
    for window in windows:
        coverage = verify_coverage(frames, window)
        result["exact_pairs"] += verify_pairs(frames, window)
        for row in window.rows:
            verify_pixels(frames, window.prefix, row, window.width)
        result["frames"] += len(window.rows)
        result["coverage_targets"] += len(coverage)
        result["windows"].append(
            {
                "width": window.width,
                "root_draw_calls_range": [min(window.root_calls), max(window.root_calls)],
                "cost": window.costs,
                "coverage": coverage,
            }
        )
    return result


def main() -> None:
    """Публикует результат historical gate; strict guard включается только явно."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPORT / "native-01")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-current-candidate", action="store_true")
    parser.add_argument("--candidate-root", type=Path, default=ROOT)
    args = parser.parse_args()
    result = verify(
        args.root,
        check_current_candidate=args.check_current_candidate,
        candidate_root=args.candidate_root,
    )
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(
        "FOLIAGE VISIBILITY VERIFIED:",
        result["frames"], "native frames,",
        result["exact_pairs"], "exact pairs,",
        result["coverage_targets"], "coverage targets; historical evidence;",
        "current candidate checked:" if args.check_current_candidate else "current candidate not checked;",
        "no FPS admission",
    )


if __name__ == "__main__":
    main()
