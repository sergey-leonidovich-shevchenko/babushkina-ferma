"""Запускает ограниченные по времени процессы с явным выводом и закреплёнными версиями."""

from __future__ import annotations

import importlib.metadata
import subprocess
import sys
import time
from pathlib import Path


def versions(root: Path) -> None:
    """Останавливает проверку, если версии локальных и CI-инструментов различаются."""
    if sys.version_info[:2] != (3, 11):
        raise ValueError("quality tools require Python 3.11; game launchers are unchanged")
    requirements = root / "tools/quality/requirements.txt"
    for line in requirements.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        package, expected = line.split("==")
        actual = importlib.metadata.version(package)
        if actual != expected:
            raise ValueError(f"{package}: expected {expected}, installed {actual}")


def run(arguments: list[str], root: Path, timeout: int = 120) -> int:
    """Считает ошибку компиляции в журнале отказом независимо от нулевого кода Godot."""
    start = time.monotonic()
    result = subprocess.run(
        arguments, cwd=root, capture_output=True, text=True, timeout=timeout, check=False
    )
    print(result.stdout, end="", flush=True)
    print(result.stderr, end="", file=sys.stderr, flush=True)
    failed = result.returncode != 0 or any(
        marker in result.stdout + result.stderr for marker in ("SCRIPT ERROR:", "ERROR:")
    )
    print(f"QUALITY STEP {Path(arguments[0]).name}: {time.monotonic() - start:.3f}s", flush=True)
    return 1 if failed else 0
