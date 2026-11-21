"""Полный парный опыт P2 на копиях настоящего native-пакета, без запуска движка."""

from __future__ import annotations

import argparse
import copy
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any
from unittest.mock import patch

from tools.common.git import git_environment
from tools.qa.world.lighting.daycycle import contract as c
from tools.qa.world.lighting.daycycle import readings
from tools.qa.world.lighting.daycycle.evidence import Evidence
from tools.qa.world.lighting.daycycle.verify import REPORT, verify

OLD_HEAD = "d5cd791284e2a516b46ee7ca1eba085277f98f90"


@contextmanager
def changed(
    folder: Path,
    edits: dict[str, bytes],
    source_change: Callable[[dict[str, Any]], None] | None = None,
) -> Iterator[Path]:
    """Меняет действительные ZIP members только в копии и переподписывает все затронутые SHA."""
    with tempfile.TemporaryDirectory(prefix="daycycle native negative ") as temporary:
        root = Path(temporary).resolve() / "native"
        shutil.copytree(folder, root)
        source = json.loads((root / "source.json").read_bytes())
        for label in ("baseline", "candidate"):
            selected = {
                name[len(label) + 1 :]: raw
                for name, raw in edits.items()
                if name.startswith(label + "/")
            }
            if not selected:
                continue
            archive = root / (label + ".zip")
            replacement = archive.with_suffix(".new.zip")
            with zipfile.ZipFile(archive) as before, zipfile.ZipFile(replacement, "x") as after:
                assert set(selected) <= set(before.namelist())
                for name in before.namelist():
                    raw = selected[name] if name in selected else before.read(name)
                    after.writestr(name, raw, compress_type=zipfile.ZIP_STORED)
            replacement.replace(archive)
        for name, raw in edits.items():
            if name.startswith("inputs/"):
                key = name.removeprefix("inputs/")
                assert key in source["inputs"]
                (root / name).write_bytes(raw)
                source["inputs"][key] = c.digest(raw)
            else:
                assert name in source["artifacts"]
                source["artifacts"][name] = c.digest(raw)
        if source_change:
            source_change(source)
        encoded = (json.dumps(source, ensure_ascii=False, indent=2) + "\n").encode()
        (root / "source.json").write_bytes(encoded)
        package_file = root / "package.json"
        if package_file.exists():
            package = json.loads(package_file.read_bytes())
            package["source_sha256"] = c.digest(encoded)
            package["archives"] = {
                name: c.digest((root / name).read_bytes()) for name in package["archives"]
            }
            package_file.write_text(json.dumps(package, indent=2) + "\n")
        yield root


def old_probe(folder: Path, current: bool) -> None:
    """Подставляет неизменённый capture из Git d5 в полный reader с исправленной общей P1 closure."""
    raw = c.shared.git("show", OLD_HEAD + ":" + c.PREFIX + "readings.py")
    namespace: dict[str, Any] = {"__name__": "historical_daycycle_readings"}
    exec(compile(raw, OLD_HEAD + ":readings.py", "exec"), namespace)
    with patch.object(readings, "capture", namespace["capture"]):
        print(json.dumps(verify(folder, current=current), ensure_ascii=False, indent=2))


def mutations() -> dict[str, Callable[[dict[str, Any]], None]]:
    """Использует настоящие состояния других кадров, не рисует и не генерирует native-свидетельства."""

    def noon_reference(data: dict[str, Any]) -> None:
        state = data["frames"]["street-day-reference"]["before"]
        for row in data["costs"]:
            row["before"] = copy.deepcopy(state)
            row["after"] = copy.deepcopy(state)

    def legacy_off(data: dict[str, Any]) -> None:
        for row in data["costs"]:
            if row["mode"] == "legacy":
                for side in ("before", "after"):
                    row[side]["legacy"] = False

    def other_scene(data: dict[str, Any]) -> None:
        state = data["frames"]["home-dusk-palette"]["before"]
        row = next(row for row in data["costs"] if row["mode"] == "palette")
        row["before"] = copy.deepcopy(state)
        row["after"] = copy.deepcopy(state)

    return {
        "all-reference-noon": noon_reference,
        "timed-legacy-off": legacy_off,
        "timed-other-scene": other_scene,
    }


def run_probe(folder: Path, old: bool, logs: Path, name: str, current: bool) -> dict[str, Any]:
    """Сохраняет фактический OS exit и stdout/stderr полного CLI; двигатель не вызывается."""
    module = (
        "qa.world.lighting.daycycle.review_regressions"
        if old
        else "qa.world.lighting.daycycle.verify"
    )
    arguments = [sys.executable, str(c.ROOT / "tools/run.py"), module]
    arguments += ["--probe-old", str(folder)] if old else ["--output", str(folder)]
    if current:
        arguments.append("--check-current-candidate")
    result = subprocess.run(
        arguments, cwd=c.ROOT, env=git_environment(), capture_output=True, timeout=180, check=False
    )
    for suffix, raw in (("stdout", result.stdout), ("stderr", result.stderr)):
        (logs / (name + "." + suffix + ".txt")).write_bytes(raw)
    return {
        "exit_code": result.returncode,
        "stdout_sha256": c.digest(result.stdout),
        "stderr_sha256": c.digest(result.stderr),
        "last_error": result.stderr.decode(errors="replace").strip().splitlines()[-1:] or [],
    }


def pair(folder: Path, output: Path, current: bool = True) -> dict[str, Any]:
    """Один и тот же реальный пакет проходит старый timing и отвергается новым по P2, не по SHA."""
    output = c.shared.fresh_output(output)
    store = Evidence(folder)
    source_raw = store.read("source.json")
    source = json.loads(source_raw)
    result: dict[str, Any] = {
        "task": "VLIGHT-003",
        "native_head": source["head"],
        "native_source_sha256": c.digest(source_raw),
        "historical_timing_head": OLD_HEAD,
        "historical_readings_sha256": c.digest(
            c.shared.git("show", OLD_HEAD + ":" + c.PREFIX + "readings.py")
        ),
        "current_readings_sha256": c.digest((c.ROOT / (c.PREFIX + "readings.py")).read_bytes()),
        "experiment_source_sha256": c.digest(Path(__file__).read_bytes()),
        "strict_current": current,
        "method": "Exact historical d5 capture function inside the common full verifier with corrected P1 input closure; not a claim that the entire old head accepts the new 34-input manifest.",
        "native_png_generated": False,
        "cases": {},
    }
    for label, historical in (("old-timing", True), ("current", False)):
        row = run_probe(folder, historical, output, "pristine-" + label, current)
        assert row["exit_code"] == 0, row
        result["cases"]["pristine-" + label] = row
    path = "candidate/1152/capture.json"
    for name, mutation in mutations().items():
        data = store.document(path)
        mutation(data)
        encoded = json.dumps(data, ensure_ascii=False, indent=2).encode()
        with changed(folder, {path: encoded}) as damaged:
            source_copy = Evidence(damaged).document("source.json")
            assert source_copy["artifacts"][path] == c.digest(encoded)
            old = run_probe(damaged, True, output, name + "-old-timing", current)
            new = run_probe(damaged, False, output, name + "-current", current)
            assert old["exit_code"] == 0, old
            assert new["exit_code"] == 1 and any(
                "timed scene/mode differs" in line for line in new["last_error"]
            ), new
            result["cases"][name] = {
                "capture_sha256": c.digest(encoded),
                "resigned": True,
                "old_timing": old,
                "current": new,
            }
    result["cases"]["unchanged-current"] = run_probe(
        folder, False, output, "unchanged-current", current
    )
    assert result["cases"]["unchanged-current"]["exit_code"] == 0
    assert store.read("source.json") == source_raw
    (output / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    return result


def main() -> None:
    """Производит воспроизводимый отчёт во внешней новой папке либо явный исторический probe."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", type=Path, default=REPORT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--probe-old", type=Path)
    parser.add_argument("--check-current-candidate", action="store_true")
    parser.add_argument("--historical", action="store_true")
    args = parser.parse_args()
    if args.probe_old:
        old_probe(args.probe_old, args.check_current_candidate)
    else:
        if args.output is None:
            parser.error("--output is required")
        print(
            json.dumps(
                pair(args.native, args.output, current=not args.historical),
                ensure_ascii=False,
                indent=2,
            )
        )


if __name__ == "__main__":
    main()
