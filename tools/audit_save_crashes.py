#!/usr/bin/env python3
"""Прерывает собственные дочерние Godot на границах записи в отдельном tmp."""
import argparse
import json
from pathlib import Path
import signal
import subprocess
import tempfile
import time

from common.paths import project_root
from common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
POINTS = [
    f"{phase}.{point}"
    for phase in ("primary", "backup")
    for point in ("before_stage", "after_open", "after_write", "after_flush", "after_validate")
] + ["backup.before_replace", "backup.after_replace", "primary.before_replace", "primary.after_replace"]


def read(path):
    """Читает только небольшой здоровый документ этого стенда."""
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    if data.get("revision") not in (1, 2) or data.get("payload") != "healthy":
        raise ValueError(f"Invalid committed document: {path.name}")
    return data


def run(godot):
    """Убивает только созданный дочерний процесс после подтверждения нужной границы."""
    results = []
    for point in POINTS:
        with tempfile.TemporaryDirectory(prefix="farm-safe-crash-", dir="/private/tmp") as folder:
            slot = Path(folder) / "slot.json"
            slot.write_text(json.dumps(dict(revision=1, payload="healthy")))
            command = [str(godot), "--headless", "--path", str(ROOT), "--script",
                       "res://tools/save_crash_worker.gd", "--", str(slot), point]
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            marker = Path(str(slot) + ".checkpoint")
            try:
                deadline = time.monotonic() + 20
                while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.01)
                if not marker.exists() or marker.read_text() != point:
                    raise RuntimeError(f"Checkpoint not reached: {point}")
                process.kill()
                output, _ = process.communicate(timeout=10)
                if process.returncode != -signal.SIGKILL or "SCRIPT ERROR" in output or "ERROR:" in output:
                    raise RuntimeError(f"Unexpected child result at {point}: {output[-1000:]}")
                primary = read(slot)
                backup = read(Path(str(slot) + ".bak"))
                expected = 2 if point == "primary.after_replace" else 1
                if primary is None or primary["revision"] != expected:
                    raise RuntimeError(f"Lost last healthy progress at {point}")
                results.append(dict(checkpoint=point, exit_code=process.returncode,
                                    primary_revision=primary["revision"],
                                    backup_revision=None if backup is None else backup["revision"]))
            finally:
                if process.poll() is None:
                    process.kill()
                process.communicate(timeout=10)
    return results


def main():
    """Запускает аудит и сохраняет компактное проверяемое подтверждение реальных завершений процесса."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, default=ROOT / "tools/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = dict(schema=1, scope="SIGKILL of isolated child; no power-loss or physical ENOSPC claim",
                  godot=subprocess.check_output([str(args.godot), "--version"], text=True).strip(),
                  cases=run(args.godot))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"SAVE CRASH AUDIT: {len(result['cases'])} checkpoints passed")


if __name__ == "__main__":
    main()
