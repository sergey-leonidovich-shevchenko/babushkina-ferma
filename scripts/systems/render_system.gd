extends RefCounted

static func draw(game: Node2D) -> void:
	if game.language_screen:
		game.draw_language_screen(); return
	if game.title_screen:
		game.draw_title_screen(); return
	game.draw_set_transform(-game.camera_offset)
	if game.current_location == "overworld":
		game.draw_farm(); game.draw_rpg_world(); game.draw_fishing_animations()
	game.draw_enemy_nodes_and_gate(); game.draw_resource_nodes(); game.draw_food_nodes(); game.draw_world_loot(); game.draw_wildlife(); game.draw_dropped_items(); game.draw_player(); game.draw_interaction_highlight()
	game.draw_set_transform(Vector2.ZERO); game.draw_ui()
