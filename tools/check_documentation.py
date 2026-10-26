#!/usr/bin/env python3
"""Проверяет обязательные документы и локальные ссылки Markdown."""

from __future__ import annotations

import re
import sys
import os
from pathlib import Path
from urllib.parse import unquote, urlparse

from common.paths import project_root


REQUIRED_DOCUMENTS = (
    "README.md",
    "CONTRIBUTING.md",
    "ARCHITECTURE.md",
    "TESTING.md",
    "QA_CHECKLIST.md",
    "PERFORMANCE.md",
    "TECH_DEBT.md",
    "SPRITE_AUDIT.md",
    "docs/ART_GUIDE.md",
    "docs/README.md",
    "docs/GAME_GUIDE.md",
    "docs/CONTROLS.md",
    "docs/DEVELOPMENT.md",
)
LINK_PATTERN = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


# Возвращает авторские Markdown-файлы, не обходя внешние зависимости и временные сборки wiki.
def markdown_files(root: Path) -> list[Path]:
    ignored_parts = {".git", ".godot", "tools", "node_modules"}
    result: list[Path] = []
    for current, directories, filenames in os.walk(root):
        relative = Path(current).relative_to(root)
        generated = {"dist", ".cache", ".runtime"} if relative == Path("wiki") else set()
        directories[:] = [name for name in directories if name not in ignored_parts | generated]
        result.extend(Path(current) / name for name in filenames if name.endswith(".md"))
    return sorted(result)


# Отделяет путь локальной ссылки от якоря, query-параметров и необязательного заголовка Markdown.
def local_target(raw_target: str) -> str | None:
    target = raw_target.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    else:
        target = target.split(maxsplit=1)[0]
    parsed = urlparse(target)
    if parsed.scheme or parsed.netloc or target.startswith(("#", "mailto:")):
        return None
    return unquote(parsed.path)


# Собирает понятные ошибки для отсутствующих обязательных файлов и несуществующих локальных целей.
def validate(root: Path) -> list[str]:
    errors: list[str] = []
    for relative in REQUIRED_DOCUMENTS:
        if not (root / relative).is_file():
            errors.append(f"отсутствует обязательный документ: {relative}")
    for document in markdown_files(root):
        content = document.read_text(encoding="utf-8")
        for match in LINK_PATTERN.finditer(content):
            target = local_target(match.group(1))
            if not target:
                continue
            resolved = (document.parent / target).resolve()
            if not resolved.exists():
                line = content.count("\n", 0, match.start()) + 1
                relative_document = document.relative_to(root)
                errors.append(f"{relative_document}:{line}: ссылка ведёт в отсутствующий путь {target}")
    return errors


# Запускает проверку из корня репозитория и возвращает ненулевой код при любой ошибке.
def main() -> int:
    root = project_root(__file__)
    errors = validate(root)
    if errors:
        for error in errors:
            print(f"DOCUMENTATION ERROR: {error}", file=sys.stderr)
        return 1
    print("DOCUMENTATION: обязательные файлы и локальные ссылки корректны")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
