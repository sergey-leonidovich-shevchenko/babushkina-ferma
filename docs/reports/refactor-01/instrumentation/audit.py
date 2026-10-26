#!/usr/bin/env python3
"""Воспроизводит ведомость REFACTOR-01 из Git, не перемещая и не исполняя инструменты."""
from __future__ import annotations

import argparse
from collections import Counter
import csv
import gzip
import hashlib
import json
from pathlib import Path
import tempfile

from archive_index import index_archives
from git_snapshot import Snapshot, project_root, sha256_file
from mapping import cross_family_imports, directory_counts, other_catalogs, tool_inventory, validate_plan
from references import References, TEXT_SUFFIXES
from suite_registry import registry


DIRECTORIES = ["tools", "scripts/systems", "scripts/presentation", "tests/suites",
               "tests/helpers", "wiki/scripts", "docs/reports", "assets/game/items/ui/preview"]


def write_json(path: Path, value) -> None:
    """Пишет только новый результат аудита; исходный Git-снимок остаётся read-only."""
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def write_jsonl_gzip(path: Path, rows) -> None:
    """Нулевой mtime делает сжатый ledger одинаковым из разных cwd и каталогов вывода."""
    with path.open("wb") as destination:
        with gzip.GzipFile(filename="", fileobj=destination, mode="wb", mtime=0) as stream:
            for row in rows:
                stream.write((json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode())


def instrumentation_sources() -> dict[str, str]:
    """Закрепляет код генератора отдельно от принятого снимка, который он исследует."""
    return {path.name: sha256_file(path) for path in sorted(Path(__file__).parent.glob("*.py"))}


def collect(root: Path, commit: str, plan_path: Path, output: Path) -> dict:
    """Собирает полную карту из единственного commit; не дописывает существующую серию."""
    if output.exists() or not output.parent.is_dir():
        raise ValueError("fresh output directory with existing parent required")
    plan_raw = plan_path.read_bytes()
    plan = json.loads(plan_raw)
    if plan["baseline_commit"] != commit:
        raise ValueError("plan baseline commit mismatch")
    snapshot = Snapshot(root, commit)
    paths = set(snapshot.blobs)
    future_root = validate_plan(plan, paths)
    references = References(paths)
    # В registry попадают sidecars основных исходников, а не их архивные копии в reports.
    uid_names = {name for name in paths if name.endswith(".uid") and
                 name.startswith(("tools/", "scripts/", "tests/", "wiki/scripts/"))}
    for blob, _, text in snapshot.stream({".uid"}, uid_names):
        references.add(blob.path, text)
    output.mkdir()
    texts, hashes, manifest = {}, {}, []
    for number, (blob, checksum, text) in enumerate(snapshot.stream(TEXT_SUFFIXES), 1):
        hashes[blob.path] = checksum
        manifest.append({"path": blob.path, "git_blob": blob.oid, "mode": blob.mode,
                         "bytes": blob.size, "sha256": checksum})
        if text is not None:
            if blob.path.startswith(("tools/", "scripts/", "tests/", "wiki/scripts/")):
                texts[blob.path] = text
            if not blob.path.endswith(".uid"):
                references.add(blob.path, text)
        if number % 5000 == 0:
            print(json.dumps({"hashed_blobs": number, "baseline": commit}), flush=True)
    archives = index_archives(snapshot, references, hashes)
    references.finish()
    inventory = tool_inventory(plan, snapshot.blobs, hashes, texts, references.rows)
    extensions = set(plan["source_extensions"])
    counts = {directory: directory_counts(snapshot.blobs, directory, extensions) for directory in DIRECTORIES}
    families = Counter(item["family"] for item in inventory)
    archive_errors = [row for row in archives if row["errors"]]
    uid_sources = [item for item in inventory if item["uid_pair"] is not None]
    summary = {
        "schema": 1, "task": "REFACTOR-01", "baseline_commit": commit,
        "baseline_tree": snapshot.git("rev-parse", commit + "^{tree}").decode().strip(),
        "baseline_version": snapshot.contents("VERSION").decode().strip(),
        "method": "tracked Git blobs only; SHA256 of every blob; no runtime execution or relocation",
        "repository_files": len(manifest), "repository_bytes": sum(row["bytes"] for row in manifest),
        "directories": counts, "tool_files_mapped": len(inventory),
        "future_root_sources_proposed": future_root, "root_budget": plan["root_source_budget"],
        "families": dict(sorted(families.items())), "references": len(references.rows),
        "reference_kinds": dict(sorted(Counter(row["kind"] for row in references.rows).items())),
        "hazards": len(references.hazards), "archive_count": len(archives),
        "archive_index_errors": len(archive_errors),
        "tracked_uid_pairs": sum(item["uid_pair"]["tracked"] for item in uid_sources),
        "sources_without_tracked_uid": sum(not item["uid_pair"]["tracked"] for item in uid_sources),
        "uid_registry_scope": "tracked source sidecars in tools/scripts/tests/wiki/scripts; archive copies excluded",
        "generator_sha256": instrumentation_sources(),
        "plan_sha256": hashlib.sha256(plan_raw).hexdigest(),
        "verification_catalog": {
            "full-snapshot-reproduction": {
                "command": plan.get("verification_command", "python3 docs/reports/refactor-01/instrumentation/audit.py check --snapshot docs/reports/refactor-01/snapshot"),
                "coverage": "all baseline blobs, paths, UID pairs, static references and archive member index; no execution claim",
            },
        },
        "limits": ["static dependency paths do not prove every branch executed",
                   "dynamic pattern candidates are potential, not exact consumers",
                   "native captures were not repeated; no GPU/FPS claim",
                   "future targets and dispatcher are proposed, not implemented"],
    }
    write_json(output / "inventory.json", summary)
    write_json(output / "tool-map.json", inventory)
    write_json(output / "hazards.json", references.hazards)
    write_json(output / "archives.json", archives)
    write_json(output / "cross-family-imports.json", cross_family_imports(inventory, references.rows))
    write_json(output / "suite-registry.json", registry(texts))
    write_json(output / "other-catalogs.json", other_catalogs(plan, snapshot.blobs, references.rows, texts))
    write_json(output / "markdown-links.json", [row for row in references.rows if row["kind"] == "markdown_link"])
    write_jsonl_gzip(output / "baseline-files.jsonl.gz", manifest)
    write_jsonl_gzip(output / "references.jsonl.gz", references.rows)
    (output / "migration-plan-copy.json").write_bytes(plan_raw)
    _write_tables(output, plan, inventory)
    files = {path.name: sha256_file(path) for path in sorted(output.iterdir()) if path.is_file()}
    write_json(output / "packet.json", {"baseline_commit": commit, "files": files})
    return summary


def _write_tables(output: Path, plan: dict, inventory: list[dict]) -> None:
    """CSV перечисляет все blobs; Markdown группирует исходники и показывает UID рядом."""
    fields = ["old_path", "target", "family", "action", "stage", "purpose", "entry_kind", "tracked_uid", "references"]
    with (output / "tool-map.csv").open("w", newline="") as destination:
        writer = csv.DictWriter(destination, fields, lineterminator="\n")
        writer.writeheader()
        for item in inventory:
            row = {field: item[field] for field in fields if field in item}
            row["tracked_uid"] = item["uid_pair"]["tracked"] if item["uid_pair"] else ""
            row["references"] = len(item["reference_ids"])
            writer.writerow(row)
    lines = ["# Полная предложенная карта tools — REFACTOR-01", "",
             "Снимок `" + plan["baseline_commit"] + "`. Переносы не выполнены. CSV/JSON включают UID отдельными строками; здесь они указаны при исходнике.", ""]
    for family, policy in plan["families"].items():
        lines += ["## " + policy["title"], "", "| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |", "| --- | --- | --- | ---: |"]
        for item in inventory:
            if item["family"] != family or item["old_path"].endswith(".uid"):
                continue
            purpose = item["purpose"].replace("|", "\\|").replace("\n", " ")
            uid = item["uid_pair"]
            if uid is not None:
                purpose += "; UID: " + ("отслеживается" if uid["tracked"] else "нет в Git; отдельный preflight")
            lines.append(f'| `{item["old_path"]}` | `{item["target"]}` | {purpose} | {len(item["reference_ids"])} |')
        lines.append("")
    (output / "tool-map.md").write_text("\n".join(lines) + "\n")


def check(root: Path, folder: Path, plan: Path) -> dict:
    """Полностью пересчитывает Git/ledger/карты в новом temp и сравнивает весь пакет, не только summary."""
    packet = json.loads((folder / "packet.json").read_text())
    if any(path.is_symlink() or not path.is_file() for path in folder.iterdir()):
        raise ValueError("snapshot packet requires ordinary files only")
    existing = {path.name for path in folder.iterdir() if path.is_file()}
    if existing != set(packet["files"]) | {"packet.json"}:
        raise ValueError("snapshot packet file inventory differs")
    for name, expected in packet["files"].items():
        if sha256_file(folder / name) != expected:
            raise ValueError("snapshot packet SHA: " + name)
    with tempfile.TemporaryDirectory(prefix="farm-refactor01-reproduction-") as temp:
        output = Path(temp) / "fresh"
        summary = collect(root, packet["baseline_commit"], plan, output)
        for name in sorted(existing):
            if (folder / name).read_bytes() != (output / name).read_bytes():
                raise ValueError("full reproduction differs: " + name)
    return summary


def show(folder: Path, name: str) -> dict:
    """Позволяет ревьюеру найти вход и точные строки потребителей без глобального grep."""
    tools = json.loads((folder / "tool-map.json").read_text())
    item = next(row for row in tools if row["old_path"] == name)
    ids = set(item["reference_ids"]) | set(item["potential_reference_ids"])
    with gzip.open(folder / "references.jsonl.gz", "rt") as source:
        consumers = [json.loads(line) for number, line in enumerate(source) if number in ids]
    return {"tool": item, "consumers": consumers}


def main() -> None:
    """Все пути задаются явно либо выводятся из маркеров проекта; CLI работает из другой cwd."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["collect", "check", "show"])
    parser.add_argument("--root", type=Path)
    parser.add_argument("--base")
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--path")
    args = parser.parse_args()
    root = (args.root or project_root(Path(__file__).resolve().parent)).resolve()
    plan = args.plan or root / "docs/reports/refactor-01/migration-plan.json"
    if args.command == "collect":
        if not args.base or args.output is None:
            parser.error("collect requires --base and --output")
        result = collect(root, args.base, plan, args.output.resolve())
    elif args.command == "check":
        if args.snapshot is None:
            parser.error("check requires --snapshot")
        result = check(root, args.snapshot.resolve(), plan)
    else:
        if args.snapshot is None or not args.path:
            parser.error("show requires --snapshot and --path")
        result = show(args.snapshot.resolve(), args.path)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
