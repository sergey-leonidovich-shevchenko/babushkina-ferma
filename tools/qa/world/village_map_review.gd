extends SceneTree

const GAME_SCENE:=preload("res://main.tscn")
const MapData:=preload("res://scripts/systems/village_map_data.gd")
var game:Node

## Начинает съёмку только после готовности настоящего окна и корневого viewport.
func _initialize()->void:
	_run.call_deferred()

## Снимает реальную игровую сцену: общий план для проверки связности и три обычных кадра игрока.
func _run()->void:
	game=GAME_SCENE.instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.language_screen=false; game.title_screen=false; game.current_location="overworld"
	game.LocaleSystem.set_locale("ru",false); game.settings_state.screen_shake_enabled=false
	game.state.world.estate.event=""; game.FarmLifeSystem.state(game).cutscene=""
	game.day=1; game.game_minutes=9*60; game.state.world.weather_day=1; game.state.world.weather="clear"
	game.world_loot_seed=20260908; game.world_loot_nodes=game.LootContainerSystem.generate(game.world_loot_seed)
	game.NpcMovementSystem.initialize(game)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1440,720); root.content_scale_size=Vector2i(2400,1200)
	game.set_meta("capture_first_level_clean",true); game.player=MapData.START; game.camera_offset=Vector2.ZERO
	game.get_node("WorldBackground").position=Vector2.ZERO
	await _capture("village_modular_overview")
	root.size=Vector2i(1440,810); root.content_scale_size=Vector2i(1152,648)
	game.remove_meta("capture_first_level_clean")
	for shot in [{"name":"home","position":MapData.START},{"name":"plaza","position":Vector2(1320,744)},{"name":"forest","position":Vector2(2016,744)}]:
		game.player=shot.position; game.update_camera(); game.sync_background_location(); game.tutorial_visible=false
		await _capture("village_modular_%s"%shot.name)
	print("VILLAGE CAPTURE: overview/home/plaza/forest saved from main.tscn")
	game.queue_free(); await process_frame; quit()

## Ждёт готовый GPU-кадр и сохраняет его без внешней обработки или подмены игрового изображения.
func _capture(name:String)->void:
	game.queue_redraw(); game.get_node("WorldBackground").queue_redraw()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var path:="res://assets/generated/level_drafts/%s.png"%name
	print("CAPTURE %s: %s"%[name,image.save_png(path)])
