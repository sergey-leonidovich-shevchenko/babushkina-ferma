"""Lossless packaging of the completed campaign; SHA covers both original bytes and gzip."""

import gzip
import hashlib
import json
from pathlib import Path
import sys


def digest(data):
    return hashlib.sha256(data).hexdigest()


def pack(folder):
    index = []
    for path in sorted(folder.iterdir()):
        if not path.is_dir():
            continue
        for name in [
            "stdout.txt",
            "observer.json",
            "native-sample.txt",
            "frame-analysis.csv",
        ]:
            source = path / name
            raw = source.read_bytes()
            zipped = source.with_suffix(source.suffix + ".gz")
            if zipped.exists():
                raise ValueError("fresh packaging required")
            packed = gzip.compress(raw, mtime=0)
            if gzip.decompress(packed) != raw:
                raise ValueError("round-trip failed")
            zipped.write_bytes(packed)
            index.append(
                {
                    "path": str(zipped.relative_to(folder)),
                    "original_path": str(source.relative_to(folder)),
                    "raw_sha256": digest(raw),
                    "gzip_sha256": digest(packed),
                    "raw_bytes": len(raw),
                    "gzip_bytes": len(packed),
                }
            )
            source.unlink()
    (folder / "archive.json").write_text(json.dumps(index, indent=2) + "\n")


def verify(folder):
    index = json.loads((folder / "archive.json").read_text())
    for row in index:
        raw_gz = (folder / row["path"]).read_bytes()
        raw = gzip.decompress(raw_gz)
        if (
            digest(raw_gz) != row["gzip_sha256"]
            or digest(raw) != row["raw_sha256"]
            or len(raw) != row["raw_bytes"]
        ):
            raise ValueError("archive changed: " + row["path"])
        if row["original_path"].endswith("/stdout.txt"):
            ctx = json.loads(
                (folder / Path(row["path"]).parent / "context.json").read_text()
            )
            if ctx["stdout_sha256"] != digest(raw):
                raise ValueError("context raw SHA differs")
    return {
        "files": len(index),
        "raw_bytes": sum(r["raw_bytes"] for r in index),
        "gzip_bytes": sum(r["gzip_bytes"] for r in index),
        "all_round_trips_and_sha_match": True,
    }


if __name__ == "__main__":
    folder = Path(sys.argv[1])
    if "--pack" in sys.argv:
        pack(folder)
    print(json.dumps(verify(folder)))
