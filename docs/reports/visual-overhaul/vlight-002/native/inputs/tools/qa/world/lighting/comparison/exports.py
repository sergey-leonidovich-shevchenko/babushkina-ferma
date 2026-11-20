"""Проверяет каждый экспортированный runtime/asset blob по фактическому Git tree."""

from __future__ import annotations

import hashlib
from pathlib import Path

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison import contract


def expected_blobs() -> dict[str, str]:
    """Получает имена/oid из принятой истории; кроме двух overlay замен не допускает."""
    raw = shared.git(
        "ls-tree",
        "-rz",
        contract.BASE,
        "--",
        "scripts",
        "assets/game",
        "main.tscn",
        "project.godot",
        "VERSION",
    )
    result = {}
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        mode, kind, oid = metadata.decode().split()
        if kind != "blob" or mode not in ["100644", "100755"]:
            raise ValueError("unexpected production tree entry")
        name = path.decode()
        if name in contract.OVERLAYS:
            changed = contract.instrument(name, shared.git("show", contract.BASE + ":" + name))
            oid = blob_id(changed)
        result[name] = oid
    return result


def blob_id(raw: bytes) -> str:
    """Git blob oid включает тип и длину, а не только hash содержимого."""
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def check(project: Path) -> dict[str, str]:
    """До/после native сверяет реальные байты всех source и game assets экспортированной копии."""
    expected = expected_blobs()
    for name, oid in expected.items():
        path = project / name
        if path.is_symlink() or not path.is_file() or blob_id(path.read_bytes()) != oid:
            raise ValueError("exported production input differs: " + name)
    return expected
