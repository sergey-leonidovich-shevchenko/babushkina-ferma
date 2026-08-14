extends RefCounted

const FishingRenderer := preload("res://scripts/systems/fishing_renderer.gd")

## Координирует отрисовку текущего состояния без изменения игровой логики.
static func draw(game: Node2D) -> void:
	if game.language_screen:
		game.draw_language_screen(); return
	if game.title_screen:
		game.draw_title_screen(); return
	game.draw_set_transform(-game.camera_offset + game.AdventurePolishSystem.shake_offset(game))
	if game.BuildingSystem.is_interior(game.current_location):
		game.draw_interior_objects()
	elif game.current_location == "overworld":
		game.VillageAmbientRenderer.draw_ground(game); game.draw_farm(); game.draw_rpg_world(); game.draw_fishing_animations()
	else:
		game.draw_farm()
	if not game.BuildingSystem.is_interior(game.current_location):
		game.draw_buildings(); game.draw_world_events(); game.VillageEventRenderer.draw(game); game.draw_quest_npcs()
	game.CastleCampaignRenderer.draw(game); game.draw_hazards(); game.draw_enemy_nodes_and_gate(); game.draw_tree_nodes(); game.draw_resource_nodes(); game.draw_food_nodes(); game.draw_world_loot(); game.draw_wildlife(); game.draw_dropped_items(); game.draw_companions(); game.FarmLifeRenderer.draw_world(game); game.draw_player(); game.VillageForegroundRenderer.draw(game); game.AdventurePolishRenderer.draw_world(game); game.draw_interaction_highlight(); game.DebugPlaygroundRenderer.draw_world_overlay(game); game.DebugOverlayRenderer.draw_world(game)
	game.draw_set_transform(Vector2.ZERO); game.AtmosphereRenderer.draw(game)
	var clean_level_capture := game.has_meta("capture_first_level_clean")
	if not clean_level_capture and not bool(game.FarmLifeSystem.state(game).photo_mode): game.draw_ui(); FishingRenderer.draw(game); game.WorldMapRenderer.draw(game); game.AdventurePolishRenderer.draw_ui(game)
	if not clean_level_capture: game.FarmLifeRenderer.draw_ui(game); game.DebugPlaygroundRenderer.draw_overlay(game); game.DebugOverlayRenderer.draw_panel(game)
	if game.menu_state.pause_open or game.menu_state.settings_open: game.MenuRenderer.draw_pause_layer(game)
