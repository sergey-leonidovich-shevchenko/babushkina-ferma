extends RefCounted

const ATLAS := preload("res://assets/game/environment/village_ambient_atlas_v1.png")
const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
const RootProfile := preload("res://scripts/presentation/foliage_root_profile.gd")
const COLUMNS := 4
const ROWS := 3
const CELL := Vector2(362, 362)
const VillageMapData:=preload("res://scripts/systems/village_map_data.gd")
const CELLS := {
	"flowers":Vector2i(0,0), "grass":Vector2i(1,0), "reeds":Vector2i(2,0), "berry_bush":Vector2i(3,0),
	"mossy_stone":Vector2i(0,1), "stump":Vector2i(1,1), "signpost":Vector2i(2,1), "flower_fence":Vector2i(3,1),
	"lantern":Vector2i(0,2), "footbridge":Vector2i(1,2), "leaves":Vector2i(2,2), "water_lilies":Vector2i(3,2),
}
const PLACEMENTS := [
	{"kind":"reeds","position":Vector2(552,384),"phase":0.2},{"kind":"reeds","position":Vector2(744,456),"phase":1.3},{"kind":"reeds","position":Vector2(1032,768),"phase":2.1},{"kind":"reeds","position":Vector2(1440,984),"phase":0.8},
	{"kind":"reeds","position":Vector2(1800,840),"phase":0.4},{"kind":"reeds","position":Vector2(1968,960),"phase":1.7},
	{"kind":"water_lilies","position":Vector2(672,360),"phase":0.4},{"kind":"water_lilies","position":Vector2(1272,912),"phase":1.9},{"kind":"water_lilies","position":Vector2(1848,888),"phase":2.6},
	{"kind":"grass","position":Vector2(1944,648),"phase":0.5},{"kind":"grass","position":Vector2(2160,888),"phase":2.0},{"kind":"leaves","position":Vector2(2020,825),"phase":1.2},
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

## Читает настоящую опору рисунка внутри прежнего прямоугольника, не перемещая декор или физические клетки.
static func root_anchor(kind:String,position:Vector2)->Vector2:
	return RootProfile.world_anchor(kind,destination_rect(position))


## Добавляет над мастер-артом сезонный живой слой травы, камыша и водных растений.
static func draw_ground(game: Node2D) -> void:
	if game.current_location != "overworld": return
	var season: String = game.WorldEventSystem.season(game.day)
	var time := preload("res://scripts/presentation/village_ground_clock.gd").seconds(game)/0.62
	var animated:=preload("res://scripts/presentation/visual_reference_mode.gd").effects_enabled(game)
	for placement in PLACEMENTS:
		var kind: String = placement.kind
		if not is_visible_in_season(kind, season): continue
		var pose:=ground_pose(kind,placement.position,float(placement.phase),time,animated)
		var tint := Color(0.88, 0.92, 1.0, pose.alpha) if season == "winter" else Color(1.0, 1.0, 1.0, pose.alpha)
		draw_cell(game,kind,pose.position,tint)

## Возвращает исходную опору без колебаний для эталона и прежнюю формулу движения для обычной игры.
static func ground_pose(kind: String, position: Vector2, phase: float, time: float, animated: bool = true) -> Dictionary:
	if not animated: return {"position":position,"alpha":0.82}
	var sway:=sin(time+phase)*(0.018 if kind!="water_lilies" else 0.008)
	return {"position":position+Vector2(sway*30.0,sin(time*0.55+phase)*1.2),"alpha":0.82+sin(time*0.7+phase)*0.08}
