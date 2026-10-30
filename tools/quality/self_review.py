"""Упражняет настоящие публичные генераторы на внешних файлах и реальной истории Git."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

from tools.assets.migration import migration_fixture as fixture
from tools.common.git import git_environment
from tools.common.paths import project_root
from tools.quality.fixture_validation import validate
from tools.quality.preservation import source_state
from tools.quality.selection import BASE, git_paths

ROOT = project_root(__file__)
API = (
    "import sys; from pathlib import Path; sys.path.insert(0, sys.argv[1]); "
    "from tools.assets.migration.migration_fixture import create; "
    "create(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3] or None)"
)


def snapshot(root: Path) -> dict[str, str]:
    """Сверяет реальные байты после отказа генератора и сохраняет чужие index/config."""
    return {
        path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in root.rglob("*")
        if path.is_file()
    }


def execute(destination: Path) -> dict[str, Any]:
    """Вызывает настоящий генератор и коллектор внешнего проекта, не собирая результат за них."""
    if destination.exists() or destination.resolve().is_relative_to(ROOT):
        raise ValueError("self-review requires a new report directory outside the project")
    destination.mkdir(parents=True)
    records: list[dict[str, Any]] = []
    before_environment = dict(os.environ)
    before_source = source_state(ROOT)
    (destination / "source-state.json").write_text(json.dumps(before_source, indent=2) + "\n")

    def command(
        label: str,
        arguments: list[str],
        cwd: Path,
        environment: dict[str, str],
        success: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        """Сохраняет фактический вывод команды и сверяет ожидаемый успех или отказ."""
        start = time.monotonic()
        result = subprocess.run(
            arguments,
            cwd=cwd,
            env=environment,
            capture_output=True,
            text=True,
            timeout=180,
        )
        failed = (
            result.returncode != 0 or "SCRIPT ERROR:" in result.stderr or "ERROR:" in result.stderr
        )
        records.append(
            {
                "label": label,
                "argv": arguments,
                "cwd": str(cwd),
                "code": result.returncode,
                "seconds": round(time.monotonic() - start, 3),
                "stdout": result.stdout,
                "stderr": result.stderr,
            }
        )
        (destination / "commands.json").write_text(json.dumps(records, indent=2) + "\n")
        if failed == success:
            raise RuntimeError("unexpected producer result: " + label)
        return result

    with tempfile.TemporaryDirectory(prefix="farm self review real IO ") as temporary:
        parent = Path(temporary)
        clean = git_environment()
        foreign = parent / "foreign repository"
        command("foreign-init", ["git", "init", "-q", str(foreign)], parent, clean)
        (foreign / "sentinel").write_text("keep foreign staging\n")
        command("foreign-stage", ["git", "add", "sentinel"], foreign, clean)
        foreign_before = snapshot(foreign)
        poison = parent / "hostile Python"
        (poison / "tools").mkdir(parents=True)
        (poison / "tools/__init__.py").write_text('raise RuntimeError("foreign tools imported")\n')
        hostile = dict(
            os.environ,
            PYTHONPATH=str(poison),
            GIT_DIR=str(foreign / ".git"),
            GIT_WORK_TREE=str(foreign),
            GIT_INDEX_FILE=str(foreign / ".git/index"),
            GIT_CONFIG_COUNT="1",
            GIT_CONFIG_KEY_0="core.bare",
            GIT_CONFIG_VALUE_0="true",
        )
        clone, linked = parent / "owned clone", parent / "actual linked worktree"
        source_head = subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"], env=clean, text=True
        ).strip()
        command(
            "owned-clone",
            ["git", "clone", "--shared", "--no-checkout", "-q", str(ROOT), str(clone)],
            parent,
            clean,
        )
        command(
            "linked-worktree",
            [
                "git",
                "-C",
                str(clone),
                "worktree",
                "add",
                "--detach",
                "--no-checkout",
                str(linked),
                source_head,
            ],
            parent,
            clean,
        )
        # Берём настоящие файлы проекта; результат вместо генератора не собираем.
        names = fixture.closure(ROOT)
        catalog = json.loads((ROOT / "assets/game/visual_resources.json").read_text())
        for side in fixture.SIDES:
            path = catalog["textures"]["oak_table_" + side]["file"].removeprefix("res://")
            names.extend([path, path + ".import"])
        names.extend(
            name + ".import" for name in names.copy() if (ROOT / (name + ".import")).is_file()
        )
        command(
            "checkout-real-inputs",
            [
                "git",
                "-C",
                str(linked),
                "checkout",
                source_head,
                "--",
                "tools",
                "VERSION",
                "project.godot",
            ],
            parent,
            clean,
        )
        # Проверяем текущую рабочую реализацию, включая новые незакоммиченные файлы.
        # BASE задаёт только исторический вход; реализация берётся из проверяемых исходников.
        current_tools = {name for name in git_paths(ROOT) if name.startswith("tools/")}
        for path in (linked / "tools").rglob("*"):
            if path.is_file() and path.relative_to(linked).as_posix() not in current_tools:
                path.unlink()
        for name in current_tools | set(names) | {"project.godot", "VERSION"}:
            source = ROOT / name
            if source.is_file():
                target_file = linked / name
                target_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target_file)
        output = parent / "alpha output"
        cli = [
            sys.executable,
            str(linked / "tools/run.py"),
            "assets.alpha.alpha_fixtures",
            str(output),
        ]
        command("public-alpha-create", cli, foreign, hostile)
        rows = json.loads((output / "fixtures.json").read_text())
        if len(rows) != 8 or not all((output / row["file"]).is_file() for row in rows):
            raise ValueError("public alpha producer did not produce its complete real catalog")
        alpha_before = snapshot(output)
        command("alpha-no-overwrite", cli, foreign, hostile, success=False)
        if snapshot(output) != alpha_before:
            raise ValueError("failed alpha command changed existing output")
        target = parent / "new external project"
        api = [sys.executable, "-c", API, str(linked), str(target), ""]
        command("public-fixture-api-create", api, foreign, hostile)
        command(
            "public-fixture-api-historical-create",
            [sys.executable, "-c", API, str(linked), str(parent / "historical project"), BASE],
            foreign,
            hostile,
        )
        case = validate(target, linked)
        before = snapshot(target)
        command("fixture-no-overwrite", api, foreign, hostile, success=False)
        if snapshot(target) != before:
            raise ValueError("refused fixture overwrote its output")
        command(
            "fixture-reject-source-root",
            [sys.executable, "-c", API, str(linked), str(linked / "new internal project"), BASE],
            foreign,
            hostile,
            success=False,
        )
        engine = os.environ.get("FARM_GODOT_BIN")
        if not engine:
            raise ValueError("FARM_GODOT_BIN is required for actual external fixture parsing")
        command(
            "fixture-fresh-import",
            [engine, "--headless", "--editor", "--path", str(target), "--quit"],
            foreign,
            hostile,
        )
        command(
            "fixture-check-live-uri",
            [
                engine,
                "--headless",
                "--path",
                str(target),
                "--check-only",
                "--script",
                "res://tools/migration_capture.gd",
            ],
            foreign,
            hostile,
        )
        environment = dict(
            hostile,
            VMIGRATION_OUTPUT=str(parent / "headless output"),
            VMIGRATION_PROFILE="Codex-VPIPELINE-009-REFACTOR07",
        )
        command(
            "fixture-actual-headless-capture",
            [
                engine,
                "--headless",
                "--path",
                str(target),
                "--script",
                "res://tools/migration_capture.gd",
            ],
            foreign,
            environment,
        )
        capture_json = json.loads((parent / "headless output/capture.json").read_text())
        if capture_json["errors"] or capture_json["performance_eligible"] or capture_json["frames"]:
            raise ValueError("headless fixture failed or was misrepresented as native/FPS evidence")
        if source_state(ROOT) != before_source:
            raise ValueError("self-review changed source files, owning Git index or config")
        if snapshot(foreign) != foreign_before or dict(os.environ) != before_environment:
            raise ValueError("self-review changed foreign Git files or the process environment")
        (destination / "capture.json").write_text(json.dumps(capture_json, indent=2) + "\n")
        result = {
            "task": "REFACTOR-07",
            "base": BASE,
            "source_head": source_head,
            "commands": len(records),
            "alpha_fixtures": len(rows),
            "fixture_files": len(case["copied_files"]),
            "foreign_git_unchanged": True,
            "environment_unchanged": True,
            "source_checkout_and_git_unchanged": True,
            "real_linked_worktree": True,
            "temp_parent": str(parent),
            "native_or_fps_acceptance": False,
        }
    result["temp_removed"] = not parent.exists()
    (destination / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def main() -> None:
    """Сохраняет успехи и отказы вне игры, запрещая перезапись существующего отчёта."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(execute(args.output), indent=2))


if __name__ == "__main__":
    main()
