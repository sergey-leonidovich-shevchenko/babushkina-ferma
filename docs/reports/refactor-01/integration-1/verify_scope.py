"""Read-only приёмка объёма REFACTOR-01; не является guard будущего HEAD."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
from collections import Counter


ALLOWED = {
    "TESTING.md", "VERSION", "project.godot", "Бабушкина ферма.app/Contents/Info.plist",
    "docs/epics/refactoring-2026-10/README.md", "docs/epics/refactoring-2026-10/TASKS.md",
    "wiki/articles/index.json", "wiki/articles/project-refactoring.md", "wiki/articles/visual-pilot.md",
}
PROTECTED = ["tools/", "scripts/", "tests/", "assets/", "docs/reports/", "wiki/scripts/"]


def digest(path: Path, mode: str = "100644") -> str:
    """Хеширует реальные байты; Git symlink сравнивается как имя цели, без разыменования."""
    result = hashlib.sha256()
    if mode == "120000":
        result.update(os.readlink(path).encode())
    else:
        with path.open("rb") as source:
            while block := source.read(1024 * 1024):
                result.update(block)
    return result.hexdigest()


def verify(root: Path) -> dict:
    """Проверяет все старые файлы, новые пути и сохранность чужих карточек/реестров."""
    report = Path(__file__).resolve().parent
    snapshot = report / "snapshot"
    packet = json.loads((snapshot / "packet.json").read_text())
    manifest = snapshot / "baseline-files.jsonl.gz"
    assert digest(manifest) == packet["files"][manifest.name], "baseline manifest SHA"
    baseline = packet["baseline_commit"]
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}

    def git(*args: str) -> bytes:
        """Всегда читает выбранный repo; не наследует GIT_DIR или альтернативный index."""
        return subprocess.check_output(["git", "-C", str(root), *args], env=environment)

    def original(name: str) -> bytes:
        """Читает закреплённый accepted blob, а не нынешний HEAD."""
        return git("show", baseline + ":" + name)

    with gzip.open(manifest, "rt") as source:
        rows = [json.loads(line) for line in source]
    changed, protected = {}, Counter()
    for row in rows:
        path = root / row["path"]
        assert path.exists() or path.is_symlink(), "old file missing: " + row["path"]
        checksum = digest(path, row["mode"])
        if checksum != row["sha256"]:
            changed[row["path"]] = {"before": row["sha256"], "after": checksum}
        else:
            protected.update(prefix for prefix in PROTECTED if row["path"].startswith(prefix))
    assert set(changed) == ALLOWED, "unexpected old changes: " + str(sorted(set(changed) ^ ALLOWED))
    old_names = {row["path"] for row in rows}
    new_names = set(git("ls-files", "-z").decode().split("\0"))
    new_names.update(git("ls-files", "--others", "--exclude-standard", "-z").decode().split("\0"))
    added = sorted(new_names - old_names - {""})
    assert all(name.startswith("docs/reports/refactor-01/") or name == "wiki/articles/tools-migration-map.md"
               for name in added), "unexpected new files"
    before = json.loads(original("wiki/articles/index.json"))
    after = json.loads((root / "wiki/articles/index.json").read_text())
    index = {row["id"]: row for row in after}
    assert len(index) == len(after) and set(index) - {row["id"] for row in before} == {"tools-migration-map"}
    assert [row["id"] for row in after if row["id"] != "tools-migration-map"] == [row["id"] for row in before]
    for row in before:
        if row["id"] != "project-refactoring":
            assert index[row["id"]] == row, "Wiki entry changed: " + row["id"]
        else:
            assert {k: v for k, v in row.items() if k != "summary"} == {
                k: v for k, v in index[row["id"]].items() if k != "summary"}
    name = "docs/epics/refactoring-2026-10/TASKS.md"
    old_parts = original(name).decode().split("## REFACTOR-")
    new_parts = (root / name).read_text().split("## REFACTOR-")
    assert len(old_parts) == len(new_parts)
    for old, new in zip(old_parts, new_parts):
        if not old.startswith("01 "):
            assert old == new, "another task changed"
            continue
        assert "**Статус:** in_progress" in new
        mutable = ("**Статус:**", "**Подтверждения / результат:**", "**Pull Request:**")
        assert [p for p in old.split("\n\n") if not p.startswith(mutable)] == [
            p for p in new.split("\n\n") if not p.startswith(mutable)], "REFACTOR-01 criteria changed"
    planning = {}
    for name in ["wiki/planning/sources.json", "wiki/planning/state.json", "wiki/planning/assessments.json"]:
        checksum = digest(root / name)
        assert checksum == hashlib.sha256(original(name)).hexdigest(), "planning changed: " + name
        planning[name] = checksum
    return {"task": "REFACTOR-01", "baseline": baseline,
            "method": "SHA256 of every accepted blob versus worktree; declared new paths only; live candidate scope, not future placement guard",
            "baseline_files_checked": len(rows), "unchanged": len(rows) - len(changed),
            "unexpected_changes": [], "declared_changes": changed, "protected_unchanged": dict(protected),
            "new_files": added, "planning_sha256_preserved": planning,
            "other_task_sections_byte_identical": True, "other_Wiki_entries_preserved": len(before) - 1,
            "Wiki_entry_order_preserved": True, "task_status": "in_progress"}


def main() -> None:
    """Печатает результат; файл пишет только по явному --output и никогда не заменяет старый."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = next(path for path in Path(__file__).resolve().parents
                if (path / "project.godot").is_file() and (path / ".git").exists())
    text = json.dumps(verify(root), ensure_ascii=False, indent=2) + "\n"
    if args.output is not None:
        with args.output.open("x") as destination:
            destination.write(text)
    print(text, end="")


if __name__ == "__main__":
    main()
