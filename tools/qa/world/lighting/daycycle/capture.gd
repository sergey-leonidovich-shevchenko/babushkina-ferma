extends SceneTree

const Cases := preload("res://tools/qa/world/lighting/daycycle/scenarios.gd")
const Fixture := preload("res://tools/qa/world/lighting/daycycle/game.gd")
const Twins := preload("res://tools/qa/world/lighting/daycycle/viewports.gd")
const WorldSpace := preload("res://scripts/systems/world_projection_system.gd")

var output := ""
var profile := ""
var size := Vector2i(1152, 648)
var baseline := false
var game: Fixture
var frames: Dictionary = {}
var failures: Array[String] = []


## Требует новый внешний output, собственный эффективный профиль и настоящий X11 renderer.
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		elif argument == "--wide":
			size = Vector2i(1280, 720)
		elif argument == "--baseline":
			baseline = true
	if (
		not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or FileAccess.file_exists(output)
		or not profile.begins_with("Codex-VLIGHT-003-")
		or not profile.is_valid_filename()
		or OS.get_user_data_dir().get_file() != profile
		or DisplayServer.get_name() != "X11"
	):
		quit(2)
		return
	_start.call_deferred()


## Снимает обычный production root, затем контроли; CPU-серия идёт отдельно от readback.
func _start() -> void:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	root.title = "VLIGHT-003 | Calendar palette · native X11"
	root.mode = Window.MODE_WINDOWED
	root.size = size
	root.show()
	root.grab_focus()
	DisplayServer.window_move_to_foreground()
	game = Cases.create(root)
	current_scene = game
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await Cases.redraw(self, game, 10)
	for entry: Dictionary in Cases.CASES:
		Cases.configure(game, entry)
		var modes: Array[String] = ["palette"] if baseline else ["palette", "legacy", "reference"]
		for value: String in modes:
			Cases.mode(game, value)
			await _capture(str(entry.id) + "-" + value, entry)
	var costs := await Cases.measure(self, game)
	game.queue_free()
	current_scene = null
	await process_frame
	var twins := {} if baseline else await Twins.capture(self, output)
	var document := {
		"schema": 1,
		"task": "VLIGHT-003",
		"baseline": baseline,
		"engine": Engine.get_version_info().string,
		"display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"profile": profile,
		"user_dir": OS.get_user_data_dir(),
		"arguments": OS.get_cmdline_user_args(),
		"size": [size.x, size.y],
		"frames": frames,
		"costs": costs,
		"twins": twins,
		"gpu_time_measured": false,
		"hardware_fps_acceptance": false,
		"failures": failures,
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(document, "\t") + "\n"
	)
	print("DAYCYCLE NATIVE: ", frames.size(), " frames; ", failures)
	quit(0 if failures.is_empty() else 2)


## Записывает пиксели и полные состояния; неправильный global tint проверяется отдельным PNG.
func _capture(id: String, entry: Dictionary) -> void:
	await Cases.redraw(self, game, 6)
	var before := Cases.state(game)
	game.draw_records.clear()
	game.observe_draw = true
	await Cases.redraw(self, game, 2)
	game.observe_draw = false
	var row := {
		"before": before, "after": Cases.state(game), "draws": game.draw_records.duplicate(true)
	}
	row.file = _png(id + ".png")
	var screen := WorldSpace.world_to_screen(game, game.player)
	var stretch := game.get_viewport().get_stretch_transform()
	row.stretch = [
		stretch.x.x, stretch.x.y, stretch.y.x, stretch.y.y, stretch.origin.x, stretch.origin.y
	]
	row.ground = [screen.x, screen.y]
	row.hero = Cases.pixel_rect(Rect2(screen - Vector2(45, 105), Vector2(90, 130)), stretch)
	row.threat = Cases.pixel_rect(Rect2(screen + Vector2(105, -85), Vector2(125, 145)), stretch)
	game.hud_only = true
	var background := game.get_node("WorldBackground") as CanvasItem
	background.visible = false
	root.transparent_bg = true
	await Cases.redraw(self, game, 4)
	row.hud = _png(id + "-hud.png")
	game.hud_only = false
	background.visible = true
	root.transparent_bg = false
	if str(entry.id).begins_with("street-") and not id.ends_with("reference"):
		row.hidden = {}
		for target: String in ["hero", "threat"]:
			game.hidden_target = target
			await Cases.redraw(self, game, 4)
			row.hidden[target] = _png(id + "-" + target + "-hidden.png")
		game.hidden_target = ""
	if id == "street-dusk-palette" and not baseline:
		game.bad_hud = true
		await Cases.redraw(self, game, 4)
		row.bad_hud = _png(id + "-bad-hud.png")
		game.bad_hud = false
	frames[id] = row
	if before != Cases.state(game):
		failures.append(id + ": draw changed complete state")
	print("DAYCYCLE FRAME: ", id)


## Читает действительный framebuffer; ошибка размера или записи остаётся в capture.json.
func _png(filename: String) -> String:
	var image := root.get_texture().get_image()
	if image.get_size() != size or image.save_png(output.path_join(filename)) != OK:
		failures.append(filename + ": framebuffer/save failure")
	return filename
