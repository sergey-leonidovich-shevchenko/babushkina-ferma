"""Воспроизводит Git hook-контекст только на полностью временном родительском repo."""

from __future__ import annotations

import configparser
import hashlib
import importlib.util
import json
import os
import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

from tools.common.git import git_environment
from tools.qa.world.shadows import contract

ROOT = contract.ROOT
SOURCE = "tools/qa/world/shadows/test_contract.py"
OLD_COMMIT = "4cf7b421a1c879f9240e37a9aa478a1d97e5cf69"
METHOD = "test_working_candidate_guard_uses_real_git_and_rejects_unrelated_production"


def digest(raw: bytes) -> str:
    """Снимок хранит хеши, а не пользовательские Git-настройки или окружение."""
    return hashlib.sha256(raw).hexdigest()


def linked_gitdir(linked: Path) -> Path:
    """Разрешает Git-pointer только внутри собственного временного родителя."""
    marker = (linked / ".git").read_text().strip()
    if not marker.startswith("gitdir: "):
        raise ValueError("expected real linked worktree")
    return (linked / marker.removeprefix("gitdir: ")).resolve()


def snapshot(parent: Path, linked: Path) -> dict[str, Any]:
    """Сравнивает config, оба index, HEAD и refs перед/после тела настоящего hook."""
    common, local = parent / ".git", linked_gitdir(linked)
    paths = {
        "config": common / "config",
        "parent_index": common / "index",
        "parent_head": common / "HEAD",
        "linked_index": local / "index",
        "linked_head": local / "HEAD",
        "linked_config": local / "config.worktree",
    }
    config = configparser.ConfigParser(strict=False)
    config.read(common / "config")
    return {
        "files": {key: digest(p.read_bytes()) if p.exists() else None for key, p in paths.items()},
        "refs": {
            p.relative_to(common).as_posix(): digest(p.read_bytes())
            for p in sorted((common / "refs").rglob("*"))
            if p.is_file()
        },
        "bare": config.getboolean("core", "bare"),
    }


def validate_fixture(folder: Path) -> tuple[Path, Path, Path]:
    """Отрицательный опыт не принимает произвольный checkout или внешний Git-pointer."""
    folder = folder.resolve()
    temporary = Path(tempfile.gettempdir()).resolve()
    if folder.parent != temporary or not folder.name.startswith("shadow-hook-"):
        raise ValueError("owned temporary hook fixture required")
    if folder == ROOT or ROOT in folder.parents or folder in ROOT.parents:
        raise ValueError("working project cannot be a negative fixture")
    parent, linked, candidate = (
        folder / "parent",
        folder / "linked project",
        folder / "candidate.py",
    )
    if any(p.is_symlink() for p in (parent, linked, candidate, parent / ".git", linked / ".git")):
        raise ValueError("fixture paths must not be symlinks")
    common = parent / ".git"
    local = linked_gitdir(linked)
    if not local.is_relative_to(common / "worktrees"):
        raise ValueError("linked worktree escaped temporary parent")
    if (local / (local / "commondir").read_text().strip()).resolve() != common:
        raise ValueError("temporary common Git directory mismatch")
    marker = json.loads((folder / "owned.json").read_text())
    if marker != {"task": "VSHADOW-010", "candidate_sha256": digest(candidate.read_bytes())}:
        raise ValueError("hook candidate changed")
    allowed = {
        digest((ROOT / SOURCE).read_bytes()),
        digest(contract.git("show", OLD_COMMIT + ":" + SOURCE)),
    }
    if marker["candidate_sha256"] not in allowed:
        raise ValueError("unknown negative/positive candidate")
    return parent, linked, candidate


def hook_run(folder: Path) -> int:
    """Git сам передаёт GIT_DIR; выполняется прежний или исправленный настоящий test case."""
    parent, linked, candidate = validate_fixture(folder)
    if Path.cwd().resolve() != linked or "GIT_DIR" not in os.environ:
        raise ValueError("actual Git pre-commit context required")
    expected = {
        "GIT_DIR": linked_gitdir(linked),
        "GIT_INDEX_FILE": linked_gitdir(linked) / "index",
        "GIT_WORK_TREE": linked,
        "GIT_COMMON_DIR": parent / ".git",
    }
    for key, target in expected.items():
        if key in os.environ and (linked / os.environ[key]).resolve() != target:
            raise ValueError("hook Git path escaped temporary fixture: " + key)
    if any(
        key.startswith("GIT_CONFIG_")
        or key in {"GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE"}
        for key in os.environ
    ):
        raise ValueError("unexpected Git override in negative fixture")
    environment = digest(json.dumps(dict(os.environ), sort_keys=True).encode())
    before = snapshot(parent, linked)
    original = contract.ROOT
    contract.ROOT = linked
    try:
        spec = importlib.util.spec_from_file_location("shadow_hook_candidate", candidate)
        if spec is None or spec.loader is None:
            raise ValueError("candidate import failed")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        # Динамический импорт нужен для одинакового исполнения frozen и текущего тела.
        case = module.ContactContractTests(METHOD)
        if not isinstance(case, unittest.TestCase):
            raise ValueError("expected actual contact contract test")
        result = unittest.TextTestRunner().run(unittest.TestSuite([case]))
    finally:
        contract.ROOT = original
    receipt = {
        "candidate_sha256": digest(candidate.read_bytes()),
        "tests": result.testsRun,
        "passed": result.wasSuccessful(),
        "inherited": {
            key: os.environ.get(key)
            for key in ("GIT_DIR", "GIT_INDEX_FILE", "GIT_WORK_TREE", "GIT_PREFIX")
        },
        "before": before,
        "after": snapshot(parent, linked),
        "environment_preserved": environment
        == digest(json.dumps(dict(os.environ), sort_keys=True).encode()),
    }
    (folder / "hook-result.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return 0 if result.wasSuccessful() else 1


def run_case(candidate: bytes) -> dict[str, Any]:
    """Реальный git commit вызывает hook в linked worktree собственного временного repo."""
    environment = git_environment()
    with tempfile.TemporaryDirectory(prefix="shadow-hook-") as temporary:
        folder = Path(temporary).resolve()
        parent, linked = folder / "parent", folder / "linked project"

        def command(*args: str) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                ["git", "-c", "core.hooksPath=/dev/null", *args],
                env=environment,
                check=True,
                capture_output=True,
                text=True,
            )

        command("init", "-q", "-b", "main", str(parent))
        for key, value in (
            ("user.name", "QA"),
            ("user.email", "qa@example.test"),
            ("extensions.worktreeConfig", "true"),
        ):
            command("-C", str(parent), "config", key, value)
        for name in contract.RUNTIME:
            target = parent / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(contract.git("show", "HEAD:" + name))
        command("-C", str(parent), "add", ".")
        command("-C", str(parent), "-c", "core.hooksPath=/dev/null", "commit", "-qm", "seed")
        command("-C", str(parent), "worktree", "add", "-qb", "hook-candidate", str(linked))
        (linked / "marker.txt").write_text("actual pending commit\n")
        command("-C", str(linked), "add", "marker.txt")
        (folder / "candidate.py").write_bytes(candidate)
        (folder / "owned.json").write_text(
            json.dumps({"task": "VSHADOW-010", "candidate_sha256": digest(candidate)})
        )
        hooks = folder / "hooks"
        hooks.mkdir()
        hook = hooks / "pre-commit"
        argv = [
            sys.executable,
            str(ROOT / "tools/run.py"),
            "qa.world.shadows.test_hook_context",
            "--hook",
            str(folder),
        ]
        hook.write_text("#!/bin/sh\nexec " + " ".join(map(shlex.quote, argv)) + "\n")
        hook.chmod(0o700)
        command("-C", str(parent), "config", "core.hooksPath", str(hooks))
        before = snapshot(parent, linked)
        commit = subprocess.run(
            ["git", "-C", str(linked), "commit", "-qm", "actual hook candidate"],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )
        return {
            "exit_code": commit.returncode,
            "stdout": commit.stdout,
            "stderr": commit.stderr,
            "parent_before_commit": before,
            "parent_after_commit": snapshot(parent, linked),
            "hook": json.loads((folder / "hook-result.json").read_text()),
        }


class HookContextTests(unittest.TestCase):
    """Старый FAIL и новый PASS получены тем же hook-сценарием, без изменений рабочей игры."""

    def test_previous_source_reinitializes_only_the_temporary_parent(self) -> None:
        """Старый git init получает настоящий GIT_DIR и воспроизводит повреждение bare."""
        proof = run_case(contract.git("show", OLD_COMMIT + ":" + SOURCE))
        self.assertNotEqual(proof["exit_code"], 0)
        self.assertFalse(proof["hook"]["passed"])
        self.assertFalse(proof["hook"]["before"]["bare"])
        self.assertTrue(proof["hook"]["after"]["bare"])
        self.assertIn("must be run in a work tree", proof["stderr"])
        self.assertTrue(proof["hook"]["environment_preserved"])

    def test_current_source_preserves_parent_in_real_linked_worktree_hook(self) -> None:
        """Текущий test case проходит; config/index/refs и hook-окружение не меняются."""
        proof = run_case((ROOT / SOURCE).read_bytes())
        self.assertEqual(proof["exit_code"], 0, proof["stderr"])
        hook = proof["hook"]
        self.assertTrue(hook["passed"])
        self.assertTrue(hook["inherited"]["GIT_DIR"])
        self.assertEqual(hook["tests"], 1)
        self.assertEqual(hook["before"], hook["after"])
        self.assertTrue(hook["environment_preserved"])
        # Сам внешний commit меняет только свою ветку/index, не родительскую main.
        for key in ("config", "parent_index", "parent_head"):
            self.assertEqual(
                proof["parent_before_commit"]["files"][key],
                proof["parent_after_commit"]["files"][key],
            )
        self.assertEqual(
            proof["parent_before_commit"]["refs"]["refs/heads/main"],
            proof["parent_after_commit"]["refs"]["refs/heads/main"],
        )


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--hook":
        raise SystemExit(hook_run(Path(sys.argv[2])))
    unittest.main()
