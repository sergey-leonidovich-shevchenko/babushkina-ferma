extends SceneTree

const Scene := preload("res://main.tscn")
const Occlusion := preload("res://scripts/systems/tree_occlusion_system.gd")
var game: Node2D


## Откладывает проверку до готовности настоящего окна Godot; пользовательская игра не затрагивается.
func _initialize() -> void:
	_run.call_deferred()


## Снимает реальную сцену до и после перекрытия деревьев без загрузки и записи сохранения игрока.
func _run() -> void:
	var save_path := ProjectSettings.globalize_path("user://farm-save.json")
	var save_before := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else "absent"
	game=Scene.instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.language_screen=false; game.title_screen=false; game.current_location="overworld"
	game.settings_state.reduced_motion=false; game.settings_state.screen_shake_enabled=false
	game.day=1; game.game_minutes=600; game.state.world.weather_day=1; game.state.world.weather="clear"
	game.set_meta("capture_first_level_clean",true)
	game.state.world.estate.event=""; game.FarmLifeSystem.state(game).cutscene=""
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(960,540); root.content_scale_size=Vector2i(960,540)
	game.facing=Vector2.DOWN
	for shot in [
		{"name":"orchard_behind","player":Vector2(696,967),"camera":Vector2(220,690)},
		{"name":"orchard_front","player":Vector2(696,1100),"camera":Vector2(220,690)},
		{"name":"orchard_side","player":Vector2(566,1010),"camera":Vector2(220,690)},
		{"name":"timber_behind","player":Vector2(2016,310),"camera":Vector2(1610,90)},
		{"name":"timber_front","player":Vector2(2016,420),"camera":Vector2(1610,90)},
		{"name":"seasonal_behind","player":Vector2(1056,365),"camera":Vector2(630,100)},
	]:
		game.player=shot.player; game.camera_offset=shot.camera
		game.get_node("WorldBackground").position=-game.camera_offset
		game.sync_background_location(); game.sync_background_environment()
		await _capture(String(shot.name))
	var save_after := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else "absent"
	print("TREE REVIEW SAVE UNCHANGED: ",save_before==save_after)
	game.queue_free(); await process_frame
	quit(0 if save_before==save_after else 1)


## Даёт opacity пройти полный переход и сохраняет кадр непосредственно из реального GPU viewport.
func _capture(name: String) -> void:
	for frame in 24:
		game.queue_redraw(); game.get_node("WorldBackground").queue_redraw()
		await process_frame
		await create_timer(0.015).timeout
	await RenderingServer.frame_post_draw
	var path := "res://docs/reports/tree_occlusion_%s.png"%name
	var result := root.get_texture().get_image().save_png(path)
	print("TREE REVIEW ",name,": ",result)
	var entries:Dictionary=game.get_meta(Occlusion.META_KEY).entries
	for key in entries:
		if entries[key].alpha<0.99: print("FADED ",key,": ",entries[key].alpha)
