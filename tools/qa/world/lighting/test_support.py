"""Настоящий sparse Git и raw-копия архива для отрицательных проверок без Godot."""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any, cast

from tools.common.git import git_environment
from tools.qa.world.lighting import contract
from tools.qa.world.lighting.collect import QA_INPUTS
from tools.qa.world.lighting.inventory import INPUTS
from tools.qa.world.lighting.storage import SETUP, Artifacts
from tools.qa.world.lighting.verify import SHARED_QA


def document(path: Path) -> dict[str, Any]:
    """Читает отдельный документ, не исправляет и не пересоздаёт доказательства."""
    return cast(dict[str, Any], json.loads(path.read_text()))


def raw_copy(archive: Path, target: Path) -> None:
    """Разворачивает только точные разрешённые имена через reader, не extractall."""
    source = document(archive / "source.json")
    artifacts = Artifacts(archive, source)
    shutil.copytree(archive, target)
    for name in sorted(
        SETUP
        | {key + "/" + name for key, run in source["runs"].items() for name in run["artifacts"]}
    ):
        path = target / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(artifacts.read(name))
    for path in target.glob("*.zip"):
        path.unlink()


@contextmanager
def frozen_checkout(archive: Path) -> Iterator[Path]:
    """Object store читается из источника; config/index/refs меняются только в своей clone."""
    source = document(archive / "source.json")
    with tempfile.TemporaryDirectory(prefix="light frozen Git ") as temporary:
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
                str(contract.ROOT),
                str(repo),
            ],
            env=environment,
            check=True,
            capture_output=True,
        )
        prefix = ["git", "-c", "core.hooksPath=/dev/null", "-C", str(repo)]
        names = {"VERSION", *INPUTS, *QA_INPUTS, *SHARED_QA}
        subprocess.run(
            [*prefix, "sparse-checkout", "set", "--no-cone", "--stdin"],
            input="\n".join("/" + name for name in sorted(names)) + "\n",
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
        for name in QA_INPUTS:
            destination = repo / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(archive / "inputs" / name, destination)
        yield repo
