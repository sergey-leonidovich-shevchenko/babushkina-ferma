"""Восстанавливает исходный Actions ZIP из точных частей, без extract или repack."""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path, PurePosixPath
from typing import Any

from tools.qa.world.lighting.quality import contract as c
from tools.qa.world.lighting.quality.verify import verify


@contextmanager
def materialize(manifest: Path) -> Iterator[Path]:
    """Читает только именованные соседние части; временный ZIP удаляется после reader."""
    c.need(
        not any(p.is_symlink() for p in (manifest, *manifest.parents)), "symlink archive manifest"
    )
    record = json.loads(manifest.read_bytes())
    c.need(record["schema"] == 1 and record["task"] == "VLIGHT-010", "wrong retained archive")
    parts = record["parts"]
    c.need(bool(parts) and len(parts) <= 16, "retained archive parts missing or excessive")
    names = [part["name"] for part in parts]
    c.need(len(names) == len(set(names)), "duplicate retained archive part")
    for name in names:
        key = PurePosixPath(name)
        c.need(
            not key.is_absolute()
            and key.as_posix() == name
            and len(key.parts) == 1
            and name not in ("", ".", "..")
            and "\\" not in name,
            "unsafe retained archive part",
        )
    with tempfile.TemporaryDirectory(prefix="farm original lighting ZIP ") as temporary:
        archive = Path(temporary).resolve() / "artifact.zip"
        whole = hashlib.sha256()
        total = 0
        with archive.open("xb") as output:
            for part in parts:
                path = manifest.parent / part["name"]
                c.need(path.is_file() and not path.is_symlink(), "missing/symlink archive part")
                c.need(
                    0 < path.stat().st_size == part["bytes"] <= 64 * 1024 * 1024,
                    "archive part size differs",
                )
                digest = hashlib.sha256()
                with path.open("rb") as stream:
                    while chunk := stream.read(128 * 1024):
                        digest.update(chunk)
                        whole.update(chunk)
                        total += len(chunk)
                        output.write(chunk)
                c.need(digest.hexdigest() == part["sha256"], "archive part SHA differs")
        c.need(
            total == record["bytes"] and whole.hexdigest() == record["sha256"],
            "original Actions ZIP SHA differs",
        )
        yield archive


def check(manifest: Path, expected_head: str, current: bool = False) -> dict[str, Any]:
    """Проверка восстановленного оригинала использует тот же полный native reader."""
    with materialize(manifest) as archive:
        return verify(archive, expected_head, current)


def main() -> None:
    """CLI не меняет части или manifest; expected SHA обязателен."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    try:
        result = check(args.manifest, args.expected_head, args.check_current_candidate)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(2, str(error) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
