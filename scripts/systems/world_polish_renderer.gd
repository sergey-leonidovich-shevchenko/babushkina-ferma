extends RefCounted

const ATLAS := preload("res://assets/game/world_polish/village_polish_atlas.png")
const CELL := Vector2(128, 128)


## Возвращает область одной ячейки строгого атласа 5×4.
static func source(column: int, row: int) -> Rect2:
	return Rect2(Vector2(column, row) * CELL, CELL)


## Рисует одну прозрачную ячейку атласа в указанном мировом прямоугольнике.
static func draw_cell(canvas: Node2D, column: int, row: int, destination: Rect2, modulate: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(ATLAS, destination, source(column, row), modulate)


## Рисует оружие у ведущей руки героя в направлении текущего действия.
static func draw_held_weapon(game: Node2D, kind: String, position: Vector2, direction: Vector2, attacking: bool, visual_scale: float = 1.0) -> void:
	var column: int = int({"forest_sword":0,"crystal_sword":1,"bow":2}.get(kind, -1))
	if column < 0: return
	var destination := held_weapon_destination(position, direction, attacking, visual_scale)
	draw_cell(game, column, 2, destination)
	if kind == "bow" and attacking: draw_cell(game,3,2,Rect2(position+direction*38.0-Vector2(16,16),Vector2(32,32)))


## Рассчитывает экранный прямоугольник предмета в руке с учётом общего визуального масштаба героя.
static func held_weapon_destination(position: Vector2, direction: Vector2, attacking: bool, visual_scale: float = 1.0) -> Rect2:
	var side := -1.0 if direction.x < -0.1 else 1.0
	var item_size := Vector2(48, 48) * visual_scale
	var offset := Vector2(22.0 * side, -3.0) * visual_scale + (direction * 7.0 * visual_scale if attacking else Vector2.ZERO)
	return Rect2(position + offset - item_size * 0.5, item_size)


## Рисует короткую тематическую частицу нового набора без изменения игрового состояния.
static func draw_effect(canvas: Node2D, kind: String, position: Vector2, alpha: float = 1.0) -> void:
	var column: int = int({"dust":0,"leaves":1,"splash":2,"stone":3,"wood":4}.get(kind, 0))
	draw_cell(canvas, column, 3, Rect2(position - Vector2(32,32), Vector2(64,64)), Color(1,1,1,alpha))
