extends "res://tools/livestock_review.gd"

const Scene := preload("res://main.tscn")
const FarmingSuite := preload("res://tests/suites/world_farming_suite.gd")
const FOLDER := "res://docs/reports/farm-cursor-2026-10-14/"
var game: Node2D
var viewport: SubViewport

## Запускает прежние сценарии земледелия либо нативное сравнение рамки перед героем.
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		FarmingSuite.new(self).run(); print("FARM CURSOR REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
	else: _capture.call_deferred()

## Снимает героя перед настоящей доступной клеткой и проверяет видимость посаженной культуры после удаления рамки.
func _capture() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Farm-Cursor-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	game.FarmLifeSystem.state(game).cutscene=""; game.selected_tool=game.Tool.HOE; game.settings_state.screen_shake_enabled=false
	var suite:=FarmingSuite.new(self); suite.home_target(game,Vector2i.ZERO)
	game.sync_background_location(); game.update_camera(); DirAccess.make_dir_recursive_absolute(FOLDER)
	var phase:=OS.get_environment("FARM_CURSOR_PHASE"); if phase.is_empty(): phase="before"
	await capture(phase)
	if phase=="after":
		game.use_selected_tool(); game.selected_tool=game.Tool.SEEDS; game.use_selected_tool(); game.selected_tool=game.Tool.WATER; game.use_selected_tool()
		game.HeroActionSystem.update(game,1); await capture("after-crop")
	print("FARM CURSOR NATIVE: "+phase); quit()

## Сохраняет полный кадр без обрезки, изменения масштаба и чтения игровых слотов пользователя.
func capture(label: String) -> void:
	for _frame in 4:
		game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
		await process_frame; RenderingServer.force_draw()
	if viewport.get_texture().get_image().save_png(FOLDER+label+".png")!=OK: push_error("Не удалось сохранить "+label)
