extends SceneTree

const Cases := preload("res://tools/qa/world/lighting/quality/cases.gd")
const Fixture := preload("res://tools/qa/world/lighting/quality/game.gd")
const Measure := preload("res://tools/qa/world/lighting/quality/measure.gd")
const Twins := preload("res://tools/qa/world/lighting/quality/viewports.gd")

var output := ""
var profile := ""
var size := Vector2i(1152, 648)
var baseline := false
var game: Fixture
var frames: Dictionary = {}
var restores: Dictionary = {}
var failures: Array[String] = []


## Разрешает съёмку только новому внешнему каталогу, отдельному userdata и настоящему X11.
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
		or not profile.begins_with("Codex-VLIGHT-010-")
		or not profile.is_valid_filename()
		or OS.get_user_data_dir().get_file() != profile
		or OS.get_name() != "Linux"
		or DisplayServer.get_name() != "X11"
	):
		quit(2)
		return
	_start.call_deferred()


## Сохраняет неизменённый production root и отдельные контроли; стоимость измеряется без PNG.
func _start() -> void:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	root.title = "VLIGHT-010 | Lighting quality · native X11"
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
	for entry: Dictionary in Cases.ENTRIES:
		Cases.configure(game, entry)
		for selected: String in Cases.modes(baseline):
			Cases.mode(game, selected, baseline)
			await _capture(str(entry.id) + "-" + selected)
		if not baseline:
			Cases.mode(game, "standard", false)
			await Cases.redraw(self, game, 6)
			var before := Cases.state(game, false)
			restores[entry.id] = {
				"file": _png(str(entry.id) + "-restored.png"),
				"before": before,
				"after": Cases.state(game, false),
			}
	var costs := await Measure.capture(self, game, baseline)
	game.queue_free()
	current_scene = null
	await process_frame
	var twins := {} if baseline else await Twins.capture(self, output)
	var document := {
		"schema": 1,
		"task": "VLIGHT-010",
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
		"restores": restores,
		"costs": costs,
		"twins": twins,
		"gpu_time_measured": false,
		"hardware_fps_acceptance": false,
		"failures": failures,
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(document, "\t") + "\n"
	)
	print("LIGHT QUALITY NATIVE: ", frames.size(), " frames; ", failures)
	quit(0 if failures.is_empty() else 2)


## Читаемость целей проверяет их production ROI без действительного прохода отрисовки.
func _capture(id: String) -> void:
	await Cases.redraw(self, game, 6)
	var before := Cases.state(game, baseline)
	game.draw_records.clear()
	game.observe_draw = true
	await Cases.redraw(self, game, 2)
	game.observe_draw = false
	var row := {
		"before": before,
		"after": Cases.state(game, baseline),
		"draws": game.draw_records.duplicate(true),
		"file": _png(id + ".png"),
		"targets": {},
		"hidden": {},
		"hidden_passes": {},
	}
	var window := DisplayServer.window_get_size()
	row.observation = {
		"window": [window.x, window.y],
		"visible": root.visible,
		"focused": DisplayServer.window_is_focused(),
		"process_frame": Engine.get_process_frames(),
		"tick_us": Time.get_ticks_usec(),
	}
	var targets := Cases.targets(game)
	for target: String in ["door", "enemy", "resource"]:
		var world: Rect2 = targets[target]
		row.targets[target] = {
			"world": [world.position.x, world.position.y, world.size.x, world.size.y],
			"native": Cases.native_rect(game, world),
		}
	var stretch := game.get_viewport().get_stretch_transform()
	row.stretch = [
		stretch.x.x, stretch.x.y, stretch.y.x, stretch.y.y, stretch.origin.x, stretch.origin.y
	]
	var background := game.get_node("WorldBackground") as CanvasItem
	for target: String in ["door", "enemy", "resource"]:
		game.hidden_target = target
		game.hidden_passes.clear()
		await Cases.redraw(self, game, 4)
		row.hidden[target] = _png(id + "-" + target + "-hidden.png")
		row.hidden_passes[target] = game.hidden_passes.duplicate()
	game.hidden_target = ""
	game.hud_only = true
	background.visible = false
	root.transparent_bg = true
	await Cases.redraw(self, game, 4)
	row.hud = _png(id + "-hud.png")
	game.hud_only = false
	background.visible = true
	root.transparent_bg = false
	if id == "street-dusk-standard" and not baseline:
		game.bad_hud = true
		await Cases.redraw(self, game, 4)
		row.bad_hud = _png(id + "-bad-hud.png")
		game.bad_hud = false
	frames[id] = row
	if before != Cases.state(game, baseline):
		failures.append(id + ": draw changed complete gameplay/owner state")
	print("LIGHT QUALITY FRAME: ", id)


## Записывает действительный framebuffer без resize; ошибка размера/PNG остаётся отказом.
func _png(filename: String) -> String:
	var image := root.get_texture().get_image()
	if image.get_size() != size:
		failures.append(filename + ": physical framebuffer differs")
	if image.save_png(output.path_join(filename)) != OK:
		failures.append(filename + ": PNG save failed")
	return filename
