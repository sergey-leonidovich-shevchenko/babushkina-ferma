"""Actual Linux pre-render CLI guard, not a synthetic native-positive test."""

from __future__ import annotations

import argparse
import json
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

from tools.common.git import git_environment
from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality.evidence import Evidence
from tools.qa.world.lighting.quality.verify import verify


def snapshot(folder: Path) -> dict[str, tuple[int, int, int, str]]:
    """All existing copied evidence bytes, modes, sizes and modification times are protected."""
    return {
        str(path.relative_to(folder)): (
            stat.S_IMODE(path.stat().st_mode),
            path.stat().st_size,
            path.stat().st_mtime_ns,
            c.digest(path.read_bytes()),
        )
        for path in sorted(folder.rglob("*"))
        if path.is_file()
    }


def run(archive: Path, head: str) -> dict[str, object]:
    """The positive actual renderer is separately required before exercising the early guard."""
    assert sys.platform == "linux", "early CLI guard runs on real Linux; local macOS is skipped"
    positive = verify(archive, head)
    assert positive["native_png"] == 270 and positive["runs"] == 4
    raw_archive = archive.read_bytes()
    store = Evidence(archive)
    with tempfile.TemporaryDirectory(prefix="farm actual early output ") as temporary:
        parent = Path(temporary).resolve()
        repo = parent / "producer source"
        repo.mkdir()
        for name in c.INPUTS:
            path = repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(store.read("inputs/" + name))
        for name in ("project.godot", "VERSION"):
            (repo / name).write_bytes(c.shared.git("show", head + ":" + name))
        env = git_environment()
        git = ["/usr/bin/git", "--no-replace-objects", "-C", str(repo)]
        subprocess.run(["/usr/bin/git", "init", "-q", str(repo)], env=env, check=True)
        subprocess.run([*git, "add", "."], env=env, check=True)
        empty_hooks = parent / "empty fixture hooks"
        empty_hooks.mkdir()
        subprocess.run(
            [
                *git,
                "-c",
                "commit.gpgsign=false",
                "-c",
                "user.name=Lighting guard fixture",
                "-c",
                "user.email=fixture@example.invalid",
                "-c",
                "core.hooksPath=" + str(empty_hooks),
                "commit",
                "-q",
                "-m",
                "Captured real CLI inputs for early refusal",
            ],
            env=env,
            check=True,
        )
        test_head = subprocess.check_output([*git, "rev-parse", "HEAD"], env=env, text=True).strip()
        assert not subprocess.check_output([*git, "status", "--porcelain"], env=env)
        output = parent / "existing actual evidence"
        output.mkdir()
        for name in ("source.json", *sorted(c.artifacts()), *("inputs/" + n for n in c.INPUTS)):
            path = output / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(store.read(name))
        marker = parent / "unexpected-engine-invocation"
        engine = parent / "safe engine sentinel"
        engine.write_text(
            '#!/bin/sh\nprintf "unexpected" > "$FARM_VLIGHT_TEST_SENTINEL"\nexit 97\n'
        )
        engine.chmod(0o700)
        foreign = parent / "foreign cwd"
        foreign.mkdir()
        before = snapshot(output)
        source_before = snapshot(repo)
        child_env = {
            **env,
            "DISPLAY": ":early-guard-no-server",
            "FARM_GODOT_BIN": str(engine),
            "FARM_VLIGHT_TEST_SENTINEL": str(marker),
            "VLIGHT_QUALITY_EXPECTED_HEAD": test_head,
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        result = subprocess.run(
            [
                sys.executable,
                str(repo / "tools/run.py"),
                "qa.world.lighting.quality.collect",
                "--output",
                str(output),
            ],
            cwd=foreign,
            env=child_env,
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )
        assert result.returncode == 2, (result.returncode, result.stdout, result.stderr)
        assert result.stderr.strip() == "fresh external output with existing parent required", (
            result.stderr
        )
        assert not result.stdout and not marker.exists()
        assert snapshot(output) == before
        # Git may refresh its own disposable index stat cache; committed inputs/config must remain exact.
        assert not subprocess.check_output([*git, "status", "--porcelain"], env=env)
        for name in c.INPUTS:
            assert (repo / name).read_bytes() == store.read("inputs/" + name)
        source_after = snapshot(repo)
        assert all(source_after.get(k) == v for k, v in source_before.items() if k != ".git/index")
        assert archive.read_bytes() == raw_archive
        return {
            "task": "VLIGHT-010",
            "captured_head": head,
            "fixture_head": test_head,
            "actual_linux_cli": True,
            "early_guard_only": True,
            "real_x_connection_claimed": False,
            "real_engine_invoked": False,
            "exit_code": result.returncode,
            "error": result.stderr.strip(),
            "existing_files_unchanged": len(before),
            "original_archive_unchanged": True,
            "synthetic_native_positive": False,
        }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--head", required=True)
    arguments = parser.parse_args()
    print(json.dumps(run(arguments.archive, arguments.head), ensure_ascii=False, indent=2))
