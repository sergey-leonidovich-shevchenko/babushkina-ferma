"""Встраивает исходные PNG в переносимый просмотр без изменения пикселей."""

from pathlib import Path
import argparse
import base64
import hashlib
import json


def main():
    """Собирает фрагмент из шаблона и при необходимости копирует его в каталог беседы."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inline-output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    repo = root.parents[3]
    meta = json.loads((root / "source.json").read_text())
    source = root / meta["source"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == meta["sha256"]

    def encoded(path):
        """Упаковывает файл без преобразования изображения."""
        return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")

    assets = {
        "frames": meta["frames"],
        "sourceHeight": max(frame["rect"][3] for frame in meta["frames"]),
        "floatPixels": meta["float_pixels"],
        "atlas": encoded(source),
        "wood": encoded(repo / "assets/game/items/catalog/wood.png"),
        "grass": encoded(repo / "assets/game/tiles/grass.png"),
    }
    template = (root / "preview-fragment.template.html").read_text()
    fragment = template.replace("__MARKER_PREVIEW_ASSETS__", json.dumps(assets, separators=(",", ":")))
    assert len(fragment.encode()) < 1_000_000
    assert "\\\"" not in fragment and "\\n" not in fragment
    (root / "preview-fragment.html").write_text(fragment)
    if args.inline_output:
        args.inline_output.parent.mkdir(parents=True, exist_ok=True)
        args.inline_output.write_text(fragment)
    print(f"MARKER PREVIEW: {len(fragment.encode())} bytes, six source frames")


if __name__ == "__main__":
    main()
