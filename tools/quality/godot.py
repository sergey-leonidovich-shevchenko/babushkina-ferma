"""Проверяет семантику Godot на собственной внешней копии с настоящими зависимостями."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path, PurePosixPath

from tools.quality.process import run
from tools.quality.selection import git_paths, sha

WARNINGS = (
    "untyped_declaration",
    "unsafe_call_argument",
    "unsafe_cast",
    "unsafe_method_access",
    "unsafe_property_access",
    "unsafe_void_return",
)
IGNORE = "@warning_ignore_start(" + ", ".join('"' + name + '"' for name in WARNINGS) + ")\n"


def configuration(project: Path) -> None:
    """Загружает строгие предупреждения при старте только своего изолированного проекта."""
    if (project / ".git").exists() or (
        (project / "VERSION").exists() and not (project / ".quality-owned-mirror").is_file()
    ):
        raise ValueError("semantic settings require an isolated copy, not a source checkout")
    settings = (
        '[application]\nconfig/name="REFACTOR-07 ' + project.name + '"\n'
        "config/use_custom_user_dir=false\n[debug]\ngdscript/warnings/enable=true\n"
        'gdscript/warnings/directory_rules={"res://":1}\n'
    )
    settings += "".join("gdscript/warnings/" + name + "=2\n" for name in WARNINGS)
    (project / "override.cfg").write_text(settings)


def mirror(root: Path, destination: Path, files: list[str], legacy: dict[str, str]) -> None:
    """Копирует ресурсы во внешнюю пустую папку, не связывая изменяемые файлы с исходниками."""
    if (
        destination.is_symlink()
        or destination.resolve().is_relative_to(root.resolve())
        or not destination.is_dir()
        or any(destination.iterdir())
    ):
        raise ValueError("semantic mirror requires an empty external directory")
    if any(
        PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts for name in files
    ):
        raise ValueError("non-canonical semantic input")
    names = set(git_paths(root)) | set(files) | {"project.godot", "main.tscn"}
    pending = [
        name
        for name in names
        if name in {"project.godot", "main.tscn"}
        or name.startswith(("assets/", "scripts/", "tests/", "tools/"))
        and Path(name).suffix != ".py"
        or name in files
    ]
    copied: set[str] = set()
    while pending:
        name = pending.pop()
        if PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts:
            raise ValueError("non-canonical semantic input: " + name)
        if name in copied:
            continue
        copied.add(name)
        source = root / name
        if source.is_symlink() or not source.resolve().is_relative_to(root.resolve()):
            raise ValueError("unsafe semantic input: " + name)
        if not source.is_file():
            continue
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.suffix == ".gd":
            content = source.read_text()
            # Исключение относится только к новым предупреждениям неизменённых старых зависимостей.
            # Семантические ошибки и прежние предупреждения проверяются во всех файлах.
            if name not in files and sha(source) == legacy.get(name):
                content = IGNORE + content
            target.write_text(content)
            pending.extend(
                match
                for match in re.findall(r"""["']res://([^"'\n]+)["']""", content)
                if (root / match).is_file()
            )
        else:
            shutil.copyfile(source, target)
    (destination / ".quality-owned-mirror").write_text("REFACTOR-07 isolated semantic mirror\n")
    configuration(destination)


def analyze_project(project: Path, files: list[str], engine: str) -> int:
    """После свежего импорта проверяет файлы и считает ошибки журнала отказом даже при коде0."""
    configuration(project)
    if run(
        [
            engine,
            "--headless",
            "--path",
            str(project),
            "--log-file",
            str(project / "quality-import.log"),
            "--editor",
            "--quit",
        ],
        project,
        180,
    ):
        return 1
    return sum(
        run(
            [
                engine,
                "--headless",
                "--path",
                str(project),
                "--log-file",
                str(project / "quality-check.log"),
                "--check-only",
                "--script",
                "res://" + name,
            ],
            project,
            90,
        )
        for name in files
    )


def analyze(root: Path, files: list[str], legacy: dict[str, str]) -> int:
    """Проверяет одноразовую копию: даже check-only может выполнять статическую инициализацию."""
    engine = os.environ.get("FARM_GODOT_BIN")
    if not engine:
        raise ValueError("FARM_GODOT_BIN must name pinned Godot 4.7.1")
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.1.stable.official."):
        raise ValueError("semantic analyzer requires Godot 4.7.1 official: " + version)
    with tempfile.TemporaryDirectory(prefix="farm quality Godot ") as temporary:
        project = Path(temporary)
        mirror(root, project, files, legacy)
        return analyze_project(project, files, engine)
