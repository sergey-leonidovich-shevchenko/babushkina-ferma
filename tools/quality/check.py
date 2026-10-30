"""Проверяет качество без исправлений; явный fix меняет только выбранные исходники."""

from __future__ import annotations

import argparse
import importlib.metadata
import sys
import tempfile
import time
from pathlib import Path

from tools.common.paths import project_root
from tools.quality.index import matching_sources
from tools.quality.process import run, versions
from tools.quality.selection import baseline, selected


def tools(root: Path, files: list[str], fix: bool = False) -> int:
    """Применяет одинаковые локальные и CI-правила ко всему выбранному файлу."""
    executable = Path(sys.executable).parent
    python = [name for name in files if name.endswith(".py")]
    gdscript = [name for name in files if name.endswith(".gd")]
    failures = 0
    if python:
        lint = [str(executable / "ruff"), "check", "--config", str(root / "pyproject.toml")]
        failures += run([*lint, *(["--fix"] if fix else []), *python], root)
        formatting = [str(executable / "ruff"), "format", "--config", str(root / "pyproject.toml")]
        failures += run([*formatting, *([] if fix else ["--check"]), *python], root)
        if not fix:
            with tempfile.TemporaryDirectory(prefix="farm quality mypy ") as cache:
                failures += run(
                    [
                        str(executable / "mypy"),
                        "--config-file",
                        str(root / "pyproject.toml"),
                        "--cache-dir",
                        cache,
                        *python,
                    ],
                    root,
                )
    if gdscript:
        formatting = [str(executable / "gdformat"), "--line-length", "100"]
        failures += run([*formatting, *([] if fix else ["--check"]), *gdscript], root)
        failures += run([str(executable / "gdlint"), *gdscript], root)
        if not fix:
            from tools.quality.godot import analyze

            failures += analyze(root, gdscript, baseline(root))
    return failures


def main() -> None:
    """Запускает проверку из любой рабочей папки, сохраняя окружение процесса."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "fix"), nargs="?", default="check")
    parser.add_argument(
        "--staged", action="store_true", help="отказать при разных байтах исходников в index и cwd"
    )
    args = parser.parse_args()
    if args.staged and args.command == "fix":
        parser.error("--staged is read-only and cannot be combined with fix")
    start = time.monotonic()
    root = project_root(__file__)
    try:
        versions(root)
        indexed = matching_sources(root) if args.staged else []
        files = selected(root, baseline(root), indexed)
        print(f"QUALITY: {len(files)} whole changed/new files", flush=True)
        for name in files:
            print("  " + name)
        failures = tools(root, files, fix=args.command == "fix")
    except (ValueError, OSError, importlib.metadata.PackageNotFoundError) as error:
        parser.exit(2, str(error) + "\nInstall tools/quality/requirements.txt into Python 3.11.\n")
    print(f"QUALITY: {failures} failed steps; {time.monotonic() - start:.3f}s", flush=True)
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
