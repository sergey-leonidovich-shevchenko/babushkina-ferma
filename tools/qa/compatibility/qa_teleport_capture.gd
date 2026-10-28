extends SceneTree

const Scene := preload("res://main.tscn")
const Stone := preload("res://scripts/systems/qa_teleport_system.gd")
const Controls := preload("res://scripts/systems/qa_teleport_input.gd")
const FOLDER := "res://docs/reports/qa-teleport-2026-10-15/"
var game: Node2D
var viewport: SubViewport

## Запускает нативный просмотр настоящего интерфейса в отдельном пользовательском каталоге.
func _initialize() -> void:
	_start.call_deferred()

## Снимает общий список, поиск арены и результат настоящего переноса, сохраняя пользовательские слоты.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-QA-Teleport-Capture")
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var container := SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"; game.tutorial_visible=false
	game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).cutscene_timer=0
	game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true
	game.current_location="cottage_interior"; game.player=Vector2(576,420); game.sync_background_location(); game.update_camera()
	game.discovery_current.clear(); game.change_inventory_count(Stone.KIND,1)
	if not Stone.open(game): push_error("Не открылся камень QA"); quit(1); return
	await capture("selector.png")
	Stone.state(game).query="cave_sanctum"; Stone.select(game,0)
	await capture("search.png")
	if not Controls.confirm(game): push_error("Не выполнен перенос QA"); quit(1); return
	await capture("arrival.png")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale; game.settings_state.text_scale=1.2
		Stone.open(game); await capture("locale-"+locale+".png"); Stone.close(game)
	print("QA TELEPORT CAPTURE: ",Stone.locations(game).size()," locations, safe arrival=",game.current_location," at ",game.player)
	quit()

## Дожидается реальной отрисовки и сохраняет PNG без вмешательства в графику игрового кадра.
func capture(filename: String) -> void:
	game.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(FOLDER+filename)
	if error!=OK: push_error("Не сохранён кадр "+filename)
