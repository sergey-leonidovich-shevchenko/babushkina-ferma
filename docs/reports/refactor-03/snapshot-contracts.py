"""Сохраняет прежние SOURCE/OVERLAY-контракты отдельно от будущих путей свежих сборщиков."""

import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

BASE = "d609ab4fa6d82d6d013265183f018b8836abf7cc"
CHILD = """
import importlib, json, pathlib, re, sys
root=pathlib.Path(sys.argv[1]); sys.path.insert(0,str(root/'tools')); sys.path.insert(0,str(root))
module=importlib.import_module(sys.argv[2]); fields={}
for key,value in vars(module).items():
    if re.fullmatch(r'(?:[A-Z_]*SOURCES|OVERLAY)',key):
        assert type(value) in (list,set,tuple), (key,type(value))
        assert all(isinstance(item,str) for item in value), key
        fields[key]={'kind':type(value).__name__,'value':sorted(value) if isinstance(value,set) else list(value)}
print(json.dumps(fields))
"""


def main():
    """Каждый утверждённый модуль импортирует в своём процессе; данные и исходники остаются прежними."""
    records = {}
    for path in sorted((ROOT / "tools").glob("*.py")):
        source = path.read_bytes()
        tree = ast.parse(source)
        names = []
        for node in tree.body:
            if isinstance(node, (ast.Assign, ast.AnnAssign)):
                targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                names.extend(item.id for item in targets if isinstance(item, ast.Name)
                             and re.fullmatch(r"(?:[A-Z_]*SOURCES|OVERLAY)", item.id))
        if not names:
            continue
        name = path.relative_to(ROOT).as_posix()
        old = subprocess.check_output(["git", "show", BASE + ":" + name], cwd=ROOT, env=git_environment())
        assert source == old, name
        result = subprocess.run([sys.executable, "-c", CHILD, str(ROOT), path.stem], cwd=ROOT,
                                env=git_environment(), capture_output=True, text=True, timeout=30)
        assert result.returncode == 0 and not result.stderr, (name, result.stderr)
        fields = json.loads(result.stdout)
        assert path.read_bytes() == source
        records[path.stem] = {"source": name, "sha256": hashlib.sha256(source).hexdigest(), "fields": fields}
    output = ROOT / "docs/reports/refactor-03/baseline/source-contracts.json"
    with output.open("x") as stream:
        stream.write(json.dumps({"base": BASE, "modules": records}, indent=2) + "\n")
    print(json.dumps({"modules": len(records), "fields": sum(len(row["fields"]) for row in records.values()),
                      "source_unchanged": True, "separate_import_process_each": True}))


if __name__ == "__main__":
    main()
