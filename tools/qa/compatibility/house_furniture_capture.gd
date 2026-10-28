extends SceneTree

const Scene := preload("res://main.tscn")
var game:Node2D
var viewport:SubViewport

## Снимает интерьер дома в отдельном каталоге пользователя без изменения игровых сохранений.
func _initialize() -> void:
	_start.call_deferred()

## Готовит фиксированный нативный кадр и сохраняет мебель с сеткой либо без неё.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-House-Furniture-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	game.FarmLifeSystem.state(game).cutscene=""; game.current_location="cottage_interior"; game.home_chest_owned=true
	game.player=Vector2(576,500); game.sync_background_location(); game.update_camera()
	var phase:=OS.get_environment("FARM_HOUSE_REVIEW_PHASE"); if phase.is_empty(): phase="before"
	for _frame in 8: await frame()
	var folder:="res://docs/reports/house-furniture-2026-10-14/"
	DirAccess.make_dir_recursive_absolute(folder)
	if viewport.get_texture().get_image().save_png(folder+phase+".png")!=OK: push_error("Не удалось сохранить кадр дома"); quit(1); return
	if phase=="final":
		game.FarmLifeSystem.state(game).build_mode=true; game.player=Vector2(396,480); game.facing=Vector2.UP
		for _frame in 4: await frame()
		viewport.get_texture().get_image().save_png(folder+"grid-free.png")
		game.player=Vector2(744,504); game.facing=Vector2.RIGHT
		for _frame in 4: await frame()
		viewport.get_texture().get_image().save_png(folder+"grid-blocked.png")
	print("HOUSE FURNITURE CAPTURE: "+phase); quit()

## Дожидается полного кадра графического сервера с чистым игровым интерфейсом.
func frame() -> void:
	game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.queue_redraw()
	await process_frame; RenderingServer.force_draw()
