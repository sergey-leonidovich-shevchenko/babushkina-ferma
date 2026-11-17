"""Проверяет синхронизацию настоящего capture helper на удалённом X11, без запуска игры."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.common.history import read_git_blob
from tools.common.paths import project_root

ROOT = project_root(__file__)
CAPTURE = "tools/qa/ground/color_patch_capture.gd"
PROBE = "tools/qa/ground/color_patch_sync_probe.gd"
BASELINE = "e79a3a870eb683e09e4ce3c5dfd02e6ea67e9777"
BASELINE_SHA = "0da370807958fc5e5a826641bf8e0c976579631939d308aa3ae3998555fff325"


def digest(raw: bytes) -> str:
    """Связывает доказательство с конкретными входными байтами."""
    return hashlib.sha256(raw).hexdigest()


def redraw_method(source: bytes) -> str:
    """Извлекает неизменённый метод исторического helper без копии текущей реализации."""
    matches: list[str] = re.findall(
        r"^func _redraw\(count: int\) -> void:\n(?:\t[^\n]*\n|\n)+",
        source.decode("utf-8"),
        flags=re.MULTILINE,
    )
    if len(matches) != 1:
        raise ValueError("expected one complete historical _redraw method")
    return matches[0].rstrip() + "\n"


def fresh_output(path: Path, root: Path = ROOT) -> Path:
    """Отклоняет перезапись, ссылки и вывод внутри проекта до создания файлов."""
    candidate = Path(os.path.abspath(path))
    if any(parent.is_symlink() for parent in (candidate, *candidate.parents)):
        raise ValueError("output must not traverse symlinks")
    if candidate.exists() or candidate == root or root in candidate.parents:
        raise ValueError("output must be fresh and outside the project")
    if not candidate.parent.is_dir():
        raise ValueError("output parent must already exist")
    candidate.mkdir()
    return candidate


def validate_probe(
    evidence: dict[str, Any], exit_code: int, historical: bool, width: int, pixel: str
) -> None:
    """Различает намеренный старый дефект, здоровый новый кадр и отказ инфраструктуры."""
    expected = "00ff00ff" if historical else "ff0000ff"
    expected_code = 1 if historical else 0
    trace = evidence.get("trace")
    if (
        exit_code != expected_code
        or evidence.get("exit_code") != exit_code
        or evidence.get("schema") != 1
        or evidence.get("task") != "QA-06"
        or evidence.get("display") != "X11"
        or not str(evidence.get("engine", "")).startswith("4.7.1.stable")
        or evidence.get("window") != [width, 648 if width == 1152 else 720]
        or evidence.get("initial") != "00ff00ff"
        or evidence.get("requested") != "ff0000ff"
        or evidence.get("readback") != expected
        or pixel != expected
        or evidence.get("performance_eligible") is not False
        or not isinstance(trace, list)
        or not all(isinstance(event, str) for event in trace)
        or trace.count("request:1") != 1
        or trace[-1:] != ["read:" + expected]
    ):
        raise ValueError("native probe did not prove the expected pixel and process outcome")
    if historical:
        if "draw:1" in trace:
            raise ValueError("historical failure was not a read before fresh canvas commands")
    elif not (
        trace.count("draw:1") == 1
        and trace.count("complete") == 1
        and trace.index("request:1") < trace.index("draw:1") < trace.index("complete")
    ):
        raise ValueError("candidate readback preceded fresh draw/completion")


def write_json(path: Path, value: Any) -> None:
    """Сохраняет собственный паспорт пробы, не изменяя принятый визуальный архив."""
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_case(binary: Path, output: Path, entry: str, width: int, historical: bool) -> None:
    """Снимает отдельным процессом кадр и сверяет PNG независимо от отчёта движка."""
    from PIL import Image

    name = ("historical" if historical else "candidate") + "-" + str(width)
    target = output / name
    profile = "Codex-QA-06-" + uuid.uuid4().hex
    arguments = [
        str(binary),
        "--path",
        str(ROOT),
        "--windowed",
        "--rendering-method",
        "gl_compatibility",
        "--display-driver",
        "x11",
        "--script",
        entry,
        "--",
        "--output=" + str(target),
        "--profile=" + profile,
    ]
    if width == 1280:
        arguments.append("--wide")
    log = output / (name + ".log")
    with log.open("wb") as stream:
        result = subprocess.run(arguments, cwd=ROOT, stdout=stream, stderr=stream, timeout=45)
    if re.search(r"(?m)^(?:SCRIPT )?ERROR:", log.read_text(encoding="utf-8")):
        raise ValueError(name + ": engine error is not an expected regression")
    evidence = json.loads((target / "probe.json").read_text(encoding="utf-8"))
    if evidence.get("profile") != profile:
        raise ValueError(name + ": profile identity mismatch")
    with Image.open(target / "readback.png") as image:
        if image.size != (32, 32):
            raise ValueError(name + ": invalid readback dimensions")
        pixel = bytes(image.convert("RGBA").getpixel((16, 16))).hex()
    validate_probe(evidence, result.returncode, historical, width, pixel)
    print(name + ": " + ("stale cache reproduced" if historical else "fresh frame verified"))


def collect(output: Path) -> None:
    """Сопоставляет закреплённый старый helper и текущий унаследованный метод на двух размерах."""
    if sys.platform != "linux" or os.environ.get("CI") != "true" or not os.environ.get("DISPLAY"):
        raise ValueError("native probe is restricted to remote Linux CI with X11")
    binary = Path(os.environ.get("FARM_GODOT_BIN", "")).resolve()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ValueError("pinned FARM_GODOT_BIN is required")
    historical = read_git_blob(ROOT, CAPTURE, BASELINE, BASELINE_SHA)
    current = (ROOT / CAPTURE).read_bytes()
    probe = (ROOT / PROBE).read_bytes()
    head = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, env=git_environment(), text=True
    ).strip()
    if head != os.environ.get("VGROUND_EXPECTED_HEAD"):
        raise ValueError("probe requires the exact expected CI head")
    output = fresh_output(output)
    (output / "historical-capture.gd.txt").write_bytes(historical)
    (output / "candidate-capture.gd.txt").write_bytes(current)
    (output / "probe.gd.txt").write_bytes(probe)
    entry = output / "historical-entry.gd"
    entry.write_text(
        'extends "res://' + PROBE + '"\n\n' + redraw_method(historical), encoding="utf-8"
    )
    manifest: dict[str, Any] = {
        "task": "QA-06",
        "schema": 1,
        "head": head,
        "baseline": {"commit": BASELINE, "source": CAPTURE, "sha256": BASELINE_SHA},
        "candidate_sha256": digest(current),
        "probe_sha256": digest(probe),
        "performance_eligible": False,
        "passed": False,
        "failures": [],
    }
    write_json(output / "manifest.json", manifest)
    for width in (1152, 1280):
        for old in (True, False):
            try:
                run_case(binary, output, str(entry) if old else "res://" + PROBE, width, old)
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                manifest["failures"].append(f"{width} historical={old}: {error}")
    if (ROOT / CAPTURE).read_bytes() != current or (ROOT / PROBE).read_bytes() != probe:
        manifest["failures"].append("source changed while collecting")
    manifest["passed"] = not manifest["failures"]
    manifest["files"] = {
        path.relative_to(output).as_posix(): digest(path.read_bytes())
        for path in sorted(output.rglob("*"))
        if path.is_file() and path.name != "manifest.json"
    }
    write_json(output / "manifest.json", manifest)
    if manifest["failures"]:
        raise ValueError("; ".join(manifest["failures"]))


def main() -> None:
    """Сохраняет все четыре исхода, включая диагностический отказ старого helper."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        collect(args.output)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
