"""Собирает переносимый макет из подготовленных кадров и существующих игровых текстур."""

from pathlib import Path
import argparse
import base64
import hashlib
import json


def main():
    """Встраивает PNG без изменения изображения и проверяет целостность нарисованных мастеров."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inline-output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    repo = root.parents[3]
    meta = json.loads((root / "source.json").read_text())

    def encoded(path):
        """Упаковывает готовый файл для автономного просмотра."""
        return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")

    images = {}
    for variant in meta["variants"]:
        assert hashlib.sha256((root / variant["source"]).read_bytes()).hexdigest() == variant["sha256"]
        images[variant["id"]] = encoded(root / variant["preview_atlas"])
    images["soil"] = encoded(repo / "assets/game/tiles/editor/terrain/ground_farm_soil.png")
    images["grass"] = encoded(repo / "assets/game/tiles/grass.png")
    images["crops"] = encoded(repo / "assets/game/farming/crops/atlases/annual_a.png")
    assets = {"images": images, "cell": meta["preview_cell"], "referenceHeight": meta["preview_height"], "duration": meta["duration_seconds"], "floatPixels": meta["float_pixels"]}
    fragment = (root / "preview-fragment.template.html").read_text().replace("__WATERING_PREVIEW_ASSETS__", json.dumps(assets, separators=(",", ":")))
    assert len(fragment.encode()) < 1_000_000
    assert "\\\"" not in fragment and "\\n" not in fragment
    (root / "preview-fragment.html").write_text(fragment)
    if args.inline_output:
        args.inline_output.parent.mkdir(parents=True, exist_ok=True)
        args.inline_output.write_text(fragment)
    print(f"WATERING PREVIEW: {len(fragment.encode())} bytes, two animated variants")


if __name__ == "__main__":
    main()
