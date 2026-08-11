#!/usr/bin/env python3
"""Повышает SemVer приложения и синхронизирует Godot и macOS metadata."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "VERSION"
PROJECT_FILE = ROOT / "project.godot"
PLIST_FILE = ROOT / "Бабушкина ферма.app" / "Contents" / "Info.plist"
SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def parse_version(value: str) -> tuple[int, int, int]:
    """Проверяет и разбирает строгую версию major.minor.patch."""
    match = SEMVER.fullmatch(value.strip())
    if match is None:
        raise SystemExit(f"Некорректная версия SemVer: {value!r}")
    return tuple(int(part) for part in match.groups())


def head_version() -> str | None:
    """Читает версию предыдущего коммита либо сообщает о первом versioned-коммите."""
    result = subprocess.run(
        ["git", "show", "HEAD:VERSION"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def replace_or_insert_project_version(source: str, version: str) -> str:
    """Обновляет версию Godot или добавляет её рядом с названием приложения."""
    replacement = f'config/version="{version}"'
    if re.search(r'^config/version="[^"]*"$', source, re.MULTILINE):
        return re.sub(r'^config/version="[^"]*"$', replacement, source, flags=re.MULTILINE)
    return re.sub(r'^(config/name="[^"]*"\n)', rf'\1{replacement}\n', source, count=1, flags=re.MULTILINE)


def replace_or_insert_plist_version(source: str, version: str) -> str:
    """Синхронизирует пользовательскую и сборочную версии macOS-лаунчера."""
    short_pattern = r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(</string>)'
    source = re.sub(short_pattern, rf'\g<1>{version}\g<2>', source, count=1)
    build_pattern = r'(<key>CFBundleVersion</key>\s*<string>)[^<]*(</string>)'
    if re.search(build_pattern, source):
        return re.sub(build_pattern, rf'\g<1>{version}\g<2>', source, count=1)
    anchor = f"\t<key>CFBundleShortVersionString</key>\n\t<string>{version}</string>\n"
    return source.replace(anchor, anchor + f"\t<key>CFBundleVersion</key>\n\t<string>{version}</string>\n", 1)


def synchronized(version: str) -> bool:
    """Проверяет совпадение источника версии с двумя сборочными конфигурациями."""
    project = PROJECT_FILE.read_text(encoding="utf-8")
    plist = PLIST_FILE.read_text(encoding="utf-8")
    return f'config/version="{version}"' in project and plist.count(f"<string>{version}</string>") >= 2


def sync_files(version: str) -> None:
    """Записывает одну версию во все платформенные metadata проекта."""
    VERSION_FILE.write_text(version + "\n", encoding="utf-8")
    project = replace_or_insert_project_version(PROJECT_FILE.read_text(encoding="utf-8"), version)
    PROJECT_FILE.write_text(project, encoding="utf-8")
    plist = replace_or_insert_plist_version(PLIST_FILE.read_text(encoding="utf-8"), version)
    PLIST_FILE.write_text(plist, encoding="utf-8")


def next_version(requested: str | None) -> tuple[str | None, str]:
    """Выбирает ручную версию либо автоматически повышает patch относительно HEAD."""
    previous = head_version()
    current = VERSION_FILE.read_text(encoding="utf-8").strip() if VERSION_FILE.exists() else "0.0.1"
    parse_version(current)
    if requested is not None:
        parse_version(requested)
        if previous is not None and parse_version(requested) <= parse_version(previous):
            raise SystemExit(f"Новая версия {requested} должна быть выше {previous}")
        return previous, requested
    if previous is None:
        if current != "0.0.1":
            raise SystemExit("Первая версия проекта должна быть 0.0.1")
        return None, current
    if current != previous:
        if parse_version(current) <= parse_version(previous):
            raise SystemExit(f"Версия {current} должна быть выше HEAD {previous}")
        return previous, current
    major, minor, patch = parse_version(previous)
    return previous, f"{major}.{minor}.{patch + 1}"


def main() -> None:
    """Выполняет проверку либо повышение с необязательным добавлением файлов в индекс."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="только проверить синхронизацию")
    parser.add_argument("--stage", action="store_true", help="добавить metadata в Git index")
    parser.add_argument("--set", dest="requested", help="задать следующую версию вручную")
    args = parser.parse_args()
    if args.check:
        version = VERSION_FILE.read_text(encoding="utf-8").strip()
        parse_version(version)
        if not synchronized(version):
            raise SystemExit("VERSION, project.godot и Info.plist рассинхронизированы")
        print(f"VERSION: {version} synchronized")
        return
    previous, version = next_version(args.requested)
    sync_files(version)
    if args.stage:
        subprocess.run(
            ["git", "add", "VERSION", "project.godot", "Бабушкина ферма.app/Contents/Info.plist"],
            cwd=ROOT,
            check=True,
        )
    print(f"VERSION: {previous or 'initial'} -> {version}")


if __name__ == "__main__":
    main()
