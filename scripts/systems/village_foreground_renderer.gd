extends RefCounted

const FOREST_TREE := preload("res://assets/game/environment/forest_tree.png")
const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")

## Рисует только те высокие объекты, за которыми в текущий момент проходит герой.
static func draw(game: Node2D) -> void:
	if game.current_location != "overworld": return
	for building_id in game.BuildingSystem.buildings_at("overworld"):
		var rect: Rect2 = game.BuildingSystem.destination_rect(building_id)
		if absf(game.player.x - rect.get_center().x) < rect.size.x * 0.48 and game.player.y < rect.end.y - 22.0:
			var cell := Vector2(game.BUILDING_ATLAS.get_width() / 4.0, game.BUILDING_ATLAS.get_height() / 2.0)
			var sprite_index: int = game.BuildingSystem.BUILDINGS[building_id].sprite
			game.draw_texture_rect_region(game.BUILDING_ATLAS, rect, Rect2(Vector2(sprite_index % 4, sprite_index / 4) * cell, cell))
	for position in VillageLayoutSystem.BORDER_TREES:
		if absf(game.player.x - position.x) < 64.0 and game.player.y < position.y + 36.0:
			game.draw_texture_rect(FOREST_TREE, Rect2(position - Vector2(72,98), Vector2(144,144)), false)
	for bridge in game.VillageLayoutSystem.BRIDGES:
		if bridge.has_point(game.player):
			game.draw_line(bridge.position + Vector2(12,4), Vector2(bridge.position.x + 12, bridge.end.y - 4), Color("6d4930"), 7)
			game.draw_line(Vector2(bridge.end.x - 12, bridge.position.y + 4), bridge.end - Vector2(12,4), Color("6d4930"), 7)
