extends RefCounted

const ATLAS := preload("res://assets/game/world_loot/world_loot_atlas_v1.png")
const CELL := Vector2(443.5, 443.5)
const CELLS := {
	"sack":Vector2i(0,0), "trash":Vector2i(1,0), "chest":Vector2i(2,0), "bone_pile":Vector2i(3,0),
	"supply_crate":Vector2i(0,1), "barrel":Vector2i(1,1), "hollow_log":Vector2i(2,1), "fairy_cache":Vector2i(3,1),
}


## Возвращает строгую область атласа для одного типа случайного контейнера.
static func source_rect(kind: String) -> Rect2:
	var resolved := "chest" if kind == "pirate_chest" else kind
	var cell: Vector2i = CELLS.get(resolved, Vector2i(2,0))
	return Rect2(Vector2(cell) * CELL, CELL)


## Рисует все контейнеры текущей локации готовыми атласными спрайтами и показывает открытое состояние.
static func draw(game: Node2D) -> void:
	for container in game.world_loot_nodes:
		if container.location != game.current_location: continue
		var position: Vector2 = container.position.round()
		var alpha := 0.38 if container.opened else 1.0
		var size := Vector2(76,76) if container.kind in ["chest","pirate_chest","bone_pile"] else Vector2(68,68)
		var tint := Color(0.82,0.92,1.0,alpha) if container.kind == "pirate_chest" else Color(1.0,1.0,1.0,alpha)
		game.draw_texture_rect_region(ATLAS, Rect2(position-size*0.5,size), source_rect(container.kind), tint)
		if container.opened:
			game.draw_ui_string(game.UI_FONT, position+Vector2(-35,38), game.LocaleSystem.ui("empty"), HORIZONTAL_ALIGNMENT_CENTER, 70, 12, Color(0.8,0.8,0.75,0.55))
