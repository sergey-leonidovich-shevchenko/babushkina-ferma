"""Сверяет подготовку путей с базой и исполняет безопасные границы настоящих генераторов."""

import ast
import hashlib
import importlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

BASE = "d609ab4fa6d82d6d013265183f018b8836abf7cc"
REPORT = ROOT / "docs/reports/refactor-03/authoring-prepare"


class AddressOnly(ast.NodeTransformer):
    """Нормализует только три явно разрешённые формы корня и новый импорт общего helper."""

    def visit_ImportFrom(self, node):
        if node.module == "tools.common.paths":
            assert [(name.name, name.asname) for name in node.names] == [("project_root", None)]
            return None
        return self.generic_visit(node)

    def visit_Call(self, node):
        if ast.unparse(node) == "project_root(__file__)":
            return ast.Name(id="APPROVED_SOURCE_ROOT", ctx=ast.Load())
        return self.generic_visit(node)

    def visit_Attribute(self, node):
        if ast.unparse(node) == "Path(__file__).resolve().parent.parent":
            return ast.Name(id="APPROVED_SOURCE_ROOT", ctx=ast.Load())
        return self.generic_visit(node)

    def visit_Subscript(self, node):
        if ast.unparse(node) == "Path(__file__).resolve().parents[1]":
            return ast.Name(id="APPROVED_SOURCE_ROOT", ctx=ast.Load())
        return self.generic_visit(node)


def main():
    """Сравнивает все алгоритмы и реальные пиксели/отказы, не выполняя записывающий main."""
    before_status = subprocess.check_output(["git", "status", "--porcelain", "-z"], cwd=ROOT, env=git_environment())
    records = json.loads((REPORT / "sources.json").read_text())["files"]
    for row in records:
        old = subprocess.check_output(["git", "show", BASE + ":" + row["path"]], cwd=ROOT, env=git_environment())
        current = (ROOT / row["path"]).read_bytes()
        assert hashlib.sha256(old).hexdigest() == row["before"]
        assert hashlib.sha256(current).hexdigest() == row["prepared"]
        normalized = [ast.dump(AddressOnly().visit(ast.parse(code)), include_attributes=False) for code in (old, current)]
        assert normalized[0] == normalized[1], row["path"]
        compile(current, row["path"], "exec")
    module = importlib.import_module("tools.build_bridge_sprites")
    assert module.ROOT == ROOT
    old = subprocess.check_output(["git", "show", BASE + ":tools/build_bridge_sprites.py"], cwd=ROOT, env=git_environment())
    namespace = {"__name__": "approved_baseline", "__file__": str(ROOT / "tools/build_bridge_sprites.py")}
    exec(compile(old, namespace["__file__"], "exec"), namespace)
    source = Image.new("RGBA", (18, 16), (0, 0, 0, 0))
    ImageDraw.Draw(source).rectangle((4, 3, 12, 10), fill=(173, 112, 51, 224))
    pixel_cases = 0
    for size in [(12, 12), (24, 24), (32, 48)]:
        images = [entry(source, (0, 0, 18, 16), size) for entry in (namespace["extract"], module.extract)]
        assert images[0].size == images[1].size and images[0].tobytes() == images[1].tobytes()
        pixel_cases += 1
    failures = []
    for image, size in [(source, (2, 2)), (Image.new("RGBA", (18, 16)), (24, 24))]:
        messages = []
        for entry in (namespace["extract"], module.extract):
            try:
                entry(image, (0, 0, 18, 16), size)
            except RuntimeError as error:
                messages.append(str(error))
        assert len(messages) == 2 and messages[0] == messages[1]
        failures.append(messages[0])
    commands = []
    with tempfile.TemporaryDirectory(prefix="authoring cwd with spaces ") as temporary:
        folder = Path(temporary)
        (folder / "tools").mkdir()
        (folder / "tools/__init__.py").write_text("raise RuntimeError('foreign tools must not load')\n")
        for name in ("build_forest_tree_atlas", "build_level_editor_tiles"):
            environment = dict(os.environ, PYTHONPATH=str(folder), GIT_DIR=str(folder / "foreign.git"))
            command = [sys.executable, str(ROOT / "tools/run.py"), name, "--help"]
            result = subprocess.run(command, cwd=folder, env=environment, capture_output=True, text=True, timeout=30)
            assert result.returncode == 0 and "--project" in result.stdout and not result.stderr, result
            commands.append({"command": command, "exit": result.returncode, "stdout": result.stdout})
    assert not folder.exists()
    after_status = subprocess.check_output(["git", "status", "--porcelain", "-z"], cwd=ROOT, env=git_environment())
    assert before_status == after_status, "profile changed repository paths"
    output = {"base": BASE, "version": (ROOT / "VERSION").read_text().strip(),
              "AST_and_byte_guard_files": len(records), "pixel_cases": pixel_cases,
              "real_negative_cases": failures, "arbitrary_cwd_hostile_PYTHONPATH_GIT": commands,
              "temporary_removed": True, "repository_paths_unchanged": True}
    with (REPORT / "profile.json").open("x") as stream:
        stream.write(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"AST_files": len(records), "pixel_cases": pixel_cases,
                      "negative_cases": len(failures), "CLI": len(commands), "passed": True}))


if __name__ == "__main__":
    main()
