"""Изолированные файловые fixture исторического кандидата для регрессий VFOLIAGE-010."""
from __future__ import annotations

from tools.common.git import git_environment
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

from tools.qa.foliage.foliage_visibility_evidence import REPORT, ROOT, require
from tools.qa.foliage.foliage_visibility_provenance import BASE


def build_candidate(destination: Path) -> None:
    """Восстанавливает только нужные Git assets и сохранённую капсулу в новом временном корне."""
    destination.mkdir()
    with tempfile.TemporaryFile() as error_log:
        process = subprocess.Popen(
            ["git", "archive", BASE, "assets/game"],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=error_log,
        env=git_environment())
        try:
            with tarfile.open(fileobj=process.stdout, mode="r|") as archive:
                for member in archive:
                    if member.isdir():
                        continue
                    target = destination / member.name
                    require(
                        member.isfile()
                        and member.name.startswith("assets/game/")
                        and target.resolve().is_relative_to(destination.resolve()),
                        "unsafe candidate fixture path",
                    )
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with target.open("wb") as output:
                        shutil.copyfileobj(archive.extractfile(member), output)
            require(process.wait(timeout=10) == 0, "candidate fixture Git export failed")
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
            process.stdout.close()

    with tarfile.open(REPORT / "sources.tar.gz") as capsule:
        for member in capsule:
            target = destination / member.name
            require(
                member.isfile() and target.resolve().is_relative_to(destination.resolve()),
                "unsafe candidate capsule path",
            )
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(capsule.extractfile(member).read())
