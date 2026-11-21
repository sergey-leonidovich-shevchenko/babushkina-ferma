"""Reader нативной палитры: Git, реальные кадры/HUD, save, изоляция и исходные samples."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.qa.world.lighting.daycycle import contract as c
from tools.qa.world.lighting.daycycle import pixels, provenance, readings
from tools.qa.world.lighting.daycycle.evidence import Evidence

REPORT = c.ROOT / "docs/reports/visual-overhaul/vlight-003/native"


def compare(
    store: Evidence, width: int, old: dict[str, Any], new: dict[str, Any]
) -> dict[str, Any]:
    """Старый runtime сравнивается с реальным legacy; endpoints/области сохранены, dusk изменён."""
    size = new["size"]
    results = {}
    for case in c.CASES:
        baseline = old["frames"][case + "-palette"]
        legacy = new["frames"][case + "-legacy"]
        selected = new["frames"][case + "-palette"]
        before = store.image(f"baseline/{width}/" + baseline["file"], size)
        prior = store.image(f"candidate/{width}/" + legacy["file"], size)
        after = store.image(f"candidate/{width}/" + selected["file"], size)
        pixels.stable_hud(
            store.image(f"baseline/{width}/" + baseline["hud"], size),
            store.image(f"candidate/{width}/" + legacy["hud"], size),
            store.image(f"candidate/{width}/" + selected["hud"], size),
        )
        c.need(pixels.equal(before, prior), "legacy no longer matches accepted runtime: " + case)
        for field in ("save", "geometry"):
            c.need(
                baseline["before"][field] == selected["before"][field],
                "old/current complete state differs: " + case,
            )
        changed = not pixels.equal(prior, after)
        c.need(
            changed == (case in ("street-dawn", "street-dusk")),
            "palette scope/endpoint differs: " + case,
        )
        for target in ("hero", "threat") if case.startswith("street-") else ():
            hidden = store.image(f"candidate/{width}/" + selected["hidden"][target], size)
            prior_hidden = store.image(f"candidate/{width}/" + legacy["hidden"][target], size)
            signal = pixels.target(after, hidden, selected[target])
            prior_signal = pixels.target(prior, prior_hidden, legacy[target])
            c.need(signal >= prior_signal * 0.70, "palette obscures existing hero/threat: " + case)
        results[case] = {"changed": changed, "legacy_matches_main": True}
    row = new["frames"]["street-dusk-palette"]
    try:
        pixels.hud(
            store.image(f"candidate/{width}/" + row["bad_hud"], size),
            store.image(f"candidate/{width}/" + row["hud"], size),
        )
    except ValueError as error:
        c.need("recolors opaque HUD" in str(error), "negative control failed for unrelated reason")
    else:
        raise ValueError("native bad-HUD control was accepted")
    return results


def verify(folder: Path, expected_head: str | None = None, current: bool = False) -> dict[str, Any]:
    """Полная матрица обязательна; ни диагностический PNG, ни unit-тест не дают допуска."""
    store = Evidence(folder)
    source = store.document("source.json")
    if expected_head:
        c.need(source["head"] == expected_head, "expected exact head differs")
    provenance.check(store, source, current)
    result = {}
    for width in c.WIDTHS:
        old = readings.capture(store, source, "baseline", width)
        new = readings.capture(store, source, "candidate", width)
        result[str(width)] = compare(store, width, old, new)
        readings.twins(store, width, new)
    return {
        "task": "VLIGHT-003",
        "head": source["head"],
        "widths": result,
        "hardware_fps_acceptance": False,
    }


def main() -> None:
    """Старые отчёты остаются frozen; проверка текущего render/QA включается явно перед ревью."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=REPORT)
    parser.add_argument("--expected-head")
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            verify(args.output, args.expected_head, args.check_current_candidate),
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
