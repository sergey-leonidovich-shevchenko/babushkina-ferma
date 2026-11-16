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
const LATER_SECONDS := START_SECONDS + 20.0 / 3.0
const CAMERAS := {
	"upper": Vector2(288, 18),
	"lower": Vector2(700, 540),
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
	"scripts/presentation/village_river_flow.gd",
	"scripts/presentation/village_water_surface.gd",
	"scripts/presentation/village_water_surface.gdshader",
	"scripts/presentation/underwater_bottom.gd",
	"scripts/presentation/visual_reference_mode.gd",
	"scripts/systems/village_terrain_renderer.gd",
	"scripts/systems/water_layout_data.gd",
	"scripts/systems/water_map_registry.gd",
	"scripts/systems/water_topology.gd",
	"scripts/world_background.gd",
	"tools/qa/camera/visual_camera_points.gd",
	"tools/qa/world/river_flow_capture.gd",
]

var output := ""
var base := ""
var profile := ""
var viewport := SubViewport.new()
var game: Node
var background: Node
var river: Node2D
var captures: Dictionary = {}
var motion: Array[Dictionary] = []
var checks: Dictionary = {}
var atlas: Dictionary = {}
var valid := true


## Запрещает headless и запись в уже существующий каталог или обычный профиль игры.
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
		or RegEx.create_from_string("^Codex-VSHORE-006-[a-zA-Z0-9-]+$").search(profile) == null
		or RegEx.create_from_string("^[a-f0-9]{40}$").search(base) == null
	):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_run.call_deferred()


## Снимает две части реки и пруд в одной игровой сцене с одинаковым состоянием мира.
func _run() -> void:
	if (
		not OS.get_user_data_dir().ends_with(profile)
		or DirAccess.make_dir_absolute(output) != OK
		or DirAccess.make_dir_absolute(output.path_join("frames")) != OK
	):
		quit(2)
		return
	root.title = "VSHORE-006 · течение вдоль русла"
	root.size = SIZE
	root.show()
	create_timer(180.0).timeout.connect(func() -> void: quit(3), CONNECT_ONE_SHOT)
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
	river = background.water_surface.get_node("RiverCurrent") as Node2D
	var original: Dictionary = game.SaveSystem.snapshot(game)
	_camera(CAMERAS.upper)
	await _draw()
	checks["split_visible"] = background.terrain_ready and river.is_visible_in_tree()

	for place: String in CAMERAS:
		_camera(CAMERAS[place])
		await _capture(place + "-before", "normal", START_SECONDS, false)
		await _capture(place + "-after", "normal", START_SECONDS)
		if place != "pond":
			await _capture(place + "-static", "static", START_SECONDS)
			await _capture(place + "-later", "normal", LATER_SECONDS)
	_camera(CAMERAS.upper)
	await _capture("upper-low", "low", START_SECONDS)
	await _capture("upper-low-later", "low", LATER_SECONDS)
	await _capture("upper-wrapped", "normal", START_SECONDS + Surface.LOOP_SECONDS)
	_camera(CAMERAS.upper + Vector2(40, 0))
	await _capture("upper-shifted", "normal", START_SECONDS)
	await _runtime_checks()
	checks["save_equal"] = original == game.SaveSystem.snapshot(game)
	await _motion()
	_finish()


## Меняет только мировую проекцию и сохраняет один масштаб для всех кадров.
func _camera(offset: Vector2) -> void:
	game.camera_offset = offset
	WorldProjection.sync_background(game)
	game.queue_redraw()


## Использует штатный путь обновления. Для нового рендера метаданные контроля отсутствуют.
func _apply(quality: String, seconds: float, directed: bool = true) -> void:
	game.set_meta(Clock.META, seconds)
	game.set_meta(Surface.QUALITY, quality)
	if directed:
		if game.has_meta(Surface.DIRECTIONAL):
			game.remove_meta(Surface.DIRECTIONAL)
	else:
		game.set_meta(Surface.DIRECTIONAL, false)
	background._process(0.0)


## Записывает происхождение кадра вместе с неизменными настройками пары для Wiki.
func _capture(id: String, quality: String, seconds: float, directed: bool = true) -> void:
	_apply(quality, seconds, directed)
	await _draw()
	var entry := _save(id + ".png", seconds)
	entry["quality"] = quality
	entry["directed"] = directed
	captures[id] = entry


## Проверяет паузу, повторное использование атласа и ранний выход из разделённого рендера.
func _runtime_checks() -> void:
	_camera(CAMERAS.upper)
	_apply("normal", START_SECONDS)
	await _draw()
	var material := river.material as ShaderMaterial
	var texture := material.get_shader_parameter("flow_coordinates") as ImageTexture
	var bounds: Vector4 = material.get_shader_parameter("flow_bounds")
	atlas = {
		"size": [texture.get_width(), texture.get_height()],
		"bytes": texture.get_image().get_data().size(),
		"bounds": [bounds.x, bounds.y, bounds.z, bounds.w]
	}
	checks["directed_default"] = material.get_shader_parameter("directed") == true
	checks["normal_fine"] = material.get_shader_parameter("fine_ripples") == true
	var phase: float = material.get_shader_parameter("flow_phase")
	var paints: int = background.water_layer.paint_count
	var requests: int = background.terrain_requests
	game.menu_state.pause_open = true
	var held := not Frame.publish(game, 0.25)
	background._process(0.0)
	checks["pause"] = held and phase == material.get_shader_parameter("flow_phase")
	game.menu_state.pause_open = false
	var resumed := Frame.publish(game, 0.25)
	background._process(0.0)
	checks["resume"] = resumed and phase != material.get_shader_parameter("flow_phase")
	_apply("low", START_SECONDS)
	checks["low_keeps_flow"] = (
		material.get_shader_parameter("directed") == true
		and material.get_shader_parameter("fine_ripples") == false
	)
	checks["uniform_only"] = (
		paints == background.water_layer.paint_count
		and requests == background.terrain_requests
		and material.get_shader_parameter("flow_coordinates") == texture
	)
	game.settings_state.reduced_motion = true
	_apply("normal", START_SECONDS)
	checks["reduced_motion_static"] = river.material == null
	game.settings_state.reduced_motion = false
	Reference.enable(game)
	_apply("normal", START_SECONDS)
	checks["reference_static"] = river.material == null
	Reference.disable(game)
	background.set_ground_split(false)
	await _draw()
	checks["unsplit_hidden"] = not river.is_visible_in_tree()
	background.set_ground_split(true)
	await _draw()
	background.set_meta("terrain_direct", true)
	background._sync_ground_layers()
	checks["direct_hidden"] = not river.is_visible_in_tree()
	background.remove_meta("terrain_direct")
	background._sync_ground_layers()
	await _draw()


## Две секунды показывают течение с места, затем камера проходит через стык чанков.
func _motion() -> void:
	var start := Vector2(268, 72)
	var finish := Vector2(472, 94)
	_camera(CAMERAS.lower)
	for index in 120:
		var local := index % 60
		var seconds := START_SECONDS + float(local) / 30.0
		if index >= 60:
			_camera(start.lerp(finish, float(local) / 59.0))
		_apply("normal", seconds)
		await RenderingServer.frame_post_draw
		motion.append(_save("frames/%04d.png" % index, seconds))


## Ждёт фактической отрисовки сцены после изменения материала и камеры.
func _draw() -> void:
	for index in 2:
		await RenderingServer.frame_post_draw


## Сохраняет исходный PNG из Compatibility и вычисляет его точную контрольную сумму.
func _save(file: String, seconds: float) -> Dictionary:
	var image := viewport.get_texture().get_image()
	var path := output.path_join(file)
	if image.get_size() != SIZE or image.save_png(path) != OK:
		valid = false
	return {
		"file": file,
		"png": FileAccess.get_sha256(path),
		"camera": Points.pair(game.camera_offset),
		"scale": WorldProjection.zoom(game),
		"location": game.current_location,
		"owner": "WorldBackground/WaterSurface/Ripples",
		"seconds": seconds,
	}


## Записывает геометрию из общего плана и версию фактически отрисованных исходников.
func _finish() -> void:
	var sources := {}
	for path: String in SOURCES:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var water_plan := Water.geometry("overworld")
	var cells: Array = water_plan.cells().keys()
	cells.sort()
	var river_cells := []
	var pond_cells := []
	for cell: Vector2i in cells:
		var point := Vector2(cell * water_plan.CELL) + Vector2.ONE * water_plan.CELL * 0.5
		var pair := [cell.x, cell.y]
		if water_plan.kind_at(point) == "river":
			river_cells.append(pair)
		else:
			pond_cells.append(pair)
	var bridges := []
	for index in Map.BRIDGES.size():
		var rect := Map.bridge_render_rect(index)
		bridges.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	var data := {
		"task": "VSHORE-006",
		"base": base,
		"profile": profile,
		"size": [SIZE.x, SIZE.y],
		"engine": Engine.get_version_info().string,
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"atlas": atlas,
		"sources": sources,
		"checks": checks,
		"river_cells": river_cells,
		"pond_cells": pond_cells,
		"bridges": bridges,
		"captures": captures,
		"motion": motion,
	}
	var manifest := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if manifest == null:
		quit(4)
		return
	manifest.store_string(JSON.stringify(data, "\t", true) + "\n")
	manifest.close()
	print("VSHORE-006: ", checks, " · ", motion.size(), " frames")
	quit(0 if valid and not checks.values().has(false) else 1)
