"""Статический аудит достижимых preload-ресурсов, без загрузки или редактирования изображений."""
import argparse
import json
import re
import struct
from pathlib import Path

from tools.common.paths import project_root
from tools.common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REFERENCES = re.compile(r'(?:preload\s*\(\s*|extends\s+)[\"\'](res://[^\"\']+)[\"\']')
SCENE_REFERENCES = re.compile(r'path\s*=\s*[\"\'](res://[^\"\']+)[\"\']')


def audit(root=ROOT):
    """Обходит только буквальные предварительные зависимости стартовой сцены и отмечает ограничения оценки."""
    pending = ["main.tscn"]
    visited, edges, textures, other = set(), [], [], []
    while pending:
        relative = pending.pop()
        if relative in visited:
            continue
        visited.add(relative)
        path = root / relative
        if not path.is_file():
            raise ValueError(f"Missing eager dependency: {relative}")
        if path.suffix == ".png":
            with path.open("rb") as image:
                header = image.read(24)
            if header[:8] != b"\x89PNG\r\n\x1a\n":
                raise ValueError(f"Invalid PNG: {relative}")
            width, height = struct.unpack(">II", header[16:24])
            textures.append(dict(path=relative, width=width, height=height,
                                 disk_bytes=path.stat().st_size, rgba8_estimate=width*height*4))
        elif path.suffix in {".gd", ".tscn", ".tres"}:
            pattern = REFERENCES if path.suffix == ".gd" else SCENE_REFERENCES
            for target in pattern.findall(path.read_text()):
                target = target.removeprefix("res://")
                edges.append([relative, target])
                pending.append(target)
        else:
            other.append(dict(path=relative, disk_bytes=path.stat().st_size))
    textures.sort(key=lambda row: row["rgba8_estimate"], reverse=True)
    return dict(schema=1, entry="main.tscn", dependency_count=len(visited),
                texture_count=len(textures), rgba8_estimate=sum(x["rgba8_estimate"] for x in textures),
                texture_disk_bytes=sum(x["disk_bytes"] for x in textures),
                textures=textures, other=other, edges=edges,
                limitations="Static literal preload/extends/scene graph only. Dynamic load, generated textures and drivers excluded. RGBA8 estimate is not measured VRAM; shared paths counted once; import compression/mipmaps may change residency.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "docs/reports/optimization-audit-2026-10-14/assets.json")
    args = parser.parse_args()
    result = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps({key: result[key] for key in ["dependency_count", "texture_count", "rgba8_estimate", "texture_disk_bytes"]}))
