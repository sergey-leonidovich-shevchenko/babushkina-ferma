"""Проверяет настоящий CLI будущего пакета в disposable Git/worktree, не генерируя игровые ресурсы проекта."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

BASE = "d609ab4fa6d82d6d013265183f018b8836abf7cc"
SOURCE = "tools/build_forest_tree_atlas.py"
TARGET = "tools/assets/authoring/build_forest_tree_atlas.py"


def git(directory, *arguments):
    """Все Git-изменения адресуются только явно переданному временному репозиторию."""
    return subprocess.check_output(["git", *arguments], cwd=directory, env=git_environment(), stderr=subprocess.PIPE)


def snapshot(folder):
    """Фиксирует два фактических PNG независимо от имени checkout и временных timestamp."""
    files = sorted((folder / "assets/game/environment").rglob("*.png"))
    return {str(path.relative_to(folder)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}


def masters(folder):
    """Создаёт маленькие собственные входы с четырьмя изолированными стадиями и листом4×4."""
    source = folder / "assets/generated/sprite_sources"
    source.mkdir(parents=True, exist_ok=True)
    forest = Image.new("RGB", (128, 40), "white")
    draw = ImageDraw.Draw(forest)
    for index in range(4):
        draw.rectangle((index * 32 + 5, 4, index * 32 + 22, 34), fill=(62 + index * 10, 106, 45))
    forest.save(source / "forest_tree_growth_source_v1.png")
    Image.new("RGBA", (96, 96), (79, 136, 66, 217)).save(source / "orchard_fruit_trees_source_v2.png")


def main():
    """Сравнивает старый CLI, реальный отказ наивного переноса и подготовленный CLI в новой глубине."""
    report = ROOT / "docs/reports/refactor-03/authoring-prepare/preview.json"
    assert not report.exists()
    old = git(ROOT, "show", BASE + ":" + SOURCE)
    prepared = (ROOT / SOURCE).read_bytes()
    source_before = hashlib.sha256(prepared).hexdigest()
    records = []
    with tempfile.TemporaryDirectory(prefix="authoring real worktree ") as temporary:
        temporary = Path(temporary)
        repository, worktree, foreign_cwd = [temporary / name for name in ("fixture repository", "linked worktree with spaces", "other cwd")]
        repository.mkdir()
        foreign_cwd.mkdir()
        (repository / "tools").mkdir()
        for name in ("project.godot", "VERSION", "tools/__init__.py", "tools/run.py"):
            shutil.copy2(ROOT / name, repository / name)
        shutil.copytree(ROOT / "tools/common", repository / "tools/common", ignore=shutil.ignore_patterns("__pycache__"))
        (repository / SOURCE).write_bytes(old)
        git(repository, "init", "--template=", "-q")
        git(repository, "add", ".")
        git(repository, "-c", "user.name=Codex QA", "-c", "user.email=qa@example.invalid", "-c", "commit.gpgsign=false",
            "-c", "core.hooksPath=/dev/null", "commit", "-qm", "disposable source-root fixture")
        git(repository, "worktree", "add", "--detach", str(worktree), "HEAD")
        assert (worktree / ".git").is_file()
        for folder in (repository, worktree):
            masters(folder)
        (worktree / "tools/assets/authoring").mkdir(parents=True)
        for name in ("tools/assets/__init__.py", "tools/assets/authoring/__init__.py"):
            (worktree / name).write_text('"""Disposable package."""\n')
        git(worktree, "mv", SOURCE, TARGET)
        # Чужой контекст существует, но helper обязан выбирать источник своего worktree.
        (foreign_cwd / "tools").mkdir()
        (foreign_cwd / "tools/__init__.py").write_text("raise RuntimeError('foreign package loaded')\n")
        environment = dict(os.environ, PYTHONPATH=str(foreign_cwd), GIT_DIR=str(repository / ".git"),
                           GIT_WORK_TREE=str(repository), GIT_INDEX_FILE=str(repository / ".git/index"))
        foreign_before = {name: (repository / ".git" / name).read_bytes() for name in ("config", "index")}
        for label, command in [
            ("baseline", [sys.executable, str(repository / SOURCE)]),
            ("naive-move", [sys.executable, str(worktree / "tools/run.py"), "assets.authoring.build_forest_tree_atlas"]),
            ("prepared-move", [sys.executable, str(worktree / "tools/run.py"), "assets.authoring.build_forest_tree_atlas"]),
        ]:
            if label == "prepared-move":
                (worktree / TARGET).write_bytes(prepared)
            result = subprocess.run(command, cwd=foreign_cwd, env=environment, capture_output=True, text=True, timeout=60)
            records.append({"label": label, "command": command, "exit": result.returncode,
                            "stdout": result.stdout, "stderr": result.stderr})
            if label == "naive-move":
                assert result.returncode != 0 and "FileNotFoundError" in result.stderr
                assert snapshot(worktree) == {}
            else:
                assert result.returncode == 0 and not result.stderr, records[-1]
        expected, actual = snapshot(repository), snapshot(worktree)
        assert len(expected) == 2 and expected == actual
        assert all((repository / ".git" / name).read_bytes() == raw for name, raw in foreign_before.items())
        assert (ROOT / SOURCE).read_bytes() == prepared
        result = {"base": BASE, "version": (ROOT / "VERSION").read_text().strip(),
                  "prepared_sha256": source_before, "linked_worktree": True,
                  "records": records, "byte_identical_outputs": expected,
                  "foreign_index_config_unchanged": True, "source_unchanged": True}
    assert not temporary.exists()
    result["temporary_removed"] = True
    with report.open("x") as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"baseline_exit": records[0]["exit"], "naive_exit": records[1]["exit"],
                      "prepared_exit": records[2]["exit"], "exact_outputs": len(expected), "temporary_removed": True}))


if __name__ == "__main__":
    main()
