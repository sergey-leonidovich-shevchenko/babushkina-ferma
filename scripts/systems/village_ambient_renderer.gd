extends RefCounted

const ATLAS := preload("res://assets/game/environment/village_ambient_atlas_v1.png")
const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
const COLUMNS := 4
const ROWS := 3
const CELL := Vector2(362, 362)
const CELLS := {
	"flowers":Vector2i(0,0), "grass":Vector2i(1,0), "reeds":Vector2i(2,0), "berry_bush":Vector2i(3,0),
	"mossy_stone":Vector2i(0,1), "stump":Vector2i(1,1), "signpost":Vector2i(2,1), "flower_fence":Vector2i(3,1),
	"lantern":Vector2i(0,2), "footbridge":Vector2i(1,2), "leaves":Vector2i(2,2), "water_lilies":Vector2i(3,2),
}
const PLACEMENTS := [
	{"kind":"flowers","position":Vector2(535,700),"phase":0.2},{"kind":"flowers","position":Vector2(930,620),"phase":1.3},{"kind":"flowers","position":Vector2(1325,680),"phase":2.1},{"kind":"flowers","position":Vector2(1680,655),"phase":0.8},
	{"kind":"grass","position":Vector2(610,570),"phase":2.7},{"kind":"grass","position":Vector2(1050,665),"phase":1.7},{"kind":"grass","position":Vector2(1765,795),"phase":0.4},
	{"kind":"reeds","position":Vector2(380,360),"phase":0.1},{"kind":"reeds","position":Vector2(560,525),"phase":1.0},{"kind":"reeds","position":Vector2(790,620),"phase":2.4},{"kind":"reeds","position":Vector2(1015,700),"phase":1.8},{"kind":"reeds","position":Vector2(1285,715),"phase":0.7},{"kind":"reeds","position":Vector2(1540,785),"phase":2.9},{"kind":"reeds","position":Vector2(1820,890),"phase":1.4},
	{"kind":"water_lilies","position":Vector2(450,430),"phase":0.4},{"kind":"water_lilies","position":Vector2(850,665),"phase":1.9},{"kind":"water_lilies","position":Vector2(1180,750),"phase":2.6},{"kind":"water_lilies","position":Vector2(1590,835),"phase":1.1},{"kind":"water_lilies","position":Vector2(1930,955),"phase":2.2},
	{"kind":"leaves","position":Vector2(720,385),"phase":0.5},{"kind":"leaves","position":Vector2(1460,565),"phase":2.0},{"kind":"leaves","position":Vector2(2020,825),"phase":1.2},
]


## Возвращает область одной ячейки строгого атласа четыре на три.
static func source_rect(kind: String) -> Rect2:
	var cell: Vector2i = CELLS.get(kind, Vector2i.ZERO)
	return Rect2(Vector2(cell) * CELL, CELL)


## Проверяет, разрешён ли тип декора в конкретном сезонном состоянии деревни.
static func is_visible_in_season(kind: String, season: String) -> bool:
	if kind == "leaves": return season == "autumn"
	if season == "winter" and kind in ["flowers", "grass", "reeds", "water_lilies"]: return false
	return true


## Рисует одну ячейку атласа с общей нижней точкой опоры и заданной прозрачностью.
static func draw_cell(canvas: Node2D, kind: String, position: Vector2, modulate: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(ATLAS,destination_rect(position),source_rect(kind),modulate)


## Возвращает стабильный прямоугольник 72×72 без масштабирования во время анимации ветра.
static func destination_rect(position: Vector2) -> Rect2:
	return WorldVisualProfileSystem.visual_rect("village_ambient",position+Vector2(0,24))


## Добавляет над мастер-артом сезонный живой слой травы, камыша и водных растений.
static func draw_ground(game: Node2D) -> void:
	if game.current_location != "overworld": return
	var season: String = game.WorldEventSystem.season(game.day)
	var time := Time.get_ticks_msec() / 620.0
	for placement in PLACEMENTS:
		var kind: String = placement.kind
		if not is_visible_in_season(kind, season): continue
		var phase: float = float(placement.phase)
		var sway := sin(time + phase) * (0.018 if kind != "water_lilies" else 0.008)
		var alpha := 0.82 + sin(time * 0.7 + phase) * 0.08
		var position: Vector2 = placement.position + Vector2(sway * 30.0, sin(time * 0.55 + phase) * 1.2)
		var tint := Color(0.88, 0.92, 1.0, alpha) if season == "winter" else Color(1.0, 1.0, 1.0, alpha)
		draw_cell(game,kind,position,tint)
