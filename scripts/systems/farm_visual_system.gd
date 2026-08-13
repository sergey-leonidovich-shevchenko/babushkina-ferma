extends RefCounted

const ATLAS := preload("res://assets/game/environment/farm_plot_atlas.png")
const CELL_SIZE := 48
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


## Возвращает исходный прямоугольник стадии моркови с безопасным ограничением диапазона.
static func crop_source(stage: int) -> Rect2:
	return atlas_source(clampi(stage, 0, CROP_STAGE_COUNT - 1), CROP_ROW)


## Возвращает точную ячейку атласа 48×48 для заданных столбца и ряда.
static func atlas_source(column: int, row: int) -> Rect2:
	return Rect2(column * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)


## Возвращает модульный мировой прямоугольник грядки размером две на две базовые клетки.
static func plot_rect(origin: Vector2, cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))


## Проверяет размеры атласа и гарантирует целочисленную сетку всех его кадров.
static func atlas_is_valid() -> bool:
	return ATLAS.get_size() == Vector2(CELL_SIZE * COLUMN_COUNT, CELL_SIZE * ROW_COUNT)
