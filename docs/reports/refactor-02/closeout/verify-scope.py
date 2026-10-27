"""Check this accounting candidate against its accepted implementation, without rewriting it."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

# Bootstrap the accepted common package from this source, even outside the repository cwd.
anchor = Path(__file__).resolve()
import_root = next(parent for parent in anchor.parents
                   if (parent / "project.godot").is_file()
                   and (parent / "VERSION").is_file()
                   and (parent / "tools/common/git.py").is_file())
sys.path.insert(0, str(import_root))

from tools.common.git import git_environment
from tools.common.paths import project_root

root = project_root(anchor)
report = root / "docs/reports/refactor-02/closeout"
baseline = json.loads((report / "baseline.json").read_text())
base = baseline["base"]
version = "0.0.356"


def git(*args):
    # cwd alone cannot override an inherited worktree, alternate index or config context.
    return subprocess.check_output(["git", *args], cwd=root, env=git_environment())


# Frozen reports, UID and plans are checked from the recorded byte-level snapshot.
for row in baseline["files"]:
    data = (root / row["path"]).read_bytes()
    assert len(data) == row["bytes"], row["path"]
    assert hashlib.sha256(data).hexdigest() == row["sha256"], row["path"]


def cards(text):
    blocks = re.split(r"(?=^## REFACTOR-\d+ )", text, flags=re.MULTILINE)[1:]
    return {re.search(r"REFACTOR-\d+", block)[0]: block for block in blocks}


source = "docs/epics/refactoring-2026-10/TASKS.md"
old = cards(git("show", base + ":" + source).decode())
new = cards((root / source).read_text())
assert old.keys() == new.keys()
assert len(new) == 7
for key in old.keys() - {"REFACTOR-02", "REFACTOR-03"}:
    assert new[key] == old[key], key
assert new["REFACTOR-03"] == old["REFACTOR-03"].replace("blocked", "ready", 1)
assert "**Статус:** done" in new["REFACTOR-02"]
assert "**Дата завершения:** 2026-10-27\n" in new["REFACTOR-02"]

# No tools/game/test changes or unrelated additions may hide in this editorial PR.
allowed = {
    "TESTING.md", "VERSION", "project.godot", source,
    "docs/epics/refactoring-2026-10/README.md", "wiki/articles/index.json",
    "wiki/articles/project-refactoring.md", "wiki/articles/visual-pilot.md",
    "\u0411\u0430\u0431\u0443\u0448\u043a\u0438\u043d\u0430 \u0444\u0435\u0440\u043c\u0430.app/Contents/Info.plist",
}
changed = git("diff", "--name-only", "-z", base).decode().strip("\0").split("\0")
untracked = git("ls-files", "--others", "--exclude-standard", "-z").decode().strip("\0").split("\0")
prefix = "docs/reports/refactor-02/closeout/"
assert all(not path or path in allowed or path.startswith(prefix) for path in changed + untracked)
for path in ("tools", "scripts", "tests", "assets", "scenes", "level_designs", "wiki/planning"):
    assert not git("diff", base, "--", path), path

# Platform metadata changes only the publication version; the Wiki index changes one summary.
metadata = [path for path in allowed if path in ("VERSION", "project.godot") or path.endswith("Info.plist")]
for path in metadata:
    before = git("show", base + ":" + path)
    assert (root / path).read_bytes() == before.replace(b"0.0.354", version.encode("ascii")), path
before = json.loads(git("show", base + ":wiki/articles/index.json"))
after = json.loads((root / "wiki/articles/index.json").read_text())
assert [item["id"] for item in before] == [item["id"] for item in after]
for left, right in zip(before, after):
    if left["id"] == "project-refactoring":
        assert {key: value for key, value in left.items() if key != "summary"} == {
            key: value for key, value in right.items() if key != "summary"
        }
    else:
        assert left == right, left["id"]
print(json.dumps({
    "base": base, "preserved": baseline["counts"], "files_verified": len(baseline["files"]),
    "changed_tasks": ["REFACTOR-02", "REFACTOR-03"], "other_cards_unchanged": 5,
    "runtime_tools_tests_planning_unchanged": True,
    "only_wiki_index_field": "project-refactoring.summary", "version": version,
}, indent=2))
