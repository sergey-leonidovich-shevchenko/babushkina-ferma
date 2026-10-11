"""Измеряет целые прозрачные фигуры без изменения пикселей исходников."""
from pathlib import Path
import json
from PIL import Image

root = Path("docs/concepts/skeleton-2026-10-12/v2")
catalog = {}
for name in ["walk", "actions"]:
    image = Image.open(root / "sources" / f"{name}.png").convert("RGBA")
    width, height = image.size
    mask = bytearray(alpha > 16 for *rgb, alpha in image.getdata())
    bodies = []
    for start in range(width * height):
        if not mask[start]:
            continue
        mask[start] = 0
        queue = [start]
        count = 0
        left, top, right, bottom = width, height, 0, 0
        while queue:
            position = queue.pop()
            x, y = position % width, position // width
            count += 1
            left, top, right, bottom = min(left, x), min(top, y), max(right, x), max(bottom, y)
            adjacent = ([position - 1] if x else []) + ([position + 1] if x + 1 < width else [])
            adjacent += ([position - width] if y else []) + ([position + width] if y + 1 < height else [])
            for neighbour in adjacent:
                if mask[neighbour]:
                    mask[neighbour] = 0
                    queue.append(neighbour)
        if count > 1000:
            bodies.append([left, top, right - left + 1, bottom - top + 1])
    assert len(bodies) == 24, (name, len(bodies))
    assert all(x > 0 and y > 0 and x + w < width and y + h < height for x, y, w, h in bodies)
    bodies.sort(key=lambda b: b[1] + b[3] / 2)
    ordered = []
    for row in range(8):
        ordered.extend(sorted(bodies[row * 3:row * 3 + 3], key=lambda b: b[0]))
    catalog[name] = ordered
    print(name, "24 isolated complete figures")
(root / "regions.json").write_text(json.dumps(catalog, indent=2) + "\n")
