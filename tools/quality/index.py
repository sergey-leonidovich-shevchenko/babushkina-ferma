"""Не допускает проверку исправленной рабочей копии вместо ошибочного будущего коммита."""

from __future__ import annotations

import hashlib
import os
import stat
import subprocess
from pathlib import Path

from tools.common.git import git_environment
from tools.quality.selection import BASELINE, discover

POLICY_FILES = {
    BASELINE,
    ".githooks/pre-commit",
    ".gdlintrc",
    "pyproject.toml",
    "project.godot",
    "tools/quality/requirements.txt",
}


def relevant(name: str) -> bool:
    """Включает исходники до baseline-фильтра, а также влияющие на проверку правила."""
    return name in POLICY_FILES or (
        Path(name).suffix in {".py", ".gd"} and not name.startswith("docs/reports/")
    )


def environment() -> dict[str, str]:
    """Сохраняет намеренный index hook, изолируя остальные унаследованные Git-подмены."""
    result = git_environment()
    alternate = os.environ.get("GIT_INDEX_FILE")
    if alternate is not None:
        path = Path(alternate).absolute()
        if not alternate or not path.is_file() or path.is_symlink():
            raise ValueError("QUALITY INDEX: GIT_INDEX_FILE must name an existing regular index")
        result["GIT_INDEX_FILE"] = str(path)
    result["GIT_OPTIONAL_LOCKS"] = "0"
    return result


def read(root: Path, env: dict[str, str], *arguments: str, missing_head: bool = False) -> bytes:
    """Читает Git без обновления index и передаёт отказ как диагностируемую ошибку gate."""
    result = subprocess.run(
        ["git", "-C", str(root), *arguments], env=env, capture_output=True, check=False
    )
    if missing_head and result.returncode == 1:
        return b""
    if result.returncode:
        raise ValueError("QUALITY INDEX: " + os.fsdecode(result.stderr).strip())
    return result.stdout


def blob_hash(path: Path, algorithm: str) -> str:
    """Считает Git blob по сырым рабочим байтам, не записывая объект в репозиторий."""
    digest = hashlib.new(algorithm)
    digest.update(f"blob {path.stat().st_size}\0".encode())
    with path.open("rb") as source:
        for block in iter(lambda: source.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


def matching_sources(root: Path) -> list[str]:
    """Отказывает при разнице исходников/index; не прячет, не добавляет и не меняет файлы."""
    env = environment()
    entries: dict[str, tuple[str, str, str]] = {}
    conflicts: set[str] = set()
    for record in read(root, env, "ls-files", "--stage", "-z").split(b"\0"):
        if not record:
            continue
        metadata, raw_name = record.split(b"\t", 1)
        name = os.fsdecode(raw_name)
        mode, oid, stage = metadata.decode("ascii").split()
        if stage != "0":
            conflicts.add(name)
        entries[name] = (mode, oid, stage)
    algorithm = read(root, env, "rev-parse", "--show-object-format").decode().strip()
    head = read(root, env, "rev-parse", "--verify", "--quiet", "HEAD", missing_head=True)
    history = (
        {
            os.fsdecode(name)
            for name in read(
                root, env, "ls-tree", "-r", "--name-only", "-z", head.strip().decode()
            ).split(b"\0")
            if name
        }
        if head
        else set()
    )
    names = {
        name
        for name in set(entries) | history | set(discover(root)) | POLICY_FILES
        if relevant(name)
    }
    mismatches = []
    for name in sorted(names):
        path = root / name
        entry = entries.get(name)
        exists = path.exists() or path.is_symlink()
        if entry is None and not exists:
            continue
        parents = path.relative_to(root).parents
        regular = exists and not any((root / parent).is_symlink() for parent in parents)
        regular = regular and stat.S_ISREG(path.lstat().st_mode)
        if (
            name in conflicts
            or entry is None
            or entry[0] not in {"100644", "100755"}
            or not regular
            or blob_hash(path, algorithm) != entry[1]
        ):
            mismatches.append(name)
    if mismatches:
        raise ValueError(
            "QUALITY INDEX: staged and working sources/rules differ:\n  "
            + "\n  ".join(mismatches)
            + "\nStage the intended source/rule bytes (or restore them), then retry. "
            "No index or working files were changed."
        )
    return sorted(name for name in names if name in entries and name not in POLICY_FILES)
