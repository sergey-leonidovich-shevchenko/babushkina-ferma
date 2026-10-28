extends "res://tools/qa/compatibility/farm_cursor_review.gd"

## Снимает настоящий игровой кадр запрета на дороге и работающей домашней грядки.
func _initialize() -> void:
	_capture_bounds.call_deferred()

## Использует отдельную игровую сцену и каталог, не открывая сохранения пользователя.
func _capture_bounds() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Farm-Bounds-Review")
	var container := SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	game.FarmLifeSystem.state(game).cutscene=""; game.selected_tool=game.Tool.HOE; game.settings_state.screen_shake_enabled=false
	game.current_location="overworld"; game.facing=Vector2.RIGHT
	game.player=game.BuildingSystem.VILLAGE_SQUARE.position+Vector2(140,220)-Vector2.RIGHT*42
	game.sync_background_location(); game.update_camera(); game.use_selected_tool()
	await capture("road-blocked")
	FarmingSuite.new(self).home_target(game,Vector2i(2,2)); game.update_camera()
	game.use_selected_tool(); game.selected_tool=game.Tool.SEEDS; game.use_selected_tool(); game.selected_tool=game.Tool.WATER; game.use_selected_tool()
	game.HeroActionSystem.update(game,1); await capture("home-crop")
	print("FARM BOUNDS NATIVE: road-blocked, home-crop"); quit()

## Сохраняет полный кадр без изменения масштаба и графических правок.
func capture(label: String) -> void:
	var folder := "res://docs/reports/farm-bounds-2026-10-14/"
	DirAccess.make_dir_recursive_absolute(folder)
	for _frame in 4:
		game.tutorial_visible=false; game.discovery_current={}; game.hud_message_timer=4; game.hud_last_message=game.message; game.queue_redraw()
		await process_frame; RenderingServer.force_draw()
	if viewport.get_texture().get_image().save_png(folder+label+".png")!=OK: push_error("Не удалось сохранить "+label)
