"""Replay the old packet's bytes, mapping only the corrected source to its exact archive."""

import hashlib
import json
from pathlib import Path

root = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
report = root / "docs/reports/refactor-02/closeout/review-1"
packet = json.loads((report / "previous-packet.json").read_text())
for row in packet["files"]:
    source = report / "scope-before.py.txt" if row["path"] == packet["source_to_fix"] else root / row["path"]
    data = source.read_bytes()
    assert len(data) == row["bytes"], source
    assert hashlib.sha256(data).hexdigest() == row["sha256"], source
baseline = json.loads((root / "docs/reports/refactor-02/closeout/baseline.json").read_text())
for row in baseline["files"]:
    data = (root / row["path"]).read_bytes()
    assert len(data) == row["bytes"], row["path"]
    assert hashlib.sha256(data).hexdigest() == row["sha256"], row["path"]
print(json.dumps({
    "previous_head": packet["head"], "previous_files": len(packet["files"]),
    "source_exception": packet["source_to_fix"], "old_source_exact_archive": True,
    "other_previous_files_byte_unchanged": len(packet["files"]) - 1,
    "implementation_UID_plan_files_unchanged": len(baseline["files"]),
    "groups": baseline["counts"],
}, indent=2))
