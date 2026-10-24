"""Recompute the fixed redraw campaign from lossless raw evidence, without new game runs."""

from __future__ import annotations

import collections
import gzip
import hashlib
import json
from pathlib import Path
import sys
import tempfile

REPORT = Path(__file__).resolve().parent
ROOT = REPORT.parents[4]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(REPORT.parent / "causal-investigation" / "analysis"))
from analyze import analyze, read
from performance_protocol import validate
from performance_gate import runtime_sources


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def profile_counts(folder: Path, raw: bytes) -> dict:
    """Reuse the original span analyzer; count repeated draw by actual process-frame ID."""
    # The historical analyzer writes derived files. Give it private copies, never evidence paths.
    with tempfile.TemporaryDirectory(prefix="redraw-offline-") as directory:
        temporary = Path(directory)
        (temporary / "plan.json").write_bytes((REPORT / "plan.json").read_bytes())
        captured = temporary / "campaign" / folder.name
        captured.mkdir(parents=True)
        for name in ["context.json", "observer.json", "stdout.txt"]:
            (captured / name).write_bytes(read(folder / name))
        details = analyze(captured)
    assert details["effective_settings_match"] and details["all_frame_settings_match"]
    assert not details["overflow"]
    names, spans = [], []
    for line in raw.decode().splitlines():
        if line.startswith("DIAG_FINAL "):
            names = json.loads(line[len("DIAG_FINAL "):])["names"]
        elif line.startswith("DIAG_SPAN "):
            spans.append(json.loads(line[len("DIAG_SPAN "):]))
    draws = collections.defaultdict(list)
    for span in spans:
        if names[span[0]] == "_draw":
            draws[span[3]].append(span)
    return {
        "draws": sum(map(len, draws.values())),
        "max_draws_per_process_frame": max(map(len, draws.values())),
        "excess_draws": sum(len(group) - 1 for group in draws.values()),
        "excess_wall_us": sum(
            span[2] - span[1]
            for group in draws.values()
            for span in sorted(group, key=lambda item: item[1])[:-1]
        ),
        "draw_wall_us": details["phase_inclusive_us"]["_draw"]["sum"],
        "physics_calls": details["phase_inclusive_us"]["_physics_process"]["count"],
        "process_calls": details["phase_inclusive_us"]["_process"]["count"],
        "root_union_us": details["root_union_us"],
        "frame_gap_us": details["frame_gap_us"],
    }


def verify() -> dict:
    """Keep the historical plan immutable and compare every case, including failed budgets."""
    plan = json.loads((REPORT / "plan.json").read_text())
    manifest = json.loads((REPORT / "campaign/manifest.json").read_text())
    expected_sha = "5384a3bedb06a07910e44e683cc20d92a87794cb92ccc22d2c89e15e965c096c"
    assert digest((REPORT / "plan.json").read_bytes()) == expected_sha
    assert manifest["plan_sha256"] == expected_sha
    assert manifest["complete"] and len(manifest["cases"]) == 18
    assert runtime_sources(ROOT) == manifest["candidate_sources"]
    assert digest((REPORT / "candidate.patch").read_bytes()) == plan["candidate_patch_sha256"]
    for path, expected in plan["instrumentation_sha256"].items():
        assert digest((REPORT / "instrumentation" / path).read_bytes()) == expected, path
    for path, expected in plan["candidate_runtime_delta"].items():
        assert digest((ROOT / path).read_bytes()) == expected["after"], path
    # Compression changes storage only; independently verify both container and original bytes.
    archives = json.loads((REPORT / "archive.json").read_text())
    for entry in archives:
        data = (REPORT / entry["path"]).read_bytes()
        assert digest(data) == entry["gzip_sha256"], entry["path"]
        raw = gzip.decompress(data)
        assert len(raw) == entry["raw_bytes"] and digest(raw) == entry["raw_sha256"]
    rows = []
    for case, order in zip(manifest["cases"], plan["order"]):
        assert [case["cohort"], case["target"], case["mode"]] == order
        folder = REPORT / "campaign" / case["folder"]
        context = json.loads((folder / "context.json").read_text())
        raw = read(folder / "stdout.txt")
        assert digest(raw) == context["stdout_sha256"]
        result = validate(raw, context["returncode"], case["mode"], context["expected"])
        assert result == case["result"]
        source_key = "candidate_sources" if case["target"] == "after" else "before_sources"
        assert context["sources"] == manifest[source_key]
        observer = json.loads(read(folder / "observer.json"))
        assert observer["cpu_window"]["available"]
        row = {**case, "cpu_window": observer["cpu_window"]}
        if case["cohort"] == "profile":
            row["profile"] = profile_counts(folder, raw)
        else:
            assert observer["profiler"]["enabled"] is False
            settings = [
                json.loads(line[len("REVIEW_SETTINGS "):])["settings"]
                for line in raw.decode().splitlines()
                if line.startswith("REVIEW_SETTINGS ")
            ]
            assert len(settings) == 3
            assert all(
                all(item.get(key) == value for key, value in plan["effective_after_startup"].items())
                for item in settings
            )
        rows.append(row)
    saved = json.loads((REPORT / "measurements.json").read_text())
    assert rows == saved["cases"]
    after = [row for row in rows if row["cohort"] == "primary" and row["target"] == "after"]
    passed = len(after) == 6 and all(row["result"]["valid"] and row["result"]["budget_passed"] for row in after)
    assert passed == saved["primary_after_all6_ge50"]
    return {"cases": len(rows), "lossless_archives": len(archives), "primary_after_all_six_ge50": passed}


if __name__ == "__main__":
    print(json.dumps(verify()))
