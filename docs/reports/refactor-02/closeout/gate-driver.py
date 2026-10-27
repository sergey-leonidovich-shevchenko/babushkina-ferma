"""Record fresh accounting gates without overwriting accepted implementation evidence."""

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess

root = Path.cwd()
output = root / "docs/reports/refactor-02/closeout/final"
output.mkdir()
assert (root / "VERSION").read_text().strip() == "0.0.355"
assert not (output / "gate-exits.json").exists()
environment = os.environ.copy()
environment["FARM_REDRAW_TEST_OUTPUT"] = str(output / "headless")
records = []
for name, command, timeout in [
    ("architecture", ["tools/check_architecture.sh"], 2400),
    ("game", ["./run_tests.sh"], 1800),
    ("wiki", ["pnpm", "--dir", "wiki", "check"], 900),
]:
    target = output / (name + ".txt")
    assert not target.exists()
    record = {
        "gate": name,
        "command": command,
        "version": "0.0.355",
        "environment": "approved normal engine journal access; test source and assertions unchanged",
        "started_at": datetime.now(timezone.utc).isoformat(),
    }
    with target.open("x") as log:
        try:
            result = subprocess.run(
                command, cwd=root, env=environment, stdout=log,
                stderr=subprocess.STDOUT, timeout=timeout, check=False,
            )
            record["exit"] = result.returncode
        except subprocess.TimeoutExpired:
            record["exit"] = 124
            record["failure"] = "timeout; partial raw preserved"
    record["finished_at"] = datetime.now(timezone.utc).isoformat()
    records.append(record)
    (output / "gate-exits.json").write_text(json.dumps(records, indent=2) + "\n")
    print(json.dumps(record), flush=True)
    if record["exit"]:
        raise SystemExit(record["exit"])
