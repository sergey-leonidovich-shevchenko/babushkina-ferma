"""Выполняет только первый тематический git mv после отдельного чистого подготовительного коммита."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def git(*arguments):
    """Адресует Git только текущей рабочей копии, не наследуя чужой индекс или worktree."""
    return subprocess.check_output(["git", *arguments], cwd=ROOT, env=git_environment())


def main():
    """Перемещает принятые назначения и UID, меняя только пути импортов и живых команд."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepared", required=True)
    args = parser.parse_args()
    assert re.fullmatch(r"[0-9a-f]{40}", args.prepared)
    assert git("rev-parse", "HEAD").decode().strip() == args.prepared
    assert git("branch", "--show-current").decode().strip() == "codex/refactor-03-maintainable-layout"
    assert not git("status", "--porcelain"), "нужен чистый проверенный подготовительный коммит"
    assert (ROOT / "VERSION").read_text().strip() == "0.0.357"
    baseline = json.loads((ROOT / "docs/reports/refactor-03/baseline/migration.json").read_text())
    records = [row for row in baseline["assignments"] if row["family"] == "assets-authoring"]
    assert len(records) == 36
    report = ROOT / "docs/reports/refactor-03/authoring-move"
    assert not report.exists()
    report.mkdir()
    before = {row["old_path"]: (ROOT / row["old_path"]).read_bytes() for row in records}
    modes = {row["old_path"]: (ROOT / row["old_path"]).stat().st_mode & 0o777 for row in records}
    local_uids = []
    tracked = set(git("ls-files").decode().splitlines())
    for row in records:
        old, target = row["old_path"], row["target"]
        uid = ROOT / (old + ".uid")
        if old.endswith(".gd") and uid.is_file() and str(uid.relative_to(ROOT)) not in tracked:
            ignored = subprocess.run(["git", "check-ignore", "-q", str(uid.relative_to(ROOT))],
                                     cwd=ROOT, env=git_environment()).returncode
            assert ignored == 0
            local_uids.append({"old_path": old + ".uid", "target": target + ".uid",
                               "bytes": uid.read_text(), "tracked": False})
    ignore = ROOT / ".gitignore"
    rule = ("\n# REFACTOR-03: authoring sources; local generated UID/cache remain ignored.\n"
            "!tools/assets/\ntools/assets/*\n!tools/assets/__init__.py\n"
            "!tools/assets/authoring/\ntools/assets/authoring/*\n"
            "!tools/assets/authoring/__init__.py\n!tools/assets/authoring/*.py\n!tools/assets/authoring/*.gd\n")
    rule += "".join("!" + row["target"] + "\n" for row in records if row["old_path"].endswith(".uid"))
    ignore.write_text(ignore.read_text() + rule)
    for folder, description in [("tools/assets", "Подготовка и проверка ресурсов."),
                                ("tools/assets/authoring", "Детерминированная подготовка игровых рисунков.")]:
        path = ROOT / folder
        path.mkdir(exist_ok=True)
        assert not (path / "__init__.py").exists()
        (path / "__init__.py").write_text('"""' + description + '"""\n')
    for row in records:
        subprocess.run(["git", "mv", "--", row["old_path"], row["target"]], cwd=ROOT,
                       env=git_environment(), check=True)
    for row in local_uids:
        shutil.move(ROOT / row["old_path"], ROOT / row["target"])
        assert (ROOT / row["target"]).read_text() == row["bytes"]
        assert subprocess.run(["git", "check-ignore", "-q", row["target"]], cwd=ROOT,
                              env=git_environment()).returncode == 0
    for row in records:
        path = ROOT / row["target"]
        raw = before[row["old_path"]]
        if path.suffix == ".py":
            source = raw.decode().replace("from measure_hero_actions import ",
                                         "from tools.assets.authoring.measure_hero_actions import ")
            if path.name == "measure_skeleton_regions.py":
                # Единственный прежний cwd-вход семейства: адрес меняется, измерение остаётся прежним.
                source = source.replace('root = Path("docs/concepts/skeleton-2026-10-12/v2")',
                                        'root = project_root(__file__) / "docs/concepts/skeleton-2026-10-12/v2"')
                source = source.replace("from pathlib import Path", "from pathlib import Path\nfrom tools.common.paths import project_root")
            path.write_text(source)
        elif path.suffix == ".gd":
            source = raw.decode()
            for item in records:
                source = source.replace(item["old_path"], item["target"])
            path.write_text(source)
        assert path.stat().st_mode & 0o777 == modes[row["old_path"]]
    for name in ("docs/DEVELOPMENT.md", "tools/README.md"):
        path = ROOT / name
        source = path.read_text()
        for row in records:
            if row["old_path"].endswith(".py"):
                command = ".".join(Path(row["target"]).relative_to("tools").with_suffix("").parts)
                source = source.replace("python3 tools/run.py " + Path(row["old_path"]).stem,
                                        "python3 tools/run.py " + command)
                source = source.replace("python3 " + row["old_path"], "python3 tools/run.py " + command)
            else:
                source = source.replace(row["old_path"], row["target"])
        path.write_text(source)
    assert not git("diff", "HEAD", "--name-only", "--", "scripts", "assets", "tests", "scenes", "level_designs")
    result = {"prepared_head": args.prepared, "moves": [
        {"old_path": row["old_path"], "target": row["target"], "mode": modes[row["old_path"]],
         "prepared_sha256": hashlib.sha256(before[row["old_path"]]).hexdigest(),
         "moved_sha256": hashlib.sha256((ROOT / row["target"]).read_bytes()).hexdigest()}
        for row in records], "local_ignored_UID": local_uids, "runtime_changes": False}
    (report / "migration.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"moved": len(records), "tracked_UID": 5, "local_ignored_UID": len(local_uids)}))


if __name__ == "__main__":
    main()
