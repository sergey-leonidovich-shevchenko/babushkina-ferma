"""Проверяет выгруженный каталог и настоящие интервалы отрисовки после добавления алхимии."""
import json
import math
from pathlib import Path

from tools.common.paths import project_root

ROOT = project_root(__file__)


def main():
    """Сверяет реестры дизайна, полноту рецептов и два полных графических сценария деревни."""
    catalog = json.loads((ROOT / "docs/design/alchemy-catalog.json").read_text())
    herbs = json.loads((ROOT / "docs/design/alchemy-herbs.json").read_text())
    assert catalog["herbs"] == herbs
    assert len(herbs) == 24 and len(catalog["items"]) == 148
    assert len(catalog["potions"]) == 16 and len(catalog["recipes"]) == 131
    registered = catalog["items"] | catalog["legacy"]
    identities = set()
    for recipe in catalog["recipes"]:
        assert recipe["id"] not in identities
        identities.add(recipe["id"])
        assert recipe["output"] in registered and recipe["count"] > 0
        for kind, quantity in (recipe["inputs"] | recipe.get("byproducts", {})).items():
            assert kind in registered and quantity > 0
    for names in registered.values():
        assert len(names) == 6 and all(names)
    for mode in ("normal", "f10"):
        path = ROOT / "docs/reports/alchemy-performance-2026-10-12/window" / ("native_profile_town_" + mode + ".json")
        report = json.loads(path.read_text())
        intervals = sorted(report["draw_intervals_ms"])
        assert len(intervals) >= 1000 and all(math.isfinite(v) and v > 0 for v in intervals)
        p95 = intervals[int((len(intervals) - 1) * 0.95)]
        assert abs(p95 - report["draw_frame"]["p95_ms"]) < 0.0001 and p95 <= 20
        assert report["route_finished"] and report["town_loops"] >= 1 and report["user_saves_unchanged"]
        assert report["mode"] == mode and report["window_size"] == [1152, 648]
        print(mode, "draw p95", p95)
    print("ALCHEMY REPORTS: catalog and both native scenarios passed")


if __name__ == "__main__":
    main()
