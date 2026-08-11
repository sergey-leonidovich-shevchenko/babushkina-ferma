extends RefCounted

const SOURCE_TILE_SIZE := 32
const SOURCE_COLUMNS := 48
const SOURCE_ROWS := 24
const SOURCE_START_ROW := 4
const WORLD_TILE_SIZE := 50
const WORLD_COLUMNS := 48
const WORLD_ROWS := 24
const SOURCE_CROP := Rect2i(0, SOURCE_START_ROW * SOURCE_TILE_SIZE, SOURCE_COLUMNS * SOURCE_TILE_SIZE, SOURCE_ROWS * SOURCE_TILE_SIZE)
const WORLD_RECT := Rect2(0, 0, WORLD_COLUMNS * WORLD_TILE_SIZE, WORLD_ROWS * WORLD_TILE_SIZE)


## Рисует мастер первой локации как атлас из 1152 независимых тайлов.
## Исходное состояние: мастер имеет сетку 48×32 по 32 px, а игровой мир — 2400×1200.
## Ожидаемый результат: центральные 48×24 тайла без искажения заполняют весь игровой мир.
static func draw_level(canvas: CanvasItem, texture: Texture2D, tint: Color = Color.WHITE) -> void:
	for row in SOURCE_ROWS:
		for column in SOURCE_COLUMNS:
			var source := source_rect(Vector2i(column, row))
			var destination := world_rect(Vector2i(column, row))
			canvas.draw_texture_rect_region(texture, destination, source, tint)


## Возвращает область выбранного тайла внутри исходного мастер-арта.
static func source_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		cell.x * SOURCE_TILE_SIZE,
		(SOURCE_START_ROW + cell.y) * SOURCE_TILE_SIZE,
		SOURCE_TILE_SIZE,
		SOURCE_TILE_SIZE
	)


## Возвращает мировую область, которую занимает выбранный тайл после масштабирования.
static func world_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		cell.x * WORLD_TILE_SIZE,
		cell.y * WORLD_TILE_SIZE,
		WORLD_TILE_SIZE,
		WORLD_TILE_SIZE
	)


## Переводит координату мастер-арта в игровую координату с учётом верхней обрезки.
static func source_to_world(source_position: Vector2) -> Vector2:
	var cropped := source_position - Vector2(SOURCE_CROP.position)
	return cropped * (float(WORLD_TILE_SIZE) / float(SOURCE_TILE_SIZE))


## Проверяет, что параметры нарезки образуют цельный игровой прямоугольник без зазоров.
static func layout_is_valid() -> bool:
	return (
		SOURCE_COLUMNS == WORLD_COLUMNS
		and SOURCE_ROWS == WORLD_ROWS
		and SOURCE_CROP.size == Vector2i(1536, 768)
		and WORLD_RECT.size == Vector2(2400, 1200)
		and source_rect(Vector2i(SOURCE_COLUMNS - 1, SOURCE_ROWS - 1)).end == Vector2(1536, 896)
		and world_rect(Vector2i(WORLD_COLUMNS - 1, WORLD_ROWS - 1)).end == WORLD_RECT.end
	)
