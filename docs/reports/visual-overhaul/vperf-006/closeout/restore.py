"""Restore the exact files from a deduplicated VPERF-006 capture bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from zipfile import BadZipFile, ZipFile

OUTER_FILES = {"collection.txt", "summary.json", "window-manager.txt", "evidence/source.json"}


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def restore(bundle: Path, receipt: Path, output: Path) -> None:
    metadata = json.loads(receipt.read_bytes())
    expected_bundle = metadata["bundle"]
    with bundle.open("rb") as stream:
        bundle_hash = hashlib.file_digest(stream, "sha256").hexdigest()
    require(
        bundle.stat().st_size == expected_bundle["bytes"]
        and bundle_hash == expected_bundle["sha256"],
        "capture bundle differs from the checked-in receipt",
    )
    with ZipFile(bundle) as stored:
        index = json.loads(stored.read("files.json"))
        payloads: dict[str, bytes] = {}
        expected_entries = {"files.json"}
        for name, row in index.items():
            path = PurePosixPath(name)
            require(
                name == str(path)
                and ".." not in path.parts
                and "\\" not in name
                and (name in OUTER_FILES or name.startswith("evidence/")),
                f"invalid capture path {name}",
            )
            digest = row["sha256"]
            size = row["size"]
            require(
                re.fullmatch(r"[a-f0-9]{64}", digest) is not None
                and type(size) is int
                and size >= 0,
                f"invalid capture metadata for {name}",
            )
            entry = f"blobs/{digest}"
            expected_entries.add(entry)
            if digest not in payloads:
                require(entry in stored.NameToInfo, f"missing capture blob {digest}")
                require(
                    stored.getinfo(entry).file_size == size, f"wrong size of capture blob {digest}"
                )
                data = stored.read(entry)
                require(
                    hashlib.sha256(data).hexdigest() == digest, f"changed capture blob {digest}"
                )
                payloads[digest] = data
            require(len(payloads[digest]) == size, f"inconsistent size of capture blob {digest}")
        require(
            set(stored.namelist()) == expected_entries
            and len(stored.namelist()) == len(expected_entries),
            "unexpected or repeated capture entries",
        )
        require(
            type(expected_bundle["unique_blobs"]) is int
            and len(payloads) == expected_bundle["unique_blobs"],
            "capture blob count differs from the checked-in receipt",
        )
    source = json.loads(payloads[index["evidence/source.json"]["sha256"]])
    source_files = source["files"]
    require(
        source["complete"] is True
        and source["task"] == "VPERF-006"
        and source["head"] == metadata["head"]
        and source["tree"] == metadata["tree"]
        and source["runner_id"] == str(metadata["run"])
        and source["runner_attempt"] == str(metadata["attempt"]),
        "capture producer differs from the recorded GitHub run",
    )
    require(
        set(index) == OUTER_FILES | {f"evidence/{name}" for name in source_files}
        and len(index) == expected_bundle["files"]
        and all(
            index[f"evidence/{name}"]["sha256"] == value for name, value in source_files.items()
        ),
        "capture file inventory differs from the original source.json",
    )
    output.mkdir()
    for name, row in index.items():
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payloads[row["sha256"]])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    try:
        restore(**vars(parser.parse_args()))
    except (BadZipFile, KeyError, OSError, TypeError, ValueError) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
