extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Cases := preload("res://tools/qa/world/lighting/inventory_cases.gd")
const Observer := preload("res://tools/qa/world/lighting/inventory_game.gd")
const Twins := preload("res://tools/qa/world/lighting/inventory_viewports.gd")
var output := ""
var profile := ""
var variant := ""
var size := Vector2i(1152, 648)
var game: Observer
var frames: Dictionary = {}
var costs: Array[Dictionary] = []
var twins: Dictionary = {}
var failures: Array[String] = []


## Отказывает до создания игры при headless, чужом профиле или существующем выводе.
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--variant="):
			variant = argument.trim_prefix("--variant=")
		elif argument == "--wide":
			size = Vector2i(1280, 720)
	if (
		not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or FileAccess.file_exists(output)
		or not profile.begins_with("Codex-VLIGHT-001-")
		or not profile.is_valid_filename()
		or DisplayServer.get_name() == "headless"
		or variant not in ["production", "on", "off"]
	):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	if (
		OS.get_user_data_dir().get_file() != profile
		or FileAccess.file_exists("user://farm-settings.cfg")
	):
		quit(2)
		return
	_start.call_deferred()


## Снимает улицу и дом при одной камере на день/сумерки/ночь; свет не меняет погоду или HUD.
func _start() -> void:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	game = Cases.create_game(root)
	current_scene = game
	OS.low_processor_usage_mode = false
	root.title = "VLIGHT-001 | Карта света · " + variant
	for attempt: int in 3:
		root.mode = Window.MODE_WINDOWED
		root.size = size
		root.show()
		await Cases.settle(self, [game], 700)
	for group: String in ["west-lamp", "east-lamp", "home"]:
		for minutes: int in [720, 1140, 1320]:
			Cases.configure(game, group, minutes)
			game.set_meta("qa_light_inventory_off", variant == "off")
			await _capture(group + "-" + str(minutes))
	if variant == "on":
		await _measure()
		game.queue_free()
		current_scene = null
		await process_frame
		twins = await Twins.capture(self, output, size)
		var twin_errors: Variant = twins.get("failures")
		if twin_errors is not Array:
			failures.append("viewport result missing")
		else:
			var twin_failures: Array = twin_errors
			if not twin_failures.is_empty():
				failures.append("viewport controls failed")
	var document := {
		"schema": 1,
		"task": "VLIGHT-001",
		"variant": variant,
		"profile": profile,
		"user_dir": OS.get_user_data_dir(),
		"engine": Engine.get_version_info().string,
		"display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window": Points.pair(size),
		"performance_eligible": false,
		"cost_kind": "CPU draw submission; instrumentation overhead retained in both modes",
		"weather_control": "clear on day2; initialized before saved-state comparisons",
		"user_arguments": OS.get_cmdline_user_args(),
		"frames": frames,
		"costs": costs,
		"viewports": twins,
		"failures": failures
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(document, "\t") + "\n"
	)
	print("LIGHT INVENTORY NATIVE: ", frames.size(), " cases, ", failures)
	quit(0 if failures.is_empty() else 2)


## Записывает настоящую production-сцену и обе стороны полной state-проверки.
func _capture(id: String) -> void:
	await Cases.redraw(self, [game], 6)
	game.draw_records.clear()
	game.observe_draw = true
	game.observe_lights = true
	var before: Dictionary = game.SaveSystem.snapshot(game)
	await Cases.redraw(self, [game], 2)
	game.observe_draw = false
	game.observe_lights = false
	var after: Dictionary = game.SaveSystem.snapshot(game)
	var image := root.get_texture().get_image()
	var snapshot := Cases.snapshot(game, id)
	var bloom := false
	for node: Node in root.find_children("*", "WorldEnvironment", true, false):
		var environment_node := node as WorldEnvironment
		if environment_node != null and environment_node.environment != null:
			bloom = bloom or environment_node.environment.glow_enabled
	var valid := before == after and game.draw_records.size() == 2 and root.visible
	valid = valid and DisplayServer.window_get_size() == size and image.get_size() == size
	valid = valid and not bloom
	for row: Dictionary in game.draw_records:
		valid = valid and row.equal and row.geometry_equal
	if not valid or image.save_png(output.path_join(id + ".png")) != OK:
		failures.append(id + ": framebuffer/state/geometry failed")
		return
	frames[id] = {
		"snapshot": snapshot,
		"size": Points.pair(image.get_size()),
		"window": Points.pair(DisplayServer.window_get_size()),
		"visible": root.visible,
		"focused": DisplayServer.window_is_focused(),
		"bloom": bloom,
		"before": before,
		"after": after,
		"draws": game.draw_records.duplicate(true),
		"calls": game.light_calls.duplicate(true),
		"darkness": game.WorldEventSystem.darkness(game.game_minutes),
		"hud": await _capture_hud(id)
	}
	print("LIGHT FRAME: ", id)


## Снимает тот же production HUD на прозрачном native target, отдельно от меняющегося мира.
func _capture_hud(id: String) -> Dictionary:
	var background := game.get_node("WorldBackground") as CanvasItem
	var was_visible := background.visible
	var was_transparent := root.transparent_bg
	game.hud_only = true
	background.visible = false
	root.transparent_bg = true
	await Cases.redraw(self, [game], 3)
	var before: Dictionary = game.SaveSystem.snapshot(game)
	await Cases.redraw(self, [game], 2)
	var after: Dictionary = game.SaveSystem.snapshot(game)
	var image := root.get_texture().get_image()
	var filename := id + "-hud.png"
	if before != after or image.save_png(output.path_join(filename)) != OK:
		failures.append(id + ": HUD snapshot failed")
	game.hud_only = false
	background.visible = was_visible
	root.transparent_bg = was_transparent
	return {
		"file": filename, "before": before, "after": after, "size": Points.pair(image.get_size())
	}


## Сравнивает равный QA-прибор on/off по настоящим draw callbacks, без выдачи этого за GPU/FPS.
func _measure() -> void:
	for group: String in ["west-lamp", "home"]:
		Cases.configure(game, group, 1320 if group == "west-lamp" else 720)
		for repeat: int in 3:
			var modes: Array[bool] = [false, true]
			if repeat == 1:
				modes.reverse()
			for off: bool in modes:
				game.set_meta("qa_light_inventory_off", off)
				await Cases.redraw(self, [game], 8)
				var before: Dictionary = game.SaveSystem.snapshot(game)
				var id := group + ("-1320" if group == "west-lamp" else "-720")
				var snapshot := Cases.snapshot(game, id)
				game.draw_microseconds.clear()
				game.measure_draw = true
				await Cases.redraw(self, [game], 90)
				game.measure_draw = false
				var after: Dictionary = game.SaveSystem.snapshot(game)
				if before != after or game.draw_microseconds.size() < 60:
					failures.append("CPU draw sample/state failure")
				costs.append(
					{
						"group": group,
						"repeat": repeat + 1,
						"off": off,
						"samples_us": game.draw_microseconds.duplicate(),
						"before": before,
						"after": after,
						"snapshot": snapshot,
						"snapshot_after": Cases.snapshot(game, id)
					}
				)
