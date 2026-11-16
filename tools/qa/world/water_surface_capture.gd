# Сценарий вызывает игровую композицию с теми же ветками рендера, что и обычная сцена.
@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return"
)
extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Clock := preload("res://scripts/presentation/village_ground_clock.gd")
const Frame := preload("res://scripts/presentation/post_motion_frame.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Map := preload("res://scripts/systems/village_layout_system.gd")
const Water := preload("res://scripts/systems/water_map_registry.gd")
const Surface := preload("res://scripts/presentation/village_water_surface.gd")
const SIZE := Vector2i(1152, 648)
const START_SECONDS := 1.25
const CAMERAS := {
	"seam": Vector2(288, 18),
	"river": Vector2(1128, 660),
	"pond": Vector2(1368, 618),
}
const SOURCES := [
	"main.tscn",
	"assets/game/locations/overworld/modular/water_material_v1.png",
	"assets/game/locations/overworld/modular/riverbed_material_v1.png",
	"scripts/game_core.gd",
	"scripts/presentation/post_motion_frame.gd",
	"scripts/presentation/village_ground_clock.gd",
	"scripts/presentation/village_ground_layer.gd",
	"scripts/presentation/village_water_surface.gd",
	"scripts/presentation/village_water_surface.gdshader",
	"scripts/presentation/underwater_bottom.gd",
	"scripts/presentation/visual_reference_mode.gd",
	"scripts/systems/village_terrain_renderer.gd",
	"scripts/systems/water_map_registry.gd",
	"scripts/systems/water_topology.gd",
	"scripts/world_background.gd",
	"tools/qa/camera/visual_camera_points.gd",
	"tools/qa/world/water_surface_capture.gd",
]

var output := ""
var base := ""
var profile := ""
var viewport := SubViewport.new()
var game: Node
var background: Node
var frames: Dictionary = {}
var motion: Array[Dictionary] = []
var checks: Dictionary = {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--base-commit="):
			base = argument.trim_prefix("--base-commit=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
	if (
		DisplayServer.get_name() == "headless"
		or not output.is_absolute_path()
		or RegEx.create_from_string("^Codex-VSHORE-005-[a-zA-Z0-9-]+$").search(profile) == null
		or RegEx.create_from_string("^[a-f0-9]{40}$").search(base) == null
	):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_run.call_deferred()


## Снимает одинаковые камеры в трёх профилях. Симуляция отключена для парных кадров.
func _run() -> void:
	if (
		not OS.get_user_data_dir().ends_with(profile)
		or DirAccess.make_dir_absolute(output) != OK
		or DirAccess.make_dir_absolute(output.path_join("frames")) != OK
	):
		quit(2)
		return
	root.title = "VSHORE-005 · рябь и читаемость дна"
	root.size = SIZE
	root.show()
	root.grab_focus()
	create_timer(180.0).timeout.connect(_timed_out, CONNECT_ONE_SHOT)
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.size = Vector2(SIZE)
	root.add_child(preview)
	game = Points.create_game()
	viewport.add_child(game)
	Points.configure(game, Points.registry().points[0])
	game.settings_state.reduced_motion = false
	WorldProjection.set_reference_zoom(game, 1.2)
	Pose.reset(game)
	background = game.get_node("WorldBackground")
	var original: Dictionary = game.SaveSystem.snapshot(game)
	_camera(CAMERAS.seam)
	await _draw()
	checks["production_split"] = background.terrain_ready and background.water_layer.visible

	for place: String in CAMERAS:
		_camera(CAMERAS[place])
		for quality: String in ["static", "normal", "low"]:
			await _capture(place + "-" + quality, quality, START_SECONDS)
		await _capture(place + "-later", "normal", START_SECONDS + 1.5)
		await _capture(place + "-low-later", "low", START_SECONDS + 1.5)

	_camera(CAMERAS.seam)
	await _capture("seam-wrapped", "normal", START_SECONDS + Surface.LOOP_SECONDS)
	_camera(CAMERAS.seam + Vector2(40, 0))
	await _capture("seam-camera-shift", "normal", START_SECONDS)
	await _compare_stationary()
	checks["save_equal"] = original == game.SaveSystem.snapshot(game)
	await _motion()
	_finish()


## Меняет только проекцию; положение героя и логическое состояние остаются теми же.
func _camera(offset: Vector2) -> void:
	game.camera_offset = offset
	WorldProjection.sync_background(game)
	game.queue_redraw()


## Вызывает штатный update с завершённым игровым временем, а не изменяет шейдер напрямую.
func _apply(quality: String, seconds: float) -> void:
	game.set_meta(Clock.META, seconds)
	game.set_meta(Surface.QUALITY, quality)
	background._process(0.0)


func _capture(id: String, quality: String, seconds: float) -> void:
	_apply(quality, seconds)
	await _draw()
	var info := _save(id + ".png")
	info["quality"] = quality
	info["seconds"] = seconds
	frames[id] = info


## Проверяет, что часы остановились на модальном экране и fallback не оставляет второй слой.
func _compare_stationary() -> void:
	_camera(CAMERAS.seam)
	game.set_meta(Clock.META, START_SECONDS)
	game.set_meta(Surface.QUALITY, "normal")
	await _draw()
	var material := background.water_surface.material as ShaderMaterial
	checks["production_update"] = material != null and material.get_shader_parameter("fine_ripples")
	var phase: Vector2 = material.get_shader_parameter("ripple_offset")
	var paints: int = background.water_layer.paint_count
	var requests: int = background.terrain_requests
	game.menu_state.pause_open = true
	checks["pause_no_publish"] = not Frame.publish(game, 0.25)
	background._process(0.0)
	checks["pause_same_phase"] = phase == material.get_shader_parameter("ripple_offset")
	game.menu_state.pause_open = false
	checks["resume_publish"] = Frame.publish(game, 0.25)
	checks["resume_advance"] = is_equal_approx(Clock.seconds(game), START_SECONDS + 0.25)
	_apply("normal", START_SECONDS + 0.25)
	checks["resume_phase_changed"] = phase != material.get_shader_parameter("ripple_offset")
	checks["uniform_only"] = (
		paints == background.water_layer.paint_count and requests == background.terrain_requests
	)
	game.settings_state.reduced_motion = true
	_apply("normal", START_SECONDS)
	checks["reduced_motion_uses_static"] = background.water_surface.material == null
	game.settings_state.reduced_motion = false
	Reference.enable(game)
	_apply("normal", START_SECONDS)
	checks["reference_uses_static"] = background.water_surface.material == null
	Reference.disable(game)
	background.set_ground_split(false)
	await _draw()
	checks["unsplit_has_no_second_surface"] = (
		background.terrain_ready and not background.water_surface.is_visible_in_tree()
	)
	background.set_ground_split(true)
	await _draw()
	background.set_meta("terrain_direct", true)
	background._sync_ground_layers()
	checks["direct_has_no_second_surface"] = not background.water_surface.is_visible_in_tree()
	background.remove_meta("terrain_direct")
	background._sync_ground_layers()
	await _draw()


## Снимает рябь с места, затем проводит камеру через границу чанков x=384.
func _motion() -> void:
	var start := Vector2(268, 88)
	var finish := Vector2(472, 108)
	_camera(CAMERAS.pond)
	for index in 120:
		var segment_frame := index % 60
		var seconds := START_SECONDS + float(segment_frame) / 30.0
		if index >= 60:
			_camera(start.lerp(finish, float(segment_frame) / 59.0))
		_apply("normal", seconds)
		await RenderingServer.frame_post_draw
		var info := _save("frames/%04d.png" % index)
		info["seconds"] = seconds
		motion.append(info)


func _draw() -> void:
	for index in 2:
		await RenderingServer.frame_post_draw


func _save(file: String) -> Dictionary:
	var image := viewport.get_texture().get_image()
	var path := output.path_join(file)
	if image.get_size() != SIZE or image.save_png(path) != OK:
		checks["pngs"] = false
	return {
		"file": file,
		"sha256": FileAccess.get_sha256(path),
		"camera": Points.pair(game.camera_offset),
		"zoom": WorldProjection.zoom(game),
	}


func _timed_out() -> void:
	checks["timeout"] = false
	_finish()


func _finish() -> void:
	var sources := {}
	for path: String in SOURCES:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var cells: Array = Water.geometry("overworld").cells().keys()
	cells.sort()
	var cell_pairs := []
	for cell: Vector2i in cells:
		cell_pairs.append([cell.x, cell.y])
	var bridge_rects := []
	for index in Map.BRIDGES.size():
		var rect := Map.bridge_render_rect(index)
		bridge_rects.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	var data := {
		"task": "VSHORE-005",
		"base": base,
		"profile": profile,
		"size": [SIZE.x, SIZE.y],
		"engine": Engine.get_version_info().string,
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"sources": sources,
		"checks": checks,
		"water_cells": cell_pairs,
		"bridge_rects": bridge_rects,
		"frames": frames,
		"motion": motion,
	}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.close()
	var ok := not checks.values().has(false) and frames.size() == 17 and motion.size() == 120
	print(
		(
			"VSHORE-005: %d stills, %d motion frames; checks %s"
			% [frames.size(), motion.size(), checks]
		)
	)
	quit(0 if ok else 1)
