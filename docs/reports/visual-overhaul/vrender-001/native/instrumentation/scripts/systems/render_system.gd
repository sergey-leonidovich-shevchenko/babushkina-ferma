extends RefCounted

const FishingRenderer := preload("res://scripts/systems/fishing_renderer.gd")
const VillagePropRenderer:=preload("res://scripts/systems/village_prop_renderer.gd")
const TreeOcclusion := preload("res://scripts/systems/tree_occlusion_system.gd")
const CaveRenderer := preload("res://scripts/systems/cave_renderer.gd")
const BossRenderer := preload("res://scripts/systems/cave_boss_renderer.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")

## Координирует отрисовку текущего состояния без изменения игровой логики.
static func draw(game: Node2D) -> void:
	if game.language_screen:
		game.draw_language_screen(); game.UiFeedbackRenderer.draw(game); return
	if game.title_screen:
		game.draw_title_screen(); game.UiFeedbackRenderer.draw(game); return
	if opaque_storage(game):
		game.draw_set_transform(Vector2.ZERO); draw_screen(game,false); return
	TreeOcclusion.begin_frame(game)
	WorldProjection.apply(game)
	if game.BuildingSystem.is_interior(game.current_location):
		game.draw_interior_objects(); game.draw_quest_npcs()
	elif game.current_location == "overworld":
		game.VillageAmbientRenderer.draw_ground(game); game.draw_farm(); VillagePropRenderer.draw(game,false); game.draw_rpg_world()
	else:
		game.draw_farm()
	preload("res://scripts/presentation/village_region_renderer.gd").draw_ground(game)
	preload("res://scripts/presentation/village_region_renderer.gd").draw_objects(game)
	if game.current_location in ["overworld","village_river"]: game.draw_fishing_animations()
	game.EnvironmentVisualSystem.draw_biome_trees(game, game.current_location)
	CaveRenderer.draw_lights(game); BossRenderer.draw_ground(game)
	game.PublishedLevelRenderer.draw_layer(game,"background"); game.PublishedLevelRenderer.draw_layer(game,"ground"); game.LevelEditorRenderer.draw_layer(game,"background"); game.LevelEditorRenderer.draw_layer(game,"ground")
	if not game.BuildingSystem.is_interior(game.current_location):
		game.draw_buildings(); game.draw_world_events(); game.VillageEventRenderer.draw(game); game.draw_quest_npcs()
	game.CastleCampaignRenderer.draw(game); game.draw_hazards(); game.draw_enemy_nodes_and_gate(); BossRenderer.draw_actors(game); game.draw_tree_nodes(); game.draw_resource_nodes(); game.draw_food_nodes(); game.draw_world_loot(); game.draw_wildlife(); game.draw_dropped_items(); FishingRenderer.draw_traps(game); game.draw_companions(); game.FarmLifeRenderer.draw_world(game); game.FirstChapterRenderer.draw_world(game); game.FenceRenderer.draw_world(game); game.PublishedLevelRenderer.draw_layer(game,"objects"); game.LevelEditorRenderer.draw_layer(game,"objects"); game.draw_player(); preload("res://scripts/systems/livestock_renderer.gd").draw(game,true); BossRenderer.draw_front(game); CaveRenderer.draw_foreground(game); game.SpellRenderer.draw_world(game); game.InteriorRenderer.draw_foreground(game); game.VillageForegroundRenderer.draw(game); game.AdventurePolishRenderer.draw_world(game); game.PublishedLevelRenderer.draw_layer(game,"foreground"); game.LevelEditorRenderer.draw_layer(game,"foreground"); game.DebugPlaygroundRenderer.draw_world_overlay(game); game.DebugOverlayRenderer.draw_world(game)
	preload("res://scripts/presentation/apiary_visual_system.gd").draw_world(game,true)
	preload("res://scripts/presentation/house_furniture_placement_renderer.gd").draw(game)
	preload("res://scripts/presentation/basement_renderer.gd").placement(game)
	preload("res://scripts/presentation/basement_renderer.gd").work_overlay(game)
	game.draw_set_transform(Vector2.ZERO); game.AtmosphereRenderer.draw(game)
	var clean_level_capture := game.has_meta("capture_first_level_clean")
	draw_screen(game,clean_level_capture)

## Отсекает только мир за полностью непрозрачным хранилищем; режимы чистого захвата и редактор сохраняют свой маршрут.
static func opaque_storage(game: Node) -> bool:
	return not game.has_meta("capture_first_level_clean") and not bool(game.FarmLifeSystem.state(game).photo_mode) and not game.LevelEditorSystem.active(game) and (game.storage_open or preload("res://scripts/systems/dev_cabinet_system.gd").active(game))

## Сохраняет общий порядок экранов, диагностических панелей, подтверждений и уведомлений поверх мира либо непрозрачного окна.
static func draw_screen(game: Node2D, clean_level_capture: bool) -> void:
	if not preload("res://scripts/presentation/visual_reference_mode.gd").hud_visible(game): return
	if not clean_level_capture and not bool(game.FarmLifeSystem.state(game).photo_mode) and not game.LevelEditorSystem.active(game): game.draw_ui(); BossRenderer.draw_ui(game); FishingRenderer.draw(game); game.WorldMapRenderer.draw(game); game.AdventurePolishRenderer.draw_ui(game); game.FenceRenderer.draw_ui(game); game.SpellRenderer.draw_ui(game)
	if not clean_level_capture and not game.LevelEditorSystem.active(game):
		game.FarmLifeRenderer.draw_ui(game)
		if not game.has_meta("capture_hud_clean"): game.FirstChapterRenderer.draw_ui(game)
		game.StoryUiRenderer.draw_notification(game)
		game.DebugPlaygroundRenderer.draw_overlay(game); game.DebugOverlayRenderer.draw_panel(game)
	if not clean_level_capture: game.LevelEditorRenderer.draw_panel(game)
	preload("res://scripts/presentation/basement_renderer.gd").ui(game)
	if game.menu_state.pause_open or game.menu_state.settings_open or game.menu_state.defeat_open: game.MenuRenderer.draw_pause_layer(game)
	preload("res://scripts/systems/menu_hub_system.gd").draw_chrome(game)
	preload("res://scripts/presentation/qa_teleport_renderer.gd").draw(game)
	game.UiFeedbackRenderer.draw(game)
	preload("res://scripts/presentation/recovery_notice_renderer.gd").draw(game)
