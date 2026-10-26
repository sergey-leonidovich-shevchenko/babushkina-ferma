"""Безопасные отрицательные опыты на копиях: глубина пути и Git hook environment."""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from git_snapshot import Snapshot, clean_git_environment, project_root, sha256_file


def git(root: Path, *arguments: str) -> bytes:
    """Мутирующие команды этого опыта адресованы только отдельному временному repo."""
    return subprocess.check_output(["git", "-C", str(root), *arguments], env=clean_git_environment(), stderr=subprocess.PIPE)


def declared_function(source: bytes, name: str, namespace: dict):
    """Компилирует только выбранную исходную функцию; setUp и импорт всего проекта не исполняются."""
    tree = ast.parse(source)
    functions = [node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name == name]
    if len(functions) != 1:
        raise ValueError("baseline function not unique: " + name)
    module = ast.fix_missing_locations(ast.Module(body=[functions[0]], type_ignores=[]))
    exec(compile(module, "accepted-baseline:" + name, "exec"), namespace)
    return namespace[name]


def root_depth(snapshot: Snapshot) -> dict:
    """Сравнивает неизменные байты настоящего checker в старой и вложенной временной позиции."""
    source = snapshot.contents("tools/check_documentation.py")
    # Нужен только tuple обязательных документов, не выполнение импортированного main.
    required = next(ast.literal_eval(node.value) for node in ast.parse(source).body
                    if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "REQUIRED_DOCUMENTS" for t in node.targets))
    with tempfile.TemporaryDirectory(prefix="farm refactor01 depth ") as value:
        root = Path(value)
        for name in required:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("# Fixture\n")
        old = root / "tools/check_documentation.py"
        nested = root / "tools/quality/check_documentation.py"
        old.parent.mkdir()
        nested.parent.mkdir()
        old.write_bytes(source)
        nested.write_bytes(source)
        results = []
        for path in [old, nested]:
            result = subprocess.run([sys.executable, str(path)], cwd=root, env=clean_git_environment(),
                                    capture_output=True, text=True, timeout=30)
            results.append({"location": str(path.relative_to(root)), "exit": result.returncode,
                            "stdout": result.stdout, "stderr": result.stderr})
        if [row["exit"] for row in results] != [0, 1]:
            raise ValueError("root-depth negative control changed: " + str(results))
    return {"baseline": snapshot.commit, "source": "tools/check_documentation.py",
            "source_sha256": hashlib.sha256(source).hexdigest(), "source_bytes_identical": True,
            "real_project_moved": False, "results": results,
            "conclusion": "naive nested copy breaks parent.parent root; shared root discovery is a precondition, not implemented here"}


def hook_environment(snapshot: Snapshot) -> dict:
    """Запускает точный проблемный test method только с искусственными private parent repos."""
    test_source = snapshot.contents("tools/test_shore_kit.py")
    kit_source = snapshot.contents("tools/shore_kit.py")
    tracked = declared_function(kit_source, "tracked", {"Path": Path, "subprocess": subprocess})
    method = declared_function(test_source, "test_required_log_must_be_indexed", {
        "Path": Path, "tempfile": tempfile, "subprocess": subprocess, "kit": SimpleNamespace(tracked=tracked),
    })
    control_paths = {name: Path(snapshot.git("rev-parse", "--path-format=absolute", "--git-path", name).decode().strip())
                     for name in ["config", "index"]}
    outer = {name: sha256_file(path) for name, path in control_paths.items() if path.is_file()}
    results = []
    with tempfile.TemporaryDirectory(prefix="farm refactor01 git probe ") as value:
        for isolated in [False, True]:
            parent = Path(value) / ("isolated" if isolated else "inherited")
            parent.mkdir()
            git(parent, "init", "--quiet")
            (parent / "sentinel.txt").write_text("private parent sentinel\n")
            git(parent, "add", "sentinel.txt")
            # Ловушка только в disposable parent: unsafe init сбрасывает core.bare.
            git(parent, "config", "core.bare", "true")
            paths = {name: parent / ".git" / name for name in ["config", "index"]}
            before = {name: sha256_file(path) for name, path in paths.items()}
            environment = {**clean_git_environment(), "GIT_DIR": str(parent / ".git"),
                           "GIT_WORK_TREE": str(parent), "GIT_INDEX_FILE": str(paths["index"])}
            error = None
            try:
                with patch.dict(os.environ, environment, clear=True):
                    if isolated:
                        with patch.dict(os.environ, clean_git_environment(), clear=True):
                            method(unittest.TestCase())
                    else:
                        method(unittest.TestCase())
            except (subprocess.CalledProcessError, AssertionError) as failure:
                error = type(failure).__name__
            after = {name: sha256_file(path) for name, path in paths.items()}
            results.append({"boundary_clears_GIT_variables": isolated, "before": before, "after": after,
                            "parent_config_changed": before["config"] != after["config"],
                            "parent_index_changed": before["index"] != after["index"], "method_error": error})
    outer_after = {name: sha256_file(control_paths[name]) for name in outer}
    if not results[0]["parent_config_changed"] or results[1]["before"] != results[1]["after"] or results[1]["method_error"]:
        raise ValueError("Git environment reproduction did not establish the expected boundary: " + str(results))
    return {"baseline": snapshot.commit, "git_version": subprocess.check_output(["git", "--version"]).decode().strip(),
            "test_source_sha256": hashlib.sha256(test_source).hexdigest(),
            "kit_source_sha256": hashlib.sha256(kit_source).hexdigest(), "results": results,
            "actual_repo_before": outer, "actual_repo_after": outer_after,
            "actual_repo_unchanged_observed": outer == outer_after,
            "boundary_is_probe_only": True, "baseline_test_shore_kit_changed": False,
            "conclusion": "REFACTOR-02 must isolate Git environment before hook use; no production fix is performed by this audit"}


def main() -> None:
    """Новые подтверждения создаются в отдельном каталоге; существующий output отклоняется."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path)
    parser.add_argument("--base", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.root or project_root(Path(__file__).resolve().parent)
    if args.output.exists() or not args.output.parent.is_dir():
        raise ValueError("fresh probe output required")
    snapshot = Snapshot(root, args.base)
    depth = root_depth(snapshot)
    environment = hook_environment(snapshot)
    args.output.mkdir()
    for name, result in [("root-depth.json", depth), ("git-hook-environment.json", environment)]:
        (args.output / name).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("PROBES: baseline checker depth failure and private Git hook contamination reproduced; isolated boundary passes")


if __name__ == "__main__":
    main()
