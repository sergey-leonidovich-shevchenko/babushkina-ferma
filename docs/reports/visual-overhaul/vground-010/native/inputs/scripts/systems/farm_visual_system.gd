extends RefCounted

const ATLAS := preload("res://assets/game/environment/farm_plot_atlas.png")
const FLAT_SOIL := preload("res://assets/game/tiles/editor/terrain/ground_farm_soil.png")
const ANNUAL_A := preload("res://assets/game/farming/crops/atlases/annual_a.png")
const ANNUAL_B := preload("res://assets/game/farming/crops/atlases/annual_b.png")
const ANNUAL_C := preload("res://assets/game/farming/crops/atlases/annual_c.png")
const ANNUAL_D := preload("res://assets/game/farming/crops/atlases/annual_d.png")
const STRAWBERRY_SEASONS := preload("res://assets/game/farming/crops/atlases/strawberry_seasons.png")
const HERBS_SEASONS := preload("res://assets/game/farming/crops/atlases/herbs_seasons.png")
const CELL_SIZE := 48
const CROP_CELL_SIZE := 64
const COLUMN_COUNT := 5
const ROW_COUNT := 2
const SOIL_ROW := 0
const CROP_ROW := 1
const CROP_STAGE_COUNT := 5
const SOIL_GRASS := 0
const SOIL_TILLED_DRY := 1
const SOIL_TILLED_WET := 2
const SOIL_PLANTED_DRY := 3
const SOIL_PLANTED_WET := 4
const SEASON_ROWS := {"spring":0,"summer":1,"autumn":2,"winter":3}
const CROP_LAYOUT := {
	"carrot":{"atlas":"annual_a","row":0},"tomato":{"atlas":"annual_a","row":1},"cabbage":{"atlas":"annual_a","row":2},"wheat":{"atlas":"annual_a","row":3},
	"corn":{"atlas":"annual_b","row":0},"potato":{"atlas":"annual_b","row":1},"onion":{"atlas":"annual_b","row":2},"pumpkin":{"atlas":"annual_b","row":3},
	"beet":{"atlas":"annual_c","row":0},"pepper":{"atlas":"annual_c","row":1},"cucumber":{"atlas":"annual_c","row":2},"sunflower":{"atlas":"annual_c","row":3},
	"cotton":{"atlas":"annual_d","row":0},"melon":{"atlas":"annual_d","row":1},
	"strawberry":{"atlas":"strawberry","seasonal":true},"herbs":{"atlas":"herbs","seasonal":true},
}


## Невскопанная клетка сохраняет живой фон локации; земля появляется только после действия игрока.
static func is_plot_visible(plot: Dictionary) -> bool:
	return bool(plot.get("tilled", false)) or bool(plot.get("planted", false))


## Рисует плоскую почву из базовых тайлов без зелёных кубов и толстых боковых граней.
static func draw_soil(canvas: CanvasItem, rect: Rect2, plot: Dictionary) -> void:
	var tint := Color("b58b60") if not bool(plot.get("watered", false)) else Color("755841")
	for row in ceili(rect.size.y / 24.0):
		for column in ceili(rect.size.x / 24.0):
			var position := rect.position + Vector2(column, row) * 24.0
			var size := Vector2(minf(24.0, rect.end.x - position.x), minf(24.0, rect.end.y - position.y))
			canvas.draw_texture_rect_region(FLAT_SOIL, Rect2(position, size), Rect2(Vector2.ZERO, size), tint)
	# Тонкая кромка отделяет обработанную землю от травы, не превращая грядку в ящик.
	canvas.draw_rect(rect.grow(-0.5), Color(0.18, 0.11, 0.055, 0.35), false, 1.0)


## Возвращает целочисленную ячейку земли для текущего состояния грядки.
static func soil_column(plot: Dictionary) -> int:
	if not plot.get("tilled", false):
		return SOIL_GRASS
	if plot.get("planted", false):
		return SOIL_PLANTED_WET if plot.get("watered", false) else SOIL_PLANTED_DRY
	return SOIL_TILLED_WET if plot.get("watered", false) else SOIL_TILLED_DRY


## Возвращает исходный прямоугольник земли без дробных координат и соседних пикселей.
static func soil_source(plot: Dictionary) -> Rect2:
	return atlas_source(soil_column(plot), SOIL_ROW)


## Возвращает исходный прямоугольник одной из пяти стадий с учётом сезонного ряда многолетника.
static func crop_source(stage: int, crop_kind: String = "carrot", season: String = "spring") -> Rect2:
	var layout: Dictionary = CROP_LAYOUT.get(crop_kind, CROP_LAYOUT.carrot)
	var row: int = int(SEASON_ROWS.get(season, 0)) if layout.get("seasonal", false) else int(layout.get("row", 0))
	return Rect2(clampi(stage, 0, CROP_STAGE_COUNT - 1) * CROP_CELL_SIZE, row * CROP_CELL_SIZE, CROP_CELL_SIZE, CROP_CELL_SIZE)


## Возвращает производственный атлас, содержащий кадры указанной культуры.
static func crop_texture(crop_kind: String) -> Texture2D:
	var atlas_id: String = String(Dictionary(CROP_LAYOUT.get(crop_kind, CROP_LAYOUT.carrot)).atlas)
	return {"annual_a":ANNUAL_A,"annual_b":ANNUAL_B,"annual_c":ANNUAL_C,"annual_d":ANNUAL_D,"strawberry":STRAWBERRY_SEASONS,"herbs":HERBS_SEASONS}.get(atlas_id, ANNUAL_A)


## Возвращает точную ячейку атласа 48×48 для заданных столбца и ряда.
static func atlas_source(column: int, row: int) -> Rect2:
	return Rect2(column * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)


## Возвращает модульный мировой прямоугольник грядки размером две на две базовые клетки.
static func plot_rect(origin: Vector2, cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))


## Проверяет размеры атласа и гарантирует целочисленную сетку всех его кадров.
static func atlas_is_valid() -> bool:
	return ATLAS.get_size() == Vector2(CELL_SIZE * COLUMN_COUNT, CELL_SIZE * ROW_COUNT)


## Проверяет размеры всех новых атласов и полноту регистрации шестнадцати культур.
static func crop_atlases_are_valid() -> bool:
	return CROP_LAYOUT.size() == 16 and ANNUAL_A.get_size() == Vector2(320,256) and ANNUAL_B.get_size() == Vector2(320,256) and ANNUAL_C.get_size() == Vector2(320,256) and ANNUAL_D.get_size() == Vector2(320,128) and STRAWBERRY_SEASONS.get_size() == Vector2(320,256) and HERBS_SEASONS.get_size() == Vector2(320,256)
