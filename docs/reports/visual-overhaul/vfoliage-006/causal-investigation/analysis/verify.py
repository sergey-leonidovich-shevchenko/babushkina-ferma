"""Independently replay every campaign input, including negative cap60 outcomes and uncapped controls."""

from pathlib import Path
import gzip
import hashlib
import io
import json
import subprocess
import sys
import tarfile

ROOT = next(
    p for p in Path(__file__).resolve().parents if (p / "project.godot").is_file()
)
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "instrumentation"))
from performance_protocol import events, validate
from causal_process import cpu_window, ticks_ns
from archive import verify as verify_archive


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify(folder):
    plan_bytes = (folder / "plan.json").read_bytes()
    plan = json.loads(plan_bytes)
    plan_sha = digest(plan_bytes)
    campaign = folder / "campaign"
    manifest = json.loads((campaign / "manifest.json").read_text())
    assert manifest["complete"] and len(manifest["cases"]) == len(plan["order"]) == 24
    assert manifest["plan_sha256"] == plan_sha
    assert (campaign / "plan.json").read_bytes() == plan_bytes
    assert digest((folder / "PLAN.md").read_bytes()) == plan["plan_text_sha256"]
    for name, value in plan["instrumentation_sha256"].items():
        assert digest((folder / "instrumentation" / name).read_bytes()) == value
    trees = {}
    for revision in [plan["head"], plan["base"]]:
        raw = subprocess.check_output(
            ["git", "archive", revision, "scripts", "main.tscn", "project.godot"],
            cwd=ROOT,
        )
        with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
            trees[revision] = {
                row.name: digest(archive.extractfile(row).read())
                for row in archive
                if row.isfile()
            }
    result = []
    for index, (case, order) in enumerate(zip(manifest["cases"], plan["order"])):
        assert [case["target"], case["mode"], case["cap"]] == order
        path = campaign / case["folder"]
        context = json.loads((path / "context.json").read_text())
        raw = gzip.decompress((path / "stdout.txt.gz").read_bytes())
        rows = events(raw, context["returncode"])
        ready = rows[0]
        assert digest(raw) == context["stdout_sha256"]
        assert context["revision"] == plan[case["target"]]
        assert context["causal_plan_sha256"] == plan_sha
        assert context["sources_unchanged"] and context["assets_unchanged"]
        assert all(
            trees[context["revision"]][key] == value
            for key, value in context["sources"].items()
        )
        assert (
            digest((path / "sampler.gd.txt").read_bytes())
            == context["expected"]["sampler_sha256"]
            == ready["sampler_sha256"]
        )
        assert (
            ready["engine_hash"] == plan["engine_hash"]
            and ready["cap_after"] == case["cap"]
        )
        assert ready["player"] == plan[case["mode"] + "_route_start"]
        assert ready["seed"] == plan["seed"] and ready["locale"] == plan["locale"]
        if case["cap"] == 60:
            value = validate(
                raw, context["returncode"], case["mode"], context["expected"]
            )
            assert value == context["measurement"] == case["measurement"]
        else:
            assert ready["purpose"] == "causal_uncapped_diagnostic"
            assert ready["mode"] == case["mode"] and ready["debug"] == (
                case["mode"] == "f10"
            )
            begin = [r for r in rows if r["kind"] == "begin"]
            end = [r for r in rows if r["kind"] == "end"]
            assert len(begin) == len(end) == 1
            start = begin[0]["time_us"]
            finishes = [r for r in rows if r["kind"] == "frame"]
            assert all(r["cap"] == 0 for r in finishes)
            assert all(
                a["time_us"] < b["time_us"] for a, b in zip(finishes, finishes[1:])
            )
            assert end[0]["time_us"] - start >= 10_000_000
            bins = [
                sum(
                    start + n * 1_000_000 <= r["time_us"] < start + (n + 1) * 1_000_000
                    for r in finishes
                )
                for n in range(10)
            ]
            samples = [r for r in rows if r["kind"] == "sample"]
            assert len(samples) == 10 and [r["frames"] for r in samples] == bins
            assert sum(bins) == case["measurement"]["window_frames"]
            assert sum(bins) / 10 == case["measurement"]["average_fps"]
            assert case["measurement"]["budget_applicable"] is False
        observer = json.loads(gzip.decompress((path / "observer.json.gz").read_bytes()))
        assert (
            cpu_window(observer["markers"]["begin"], observer["markers"]["end"])
            == observer["cpu_window"]
        )
        for marker in observer["markers"].values():
            game = marker["processes"]["game"]
            assert game["available"] and game["pid"] == observer["pid"]
            assert (
                ticks_ns(game["user_ticks"] + game["system_ticks"], *game["timebase"])
                == game["cpu_ns"]
            )
        assert (
            observer["profiler"]["returncode"] == 0
            and observer["profiler"]["target_pid"] == observer["pid"]
        )
        analysis = json.loads((path / "analysis.json").read_text())
        assert (
            analysis["effective_settings_match"]
            and analysis["all_frame_settings_match"]
            and not analysis["overflow"]
        )
        result.append(
            {
                "index": index + 1,
                "case": path.name,
                "fps": case["measurement"]["average_fps"],
                "cap": case["cap"],
                "raw_sha256": digest(raw),
                "source_and_same_PID_CPU_verified": True,
            }
        )
    old = ROOT / "docs/reports/visual-overhaul/vfoliage-006/ci-performance/production"
    assert not subprocess.check_output(
        ["git", "diff", plan["head"], "--name-only", "--", str(old)], cwd=ROOT
    )
    old_cases = 0
    for series in ["paired-before", "paired-after"]:
        previous = json.loads((old / series / "summary.json").read_text())
        for case in previous["cases"]:
            path = old / series / case["folder"]
            ctx = json.loads((path / "context.json").read_text())
            raw = (path / "stdout.txt").read_bytes()
            assert digest(raw) == ctx["stdout_sha256"]
            assert (
                validate(raw, ctx["returncode"], case["mode"], ctx["expected"])
                == case["result"]
            )
            old_cases += 1
    assert old_cases == 24
    return {
        "cases": result,
        "archive": verify_archive(campaign),
        "all_24_inputs_replayed": True,
        "old_series_unchanged": True,
        "production_changed": False,
        "local_budget_closed": False,
    }


if __name__ == "__main__":
    folder = Path(__file__).resolve().parents[1]
    result = verify(folder)
    (folder / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(
        "CAUSAL: all24 inputs, Git runtime SHA, same-PID CPU, Mach units and96 gzip round-trips verified; local budget remains open"
    )
