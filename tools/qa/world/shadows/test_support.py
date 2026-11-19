"""Создаёт настоящий sparse Git checkout замороженного кадра, не меняя рабочую игру."""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from tools.common.git import git_environment
from tools.qa.world.shadows.contract import QA_INPUTS, ROOT, RUNTIME


@contextmanager
def frozen_checkout(archive: Path) -> Iterator[Path]:
    """Реальные Git diff и blobs относятся к своей копии; objects исходника только читаются."""
    source = json.loads((archive / "source.json").read_text())
    with tempfile.TemporaryDirectory(prefix="shadow frozen Git ") as temporary:
        repo = Path(temporary) / "own project"
        environment = git_environment()
        subprocess.run(
            [
                "git",
                "-c",
                "core.hooksPath=/dev/null",
                "clone",
                "--quiet",
                "--shared",
                "--no-checkout",
                str(ROOT),
                str(repo),
            ],
            env=environment,
            check=True,
            capture_output=True,
        )
        prefix = ["git", "-c", "core.hooksPath=/dev/null", "-C", str(repo)]
        patterns = ["/project.godot", *("/" + name for name in RUNTIME), "/tools/qa/world/shadows/"]
        subprocess.run(
            [*prefix, "sparse-checkout", "set", "--no-cone", "--stdin"],
            input="\n".join(patterns) + "\n",
            text=True,
            env=environment,
            check=True,
            capture_output=True,
        )
        subprocess.run(
            [*prefix, "checkout", "--quiet", "--detach", source["commit"]],
            env=environment,
            check=True,
            capture_output=True,
        )
        for name in source.get("runtime_overlays", {}):
            shutil.copyfile(archive / "candidate" / name, repo / name)
        for name in QA_INPUTS:
            destination = repo / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(archive / "inputs" / name, destination)
        yield repo
