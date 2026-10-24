"""Same-window read-only CPU observation, without stack sampling or script-method timers."""

import json
import os
from pathlib import Path
import subprocess
import threading
import time
import sys

ROOT = next(
    p for p in Path(__file__).resolve().parents if (p / "project.godot").is_file()
)
sys.path.insert(
    0,
    str(
        ROOT
        / "docs/reports/visual-overhaul/vfoliage-006/causal-investigation/instrumentation"
    ),
)
from causal_process import Counters, cpu_window


def execute(command, project, folder, seconds):
    counters = Counters()
    process = subprocess.Popen(
        command, cwd=project, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    roles = {"runner": os.getpid(), "game": process.pid}
    samples, markers, receipt = [], {}, []
    stopped = threading.Event()

    def observe():
        while not stopped.is_set():
            samples.append(counters.snapshot(roles))
            stopped.wait(0.02)

    worker = threading.Thread(target=observe)
    worker.start()
    timeout = threading.Event()

    def watchdog():
        if process.poll() is None:
            timeout.set()
            process.kill()  # Owned child only.

    timer = threading.Timer(seconds, watchdog)
    timer.start()
    try:
        with (folder / "stdout.txt").open("wb") as output:
            for line in process.stdout:
                now = time.monotonic_ns()
                output.write(line)
                if line.startswith(b"PERF_CAPTURE "):
                    try:
                        row = json.loads(line[len(b"PERF_CAPTURE ") :])
                        kind = row["kind"]
                    except (ValueError, KeyError, TypeError) as exc:
                        receipt.append({"host_ns": now, "protocol_error": str(exc)})
                        continue
                    receipt.append(
                        {
                            "host_ns": now,
                            "kind": row["kind"],
                            "game_us": row.get("time_us"),
                        }
                    )
                    if row["kind"] in ["begin", "end"]:
                        markers[row["kind"]] = counters.snapshot(roles)
        status = process.wait()
    finally:
        timer.cancel()
        stopped.set()
        worker.join()
        process.stdout.close()
    value = {
        "pid": process.pid,
        "returncode": status,
        "watchdog": timeout.is_set(),
        "samples": samples,
        "markers": markers,
        "receipt": receipt,
        "profiler": {
            "enabled": False,
            "reason": "primary cohort has no native sampling or method timers",
        },
    }
    if set(markers) == {"begin", "end"}:
        value["cpu_window"] = cpu_window(markers["begin"], markers["end"])
    (folder / "observer.json").write_text(json.dumps(value, indent=2) + "\n")
    if timeout.is_set():
        raise subprocess.TimeoutExpired(
            command, seconds, output=(folder / "stdout.txt").read_bytes()
        )
    return subprocess.CompletedProcess(
        command, status, (folder / "stdout.txt").read_bytes()
    )
