extends RefCounted

const DETAIL_CELL := 12
const BASE_CELL := 24
const BLOCK_CELL := 48
const OVERVIEW_CELL := 96
const DEBUG_SIZES := [DETAIL_CELL, BASE_CELL, BLOCK_CELL, OVERVIEW_CELL]
const DEFAULT_DEBUG_SIZE := BASE_CELL
const PROPORTIONS := {
	"ground_tile":Vector2i(1,1), "path_min_width":Vector2i(2,1), "door_passage":Vector2i(2,1),
	"character_footprint":Vector2i(1,1), "character_visual":Vector2i(3,4),
	"small_prop":Vector2i(2,2), "tree_visual":Vector2i(4,5), "tree_trunk":Vector2i(2,2),
	"bridge_min_width":Vector2i(4,1), "small_building":Vector2i(12,12),
}


## Привязывает мировую координату к ближайшему узлу выбранной модульной сетки.
static func snap_position(position: Vector2, cell_size: int = BASE_CELL) -> Vector2:
	return Vector2(roundf(position.x / cell_size), roundf(position.y / cell_size)) * cell_size


## Возвращает прямоугольник заданного количества базовых клеток с привязкой к сетке.
static func rect_from_cells(origin: Vector2, cells: Vector2i) -> Rect2:
	return Rect2(snap_position(origin), Vector2(cells * BASE_CELL))


## Переводит мировой размер в количество базовых клеток с округлением вверх.
static func cells_for_size(size: Vector2) -> Vector2i:
	return Vector2i(ceili(size.x / BASE_CELL), ceili(size.y / BASE_CELL))


## Возвращает утверждённую пропорцию типа объекта либо безопасную клетку один на один.
static func proportion(kind: String) -> Vector2i:
	return PROPORTIONS.get(kind, Vector2i.ONE)
