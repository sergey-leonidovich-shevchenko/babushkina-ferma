"""Фиксирует назначенные пути на принятой базе, не переименовывая исходники и доказательства."""

import ast
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

BASE = "d609ab4fa6d82d6d013265183f018b8836abf7cc"
REPORT = ROOT / "docs/reports/refactor-03"


def git(*arguments):
    """Читает только принятую базу текущего проекта, исключая чужой Git-контекст."""
    return subprocess.check_output(["git", *arguments], cwd=ROOT, env=git_environment())


def main():
    """Сохраняет полную исходную карту и контроль байтов для адресного будущего переноса."""
    plan = json.loads(git("show", BASE + ":docs/reports/refactor-01/integration-1/migration-plan.json"))
    blobs = {}
    for row in git("ls-tree", "-rzl", BASE).split(b"\0"):
        if row:
            metadata, name = row.split(b"\t", 1)
            mode, kind, blob, size = metadata.split()
            blobs[name.decode()] = {"mode": mode.decode(), "blob": blob.decode(), "bytes": int(size)}
    records = []
    roots = []
    imports = []
    python_modules = {Path(name).stem for name in plan["assignments"] if name.endswith(".py")}
    for name, assignment in plan["assignments"].items():
        if name not in blobs or plan["families"][assignment["family"]]["stage"] != "REFACTOR-03":
            continue
        raw = git("show", BASE + ":" + name)
        records.append({"old_path": name, **assignment, **blobs[name],
                        "sha256": hashlib.sha256(raw).hexdigest()})
        if not name.endswith(".py"):
            continue
        source = raw.decode()
        tree = ast.parse(source)
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module and node.module.split(".")[0] in python_modules:
                imports.append({"owner": name, "module": node.module, "line": node.lineno})
            if isinstance(node, (ast.Assign, ast.AnnAssign)):
                text = ast.get_source_segment(source, node)
                if text and "__file__" in text:
                    roots.append({"owner": name, "line": node.lineno, "expression": text})
    summary = {"task": "REFACTOR-03", "base": BASE, "version": "0.0.356",
               "files": len(records), "families": dict(Counter(row["family"] for row in records)),
               "fixed_root_bindings": roots, "local_import_edges": imports, "assignments": records,
               "accepted_tools_source": "docs/reports/refactor-01/integration-1/migration-plan.json",
               "historical_plan_modified": False}
    destination = REPORT / "baseline"
    destination.mkdir()
    (destination / "migration.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    content = (json.dumps({"base": BASE, "files": blobs}, sort_keys=True, separators=(",", ":")) + "\n").encode()
    (destination / "blobs.json.gz").write_bytes(gzip.compress(content, mtime=0))
    print(json.dumps({"base": BASE, "assigned_files": len(records), "all_baseline_files": len(blobs),
                      "python_import_edges": len(imports), "root_bindings": len(roots)}))


if __name__ == "__main__":
    main()
