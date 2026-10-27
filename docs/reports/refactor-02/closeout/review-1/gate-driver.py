"""Record fresh post-review gates without changing the rejected head's evidence."""

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess

root = Path.cwd()
output = root / "docs/reports/refactor-02/closeout/review-1/final"
assert (root / "VERSION").read_text().strip() == "0.0.356"
output.mkdir()
environment = os.environ.copy()
environment["FARM_REDRAW_TEST_OUTPUT"] = str(output / "headless")
records = []
for name, command, timeout in [
    ("architecture", ["tools/check_architecture.sh"], 2400),
    ("game", ["./run_tests.sh"], 1800),
    ("wiki", ["pnpm", "--dir", "wiki", "check"], 900),
]:
    record = {
        "gate": name, "command": command, "version": "0.0.356",
        "environment": "normal approved engine journal access; same mandatory checks",
        "started_at": datetime.now(timezone.utc).isoformat(),
    }
    with (output / (name + ".txt")).open("x") as log:
        try:
            result = subprocess.run(command, cwd=root, env=environment, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=timeout, check=False)
            record["exit"] = result.returncode
        except subprocess.TimeoutExpired:
            record.update(exit=124, failure="timeout; partial raw preserved")
    record["finished_at"] = datetime.now(timezone.utc).isoformat()
    records.append(record)
    (output / "gate-exits.json").write_text(json.dumps(records, indent=2) + "\n")
    print(json.dumps(record), flush=True)
    if record["exit"]:
        raise SystemExit(record["exit"])
