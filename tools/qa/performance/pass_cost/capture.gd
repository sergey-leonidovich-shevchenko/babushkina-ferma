@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access"
)
extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Save := preload("res://scripts/systems/save_system.gd")
const Probe := preload("res://scripts/presentation/overworld_render_probe.gd")
const Light := preload("res://scripts/presentation/lighting_quality.gd")
const Wind := preload("res://scripts/presentation/foliage_wind.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Maintenance := preload("res://scripts/systems/runtime_maintenance_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const ROUTE := "res://docs/reports/visual-overhaul/vbase-001/native/run-1/native.json"
const SIZE := Vector2i(1152, 648)
const WARMUP := 120
const HZ := 60
const MAX_DRAWS := 180000
const PASSES := ["baseline", "water", "grass", "shadows", "light", "ui"]
const FRAME_FIELDS := [
	"usec",
	"interval_ms",
	"draw_id",
	"process_id",
	"physics_tick",
	"draw_calls",
	"static_bytes",
	"texture_bytes",
	"engine_process_ms",
	"engine_physics_ms",
	"render_ground_x",
	"render_ground_y",
	"render_camera_x",
	"render_camera_y"
]
const ROUTE_FIELDS := ["tick", "target", "x", "y", "camera_x", "camera_y", "minutes"]

var game: Node2D
var output := ""
var profile := ""
var omitted := ""
var seconds := 0
var route_only := false
var ticks := 0
var route_index := 0
var route_loops := 0
var route: Array[Vector2] = []
var corner: Array = []
var frames := PackedFloat64Array()
var trajectory := PackedFloat64Array()
var frame_count := 0
var previous_draw := 0
var first_draw := {}
var final_draw := {}
var sample_start := 0
var sample_end := 0
var begin_epoch := 0.0
var end_epoch := 0.0
var maintenance_start := 0
var initial := {}
var error := ""
var finished := false
var final_draw_pending := false
var entry_save := ""
var target_ticks := 0
var reported_vsync := -1


class RouteObserver:
	extends Node
	var capture: SceneTree

	func _physics_process(_delta: float) -> void:
		capture.record_step()


func _task_id() -> String:
	return "VPERF-003"


func _profiles() -> Array:
	return PASSES


func _configure_profile() -> void:
	if omitted in ["water", "grass", "shadows", "ui"]:
		game.set_meta(Probe.OMITTED_PASS, StringName(omitted))


## Принимает отдельный userdata и два срока. Headless пишет только пробу маршрута.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--pass="):
			omitted = argument.trim_prefix("--pass=")
		elif argument.begins_with("--seconds="):
			seconds = int(argument.trim_prefix("--seconds="))
		elif argument == "--route-only":
			route_only = true
		else:
			quit(2)
			return
	if (
		not output.is_absolute_path()
		or RegEx.create_from_string("^Codex-%s-[a-f0-9]{32}$" % _task_id()).search(profile) == null
		or omitted not in _profiles()
		or seconds not in [30, 600]
		or route_only != (DisplayServer.get_name() == "headless")
	):
		push_error("%s: неверный профиль, срок, вариант либо тип дисплея" % _task_id())
		quit(2)
		return
	_start.call_deferred()


## В режиме измерения окно и сцена полностью готовы до прогрева и начала физики.
func _start() -> void:
	if (
		OS.get_user_data_dir().get_file() != profile
		or FileAccess.file_exists(Save.SAVE_PATH)
		or FileAccess.file_exists("user://farm-settings.cfg")
		or DirAccess.dir_exists_absolute(output)
		or DirAccess.make_dir_absolute(output) != OK
	):
		push_error("%s: требуются новый каталог и подтверждённый userdata" % _task_id())
		quit(2)
		return
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTE))
	for point: Array in baseline.route_targets:
		route.append(Points.vector(point))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.title = "%s | %s | %ds" % [_task_id(), omitted, seconds]
	Engine.physics_ticks_per_second = HZ
	Engine.max_fps = 0
	game = Points.create_game()
	_configure_profile()
	root.add_child(game)
	current_scene = game
	(
		Points
		. configure(
			game,
			{
				"location": "overworld",
				"player": baseline.route_start,
				"facing": [1, 0],
				"day": 1,
				"minutes": 1200.0,
			}
		)
	)
	game.settings_state.reduced_motion = false
	WorldProjection.set_reference_zoom(game, 1.2)
	game.update_camera()
	Pose.reset(game)
	Light.set_profile(game, Light.OFF if omitted == "light" else Light.STANDARD)
	game.set_process(not route_only)
	if not route_only:
		root.mode = Window.MODE_WINDOWED
		root.size = SIZE
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		root.show()
		root.grab_focus()
		for frame in WARMUP:
			game.queue_redraw()
			await RenderingServer.frame_post_draw
		reported_vsync = DisplayServer.window_get_vsync_mode()
		initial = _conditions()
		if not initial.valid or not _png("before"):
			_abort("native window, cached terrain or framebuffer not ready")
			return
		if not _pass_matches(initial):
			_abort("selected pass is not independently disabled")
			return
		for frame in 8:
			game.queue_redraw()
			await RenderingServer.frame_post_draw
	target_ticks = seconds * HZ
	entry_save = JSON.stringify(Save.snapshot(game), "", true, true)
	trajectory.resize(target_ticks * ROUTE_FIELDS.size())
	if not route_only:
		frames.resize(MAX_DRAWS * FRAME_FIELDS.size())
		RenderingServer.frame_post_draw.connect(_record_draw)
	maintenance_start = int(Maintenance.statistics(game).get("cycles", 0))
	var observer := RouteObserver.new()
	observer.capture = self
	observer.process_physics_priority = 100
	root.add_child(observer)
	physics_frame.connect(_set_input)
	game.set_physics_process(true)
	create_timer(float(seconds) * 1.5 + 45.0).timeout.connect(_timeout)


## Повторяет принятый маршрут штатным вводом до очередного физического тика.
func _set_input() -> void:
	if finished or final_draw_pending:
		return
	if ticks == 0:
		begin_epoch = Time.get_unix_time_from_system()
		sample_start = Time.get_ticks_usec()
	var difference := route[route_index] - Vector2(game.player)
	_key(KEY_A, difference.x < -1.5, game.move_left_held)
	_key(KEY_D, difference.x > 1.5, game.move_right_held)
	_key(KEY_W, difference.y < -1.5, game.move_up_held)
	_key(KEY_S, difference.y > 1.5, game.move_down_held)


func _key(code: Key, pressed: bool, held: bool) -> void:
	if pressed == held:
		return
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	game._input(event)


## Записывает фактическую игровую опору и камеру после производственной физики.
func record_step() -> void:
	if finished or final_draw_pending:
		return
	var position: Vector2 = game.player
	var camera: Vector2 = game.camera_offset
	_store(
		trajectory,
		ticks,
		[
			ticks + 1,
			route_index,
			position.x,
			position.y,
			camera.x,
			camera.y,
			(game.day - 1) * 1440.0 + game.game_minutes,
		]
	)
	ticks += 1
	if position.distance_to(route[route_index]) <= 4.0:
		corner.append([ticks, route_index, Points.pair(position), Points.pair(camera)])
		route_index += 1
		if route_index == route.size():
			route_index = 0
			route_loops += 1
	if (
		game.current_location != "overworld"
		or game.GameLoop.modal_active(game)
		or game.GameLoop.gameplay_window_open(game)
		or (not route_only and not _window_valid())
	):
		_abort("route left the live focused first overworld")
	elif ticks == target_ticks:
		if route_only:
			_end_sample()
		else:
			# Последний физический тик завершён. Оставляем включённым сбор его кадра.
			final_draw_pending = true
			game.set_physics_process(false)


## Обозначает границу отправки кадра. Мониторы движка и CPU процесса анализируются отдельно.
func _record_draw() -> void:
	if sample_start == 0 or finished:
		return
	if frame_count >= MAX_DRAWS or not _window_valid():
		_abort("sample capacity, native window or focus changed")
		return
	var now := Time.get_ticks_usec()
	var draw_id := Engine.get_frames_drawn()
	var process_id := Engine.get_process_frames()
	if previous_draw == 0:
		first_draw = _draw_boundary(now, draw_id, process_id)
		previous_draw = now
		return
	var ground := Pose.ground(game)
	var camera: Vector2 = game.camera_offset
	_store(
		frames,
		frame_count,
		[
			now,
			(now - previous_draw) / 1000.0,
			draw_id,
			process_id,
			ticks,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.MEMORY_STATIC),
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			ground.x,
			ground.y,
			camera.x,
			camera.y,
		]
	)
	frame_count += 1
	previous_draw = now
	if final_draw_pending:
		final_draw = _draw_boundary(now, draw_id, process_id)
		_end_sample(now)


func _draw_boundary(usec: int, draw_id: int, process_id: int) -> Dictionary:
	return {"usec": usec, "draw_id": draw_id, "process_id": process_id, "physics_tick": ticks}


func _store(buffer: PackedFloat64Array, row: int, values: Array) -> void:
	for index in values.size():
		buffer[row * values.size() + index] = float(values[index])


func _window_valid() -> bool:
	return (
		DisplayServer.window_is_focused()
		and DisplayServer.window_get_size() == SIZE
		and Vector2i(root.get_texture().get_size()) == SIZE
		and root.size == SIZE
		and root.mode == Window.MODE_WINDOWED
		and DisplayServer.window_get_vsync_mode() == reported_vsync
	)


func _conditions() -> Dictionary:
	var background := game.get_node("WorldBackground")
	return {
		"valid": _window_valid() and background.terrain_ready and background.ground_split,
		"window": Points.pair(DisplayServer.window_get_size()),
		"framebuffer": Points.pair(root.get_texture().get_size()),
		"focus": DisplayServer.window_is_focused(),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"vsync_requested": DisplayServer.VSYNC_ENABLED,
		"weather": game.WorldEventSystem.weather(game),
		"water": background.water_layer.is_visible_in_tree(),
		"grass": not Probe.omits(game, Probe.GRASS) and Wind.allowed(game),
		"shadows": not Probe.omits(game, Probe.SHADOWS),
		"light": Light.profile(game) == Light.STANDARD,
		"ui": Reference.hud_visible(game),
	}


func _pass_matches(conditions: Dictionary) -> bool:
	for render_pass: String in PASSES.slice(1):
		if conditions[render_pass] != (render_pass != omitted):
			return false
	return true


func _png(name: String) -> bool:
	var image := root.get_texture().get_image()
	return image.get_size() == SIZE and image.save_png(output.path_join(name + ".png")) == OK


func _timeout() -> void:
	if not finished:
		_abort("native capture timeout")


func _abort(reason: String) -> void:
	error = reason
	_end_sample()


func _end_sample(last_draw_usec: int = 0) -> void:
	finished = true
	sample_end = last_draw_usec if last_draw_usec > 0 else Time.get_ticks_usec()
	end_epoch = Time.get_unix_time_from_system()
	game.set_physics_process(false)
	_finish.call_deferred()


## Весь файловый вывод и копирование framebuffer выполняются после остановки таймеров.
func _finish() -> void:
	game.clear_movement_keys()
	game.set_process(false)
	var final := {}
	if not route_only and error.is_empty():
		game.queue_redraw()
		await RenderingServer.frame_post_draw
		final = _conditions()
		if not final.valid or not _pass_matches(final) or not _png("after"):
			error = "native end frame or independent pass changed"
	if route_loops == 0 and error.is_empty():
		error = "route never reached all 16 checkpoints"
	_write_csv("trajectory", ROUTE_FIELDS, trajectory, ticks)
	_write_csv("frames", FRAME_FIELDS, frames, frame_count)
	_write("save-before.json", entry_save)
	_write("save-after.json", JSON.stringify(Save.snapshot(game), "", true, true))
	var metadata := {
		"schema": 2,
		"task": _task_id(),
		"pass": omitted,
		"seconds": seconds,
		"route_only": route_only,
		"error": error,
		"tick_count": ticks,
		"draw_count": frame_count,
		"route_start_end": route_loops,
		"checkpoints": corner,
		"profile": profile,
		"pid": OS.get_process_id(),
		"initial": initial,
		"final": final,
		"engine": Engine.get_version_info().string,
		"engine_build": Engine.get_version_info().hash,
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"display": DisplayServer.get_name(),
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"world_scale": WorldProjection.zoom(game),
		"physics_hz": Engine.physics_ticks_per_second,
		"fps_cap": Engine.max_fps,
		"warmup_draws": WARMUP,
		"gpu_time_ms": null,
		"seed": game.world_loot_seed,
		"sample_start_usec": sample_start,
		"sample_end_usec": sample_end,
		"first_draw": first_draw,
		"final_draw": final_draw,
		"utc_started": begin_epoch,
		"utc_ended": end_epoch,
		"frame_boundary": "frame_post_draw",
		"maintenance_cycles":
		int(Maintenance.statistics(game).get("cycles", 0)) - maintenance_start,
		"weather": game.WorldEventSystem.weather(game),
		"retained_interval_count": frame_count,
		"observer_buffer_bytes": (frames.size() + trajectory.size()) * 8,
		"audio_enabled": game.audio_enabled,
		"reduced_motion": game.settings_state.reduced_motion,
	}
	_write("run.json", JSON.stringify(metadata) + "\n")
	print(_task_id(), " ", omitted, " ", ticks, " ticks / ", frame_count, " intervals ", error)
	quit(0 if error.is_empty() else 2)


func _write_csv(name: String, fields: Array, buffer: PackedFloat64Array, count: int) -> void:
	var file := FileAccess.open(output.path_join(name + ".csv"), FileAccess.WRITE)
	file.store_line(",".join(fields))
	for row in count:
		var parts := PackedStringArray()
		for index in fields.size():
			parts.append(str(buffer[row * fields.size() + index]))
		file.store_line(",".join(parts))


func _write(name: String, content: String) -> void:
	FileAccess.open(output.path_join(name), FileAccess.WRITE).store_string(content)
