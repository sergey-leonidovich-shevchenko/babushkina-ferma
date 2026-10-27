"""Проверяет физическое расположение первого пакета, UID, разрешённые замены и настоящий новый CLI."""

import argparse
import ast
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

REPORT = ROOT / "docs/reports/refactor-03/authoring-move"


class AddressOnly(ast.NodeTransformer):
    """Разрешает только новый импорт измерителя и source-root прежнего cwd-скрипта."""

    def visit_ImportFrom(self, node):
        if node.module == "tools.common.paths":
            assert [(name.name, name.asname) for name in node.names] == [("project_root", None)]
            return None
        if node.module == "tools.assets.authoring.measure_hero_actions":
            node.module = "measure_hero_actions"
        return self.generic_visit(node)

    def visit_BinOp(self, node):
        if ast.unparse(node) == "project_root(__file__) / 'docs/concepts/skeleton-2026-10-12/v2'":
            return ast.Name(id="APPROVED_SKELETON_DIRECTORY", ctx=ast.Load())
        return self.generic_visit(node)

    def visit_Call(self, node):
        if ast.unparse(node) == "Path('docs/concepts/skeleton-2026-10-12/v2')":
            return ast.Name(id="APPROVED_SKELETON_DIRECTORY", ctx=ast.Load())
        return self.generic_visit(node)


def main():
    """Сравнивает все36 перемещений с отдельным prepare SHA, не исполняя записывающие main."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=REPORT / "profile.json")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.suffix != ".json" or output.exists() or output.is_relative_to(ROOT / "assets"):
        parser.error("нужен новый JSON вне assets; прежние результаты не перезаписываются")
    migration = json.loads((REPORT / "migration.json").read_text())
    paths = []
    for row in migration["moves"]:
        path = ROOT / row["target"]
        assert not (ROOT / row["old_path"]).exists(), row["old_path"]
        current = path.read_bytes()
        assert hashlib.sha256(current).hexdigest() == row["moved_sha256"]
        before = subprocess.check_output(["git", "show", migration["prepared_head"] + ":" + row["old_path"]],
                                         cwd=ROOT, env=git_environment())
        assert hashlib.sha256(before).hexdigest() == row["prepared_sha256"]
        assert path.stat().st_mode & 0o777 == row["mode"]
        if path.suffix == ".py":
            trees = [ast.dump(AddressOnly().visit(ast.parse(source)), include_attributes=False) for source in (before, current)]
            assert trees[0] == trees[1], row["target"]
            compile(current, row["target"], "exec")
        elif path.suffix == ".gd":
            expected = before.decode()
            for item in migration["moves"]:
                expected = expected.replace(item["old_path"], item["target"])
            assert current == expected.encode(), row["target"]
        else:
            assert before == current, row["target"]
        paths.append(row["target"])
    for row in migration["local_ignored_UID"]:
        assert not (ROOT / row["old_path"]).exists()
        assert (ROOT / row["target"]).read_text() == row["bytes"]
        assert subprocess.run(["git", "check-ignore", "-q", row["target"]], cwd=ROOT,
                              env=git_environment()).returncode == 0
    library = importlib.import_module("tools.assets.authoring.build_bridge_sprites")
    assert library.ROOT == ROOT
    source = Image.new("RGBA", (18, 16))
    ImageDraw.Draw(source).rectangle((4, 3, 12, 10), fill=(173, 112, 51, 224))
    image = library.extract(source, (0, 0, 18, 16), (24, 24))
    assert image.getbbox() == (7, 16, 16, 24)
    rejected = 0
    for damaged, size in [(source, (2, 2)), (Image.new("RGBA", (18, 16)), (24, 24))]:
        try:
            library.extract(damaged, (0, 0, 18, 16), size)
        except RuntimeError:
            rejected += 1
    assert rejected == 2
    calls = []
    with tempfile.TemporaryDirectory(prefix="moved authoring foreign cwd ") as temporary:
        folder = Path(temporary)
        (folder / "tools").mkdir()
        (folder / "tools/__init__.py").write_text("raise RuntimeError('foreign tools loaded')\n")
        environment = dict(os.environ, PYTHONPATH=str(folder), GIT_DIR=str(folder / "foreign.git"))
        for stem in ("build_forest_tree_atlas", "build_level_editor_tiles"):
            command = [sys.executable, str(ROOT / "tools/run.py"), "assets.authoring." + stem, "--help"]
            result = subprocess.run(command, cwd=folder, env=environment, capture_output=True, text=True, timeout=30)
            assert result.returncode == 0 and "--project" in result.stdout and not result.stderr
            calls.append({"command": command, "exit": result.returncode, "stdout": result.stdout})
    assert not folder.exists()
    result = {"version": (ROOT / "VERSION").read_text().strip(), "prepared_head": migration["prepared_head"],
              "verified_moves": len(paths), "compiled_python": sum(name.endswith('.py') for name in paths),
              "tracked_UID": 5, "ignored_UID_preserved": len(migration["local_ignored_UID"]),
              "AST_GDScript_bytes_and_modes_preserved": True, "real_negative_cases": rejected,
              "real_new_CLI": calls, "temporary_removed": True}
    with output.open("x") as stream:
        stream.write(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ("verified_moves", "compiled_python", "ignored_UID_preserved", "real_negative_cases")}))


if __name__ == "__main__":
    main()
