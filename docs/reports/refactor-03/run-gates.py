"""Пишет отдельную серию обязательных gates для каждого тематического кандидата REFACTOR-03."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess


def main():
    """Исполняет прежние команды последовательно, сохраняя точные ошибки и свежие headless-выходы."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    root = next(parent for parent in Path(__file__).resolve().parents
                if (parent / "project.godot").is_file() and (parent / "VERSION").is_file())
    output = arguments.output.resolve()
    if not output.is_relative_to(root / "docs/reports/refactor-03") or output.exists():
        parser.error("нужен новый каталог внутри отчёта03")
    output.mkdir()
    version = (root / "VERSION").read_text().strip()
    environment = dict(os.environ, FARM_REDRAW_TEST_OUTPUT=str(output / "headless"))
    records = []
    for name, command, timeout in [
        ("architecture", ["tools/check_architecture.sh"], 2400),
        ("game", ["./run_tests.sh"], 1800),
        ("wiki", ["pnpm", "--dir", "wiki", "check"], 900),
    ]:
        record = {"gate": name, "command": command, "version": version,
                  "started_at": datetime.now(timezone.utc).isoformat()}
        with (output / (name + ".txt")).open("x") as stream:
            try:
                result = subprocess.run(command, cwd=root, env=environment, stdout=stream,
                                        stderr=subprocess.STDOUT, timeout=timeout, check=False)
                record["exit"] = result.returncode
            except subprocess.TimeoutExpired:
                record.update(exit=124, failure="timeout; partial raw retained")
        record["finished_at"] = datetime.now(timezone.utc).isoformat()
        records.append(record)
        (output / "gate-exits.json").write_text(json.dumps(records, indent=2) + "\n")
        print(json.dumps(record), flush=True)
        if record["exit"]:
            raise SystemExit(record["exit"])


if __name__ == "__main__":
    main()
