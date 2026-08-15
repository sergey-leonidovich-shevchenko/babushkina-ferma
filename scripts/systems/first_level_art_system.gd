extends RefCounted

const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
const SOURCE_TILE_SIZE := WorldVisualProfileSystem.BASE_CELL
const SOURCE_COLUMNS := 100
const SOURCE_ROWS := 50
const SOURCE_START_ROW := 0
const WORLD_TILE_SIZE := WorldVisualProfileSystem.BASE_CELL
const WORLD_COLUMNS := SOURCE_COLUMNS
const WORLD_ROWS := SOURCE_ROWS
const SOURCE_CROP := Rect2i(0, 0, SOURCE_COLUMNS * SOURCE_TILE_SIZE, SOURCE_ROWS * SOURCE_TILE_SIZE)
const WORLD_RECT := Rect2(0, 0, WORLD_COLUMNS * WORLD_TILE_SIZE, WORLD_ROWS * WORLD_TILE_SIZE)


## Рисует заранее запечённый мастер первой локации один к одному без runtime-масштабирования и межтайловых швов.
static func draw_level(canvas: CanvasItem, texture: Texture2D, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture(texture, Vector2.ZERO, tint)


## Возвращает область выбранной базовой ячейки внутри нативного мастер-арта.
static func source_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * SOURCE_TILE_SIZE, cell.y * SOURCE_TILE_SIZE, SOURCE_TILE_SIZE, SOURCE_TILE_SIZE)


## Возвращает мировую область той же базовой ячейки без пересчёта масштаба.
static func world_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * WORLD_TILE_SIZE, cell.y * WORLD_TILE_SIZE, WORLD_TILE_SIZE, WORLD_TILE_SIZE)


## Переводит координату нативного мастер-арта в совпадающую игровую координату.
static func source_to_world(source_position: Vector2) -> Vector2:
	return source_position


## Проверяет, что источник и мир образуют единую сетку 100×50 с ячейкой 24 px.
static func layout_is_valid() -> bool:
	return (
		SOURCE_TILE_SIZE == WorldVisualProfileSystem.BASE_CELL
		and SOURCE_COLUMNS == WORLD_COLUMNS
		and SOURCE_ROWS == WORLD_ROWS
		and SOURCE_CROP.size == Vector2i(2400, 1200)
		and WORLD_RECT.size == Vector2(2400, 1200)
		and source_rect(Vector2i(SOURCE_COLUMNS - 1, SOURCE_ROWS - 1)).end == Vector2(2400, 1200)
		and world_rect(Vector2i(WORLD_COLUMNS - 1, WORLD_ROWS - 1)).end == WORLD_RECT.end
	)
