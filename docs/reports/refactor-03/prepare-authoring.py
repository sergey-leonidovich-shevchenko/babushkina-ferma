"""Отделяет source-root подготовки графики от последующего механического git mv."""

import ast
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
REPORT = ROOT / "docs/reports/refactor-03/authoring-prepare"


def main():
    """Меняет только фиксированную глубину пути в назначенном семействе подготовки графики."""
    plan = json.loads((ROOT / "docs/reports/refactor-01/integration-1/migration-plan.json").read_text())
    REPORT.mkdir()
    rows = []
    for name, record in plan["assignments"].items():
        if record["family"] != "assets-authoring" or not name.endswith(".py"):
            continue
        path = ROOT / name
        before = subprocess.check_output(["git", "show", BASE + ":" + name], cwd=ROOT, env=git_environment())
        assert path.read_bytes() == before, name
        source = before.decode()
        fixed = source.replace("Path(__file__).resolve().parents[1]", "project_root(__file__)")
        fixed = fixed.replace("Path(__file__).resolve().parent.parent", "project_root(__file__)")
        if fixed == source:
            continue
        tree = ast.parse(fixed)
        imports = [node for node in tree.body if isinstance(node, (ast.Import, ast.ImportFrom))]
        offset = max(node.end_lineno for node in imports)
        lines = fixed.splitlines(keepends=True)
        lines.insert(offset, "\nfrom tools.common.paths import project_root\n")
        fixed = "".join(lines)
        ast.parse(fixed)
        path.write_text(fixed)
        rows.append({"path": name, "target": record["target"],
                     "before": hashlib.sha256(before).hexdigest(),
                     "prepared": hashlib.sha256(fixed.encode()).hexdigest(),
                     "change": "accepted project_root replaces fixed parent depth; algorithms unchanged"})
    (REPORT / "sources.json").write_text(json.dumps({"base": BASE, "files": rows}, indent=2) + "\n")
    print(json.dumps({"prepared": len(rows), "moves": 0, "runtime_changes": 0}))


if __name__ == "__main__":
    main()
