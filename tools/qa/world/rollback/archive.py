"""Проверяет оригинальный CI ZIP без изменения его байтов и без импорта PNG в Godot."""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from tools.qa.world.rollback import contract as c
from tools.qa.world.rollback.verify import verify
from tools.qa.world.weather.archive import unpack
from tools.qa.world.weather.verify import Evidence


@contextmanager
def archive_input(path: Path) -> Iterator[Path]:
    """Собирает исходные ZIP-байты из проверенных частей без изменения или перепаковки архива."""
    if path.suffix != ".json":
        yield path
        return
    store = Evidence(path.parent)
    manifest = store.document(path.name)
    c.need(
        manifest["schema"] == 1
        and manifest["format"] == "zip-parts-v1"
        and manifest["task"] == "VCOMPAT-010",
        "wrong ZIP parts manifest",
    )
    c.need(
        type(manifest["bytes"]) is int
        and 0 < manifest["bytes"] <= 512 * 1024 * 1024
        and 1 <= len(manifest["parts"]) <= 8,
        "invalid ZIP parts size/count",
    )
    with tempfile.TemporaryDirectory(prefix="vcompat-010-parts-") as directory:
        original = Path(directory) / "original.zip"
        digest = hashlib.sha256()
        total = 0
        with original.open("xb") as output:
            for index, part in enumerate(manifest["parts"], 1):
                c.need(part["file"] == f"artifact.zip.{index:03}", "ZIP parts order/path differs")
                raw = store.read(part["file"])
                c.need(
                    type(part["bytes"]) is int
                    and len(raw) == part["bytes"]
                    and c.digest(raw) == part["sha256"],
                    "ZIP part bytes differ",
                )
                output.write(raw)
                digest.update(raw)
                total += len(raw)
                del raw
        c.need(
            total == manifest["bytes"] and digest.hexdigest() == manifest["sha256"],
            "original ZIP digest/size differs",
        )
        yield original


def main() -> None:
    """Использует общий безопасный unpack и именно semantic verifier VCOMPAT-010."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    with archive_input(args.archive) as original, unpack(original) as folder:
        result = verify(folder, args.expected_head, args.check_current_candidate)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
