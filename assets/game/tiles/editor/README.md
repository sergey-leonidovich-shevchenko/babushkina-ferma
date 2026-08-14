# Модульная местность конструктора

Папки `terrain` и `water` содержат 48 отдельных игровых тайлов 24×24. `source` хранит два утверждённых мастера 1536×1024 с сеткой 6×4 и исходной ячейкой 256×256. `preview` — увеличенный контрольный лист, исключённый из каталога конструктора.

Тайлы созданы встроенным режимом генерации изображений Codex и затем воспроизводимо нарезаны `tools/build_level_editor_tiles.py`.

## Финальный запрос: земля и дороги

```text
Use case: stylized-concept
Asset type: modular terrain sprite sheet for the in-game level editor of a cozy fantasy farming RPG
Input images: Image 1 is a strict style and palette reference only; do not copy its scene composition
Primary request: Create exactly 24 individually usable top-down terrain tiles in a strict 6-column by 4-row sheet.
Scene/backdrop: no scene and no outside background; every square cell is fully filled edge-to-edge with terrain.
Style/medium: polished 32-bit-style pixel art matching Image 1, crisp pixel clusters, warm fairytale village palette, orthographic top-down view, high readability at small size.
Composition/framing: exact 6×4 grid, every cell exactly the same square size, no padding, no gutters, no borders, no labels. Tile edges at identical anchor points. Row 1: seamless lush grass, seamless flower meadow grass, seamless dry autumn grass, seamless brown dirt, seamless dark farm soil, seamless pale sand. Row 2: seamless village cobblestone, cracked rocky ground, mossy stone ground, wooden deck floor, snowy grass, wet mud. Row 3: dirt path modules on lush grass — horizontal, vertical, 90-degree corner, T-junction, four-way junction, one-ended path. Row 4: cobblestone road modules on lush grass — horizontal, vertical, 90-degree corner, T-junction, four-way junction, one-ended road.
Materials/textures: grass blades, tiny restrained flowers, compact stones and soil clusters; path widths and connection points must be identical within each row.
Constraints: sheet must read as a production game tileset, each cell independently crop-safe, terrain fills the whole cell, seamless ground tiles, exact matching road endpoints at the center of cell edges, no objects taller than ground, no characters, no trees, no buildings, no shadows outside cells, no text, no watermark.
Avoid: illustrated landscape, isometric perspective, visible grid lines, bevelled UI tiles, gaps between cells, decorative frames, blurry painting, photorealism, mixed camera angles.
```

## Финальный запрос: вода и берега

```text
Use case: stylized-concept
Asset type: modular water, shoreline, and natural-boundary sprite sheet for the in-game level editor of a cozy fantasy farming RPG
Input images: Image 1 is a strict style, water, and palette reference only
Primary request: Create exactly 24 individually usable top-down terrain tiles in a strict 6-column by 4-row sheet.
Scene/backdrop: no scene and no outside background; every square cell is fully filled edge-to-edge with terrain.
Style/medium: polished 32-bit-style pixel art matching Image 1, crisp pixel clusters, orthographic top-down view, cozy fairytale nature.
Composition/framing: exact 6×4 grid, equal square cells, no padding, gutters, borders, labels, or text. Row 1: seamless clear blue water, seamless rippled water, seamless deep blue water, seamless shallow water, water with sparse lily pads, water with tiny reflected sparkles. Row 2: grassy shoreline modules with water — north edge, south edge, west edge, east edge, outer corner, inner corner. Row 3: narrow river modules on grass — horizontal, vertical, 90-degree corner, T-junction, four-way junction, rounded pond end. Row 4: rocky terrain-boundary modules on grass — horizontal cliff edge, vertical cliff edge, corner cliff, T rocky bank, four-way rocky island crossing, small round pond surrounded by stones.
Materials/textures: blue water consistent with reference, mossy stones, lush grass, a few reeds and lily pads that do not block connection points.
Constraints: production game tileset; each cell independently crop-safe; exact matching water and terrain endpoints at center of cell edges; complete square opaque terrain tiles; consistent water color and shoreline width; no objects taller than ground; no characters; no buildings; no cast shadows; no text; no watermark.
Avoid: landscape illustration, isometric perspective, visible grid lines, gaps, UI frames, mismatched connection widths, blurry painting, photorealism, mixed camera angles.
```
