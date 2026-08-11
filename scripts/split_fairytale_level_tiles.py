from __future__ import annotations

import hashlib
import json
from collections import OrderedDict
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_IMAGE = ROOT / "assets" / "generated" / "level_drafts" / "first_level_fairytale_master_v1.png"
OUTPUT_DIR = ROOT / "assets" / "generated" / "level_drafts" / "first_level_tiles_32"
TILE_SIZE = 32


def main() -> None:
	OUT_RAW = OUTPUT_DIR / "raw"
	OUT_GRID = OUTPUT_DIR / "grid"
	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	OUT_RAW.mkdir(exist_ok=True)
	OUT_GRID.mkdir(exist_ok=True)

	src = Image.open(SOURCE_IMAGE).convert("RGBA")
	width, height = src.size
	columns = width // TILE_SIZE
	rows = height // TILE_SIZE
	total = columns * rows

	grid_preview = Image.new("RGBA", (width, height), (0, 0, 0, 0))
	grid_preview.paste(src)

	# Рисуем сетку прямо на предпросмотре, чтобы удобнее видеть вырезанные тайлы.
	for x in range(TILE_SIZE, width, TILE_SIZE):
		for y in range(height):
			grid_preview.putpixel((x - 1, y), (255, 255, 255, 50))
			grid_preview.putpixel((x, y), (255, 255, 255, 50))
			grid_preview.putpixel((x + 1, y), (255, 255, 255, 50))
	for y in range(TILE_SIZE, height, TILE_SIZE):
		for x in range(width):
			grid_preview.putpixel((x, y - 1), (255, 255, 255, 50))
			grid_preview.putpixel((x, y), (255, 255, 255, 50))
			grid_preview.putpixel((x, y + 1), (255, 255, 255, 50))

	map_index = []
	unique = OrderedDict()

	for row in range(rows):
		row_data = []
		for col in range(columns):
			x0 = col * TILE_SIZE
			y0 = row * TILE_SIZE
			rect = (x0, y0, x0 + TILE_SIZE, y0 + TILE_SIZE)
			tile = src.crop(rect)
			filename = f"tile_{row:02d}_{col:02d}.png"
			tile.save(OUT_RAW / filename)

			raw_hash = hashlib.sha1(tile.tobytes()).hexdigest()
			existing = unique.get(raw_hash)
			if existing is None:
				unique[raw_hash] = {
					"id": len(unique),
					"file": f"tile_u{len(unique):03d}.png",
					"count": 1,
				}
				tile.save(OUT_GRID / unique[raw_hash]["file"])
			else:
				existing["count"] += 1

			row_data.append(unique[raw_hash]["id"])
		map_index.append(row_data)

	grid_preview.save(OUTPUT_DIR / "first_level_fairytale_master_v1_grid.png")
	metadata = {
		"source": str(SOURCE_IMAGE),
		"tile_size": TILE_SIZE,
		"grid": {"cols": columns, "rows": rows, "total": total},
		"raw": {"path": "raw", "count": total},
		"unique": [
			{"id": item["id"], "file": item["file"], "count": item["count"]}
			for item in unique.values()
		],
		"layout": map_index,
	}

	with (OUTPUT_DIR / "first_level_grid_index.json").open("w", encoding="utf-8") as file:
		json.dump(metadata, file, ensure_ascii=False, indent=2)

	print(
		f"Sliced {total} tiles ({columns}x{rows}) into "
		f"{OUTPUT_DIR / 'raw'} and compressed to {len(unique)} unique tiles."
	)


if __name__ == "__main__":
	main()
