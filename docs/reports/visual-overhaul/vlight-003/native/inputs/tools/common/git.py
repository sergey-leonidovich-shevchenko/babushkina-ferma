"""Изолирует Git-команды, явно адресованные отдельному репозиторию."""

from __future__ import annotations

import os
from collections.abc import Mapping

GitTreeEntry = tuple[bytes, bytes, bytes]


def git_environment(environment: Mapping[str, str] | None = None) -> dict[str, str]:
    """Убирает hook/index/config overrides, не изменяя окружение родительского процесса."""
    source = os.environ if environment is None else environment
    return {name: value for name, value in source.items() if not name.startswith("GIT_")}


def parse_git_tree(output: bytes) -> dict[str, GitTreeEntry]:
    """Читает режим, тип и идентификатор каждой записи из вывода git ls-tree -z."""
    entries: dict[str, GitTreeEntry] = {}
    for row in output.split(b"\0"):
        if not row:
            continue
        metadata, name = row.split(b"\t", 1)
        mode, kind, object_id = metadata.split()
        entries[os.fsdecode(name)] = (mode, kind, object_id)
    return entries


def regular_git_blob(entry: GitTreeEntry) -> bool:
    """Git хранит симлинки как blobs, поэтому одного типа объекта недостаточно."""
    mode, kind, _ = entry
    return kind == b"blob" and mode in (b"100644", b"100755")
