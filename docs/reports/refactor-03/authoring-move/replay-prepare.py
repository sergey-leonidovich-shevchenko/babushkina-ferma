"""Повторяет опубликованные профили357 в собственной ограниченной Git-копии без изменения старых raw."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

PREPARED = "0352c5f286dc90c5fa324347b9ceadeb6a8e9350"
PREFIX = "docs/reports/refactor-03/"


def main():
    """Запускает точные старые scripts на нужных им исходниках; это не полный Game или рабочий checkout игры."""
    output = ROOT / PREFIX / "authoring-move/replay-prepare"
    output.mkdir()
    expected = json.loads(subprocess.check_output(["git", "show", PREPARED + ":" + PREFIX + "authoring-prepare/sources.json"],
                                                  cwd=ROOT, env=git_environment()))
    paths = [row["path"] for row in expected["files"]]
    paths += [".gitignore", "VERSION", "project.godot", "tools/__init__.py", "tools/run.py",
              PREFIX + "profile-authoring.py", PREFIX + "preview-authoring.py",
              PREFIX + "authoring-prepare/sources.json"]
    tree = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", PREPARED, "--", "tools/common"],
                                   cwd=ROOT, env=git_environment()).decode().splitlines()
    paths += tree
    records = []
    with tempfile.TemporaryDirectory(prefix="published357 bounded replay ") as temporary:
        clone = Path(temporary) / "source with spaces"
        subprocess.run(["git", "clone", "--quiet", "--shared", "--no-checkout", str(ROOT), str(clone)],
                       env=git_environment(), check=True, capture_output=True)
        # Меняется только HEAD собственной disposable копии; object store исходника читается через alternates.
        subprocess.run(["git", "update-ref", "--no-deref", "HEAD", PREPARED], cwd=clone,
                       env=git_environment(), check=True)
        subprocess.run(["git", "checkout", PREPARED, "--", *paths], cwd=clone,
                       env=git_environment(), check=True, capture_output=True)
        for row in expected["files"]:
            assert hashlib.sha256((clone / row["path"]).read_bytes()).hexdigest() == row["prepared"]
        for name in ("profile-authoring.py", "preview-authoring.py"):
            command = [sys.executable, str(clone / PREFIX / name)]
            result = subprocess.run(command, cwd=clone, env=git_environment(), capture_output=True, text=True, timeout=120)
            (output / (name + ".stdout.txt")).write_text(result.stdout)
            (output / (name + ".stderr.txt")).write_text(result.stderr)
            records.append({"script": name, "command": command, "exit": result.returncode})
            assert result.returncode == 0 and not result.stderr, records[-1]
        for name in ("profile.json", "preview.json"):
            shutil.copy2(clone / PREFIX / "authoring-prepare" / name, output / name)
        old = json.loads((ROOT / PREFIX / "authoring-prepare/preview.json").read_text())
        fresh = json.loads((output / "preview.json").read_text())
        assert old["byte_identical_outputs"] == fresh["byte_identical_outputs"]
        assert old["prepared_sha256"] == fresh["prepared_sha256"]
    assert not clone.exists()
    result = {"published_head": PREPARED, "bounded_source_fixture_only": True,
              "full_Game_or_native_replay": False, "selected_paths": len(paths), "records": records,
              "same_prepared_source_and_png_SHA": True, "temporary_clone_removed": True,
              "published_reports_unchanged": True}
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
