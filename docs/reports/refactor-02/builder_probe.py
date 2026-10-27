"""Сравнивает реальные writer CLI с принятой базой, записывая данные только в disposable проекты."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

BASE = "d603de591082f19b1a9964eefd8f1d0671d38839"
ART = Path("docs/concepts/visual-polish-2026-10-13/v1")
OUTPUTS = [ART / "backlog.json", *[Path("docs/epics/optimization-2026-10") / name
                                    for name in ("checks.json", "checks.csv", "index.html")]]


def probe(root: Path, moved: bool) -> dict:
    """Одинаковые входные данные проходят старый прямой CLI и новый launcher из другой cwd."""
    environment = {name: value for name, value in os.environ.items() if not name.startswith("GIT_")}
    results = []
    with tempfile.TemporaryDirectory(prefix="farm builder CLI parity ") as temporary:
        base = Path(temporary).resolve()
        for label in ("accepted-baseline", "candidate"):
            fixture = base / label
            (fixture / "tools").mkdir(parents=True)
            for name in ("project.godot", "VERSION"):
                shutil.copy2(root / name, fixture / name)
            audit = ART / "current/audit.json"
            (fixture / audit).parent.mkdir(parents=True)
            shutil.copy2(root / audit, fixture / audit)
            if label == "candidate":
                for name in ("run.py", "__init__.py"):
                    shutil.copy2(root / "tools" / name, fixture / "tools" / name)
                shutil.copytree(root / "tools/common", fixture / "tools/common",
                                ignore=shutil.ignore_patterns("__pycache__"))
                if moved:
                    (fixture / "tools/planning").mkdir()
                    shutil.copy2(root / "tools/planning/__init__.py", fixture / "tools/planning/__init__.py")
            commands = []
            for name in ("build_art_backlog", "build_optimization_matrix"):
                old = "tools/" + name + ".py"
                path = Path("tools/planning" if moved and label == "candidate" else "tools") / (name + ".py")
                source = (subprocess.check_output(["git", "-C", str(root), "show", BASE + ":" + old], env=environment)
                          if label == "accepted-baseline" else (root / path).read_bytes())
                (fixture / path).write_bytes(source)
                args = ([str(fixture / "tools/run.py"), ("planning." if moved else "") + name]
                        if label == "candidate" else [str(fixture / path)])
                result = subprocess.run([sys.executable, *args], cwd=base, env=environment,
                                        text=True, capture_output=True)
                commands.append({"command": args, "exit": result.returncode,
                                 "stdout": result.stdout, "stderr": result.stderr})
                if result.returncode:
                    raise RuntimeError(commands[-1])
            outputs = {str(name): hashlib.sha256((fixture / name).read_bytes()).hexdigest()
                       for name in OUTPUTS}
            matrix = json.loads((fixture / OUTPUTS[1]).read_text())
            assert len(matrix) == 320 and all(row["status"] == "PLANNED" for row in matrix)
            results.append({"variant": label, "commands": commands, "outputs": outputs})
    assert results[0]["outputs"] == results[1]["outputs"], results
    return {"accepted_base": BASE, "candidate_uses_moved_paths": moved,
            "same_input_sha256": hashlib.sha256((root / ART / "current/audit.json").read_bytes()).hexdigest(),
            "four_outputs_byte_identical": True, "matrix_planned_rows": 320,
            "production_plans_written": False, "results": results}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--moved", action="store_true")
    args = parser.parse_args()
    result = probe(args.root.resolve(), args.moved)
    with args.output.open("x", encoding="utf-8") as target:
        json.dump(result, target, ensure_ascii=False, indent=2)
        target.write("\n")
    print("BUILDER CLI: four exact outputs, 320 planned rows; production unchanged")
