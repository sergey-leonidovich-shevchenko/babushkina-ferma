"""Проверяет оригинальный CI ZIP без изменения его байтов и без импорта PNG в Godot."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from tools.qa.world.rollback.verify import verify
from tools.qa.world.weather.archive import unpack


def main() -> None:
    """Использует общий безопасный unpack и именно semantic verifier VCOMPAT-010."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    with unpack(args.archive) as folder:
        result = verify(folder, args.expected_head, args.check_current_candidate)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
