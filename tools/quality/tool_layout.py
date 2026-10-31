#!/usr/bin/env python3
"""Проверяет корень tools, владельческие домены и пары Godot UID без снимка всего дерева."""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from tools.common.paths import project_root

ROOT_SOURCE_LIMIT = 30
SOURCE_SUFFIXES = {".gd", ".gdshader", ".js", ".mjs", ".py", ".sh", ".swift", ".ts"}
IGNORED_DIRECTORIES = {"Godot.app", "__pycache__"}

DOMAIN_OWNERS = {
    "assets": "Asset Pipeline",
    "build": "Release Tooling",
    "common": "Developer Platform",
    "dev": "Developer Experience",
    "planning": "Team Lead / Planning",
    "qa": "QA",
    "quality": "Tech Lead / Quality",
}

ROOT_PUBLIC = {
    "__init__.py": ("Developer Platform", "закрепляет собственный пакет tools"),
    "bump_version.py": ("Release Tooling", "совместимый facade planning.bump_version"),
    "check_architecture.sh": ("Tech Lead / Quality", "совместимый вход hooks и CI"),
    "performance_gate.py": ("QA / Performance", "API и mutable globals frozen readers"),
    "performance_gate.sh": ("QA / Performance", "совместимый вход CI"),
    "performance_protocol.py": ("QA / Performance", "единая реализация frozen readers"),
    "performance_sampler.gd": ("QA / Performance", "защищённый engine --script anchor"),
    "run.py": ("Developer Platform", "общий Python CLI из любой cwd"),
    "smoke_test.sh": ("QA / Performance", "совместимый вход CI"),
    "task_batch.py": ("Team Lead / Planning", "совместимый status facade"),
    "water_audit.gd": ("QA / World", "защищённый WATER/shore anchor"),
}

ROOT_UIDS = {
    "performance_sampler.gd.uid": "performance_sampler.gd",
    "water_audit.gd.uid": "water_audit.gd",
}
REQUIRED_ROOT_UIDS = {"performance_sampler.gd.uid"}

NAVIGATION_COMMANDS = (
    "python3 tools/run.py quality.tool_layout --json",
    "python3 tools/run.py qa.foliage.foliage_root_verify --help",
    "python3 tools/run.py assets.authoring.build_forest_tree_atlas --help",
)


def is_source(path: Path) -> bool:
    """Считает исполняемые и shader-исходники, не смешивая их с JSON, PNG и UID."""
    return path.suffix in SOURCE_SUFFIXES


def readme_errors(root: Path) -> list[str]:
    """Связывает разрешённые исключения и владельцев с читаемой документацией для человека."""
    path = root / "tools/README.md"
    if not path.is_file():
        return ["отсутствует tools/README.md"]
    content = path.read_text(encoding="utf-8")
    required = [f"`tools/{name}`" for name in ROOT_PUBLIC]
    required.extend(f"| `{domain}` |" for domain in DOMAIN_OWNERS)
    required.extend(f"`{command}`" for command in NAVIGATION_COMMANDS)
    return [
        f"tools/README.md не документирует {value}" for value in required if value not in content
    ]


def walk_files(tools: Path, errors: list[str]) -> Iterable[Path]:
    """Обходит реальные файлы, не заходя в runtime/cache и не следуя directory symlink."""

    def record_error(error: OSError) -> None:
        path = Path(error.filename) if error.filename else tools
        try:
            display = path.relative_to(tools).as_posix()
        except ValueError:
            display = str(path)
        errors.append(
            f"каталог tools недоступен для полного обхода: {display}: {error.strerror or error}"
        )

    for current, directories, files in os.walk(tools, followlinks=False, onerror=record_error):
        folder = Path(current)
        kept: list[str] = []
        for name in directories:
            candidate = folder / name
            if name in IGNORED_DIRECTORIES:
                continue
            if candidate.is_symlink():
                errors.append(
                    f"каталог tools не может быть symlink: {candidate.relative_to(tools)}"
                )
                continue
            kept.append(name)
        directories[:] = kept
        for name in files:
            yield folder / name


def inspect_layout(root: Path, root_source_limit: int = ROOT_SOURCE_LIMIT) -> dict[str, Any]:
    """Возвращает полную текущую карту исходников/UID и все нарушения без изменения файлов."""
    root = root.resolve()
    tools = root / "tools"
    errors: list[str] = []
    if not tools.is_dir() or tools.is_symlink():
        return {"schema": 1, "errors": ["tools должен быть обычным каталогом проекта"]}

    domain_sources: dict[str, list[str]] = {name: [] for name in DOMAIN_OWNERS}
    domain_uids: dict[str, list[str]] = {name: [] for name in DOMAIN_OWNERS}
    root_sources: list[str] = []
    root_uids: list[str] = []

    for domain in DOMAIN_OWNERS:
        path = tools / domain
        if not path.is_dir() or path.is_symlink():
            errors.append(f"владельческий домен tools/{domain} отсутствует или является symlink")

    for path in walk_files(tools, errors):
        relative = path.relative_to(tools)
        if path.is_symlink() and (is_source(path) or path.suffix == ".uid"):
            errors.append(f"исходник или UID не может быть symlink: tools/{relative.as_posix()}")
            continue
        if relative.parent == Path("."):
            if is_source(path):
                root_sources.append(relative.as_posix())
            elif path.suffix == ".uid":
                root_uids.append(relative.as_posix())
            continue
        domain = relative.parts[0]
        if not (is_source(path) or path.suffix == ".uid"):
            continue
        if domain not in DOMAIN_OWNERS:
            errors.append(f"у tools/{relative.as_posix()} нет владельческого домена")
            continue
        name = relative.as_posix()
        if is_source(path):
            domain_sources[domain].append(name)
        else:
            domain_uids[domain].append(name)
            source = path.with_suffix("")
            if not source.is_file() or source.is_symlink() or not is_source(source):
                errors.append(f"UID не привязан к обычному исходнику: tools/{name}")

    root_sources.sort()
    root_uids.sort()
    if len(root_sources) > root_source_limit:
        errors.append(
            f"корень tools содержит {len(root_sources)} исходников при лимите {root_source_limit}"
        )
    unexpected_sources = sorted(set(root_sources) - set(ROOT_PUBLIC))
    missing_sources = sorted(set(ROOT_PUBLIC) - set(root_sources))
    if unexpected_sources:
        errors.append("в корне tools не документированы: " + ", ".join(unexpected_sources))
    if missing_sources:
        errors.append(
            "документированные публичные входы отсутствуют: " + ", ".join(missing_sources)
        )
    unexpected_uids = sorted(set(root_uids) - set(ROOT_UIDS))
    missing_uids = sorted(REQUIRED_ROOT_UIDS - set(root_uids))
    if unexpected_uids:
        errors.append("в корне tools не документированы UID: " + ", ".join(unexpected_uids))
    if missing_uids:
        errors.append("UID защищённых root anchors отсутствуют: " + ", ".join(missing_uids))
    for uid, source_name in ROOT_UIDS.items():
        if uid in root_uids and source_name not in root_sources:
            errors.append(f"UID tools/{uid} не имеет исходника tools/{source_name}")

    errors.extend(readme_errors(root))
    domains = []
    for name, owner in DOMAIN_OWNERS.items():
        sources = sorted(domain_sources[name])
        uids = sorted(domain_uids[name])
        domains.append(
            {
                "name": name,
                "owner": owner,
                "source_count": len(sources),
                "uid_count": len(uids),
                "sources": [f"tools/{value}" for value in sources],
                "uids": [f"tools/{value}" for value in uids],
            }
        )
    root_entries = [
        {
            "path": f"tools/{name}",
            "owner": ROOT_PUBLIC[name][0],
            "reason": ROOT_PUBLIC[name][1],
        }
        for name in sorted(ROOT_PUBLIC)
        if name in root_sources
    ]
    return {
        "schema": 1,
        "policy": {
            "root_source_limit": root_source_limit,
            "whole_repository_snapshot_pinned": False,
            "nested_additions_allowed_in_owned_domains": True,
            "runtime_excluded": "tools/Godot.app",
            "required_root_uids": sorted(REQUIRED_ROOT_UIDS),
            "generated_root_uids_allowed": sorted(set(ROOT_UIDS) - REQUIRED_ROOT_UIDS),
        },
        "root": {
            "source_count": len(root_sources),
            "uid_count": len(root_uids),
            "sources": root_entries,
            "uids": [
                {"path": f"tools/{name}", "source": f"tools/{ROOT_UIDS[name]}"}
                for name in root_uids
                if name in ROOT_UIDS
            ],
        },
        "domains": domains,
        "totals": {
            "source_count": len(root_sources)
            + sum(len(values) for values in domain_sources.values()),
            "uid_count": len(root_uids) + sum(len(values) for values in domain_uids.values()),
        },
        "errors": sorted(set(errors)),
    }


def audit(root: Path, root_source_limit: int = ROOT_SOURCE_LIMIT) -> dict[str, Any]:
    """Отклоняет любое нарушение и возвращает карту только для допустимого layout."""
    report = inspect_layout(root, root_source_limit)
    errors = report["errors"]
    if errors:
        assert isinstance(errors, list)
        raise ValueError("TOOLS LAYOUT:\n  " + "\n  ".join(str(error) for error in errors))
    return report


def main() -> int:
    """Запускает guard из любой cwd и по запросу печатает полный воспроизводимый JSON."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="напечатать полную карту путей")
    arguments = parser.parse_args()
    report = inspect_layout(project_root(__file__))
    if arguments.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        root = report.get("root", {})
        totals = report.get("totals", {})
        print(
            "TOOLS LAYOUT: root "
            f"{root.get('source_count', 0)}/{ROOT_SOURCE_LIMIT} source, "
            f"{root.get('uid_count', 0)} UID; total "
            f"{totals.get('source_count', 0)} source, {totals.get('uid_count', 0)} UID"
        )
    errors = report["errors"]
    if errors:
        for error in errors:
            print(f"TOOLS LAYOUT ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
