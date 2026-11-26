"""Collect and independently verify VPERF-005 on a single remote Linux/X11 runner."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
import uuid
from itertools import pairwise
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageStat

from tools.common.git import git_environment, parse_git_tree, regular_git_blob
from tools.qa.performance import perf_contract as perf
from tools.qa.performance.pass_cost import collect as remote
from tools.qa.performance.pass_cost.contract import (
    ROOT,
    digest,
    git,
    ordinary_file,
    read,
    require,
    tree,
    write,
)
from tools.qa.performance.texture_budget.inventory import (
    BUDGET,
    CONTRACT,
    INITIAL,
    PASS_COST,
    inventory,
)

TASK = "VPERF-005"
BASE = "c88db730ffb604fd64f818fa9ef9e6e287dd4cd4"
PREFIX = "tools/qa/performance/"
CAPTURE = PREFIX + "perf_contract_capture.gd"
WITNESS = PREFIX + "texture_budget/witness.gd"
POINTS = "docs/reports/visual-overhaul/vbase-003/camera-points.json"
WORKFLOW = ".github/workflows/vperf-005.yml"
PROJECT = "project.godot"
EXPORT_STAMP = ".vperf-005-export.json"
SHARED = (CAPTURE, POINTS, BUDGET, "tools/qa/camera/visual_camera_points.gd")
EXPORT = (
    PROJECT,
    "VERSION",
    "main.tscn",
    "assets",
    "scripts",
    "tools/qa",
    BUDGET,
    POINTS,
    INITIAL,
    str(CONTRACT),
    PASS_COST,
)
TOOLING = (
    WITNESS,
    WORKFLOW,
    PREFIX + "texture_budget/pair.py",
    PREFIX + "texture_budget/inventory.py",
    PREFIX + "perf_contract.py",
    PREFIX + "pass_cost/collect.py",
    PREFIX + "pass_cost/contract.py",
    "tools/common/git.py",
    "tools/common/paths.py",
)
MODES = ("baseline", "candidate")
RUNS = (("repeat-1", 30), ("repeat-2", 30), ("repeat-3", 30), ("long-cycle", 600))
RENDER_FIELDS = ["usec", "interval_ms", "render_frame", "process_frame"]
BENCH_FILES = ("run.json", "rows.csv.gz", "render-rows.csv.gz", "before.png", "after.png")
WITNESS_FILES = ("witness.json", "overworld.png", "workshop.png")


def schedule() -> list[tuple[str, str, int]]:
    return [
        (run, mode, seconds)
        for index, (run, seconds) in enumerate(RUNS)
        for mode in (MODES if index % 2 == 0 else MODES[::-1])
    ]


def payload_files(seconds: int | None) -> tuple[str, ...]:
    files = WITNESS_FILES if seconds is None else (*BENCH_FILES, "cpu-rss.json")
    return (*files, "stdout.txt", "engine.log")


def paths() -> set[str]:
    return (
        {
            f"{name}/{mode}/{file}"
            for name, mode, seconds in schedule()
            for file in ("launch.json", *payload_files(seconds))
        }
        | {
            f"witness/{mode}/{file}"
            for mode in MODES
            for file in ("launch.json", *payload_files(None))
        }
        | {f"{mode}-{file}" for mode in MODES for file in ("inventory.json", "import.txt")}
    )


def export_listing(revision: str) -> bytes:
    return git("ls-tree", "-rz", revision, "--", *EXPORT)


def identities(head: str) -> dict[str, Any]:
    require(head != BASE, "candidate and baseline coincide")
    subprocess.run(
        ["git", "--no-replace-objects", "-C", str(ROOT), "merge-base", "--is-ancestor", BASE, head],
        env=git_environment(),
        check=True,
    )
    identifiers = {}
    for mode, revision in zip(MODES, (BASE, head), strict=True):
        project = git("show", f"{revision}:{PROJECT}")
        settings = b"\n".join(
            line for line in project.splitlines() if not line.startswith(b"config/version=")
        )
        identifiers[mode] = {
            "commit": revision,
            "tree": tree(revision),
            "export_git_blobs_sha256": hashlib.sha256(export_listing(revision)).hexdigest(),
            "project_godot_sha256": hashlib.sha256(project).hexdigest(),
            "configuration": {
                path: hashlib.sha256(git("show", f"{revision}:{path}")).hexdigest()
                for path in SHARED
            }
            | {"project_settings_excluding_build_version": hashlib.sha256(settings).hexdigest()},
        }
    require(
        identifiers["baseline"]["configuration"] == identifiers["candidate"]["configuration"],
        "shared camera, project or sample protocol changed",
    )
    return identifiers


def tooling(head: str) -> dict[str, str]:
    return {path: hashlib.sha256(git("show", f"{head}:{path}")).hexdigest() for path in TOOLING}


def export_project(head: str, project: Path) -> None:
    """Export the game and QA sources while skipping unrelated multi-gigabyte reports."""
    project.mkdir()
    with tempfile.TemporaryFile() as archive:
        subprocess.run(
            ["git", "--no-replace-objects", "-C", str(ROOT), "archive", head, *EXPORT],
            stdout=archive,
            env=git_environment(),
            check=True,
        )
        archive.seek(0)
        subprocess.run(["tar", "-xf", "-", "-C", str(project)], stdin=archive, check=True)


def verify_export(project: Path, identity: dict[str, Any]) -> None:
    """Compare the actual exported source files to the Git blobs before stamping the project."""
    listing = export_listing(identity["commit"])
    require(
        hashlib.sha256(listing).hexdigest() == identity["export_git_blobs_sha256"],
        "Git export listing differs",
    )
    expected = parse_git_tree(listing)
    require(expected, "Git export has no files")
    for name, entry in expected.items():
        require(regular_git_blob(entry), f"unsupported Git export entry: {name}")
        path = ordinary_file(project, name)
        blob = hashlib.sha1(f"blob {path.stat().st_size}\0".encode("ascii"))
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                blob.update(block)
        require(blob.hexdigest().encode("ascii") == entry[2], f"exported source differs: {name}")


def run_binding(
    source: dict[str, Any], name: str, mode: str, seconds: int | None
) -> dict[str, Any]:
    variant = source["variants"][mode]
    return {
        "run": name,
        "seconds": seconds,
        "project": {
            "mode": mode,
            "path": source["export_paths"][mode],
            "commit": variant["commit"],
            "tree": variant["tree"],
            "export_git_blobs_sha256": variant["export_git_blobs_sha256"],
        },
    }


def capture(
    engine: Path, project: Path, target: Path, runtime: Path, binding: dict[str, Any]
) -> None:
    seconds: int | None = binding["seconds"]
    require(
        str(project.resolve()) == binding["project"]["path"]
        and read(project / EXPORT_STAMP) == binding["project"],
        "capture project does not match the verified Git export",
    )
    target.mkdir(parents=True)
    runtime.mkdir()
    environment = remote.runner_environment(runtime)
    prefix = "Codex-VPERF-001-" if seconds is not None else "Codex-VPERF-005-"
    profile = prefix + uuid.uuid4().hex
    remote.override(project, profile)
    captured = runtime / "capture"
    command = [
        str(engine),
        "--path",
        str(project),
        "--rendering-method",
        "gl_compatibility",
        "--windowed",
        "--resolution",
        "1152x648",
        "--audio-driver",
        "Dummy",
        "--log-file",
        str(target / "engine.log"),
        "--script",
        "res://" + (CAPTURE if seconds is not None else WITNESS),
        "--",
        "--output=" + str(captured),
        "--profile=" + profile,
    ]
    if seconds is not None:
        command.append(f"--seconds={seconds}")
    samples = []
    timed_out = False
    with (target / "stdout.txt").open("x") as stream:
        with subprocess.Popen(
            command, env=environment, stdout=stream, stderr=subprocess.STDOUT
        ) as process:
            deadline = time.monotonic() + (seconds or 0) * 1.5 + 90
            while process.poll() is None:
                if seconds is not None:
                    try:
                        samples.append(remote.process_sample(process.pid))
                    except ProcessLookupError:
                        break
                    except FileNotFoundError:
                        break
                if time.monotonic() >= deadline:
                    timed_out = True
                    process.kill()
                    break
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    continue
            receipt = {
                "command": command,
                "pid": process.pid,
                "exit": process.wait(),
                "timeout": timed_out,
                "profile": profile,
                "source": binding,
            }
    if seconds is not None:
        write(
            target / "cpu-rss.json",
            {
                "page_size": os.sysconf("SC_PAGE_SIZE"),
                "tick_hz": os.sysconf("SC_CLK_TCK"),
                "samples": samples,
            },
        )
    if captured.is_dir():
        for file in captured.iterdir():
            shutil.move(file, target / file.name)
    for name in ("rows.csv", "render-rows.csv"):
        remote.compress_csv(target / name)
    receipt["payload_sha256"] = {
        name: digest(target / name) for name in payload_files(seconds) if (target / name).is_file()
    }
    write(target / "launch.json", receipt)
    check_launch(target, binding)


def check_launch(folder: Path, binding: dict[str, Any]) -> dict[str, Any]:
    receipt: dict[str, Any] = read(folder / "launch.json")
    require(receipt["exit"] == 0 and receipt["timeout"] is False, f"capture failed: {folder}")
    require(receipt.get("source") == binding, f"capture source binding differs: {folder}")
    command = receipt["command"]
    require("--headless" not in command, f"non-native capture: {folder}")
    require(command.count("--path") == 1, f"missing or ambiguous project path: {folder}")
    path_index = command.index("--path") + 1
    require(path_index < len(command), f"missing project path: {folder}")
    project = Path(command[path_index])
    require(
        project.is_absolute() and str(project) == binding["project"]["path"],
        f"launch project path differs from capture mode: {folder}",
    )
    expected = {
        name: digest(ordinary_file(folder, name)) for name in payload_files(binding["seconds"])
    }
    require(receipt.get("payload_sha256") == expected, f"capture payload differs: {folder}")
    for name in ("stdout.txt", "engine.log"):
        log = (folder / name).read_text(errors="replace")
        require(
            "ERROR:" not in log and "Parse Error" not in log, f"engine rejected {folder}/{name}"
        )
    return receipt


def collect(folder: Path, head: str) -> None:
    require(
        sys.platform == "linux"
        and os.environ.get("GITHUB_ACTIONS") == "true"
        and os.environ.get("DISPLAY"),
        "remote Linux/X11 runner required",
    )
    require(
        git("rev-parse", "HEAD").decode().strip() == head and not git("status", "--porcelain"),
        "exact clean Git checkout required",
    )
    engine = Path(os.environ["FARM_GODOT_BIN"]).resolve(strict=True)
    version = subprocess.check_output([str(engine), "--version"], text=True).strip()
    require(version.startswith(remote.PINNED_ENGINE), "expected Godot 4.7.1")
    folder = remote.fresh_output(folder)
    source = {
        "schema": 2,
        "task": TASK,
        "head": head,
        "variants": identities(head),
        "tooling": tooling(head),
        "configuration": read(ROOT / BUDGET)["scene"],
        "export_inputs": list(EXPORT),
        "export_paths": {},
        "schedule": [list(run) for run in schedule()],
        "host": remote.host(),
        "engine": version,
        "engine_binary_sha256": digest(engine),
        "runner_id": os.environ["GITHUB_RUN_ID"],
        "runner_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
        "complete": False,
    }
    write(folder / "source.json", source)
    with tempfile.TemporaryDirectory(prefix="vperf-005-") as directory:
        work = Path(directory)
        for mode, identity in source["variants"].items():
            project = work / mode
            export_project(identity["commit"], project)
            write(folder / f"{mode}-inventory.json", inventory(project))
            if mode == "baseline":
                # Only the new observer is copied; benchmark and game code come from each exact Git tree.
                (project / WITNESS).parent.mkdir(exist_ok=True)
                (project / WITNESS).write_bytes(git("show", f"{head}:{WITNESS}"))
            runtime = work / f"import-{mode}"
            runtime.mkdir()
            remote.override(project, "Codex-VPERF-005-import-" + uuid.uuid4().hex)
            with (folder / f"{mode}-import.txt").open("x") as stream:
                subprocess.run(
                    [
                        str(engine),
                        "--headless",
                        "--path",
                        str(project),
                        "--editor",
                        "--quit",
                        "--log-file",
                        str(runtime / "import.log"),
                    ],
                    stdout=stream,
                    stderr=subprocess.STDOUT,
                    env=remote.runner_environment(runtime),
                    timeout=600,
                    check=True,
                )
            verify_export(project, identity)
            require(
                digest(project / WITNESS) == source["tooling"][WITNESS],
                "witness overlay hash differs",
            )
            source["export_paths"][mode] = str(project.resolve())
            stamp = run_binding(source, "witness", mode, None)["project"]
            write(project / EXPORT_STAMP, stamp)
        for mode in MODES:
            print(f"{TASK} {mode} visual and save witness", flush=True)
            binding = run_binding(source, "witness", mode, None)
            capture(
                engine, work / mode, folder / "witness" / mode, work / f"witness-{mode}", binding
            )
        compare_witnesses(
            folder,
            selected_atlas_paths(read(folder / "candidate-inventory.json")),
            source,
        )
        for name, mode, seconds in schedule():
            print(f"{TASK} {name}/{mode} {seconds}s", flush=True)
            binding = run_binding(source, name, mode, seconds)
            capture(engine, work / mode, folder / name / mode, work / f"{name}-{mode}", binding)
            inspect(folder / name / mode, binding)
    source["artifacts"] = {name: digest(ordinary_file(folder, name)) for name in sorted(paths())}
    source["complete"] = True
    write(folder / "source.json", source)


def verify_png(path: Path) -> None:
    with Image.open(path) as picture:
        require(
            picture.size == (1152, 648) and picture.format == "PNG", f"invalid native PNG {path}"
        )
        picture.verify()


def texture_counter(rows: list[dict[str, float]]) -> dict[str, Any]:
    values = [row["texture_bytes"] for row in rows]
    if not all(value > 0 for value in values):
        return {
            "status": "unavailable-or-incomplete",
            "nonpositive_samples": sum(value <= 0 for value in values),
            "bytes": None,
        }
    return {"status": "observed", "bytes": perf.distribution(values)}


def validate_samples(
    data: dict[str, Any], rows: list[dict[str, float]], seconds: int
) -> dict[str, Any]:
    require(
        data["schema"] == 1
        and data["task"] == "VPERF-001"
        and not data["errors"]
        and data["fault"] == ""
        and data["seconds"] == seconds
        and data["display_server"] == "X11"
        and data["driver"] == "opengl3"
        and data["vsync"] in (0, 1)
        and data["max_fps"] == 0
        and data["physics_hz"] == 60
        and data["warmup_frames"] == 120
        and data["observer_buffer_bytes"] == 15840000
        and data["zoom"] == 1.2
        and data["hud_zoom"] == 1
        and math.dist(data["field"], [960, 540]) < 0.001
        and data["reduced_motion"] is True
        and data["audio_enabled"] is False
        and data["pause_on_focus_loss"] is False
        and data["gpu_time_ms"] is None
        and all(
            data[key] is False
            for key in ("disk_io_during_samples", "readback_during_samples", "manual_simulation")
        ),
        "reference protocol or X11 settings differ",
    )
    for phase in ("initial", "final"):
        state = data[phase]
        require(
            state["mode"] == 0
            and state["focused"] is True
            and all(state[key] == [1152, 648] for key in ("window", "root", "readback", "visible"))
            and math.dist(state["camera"], [120.25, 430.25]) < 0.001,
            "native endpoint size, camera or focus changed",
        )
    require(len(rows) == data["samples"] and len(rows) > seconds * 5, "raw rows incomplete")
    for row in rows:
        require(
            all(math.isfinite(value) for value in row.values())
            and all(row[key] > 0 for key in ("interval_ms", "draw_calls", "static_bytes"))
            and all(
                row[key] >= 0
                for key in (
                    "engine_frame_ms",
                    "engine_physics_ms",
                    "callback_span_ms",
                    "texture_bytes",
                )
            )
            and (row["focused"], row["modal"], row["window_x"], row["window_y"])
            == (1, 0, 1152, 648)
            and math.dist((row["camera_x"], row["camera_y"]), [120.25, 430.25]) < 0.001,
            "invalid raw row or native conditions changed",
        )
    for previous, current in pairwise(rows):
        require(
            abs((current["usec"] - previous["usec"]) / 1000 - current["interval_ms"]) < 0.002
            and current["process_frame"] == previous["process_frame"] + 1
            and current["physics_frame"] >= previous["physics_frame"]
            and current["absolute_minutes"] >= previous["absolute_minutes"],
            "clock, frame, or simulation order changed",
        )
    actual = sum(row["interval_ms"] for row in rows) / 1000
    simulation = {
        key: rows[-1][key] - rows[0][key] for key in ("physics_frame", "absolute_minutes")
    }
    require(
        seconds <= actual < seconds + 5
        and abs((data["ended_utc"] - data["started_utc"]) - actual) < 2
        and simulation["physics_frame"] >= seconds * 20
        and simulation["absolute_minutes"] >= seconds * 0.5,
        "capture duration or simulation incomplete",
    )
    metrics = {
        key: perf.distribution([row[key] for row in rows])
        for key in (
            "interval_ms",
            "engine_frame_ms",
            "engine_physics_ms",
            "callback_span_ms",
            "draw_calls",
            "static_bytes",
        )
    }
    return metrics | {
        "seconds": actual,
        "frames": len(rows),
        "simulation": simulation,
        "maintenance_cycles": rows[-1]["maintenance_cycles"] - rows[0]["maintenance_cycles"],
    }


def inspect(folder: Path, binding: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    seconds: int = binding["seconds"]
    receipt = check_launch(folder, binding)
    data = read(folder / "run.json")
    require(
        data["pid"] == receipt["pid"]
        and data["profile"] == receipt["profile"]
        and f"res://{CAPTURE}" in receipt["command"],
        "capture receipt mismatch",
    )
    require(
        "llvmpipe" in data["adapter"].lower() and data["engine"] == "4.7.1-stable (official)",
        "expected native X11 with Mesa llvmpipe and 4.7.1",
    )
    idle = perf.rows(folder / "rows.csv.gz")
    render = perf.rows(folder / "render-rows.csv.gz", RENDER_FIELDS)
    metric = validate_samples(data, idle, seconds)
    metric["texture_counter"] = texture_counter(idle)
    metric["render"] = perf.validate_render(data, render, seconds)
    rss = read(folder / "cpu-rss.json")
    admitted = [
        sample
        for sample in rss["samples"]
        if data["started_utc"] <= sample["utc_ns"] / 1e9 <= data["ended_utc"]
    ]
    require(
        len(admitted) >= 4 and all(sample["resident_pages"] > 0 for sample in admitted),
        "insufficient process RSS samples",
    )
    metric["process_rss_bytes"] = perf.distribution(
        [sample["resident_pages"] * rss["page_size"] for sample in admitted]
    )
    for name in ("before.png", "after.png"):
        verify_png(folder / name)
    if seconds == 600:
        first = idle[0]["usec"]
        minute_rows = [
            [row for row in idle if n * 60 <= (row["usec"] - first) / 1e6 < (n + 1) * 60]
            for n in range(10)
        ]
        require(all(minute_rows), "long capture missing a minute")
        metric["texture_counter_by_minute"] = [texture_counter(section) for section in minute_rows]
    return data, metric


def compare_witnesses(
    folder: Path, atlas_paths: set[str], source: dict[str, Any]
) -> dict[str, Any]:
    images = {}
    evidence = {}
    for mode in MODES:
        directory = folder / "witness" / mode
        launch = check_launch(directory, run_binding(source, "witness", mode, None))
        state = read(directory / "witness.json")
        require(
            state["profile"] == launch["profile"] and f"res://{WITNESS}" in launch["command"],
            "witness receipt mismatch",
        )
        require(set(state["atlas_readback"]) == atlas_paths, "imported atlas readback incomplete")
        evidence[mode] = state
        for label in ("overworld", "workshop"):
            verify_png(directory / f"{label}.png")
    base, candidate = (evidence[mode] for mode in MODES)
    require(
        set(base["startup_cached"]) == set(base["after_workshop_draw"]) == atlas_paths,
        "baseline eager atlas observation differs",
    )
    require(
        not candidate["startup_cached"]
        and candidate["after_workshop_draw"]
        == ["res://assets/game/artisan/fruit_press_atlas_a.png"],
        "candidate atlas loaded before demand or loaded too many on first draw",
    )
    for key in ("overworld", "workshop_camera", "workshop_save", "atlas_readback"):
        require(base[key] == candidate[key], f"visual witness changed {key}")
    require(
        candidate["overworld"]["camera"] == [120.25, 430.25]
        and candidate["overworld"]["minutes"] == 720,
        "witness camera or clock differs",
    )
    require(
        candidate["workshop_save"]["objects"][0]["phase"] == "building",
        "witness did not reload an in-progress construction",
    )
    for label in ("overworld", "workshop"):
        with (
            Image.open(folder / "witness/baseline" / f"{label}.png") as first,
            Image.open(folder / "witness/candidate" / f"{label}.png") as second,
        ):
            delta = ImageChops.difference(first.convert("RGB"), second.convert("RGB"))
            rms = ImageStat.Stat(delta).rms
            images[label] = {"max_channel_rms_0_255": max(rms), "changed_bounds": delta.getbbox()}
            # The room and overworld are frozen; allow subpixel/light and shader warmup variance.
            require(max(rms) <= 2.0, f"native frame visibly changed: {label}, RMS {rms}")
    return {"states": evidence, "images": images}


def selected_atlas_paths(report: dict[str, Any]) -> set[str]:
    return {"res://" + row["path"] for row in report["artisan_station_atlases"]}


def verify(folder: Path, head: str) -> dict[str, Any]:
    folder = folder.resolve()
    source = read(ordinary_file(folder, "source.json"))
    require(
        source["task"] == TASK
        and source["schema"] == 2
        and source["head"] == head
        and source["complete"] is True,
        "incomplete or wrong exact head",
    )
    variants = identities(head)
    require(
        source["variants"] == variants and source["tooling"] == tooling(head),
        "Git source, tree or tooling digest differs",
    )
    require(
        source["configuration"] == read(ROOT / BUDGET)["scene"]
        and source["export_inputs"] == list(EXPORT)
        and source["schedule"] == [list(run) for run in schedule()],
        "unapproved configuration or schedule",
    )
    export_paths = source["export_paths"]
    require(set(export_paths) == set(MODES), "export path coverage differs")
    project_paths = {mode: Path(path) for mode, path in export_paths.items()}
    require(
        len({path.parent for path in project_paths.values()}) == 1
        and all(
            path.is_absolute() and path.name == mode and ".." not in path.parts
            for mode, path in project_paths.items()
        ),
        "export project paths do not identify sibling modes",
    )
    require(set(source["artifacts"]) == paths(), "artifact manifest incomplete")
    for name, sha in source["artifacts"].items():
        require(digest(ordinary_file(folder, name)) == sha, f"capture authentication error: {name}")
    startup = {mode: read(folder / f"{mode}-inventory.json") for mode in MODES}
    base, candidate = (startup[mode] for mode in MODES)
    atlas = candidate["artisan_station_atlases"]
    removed = {row["path"] for row in atlas}
    base_pngs, candidate_pngs = (
        {row["path"]: row for row in report["startup_pngs"]} for report in (base, candidate)
    )
    require(
        base["history"] == candidate["history"] and base["artisan_station_atlases"] == atlas,
        "history or deferred atlas sizes/import settings changed",
    )
    require(
        base_pngs.keys() - candidate_pngs.keys() == removed
        and candidate_pngs == {name: row for name, row in base_pngs.items() if name not in removed},
        "other startup assets or imports changed",
    )
    estimated = base["startup"]["rgba8_estimate"] - candidate["startup"]["rgba8_estimate"]
    require(
        estimated == sum(row["rgba8_estimate"] for row in atlas),
        "nominal atlas bytes do not match the graph difference",
    )
    witnesses = compare_witnesses(folder, selected_atlas_paths(candidate), source)
    runs: dict[str, Any] = {}
    configurations = set()
    profiles = set()
    pids = set()
    for name, mode, seconds in schedule():
        data, metric = inspect(folder / name / mode, run_binding(source, name, mode, seconds))
        configurations.add(
            tuple(data[key] for key in ("vsync", "adapter", "engine", "screen_scale", "hidpi"))
        )
        profiles.add(data["profile"])
        pids.add(data["pid"])
        runs.setdefault(name, {})[mode] = metric
    require(
        len(configurations) == 1 and len(profiles) == len(pids) == len(schedule()),
        "native configuration varied or process/profile reused",
    )
    for pair in runs.values():
        base_metric, candidate_metric = (pair[mode] for mode in MODES)
        pair["delta_candidate_minus_baseline"] = {
            "render_p95_ms": candidate_metric["render"]["interval_ms"]["p95"]
            - base_metric["render"]["interval_ms"]["p95"],
            "texture_counter_p50_bytes": counter_delta(base_metric, candidate_metric),
        }
    observed = [
        pair["delta_candidate_minus_baseline"]["texture_counter_p50_bytes"]
        for pair in runs.values()
    ]
    return {
        "source": {key: value for key, value in source.items() if key != "artifacts"},
        "startup_nominal_rgba8_reduction_bytes": estimated,
        "startup": {mode: data["startup"] for mode, data in startup.items()},
        "observed_paired_texture_delta_median_bytes": statistics.median(observed)
        if all(value is not None for value in observed)
        else None,
        "actual_native_configuration": dict(
            zip(
                ("vsync", "adapter", "engine", "screen_scale", "hidpi"),
                next(iter(configurations)),
                strict=True,
            )
        ),
        "witness": witnesses,
        "runs": runs,
        "hardware_vram_or_fps_accepted": False,
        "gpu_time_ms": None,
    }


def counter_delta(base: dict[str, Any], candidate: dict[str, Any]) -> float | None:
    before = base["texture_counter"]["bytes"]
    after = candidate["texture_counter"]["bytes"]
    return after["p50"] - before["p50"] if before is not None and after is not None else None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("collect", "verify"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-head", required=True)
    options = parser.parse_args()
    try:
        if options.action == "collect":
            collect(options.output, options.expected_head)
        else:
            print(
                json.dumps(
                    verify(options.output, options.expected_head),
                    ensure_ascii=False,
                    allow_nan=False,
                    indent=2,
                )
            )
    except (KeyError, OSError, TypeError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f"{TASK}: {error}\n")


if __name__ == "__main__":
    main()
