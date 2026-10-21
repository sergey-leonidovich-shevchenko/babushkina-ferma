extends RefCounted
const VillagePropRenderer:=preload("res://scripts/systems/village_prop_renderer.gd")
const TreeOcclusion := preload("res://scripts/systems/tree_occlusion_system.gd")

## Рисует только те высокие объекты, за которыми в текущий момент проходит герой.
static func draw(game: Node2D) -> void:
	TreeOcclusion.draw_foreground(game)
	preload("res://scripts/presentation/village_region_renderer.gd").draw_objects(game,true)
	if game.current_location != "overworld": return
	VillagePropRenderer.draw(game,true)
	VillagePropRenderer.draw_building_foreground(game)
