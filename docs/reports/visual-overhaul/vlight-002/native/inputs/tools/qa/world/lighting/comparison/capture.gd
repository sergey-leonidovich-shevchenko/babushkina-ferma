extends SceneTree

const Scenarios := preload("res://tools/qa/world/lighting/comparison/scenarios.gd")
const Fixture := preload("res://tools/qa/world/lighting/comparison/fixture.gd")
const ExistingObserver := preload("res://tools/qa/world/lighting/inventory_game.gd")
const ExistingCases := preload("res://tools/qa/world/lighting/inventory_cases.gd")
const Isolation := preload("res://tools/qa/world/lighting/comparison/viewports.gd")

var output := ""
var profile := ""
var size := Vector2i(1152, 648)
var world: Fixture
var hud: ExistingObserver
var frames: Dictionary = {}
var failures: Array[String] = []


## Не допускает headless, обычный профиль, перезапись сырья или неизвестный режим запуска.
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		elif argument == "--wide":
			size = Vector2i(1280, 720)
	if (
		not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or FileAccess.file_exists(output)
		or not profile.begins_with("Codex-VLIGHT-002-")
		or not profile.is_valid_filename()
		or DisplayServer.get_name() == "headless"
	):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	if OS.get_user_data_dir().get_file() != profile:
		quit(2)
		return
	_start.call_deferred()


## Сначала записывает неподвижные PNG; затем отдельную серию времени без image readback.
func _start() -> void:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	root.title = "VLIGHT-002 | Один фонарь · маска / PointLight2D"
	root.mode = Window.MODE_WINDOWED
	root.size = size
	root.show()
	root.grab_focus()
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	world = Scenarios.create(root, false) as Fixture
	hud = Scenarios.create(root, true)
	current_scene = world
	# macOS применяет начальный размер асинхронно; ожидание совпадает с принятым прибором001.
	for attempt: int in 3:
		root.mode = Window.MODE_WINDOWED
		root.size = size
		await ExistingCases.settle(self, [world, hud], 700)
	# Фиксируем режим после bootstrap; сохраняется и фактическое значение в raw samples.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for room: String in ["west-lamp", "home"]:
		for minute: int in [720, 1140, 1320]:
			Scenarios.configure(world, hud, room, minute)
			await Scenarios.redraw(self, world, hud, 10)
			for mode: String in ["off", "mask", "local", "shadow"]:
				world.configure_light(mode)
				await _capture(room + "-" + str(minute) + "-" + mode)
				if not failures.is_empty():
					_finish([], {})
					return
	var costs := await Scenarios.measure(self, world, hud)
	world.queue_free()
	hud.get_parent().queue_free()
	current_scene = null
	await process_frame
	var isolation := await Isolation.capture(self, output, size)
	_finish(costs, isolation)


## Сохраняет и неполный фактический результат отказа, не продолжая бессмысленную временную серию.
func _finish(costs: Array[Dictionary], isolation: Dictionary) -> void:
	var document := {
		"schema": 1,
		"task": "VLIGHT-002",
		"profile": profile,
		"user_dir": OS.get_user_data_dir(),
		"user_arguments": OS.get_cmdline_user_args(),
		"engine": Engine.get_version_info().string,
		"display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"window": [size.x, size.y],
		"engine_max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"frames": frames,
		"costs": costs,
		"viewports": isolation,
		"gpu_time_measured": false,
		"hardware_fps_acceptance": false,
		"cost_kind":
		"CPU draw submission + native QA frame intervals; frozen simulation; no readback",
		"failures": failures
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(document, "\t") + "\n"
	)
	print("LANTERN COMPARISON NATIVE: ", frames.size(), " cases, ", failures)
	quit(0 if failures.is_empty() else 2)


## Полный root framebuffer включает живой HUD на отдельном CanvasLayer, исключённом из света.
func _capture(id: String) -> void:
	await Scenarios.redraw(self, world, hud, 6)
	var before := Scenarios.state(world, hud)
	world.draw_records.clear()
	world.observe_draw = true
	await Scenarios.redraw(self, world, hud, 2)
	world.observe_draw = false
	var after := Scenarios.state(world, hud)
	var image := root.get_texture().get_image()
	var filename := id + ".png"
	var png_error := image.save_png(output.path_join(filename))
	if (
		before != after
		or image.get_size() != size
		or DisplayServer.window_get_size() != size
		or png_error != OK
	):
		failures.append(id + ": save/framebuffer failure")
	world.visible = false
	var background := root.transparent_bg
	root.transparent_bg = true
	await Scenarios.redraw(self, world, hud, 3)
	var hud_image := root.get_texture().get_image()
	var hud_file := id + "-hud.png"
	if hud_image.save_png(output.path_join(hud_file)) != OK:
		failures.append(id + ": HUD PNG failure")
	world.visible = true
	root.transparent_bg = background
	frames[id] = {
		"file": filename,
		"hud_file": hud_file,
		"before": before,
		"after": after,
		"light": world.light_state(),
		"draws": world.draw_records.duplicate(true),
		"visible": root.visible,
		"focused": DisplayServer.window_is_focused(),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	}
	print("LANTERN FRAME: ", id)
