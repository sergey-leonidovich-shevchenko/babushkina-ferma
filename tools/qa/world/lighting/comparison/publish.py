"""Упаковывает только проверенное native-сырьё, сохраняя точные payload/SHA и raw-источник."""

from __future__ import annotations

import argparse
import json
import shutil
import zipfile
from pathlib import Path

from tools.qa.world.lighting import contract as shared
from tools.qa.world.lighting.comparison.verify import REPORT, verify


def publish(source: Path, destination: Path) -> dict[str, object]:
    """Отказывает до записи при неполной матрице или существующем целевом каталоге."""
    if destination.exists() or destination.is_symlink():
        raise ValueError("fresh native publication directory required")
    original = verify(source, current=True)
    document = json.loads((source / "source.json").read_bytes())
    destination.mkdir()
    for name in ["source.json", "exported-blobs.json", *document["setup_artifacts"]]:
        shutil.copyfile(source / name, destination / name)
    for name in ["inputs", "overlays"]:
        shutil.copytree(source / name, destination / name)
    archives = {}
    for key, run in document["runs"].items():
        path = destination / (key + ".zip")
        with zipfile.ZipFile(
            path, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9
        ) as archive:
            for name in sorted(run["artifacts"]):
                info = zipfile.ZipInfo(name)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                raw = (source / key / name).read_bytes()
                if shared.digest(raw) != run["artifacts"][name]:
                    raise ValueError("raw artifact changed during publication")
                archive.writestr(info, raw, compresslevel=9)
        archives[key] = {"bytes": path.stat().st_size, "sha256": shared.digest(path.read_bytes())}
    packed = verify(destination, current=True)
    if packed != original:
        raise ValueError("raw and packed verifier results differ")
    return {
        "raw_and_packed_equal": True,
        "source_json_sha256": shared.digest((source / "source.json").read_bytes()),
        "archives": archives,
    }


def main() -> None:
    """Публикация явная, отдельная от съёмки и обычного чтения доказательств."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=REPORT)
    args = parser.parse_args()
    print(json.dumps(publish(args.input, args.output), indent=2))


if __name__ == "__main__":
    main()
