extends SceneTree

const Cases := preload("res://tools/qa/world/rollback/cases.gd")
const Game := preload("res://tools/qa/world/rollback/game.gd")
var output := ""
var profile := ""
var size := Vector2i(1152, 648)
var frames := []
var errors := []


## Не позволяет выдать headless или локальный Mac за нативный CI/remote readback.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		elif arg == "--wide":
			size = Vector2i(1280, 720)
	if (
		OS.get_name() != "Linux"
		or DisplayServer.get_name() != "X11"
		or output.is_empty()
		or DirAccess.dir_exists_absolute(output)
		or not profile.begins_with("Codex-VCOMPAT-010-")
		or "/" in profile
		or "\\" in profile
		or OS.get_user_data_dir().get_file() != profile
	):
		quit(2)
		return
	_start.call_deferred()


## Снимает весь набор в настоящей игре: разные участки, вечер, старый слот, повтор и
## независимые владельцы.
func _start() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game := Cases.create(root)
	current_scene = game
	root.mode = Window.MODE_WINDOWED
	root.size = size
	root.show()
	await _redraw(game, 10)
	for id: String in Cases.CAMERAS:
		var point: Vector2 = Cases.CAMERAS[id]
		Cases.camera(game, point)
		game.settings_state.reduced_motion = id != "west-bank"
		if id == "west-bank":
			game._physics_process(0.02)
		await _triplet(game, id)
	game.settings_state.reduced_motion = true
	Cases.camera(game, Cases.CAMERAS["east-bank"], 1170.0)
	await _triplet(game, "evening")
	var fixture := "res://tests/fixtures/saves/v1-core.json"
	var original_hash := FileAccess.get_sha256(fixture)
	if not game.SaveSystem.load_at(game, fixture):
		errors.append("old fixture did not load")
	game.title_screen = false
	game.language_screen = false
	game.update_camera()
	await _shot(game, "old-interior-on", true)
	await _shot(game, "old-interior-off", false)
	if not game.BuildingSystem.leave(game):
		errors.append("ordinary house exit failed")
	game.game_minutes = 720.0
	game.day = 1
	game.sync_background_environment()
	await _triplet(game, "old-return")
	if FileAccess.get_sha256(fixture) != original_hash:
		errors.append("original old fixture changed")
	Cases.camera(game, Cases.CAMERAS["square"])
	await _shot(game, "repeat-before", true)
	for repeat in 8:
		Cases.toggle(game, false)
		await _redraw(game, 3)
		Cases.toggle(game, true)
		await _redraw(game, 3)
	await _shot(game, "repeat-after", true)
	await _twins()
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		(
			JSON.stringify(
				{
					"task": "VCOMPAT-010",
					"profile": profile,
					"user_dir": OS.get_user_data_dir(),
					"display": DisplayServer.get_name(),
					"renderer": RenderingServer.get_current_rendering_method(),
					"engine": Engine.get_version_info().string,
					"window": Cases.Points.pair(size),
					"performance_eligible": false,
					"frames": frames,
					"errors": errors
				}
			)
			+ "\n"
		)
	)
	print("ROLLBACK NATIVE: ", frames.size(), " frames; ", errors)
	quit(0 if errors.is_empty() else 2)


## Возвращает тот же профиль и кадр после настоящего отключения с очисткой кеша.
func _triplet(game: Game, id: String) -> void:
	await _shot(game, id + "-on", true)
	await _shot(game, id + "-off", false)
	await _shot(game, id + "-restore", true)


## Сохраняет полный framebuffer, два callbacks и весь игровой snapshot без обрезки или
## синтетической картинки.
func _shot(
	game: Game, id: String, modern: bool, viewport: Viewport = null, apply_toggle: bool = true
) -> void:
	if apply_toggle:
		Cases.toggle(game, modern)
	await _redraw(game, 10)
	var before := Cases.state(game)
	var draws := game.draws
	await _redraw(game, 2)
	var target := viewport if viewport != null else root
	var image := target.get_texture().get_image()
	var after := Cases.state(game)
	var filename := id + ".png"
	var result := image.save_png(output.path_join(filename))
	frames.append(
		{
			"id": id,
			"file": filename,
			"before": before,
			"after": after,
			"draws": game.draws - draws,
			"size": [image.get_width(), image.get_height()],
			"window": Cases.Points.pair(DisplayServer.window_get_size()),
			"visible": root.visible,
			"png_error": result
		}
	)
	if (
		result != OK
		or before != after
		or game.draws - draws < 2
		or before.processing
		or before.reference_mode
	):
		errors.append(id + ": changed game, reference mode or missing native draw")
	print("ROLLBACK FRAME ", id)


## Разворачивает два собственных viewport одновременно и меняет профиль только у одного владельца.
func _twins() -> void:
	var views: Array[SubViewport] = []
	var games: Array[Game] = []
	for index in 2:
		ProjectSettings.set_setting("rendering/visual_overhaul/enabled", index == 1)
		var view := SubViewport.new()
		view.size = Vector2i(640, 360)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
		games.append(Cases.create(view))
		Cases.camera(games[index], Cases.CAMERAS["square"])
		await _shot(
			games[index], "startup-on" if index == 1 else "startup-off", index == 1, view, false
		)
	ProjectSettings.set_setting("rendering/visual_overhaul/enabled", true)
	for step in 2:
		for index in 2:
			await _shot(
				games[index], "twin-" + str(step) + "-" + str(index), index == step, views[index]
			)
	for view in views:
		view.queue_free()
	await process_frame


## Ждёт реальные draw-callbacks без прокручивания игровой симуляции или подстановки времени.
func _redraw(game: Game, count: int) -> void:
	for index in count:
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
