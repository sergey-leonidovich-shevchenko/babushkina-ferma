extends SceneTree

const Cases := preload("res://tools/qa/world/weather/scenarios.gd")
const Fixture := preload("res://tools/qa/world/weather/game.gd")

var output := ""
var profile := ""
var width := 1152
var frames: Dictionary = {}
var twins: Dictionary = {}


## Допускает только новый внешний output, собственный профиль и удалённый X11-дисплей.
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		elif arg == "--wide":
			width = 1280
	if (
		DisplayServer.get_name() != "X11"
		or not profile.begins_with("Codex-VWEATHER-001-")
		or OS.get_user_data_dir().get_file() != profile
		or not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or FileAccess.file_exists(output)
	):
		quit(2)
		return
	_start.call_deferred()


## Сравнивает реальные кадры по обе стороны настенного ожидания и физической паузы.
func _start() -> void:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	root.title = "VWEATHER-001 | pause clock · native X11"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(width, width * 9 / 16)
	root.show()
	root.grab_focus()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for weather: String in ["clear", "rain", "snow", "storm"]:
		await _weather(weather)
	await _twins()
	var document := {
		"schema": 1,
		"task": "VWEATHER-001",
		"engine": Engine.get_version_info().string,
		"display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"profile": profile,
		"user_dir": OS.get_user_data_dir(),
		"arguments": OS.get_cmdline_user_args(),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"frames": frames,
		"twins": twins,
		"hardware_fps_acceptance": false,
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(document, "\t") + "\n"
	)
	print("WEATHER NATIVE: ", frames.size(), " frames; ", twins.size(), " twin steps")
	quit()


## Ясно/дождь/снег/гроза используют настоящий календарный прогноз и один рисунок.
func _weather(weather: String) -> void:
	var game := Cases.create(root, weather)
	current_scene = game
	await _redraw(game, 12)
	await _capture(weather + "-full", game)
	Cases.isolated(game, true)
	await _capture(weather + "-cold", game)
	Cases.tick(game, 2)
	game.menu_state.pause_open = true
	await _capture(weather + "-pause-a", game)
	await create_timer(0.18).timeout
	Cases.tick(game, 3)
	await _capture(weather + "-pause-b", game)
	game.menu_state.pause_open = false
	Cases.tick(game)
	await _capture(weather + "-resume", game)
	game.settings_state.reduced_motion = true
	Cases.tick(game)
	await _capture(weather + "-reduced-a", game)
	await create_timer(0.18).timeout
	Cases.tick(game, 3)
	await _capture(weather + "-reduced-b", game)
	game.settings_state.reduced_motion = false
	game.BuildingSystem.enter(game, "cottage")
	await _capture(weather + "-interior", game)
	Cases.tick(game)
	game.BuildingSystem.leave(game)
	await _capture(weather + "-return", game)
	game.queue_free()
	current_scene = null
	await process_frame


## Readback сохраняет реальные callbacks, полный save, wall-time и размеры framebuffer.
func _capture(id: String, game: Fixture) -> void:
	var before := Cases.state(game)
	var count := game.draw_count
	var wall := Time.get_ticks_usec()
	await _redraw(game, 3)
	var image := root.get_texture().get_image()
	var error := image.save_png(output.path_join(id + ".png"))
	frames[id] = {
		"file": id + ".png",
		"before": before,
		"after": Cases.state(game),
		"draws": game.draw_count - count,
		"wall_start_usec": wall,
		"wall_end_usec": Time.get_ticks_usec(),
		"size": [image.get_width(), image.get_height()],
		"png_error": error,
	}


## Даёт настоящему renderer завершить кадры; время игры вручную не изменяет.
func _redraw(game: Fixture, count: int) -> void:
	for index: int in count:
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw


## Два настоящих viewport получают разные разрешённые такты и одну независимую паузу.
func _twins() -> void:
	var views: Array[SubViewport] = []
	var games: Array[Fixture] = []
	for index: int in 2:
		var view := SubViewport.new()
		view.size = Vector2i(640, 360)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
		var game := Cases.create(view, "rain")
		games.append(game)
		Cases.isolated(game, true)
		Cases.tick(game, index + 1)
	for step: int in 2:
		if step == 1:
			games[0].menu_state.pause_open = true
			Cases.tick(games[0])
			Cases.tick(games[1])
			await create_timer(0.18).timeout
		var rows: Array[Dictionary] = []
		for index: int in 2:
			var game := games[index]
			var before := Cases.state(game)
			var count := game.draw_count
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var image := views[index].get_texture().get_image()
			var filename := "twin-" + str(step) + "-" + str(index) + ".png"
			(
				rows
				. append(
					{
						"file": filename,
						"before": before,
						"after": Cases.state(game),
						"draws": game.draw_count - count,
						"png_error": image.save_png(output.path_join(filename)),
						"size": [image.get_width(), image.get_height()],
					}
				)
			)
		twins[str(step)] = rows
	for view: SubViewport in views:
		view.queue_free()
	await process_frame
