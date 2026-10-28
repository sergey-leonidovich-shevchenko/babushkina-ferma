extends SceneTree

const Scene := preload("res://main.tscn")

## Показывает настоящий сохранённый итог сквозного маршрута без выдачи ресурсов и изменения сохранения.
func _initialize() -> void:
	_start.call_deferred()

## Загружает проверочный слот в настоящую сцену и сохраняет контрольный кадр после прогрева GPU.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-MoonValley-E2E-Capture")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1152,648)
	var game:Node2D=Scene.instantiate(); root.add_child(game); current_scene=game
	game.set_physics_process(false); game.set_process(false)
	if not game.SaveSystem.load_at(game,"res://docs/reports/end-to-end-final-save-2026-10-12.json"):
		push_error("Нет успешного итогового слота сквозного маршрута"); quit(1); return
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1152,648)
	for _frame in 8:
		game.queue_redraw(); await RenderingServer.frame_post_draw
	var output:="res://docs/reports/end-to-end-victory-2026-10-12.png"
	var error:=root.get_texture().get_image().save_png(output)
	print("END TO END CAPTURE: "+("PASS" if error==OK else "FAIL")); quit(0 if error==OK else 1)
