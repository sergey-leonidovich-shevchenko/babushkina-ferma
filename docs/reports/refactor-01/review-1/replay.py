"""Воспроизводит review1 полным прежним reader, сохраняя опубликованный пакет неизменным."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import tempfile


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "instrumentation"))
import audit
from git_snapshot import project_root, sha256_file


def replay() -> dict:
    """Собирает полный временный пакет из прежних данных и двух новых metadata-файлов."""
    root = project_root(HERE)
    original = HERE.parent / "integration-1" / "snapshot"
    revised = HERE / "reproduction"
    old_packet = json.loads((original / "packet.json").read_text())
    packet = json.loads((revised / "packet.json").read_text())
    if (packet["baseline_commit"] != old_packet["baseline_commit"]
            or set(packet["files"]) != set(old_packet["files"])):
        raise ValueError("review packet must preserve baseline and file inventory")
    changed = {name for name in packet["files"] if packet["files"][name] != old_packet["files"][name]}
    if changed != {"inventory.json"}:
        raise ValueError("review changes only generator hashes in inventory metadata")
    old_inventory = json.loads((original / "inventory.json").read_text())
    inventory = json.loads((revised / "inventory.json").read_text())
    old_generators = old_inventory.pop("generator_sha256")
    generators = inventory.pop("generator_sha256")
    if old_inventory != inventory or set(old_generators) != set(generators):
        raise ValueError("review inventory data differs")
    if {name for name in generators if generators[name] != old_generators[name]} != {"mapping.py", "test_audit.py"}:
        raise ValueError("unexpected generator changes")
    # Имена проверяются до чтения/копирования; output целиком принадлежит этому опыту.
    with tempfile.TemporaryDirectory(prefix="farm-refactor01-review1-") as temp:
        output = Path(temp) / "packet"
        output.mkdir()
        for name, checksum in packet["files"].items():
            if Path(name).name != name or name in {"", ".", ".."}:
                raise ValueError("unsafe review packet filename")
            source = (revised if name in changed else original) / name
            if source.is_symlink() or not source.is_file() or sha256_file(source) != checksum:
                raise ValueError("review packet source SHA: " + name)
            shutil.copyfile(source, output / name)
        shutil.copyfile(revised / "packet.json", output / "packet.json")
        # Штатный reader не ослаблен: заново читает весь Git и сравнивает каждый байт.
        return audit.check(root, output, HERE.parent / "integration-1" / "migration-plan.json")


if __name__ == "__main__":
    print(json.dumps(replay(), ensure_ascii=False, indent=2))
