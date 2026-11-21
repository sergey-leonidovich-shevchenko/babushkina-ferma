"""Читает неизменённый CI ZIP через отдельную временную папку, не импортируя PNG в Godot."""

from __future__ import annotations

import argparse
import json
import shutil
import stat
import tempfile
import zipfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path, PurePosixPath

from tools.qa.world.weather import contract as c
from tools.qa.world.weather.verify import verify


@contextmanager
def unpack(archive: Path) -> Iterator[Path]:
    """Распаковывает только в новую свою папку; traversal, дубликаты и symlink дают отказ."""
    c.need(archive.is_file() and not archive.is_symlink(), "ordinary ZIP required")
    with tempfile.TemporaryDirectory(prefix="vweather-001-read-") as directory:
        root = Path(directory).resolve()
        with zipfile.ZipFile(archive) as bundle:
            entries = bundle.infolist()
            names = [entry.filename for entry in entries]
            c.need(len(names) == len(set(names)), "duplicate archive entry")
            sources = []
            for entry in entries:
                path = PurePosixPath(entry.filename)
                c.need(
                    not path.is_absolute()
                    and ".." not in path.parts
                    and "\\" not in entry.filename,
                    "unsafe archive path",
                )
                mode = stat.S_IFMT(entry.external_attr >> 16)
                c.need(mode in (0, stat.S_IFREG, stat.S_IFDIR), "symlink or special archive entry")
                if not entry.is_dir() and path.name == "source.json":
                    sources.append(path)
                target = root.joinpath(*path.parts)
                c.need(target.is_relative_to(root), "archive escaped output")
                if entry.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with bundle.open(entry) as source, target.open("xb") as output:
                        shutil.copyfileobj(source, output)
            c.need(len(sources) == 1, "one native source manifest required")
        yield root.joinpath(*sources[0].parent.parts)


def main() -> None:
    """Применяет тот же semantic verifier к оригинальному архиву, сохраняя его байты."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--expected-head")
    parser.add_argument("--check-current-candidate", action="store_true")
    args = parser.parse_args()
    with unpack(args.archive) as folder:
        result = verify(folder, args.expected_head, args.check_current_candidate)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
