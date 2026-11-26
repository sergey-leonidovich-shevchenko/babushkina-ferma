# The major scene exposes its gameplay API through a dynamic Node facade.
@warning_ignore_start("unsafe_call_argument", "unsafe_method_access", "unsafe_property_access")
extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Basement := preload("res://scripts/systems/basement_system.gd")
const Build := preload("res://scripts/systems/basement_construction_system.gd")
const Art := preload("res://scripts/presentation/basement_visual_system.gd")
const Stations := preload("res://scripts/systems/artisan_data.gd")
const SIZE := Vector2i(1152, 648)
const READY_DRAWS := 8
const READY_MIN_MS := 500
const READY_TIMEOUT_MS := 8000
const FOCUS_RETRY_MS := 250
const SLOT := "user://vperf-005-workshop.json"

var game: Node
var output := ""
var profile := ""
var completed_draws := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
	_start.call_deferred()


func _start() -> void:
	if (
		DisplayServer.get_name() != "X11"
		or not profile.begins_with("Codex-VPERF-005-")
		or OS.get_user_data_dir().get_file() != profile
		or FileAccess.file_exists("user://farm-settings.cfg")
		or output.is_empty()
		or DirAccess.make_dir_absolute(output) != OK
	):
		_abort("native X11 and fresh output/profile required")
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.show()
	game = Points.create_game()
	root.add_child(game)
	current_scene = game
	Points.configure(game, Points.registry().points[0])
	WorldProjection.set_reference_zoom(game, 1.2)
	game.player = Vector2(600.25, 700.25)
	game.update_camera()
	Pose.reset(game)
	if not await _frame("overworld"):
		return
	var receipt := {
		"startup_cached": _resident_atlases(),
		"overworld": Points.snapshot(game, Points.registry().points[0]),
		"profile": profile,
	}
	game.current_location = Basement.Data.LOCATION
	game.player = Basement.Data.BOARD
	Basement.open(game)
	Basement.ui(game).placing = true
	var kind := "fruit_press"
	var inputs: Dictionary[String, int] = {}
	inputs.assign(Basement.Data.STATIONS[kind].inputs)
	for material: String in inputs:
		game.change_inventory_count(material, inputs[material])
	if not Build.build(game, {"kind": kind, "x": 25, "y": 16, "direction": 0}):
		_abort("production blueprint refused construction")
		return
	var item: Dictionary = Basement.state(game).objects[0]
	game.player = Basement.Layout.center(Basement.Layout.approach_cell(item))
	game.tutorial_visible = false
	game.message = ""
	game.sync_background_location()
	game.sync_background_environment()
	game.update_camera()
	Pose.reset(game)
	if not await _frame("workshop"):
		return
	receipt["after_workshop_draw"] = _resident_atlases()
	receipt["workshop_camera"] = Points.pair(game.camera_offset)
	var before: Dictionary = Basement.state(game).duplicate(true)
	if not game.SaveSystem.save_at(game, SLOT):
		_abort("production slot write rejected")
		return
	Basement.state(game).objects.clear()
	if (
		not game.SaveSystem.load_at(game, SLOT)
		or not same_workshop_state(before, Basement.state(game))
	):
		_abort("production slot reload changed the unfinished workshop")
		return
	receipt["workshop_save"] = before
	var textures := {}
	for station: String in Stations.STATIONS:
		var atlas := Art.texture(station, 1, 0).atlas
		var image := atlas.get_image()
		var pixels := image.get_data()
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(pixels)
		textures[atlas.resource_path] = {
			"size": Points.pair(image.get_size()),
			"image_format": image.get_format(),
			"mipmaps": image.has_mipmaps(),
			"decoded_bytes": pixels.size(),
			"decoded_sha256": digest.finish().hex_encode(),
		}
	receipt["atlas_readback"] = textures
	var result := FileAccess.open(output.path_join("witness.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify(receipt) + "\n")
	quit()


## Сравнивает все поля по той же семантике JSON, что и файл сохранения.
static func same_workshop_state(before: Dictionary, after: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(before)) == JSON.parse_string(JSON.stringify(after))


func _resident_atlases() -> Array[String]:
	var result: Array[String] = []
	for kind: String in Stations.STATIONS:
		var path := "res://assets/game/artisan/%s_atlas_a.png" % kind
		if ResourceLoader.has_cached(path):
			result.append(path)
	result.sort()
	return result


func _frame(label: String) -> bool:
	var observed := await _settle_window(label)
	if observed.ready != true:
		var reason := "no_draw_callbacks" if observed.callbacks == 0 else "readiness_timeout"
		_report_frame_failure(label, reason, observed)
		return false
	var image := root.get_texture().get_image()
	var final := _window_state()
	observed["after_readback"] = final
	observed["readback"] = null if image == null else Points.pair(image.get_size())
	if not _window_ready(final) or image == null or image.is_empty() or image.get_size() != SIZE:
		_report_frame_failure(label, "invalid_readback", observed)
		return false
	var status := image.save_png(output.path_join(label + ".png"))
	if status != OK:
		observed["png_error"] = status
		_report_frame_failure(label, "png_write_failed", observed)
		return false
	return true


## Ждёт устойчивого нативного окна после инициализации игры или смены комнаты.
func _settle_window(label: String) -> Dictionary:
	print("VPERF-005 window start ", label, " ", JSON.stringify(_window_state()))
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.show()
	root.grab_focus()
	completed_draws = 0
	RenderingServer.frame_post_draw.connect(_record_draw)
	var started := Time.get_ticks_msec()
	var deadline := started + READY_TIMEOUT_MS
	var focus_retry := started + FOCUS_RETRY_MS
	var stable := 0
	var observed_draws := 0
	var observed := _window_state()
	var ready := false
	var elapsed := 0
	while Time.get_ticks_msec() < deadline and not ready:
		game.queue_redraw()
		# Срок ожидания истечёт даже без сигналов рендера, если процессный цикл работает.
		await process_frame
		observed = _window_state()
		var now := Time.get_ticks_msec()
		elapsed = now - started
		var valid := _window_ready(observed)
		if not valid:
			stable = 0
		if completed_draws != observed_draws:
			observed_draws = completed_draws
			if valid:
				stable += 1
			ready = stable >= READY_DRAWS and elapsed >= READY_MIN_MS and now < deadline
		if observed.focus == false and now >= focus_retry and now < deadline:
			root.grab_focus()
			focus_retry = now + FOCUS_RETRY_MS
	RenderingServer.frame_post_draw.disconnect(_record_draw)
	observed["stable_draws"] = stable
	observed["callbacks"] = completed_draws
	observed["elapsed_ms"] = elapsed
	observed["ready"] = ready
	return observed


func _record_draw() -> void:
	completed_draws += 1


func _window_state() -> Dictionary:
	var texture := root.get_texture()
	return {
		"display": DisplayServer.get_name(),
		"focus": DisplayServer.window_is_focused(),
		"visible": root.visible,
		"host_size": Points.pair(DisplayServer.window_get_size()),
		"window_size": Points.pair(root.size),
		"viewport": Points.pair(root.get_visible_rect().size),
		"framebuffer": null if texture == null else Points.pair(texture.get_size()),
		"window_mode": root.mode,
	}


func _window_ready(observed: Dictionary) -> bool:
	var expected := Points.pair(SIZE)
	return (
		observed.display == "X11"
		and observed.focus == true
		and observed.visible == true
		and observed.host_size == expected
		and observed.window_size == expected
		and observed.viewport == expected
		and observed.framebuffer == expected
		and observed.window_mode == Window.MODE_WINDOWED
	)


func _report_frame_failure(label: String, reason: String, observed: Dictionary) -> void:
	var failure := {
		"frame": label,
		"reason": reason,
		"expected_size": Points.pair(SIZE),
		"observed": observed,
	}
	var file := FileAccess.open(output.path_join("window-error.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(failure) + "\n")
		file.flush()
	_abort("X11 witness " + JSON.stringify(failure))


func _abort(reason: String) -> void:
	push_error("VPERF-005: " + reason)
	quit(2)
