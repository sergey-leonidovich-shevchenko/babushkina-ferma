extends SceneTree

const Board := preload("res://tools/qa/world/water_chunk_seam_board.gd")
const WaterMapRegistry := preload("res://scripts/systems/water_map_registry.gd")
const WaterTopology := preload("res://scripts/systems/water_topology.gd")

const TARGET := Vector2i(1152, 648)
const FIELD := Vector2i(576, 324)
const SEAM_X := 384.0
const CAMERAS := {
	"seam-center": Vector2(96, 90),
	"seam-east": Vector2(192, 90),
}
const MODES := ["global", "chunk-safe", "isolated-negative"]

var output := ""
var profile := ""


## Требует новый каталог и отдельный профиль, не загружая игру или пользовательский слот.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
	if (
		output.is_empty()
		or DirAccess.dir_exists_absolute(output)
		or not profile.begins_with("Codex-VSHORE-004-")
		or "/" in profile
		or "\\" in profile
	):
		push_error("Нужны новый output и отдельный профиль VSHORE-004")
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_start.call_deferred()


## Снимает две тройки одинаковых камер и 60 кадров прохода через реальный стык x=384.
func _start() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().ends_with(profile):
		push_error("Нужен нативный дисплей")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	var viewport := SubViewport.new()
	viewport.size = TARGET
	viewport.size_2d_override = FIELD
	viewport.size_2d_override_stretch = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	viewport.add_child(board)
	root.title = "VSHORE-004 · seam-safe chunks · изолированная QA-витрина"
	root.size = TARGET
	root.position = Vector2i(-5000, -5000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.size = Vector2(TARGET)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(preview)
	var frames := []
	for camera_id: String in CAMERAS:
		board.camera = CAMERAS[camera_id]
		for mode: String in MODES:
			board.mode = mode
			if not await _frame(viewport, board, camera_id + "-" + mode, frames):
				return
	var motion := []
	for index in 60:
		var phase := float(index) / 59.0
		board.camera = CAMERAS["seam-center"].lerp(Vector2(288, 90), phase)
		board.mode = "chunk-safe"
		var safe := await _readback(viewport, board)
		board.mode = "global"
		var global := await _readback(viewport, board)
		if safe.get_data() != global.get_data():
			push_error("Chunk-safe кадр отличается от глобального эталона")
			quit(2)
			return
		var name := "frames/%04d.png" % index
		safe.save_png(output.path_join(name))
		if index in [0, 30, 59]:
			safe.save_png(output.path_join("motion-%03d.png" % index))
		(
			motion
			. append(
				{
					"frame": index,
					"camera": [board.camera.x, board.camera.y],
					"board_position": [board.position.x, board.position.y],
					"seam_screen_x": (SEAM_X - board.camera.x) * 2.0,
					"file": name,
					"sha256": FileAccess.get_sha256(output.path_join(name)),
					"global_equal": true,
				}
			)
		)
	var plan: WaterTopology = WaterMapRegistry.geometry("overworld")
	var left: Dictionary = WaterMapRegistry.visual_chunk("overworld", Vector2i.ZERO)
	var right: Dictionary = WaterMapRegistry.visual_chunk("overworld", Vector2i.RIGHT)
	var left_cells: Array = left.cells
	var right_cells: Array = right.cells
	var left_halo: Dictionary = left.halo
	var right_halo: Dictionary = right.halo
	var left_edges: Dictionary = left.filled_edges
	var right_edges: Dictionary = right.filled_edges
	var builds_before: int = plan.chunk_visual_builds
	for repeat in 120:
		WaterMapRegistry.visual_chunk("overworld", Vector2i.ZERO)
		WaterMapRegistry.visual_chunk("overworld", Vector2i.RIGHT)
	var proof := {
		"schema": 1,
		"task": "VSHORE-004",
		"kind": "native-water-chunk-seam-study",
		"native_gameplay": false,
		"runtime_integration": true,
		"performance_eligible": false,
		"fixed_clock_video": true,
		"profile": profile,
		"target": [TARGET.x, TARGET.y],
		"field": [FIELD.x, FIELD.y],
		"zoom": 2.0,
		"seam_world_x": SEAM_X,
		"camera_sets": CAMERAS,
		"frames": frames,
		"motion": motion,
		"fps": 30,
		"engine": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"sources": _sources(),
		"chunks":
		{
			"left_cells": left_cells.size(),
			"right_cells": right_cells.size(),
			"left_halo": left_halo.size(),
			"right_halo": right_halo.size(),
			"left_east_filled": left_edges.east,
			"right_west_filled": right_edges.west,
			"visual_builds": plan.chunk_visual_builds,
			"repeated_reads": 240,
			"rebuilds_during_repeated_reads": plan.chunk_visual_builds - builds_before,
			"internal_shore_edges": _internal_shore_edges(left) + _internal_shore_edges(right),
		},
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(proof, "\t") + "\n"
	)
	print("WATER CHUNK SEAM CAPTURE: 6 static frames and 60 camera frames; not FPS")
	quit(0)


## Подписывает только файлы, реально участвующие в нативной композиции стыка.
func _sources() -> Dictionary:
	var result := {}
	for path: String in [
		"res://assets/game/tiles/editor/water/water_clear.png",
		"res://scripts/systems/village_terrain_renderer.gd",
		"res://scripts/systems/water_layout_data.gd",
		"res://scripts/systems/water_map_registry.gd",
		"res://scripts/systems/water_topology.gd",
		"res://scripts/systems/water_visual_system.gd",
		"res://tools/qa/world/water_chunk_seam_board.gd",
		"res://tools/qa/world/water_chunk_seam_capture.gd",
	]:
		result[path] = FileAccess.get_sha256(path)
	return result


## Считает только ложные вертикальные берега на заполненном участке x=384.
func _internal_shore_edges(snapshot: Dictionary) -> int:
	var result := 0
	for edge: Dictionary in snapshot.shore_edges:
		var start: Vector2 = edge.start
		var finish: Vector2 = edge.finish
		if (
			is_equal_approx(start.x, SEAM_X)
			and is_equal_approx(finish.x, SEAM_X)
			and minf(start.y, finish.y) < 288.0
			and maxf(start.y, finish.y) > 216.0
		):
			result += 1
	return result


## Сверяет настоящий framebuffer и повторный readback неподвижной сцены.
func _frame(viewport: SubViewport, board: Board, id: String, frames: Array) -> bool:
	var image := await _readback(viewport, board)
	await RenderingServer.frame_post_draw
	if (
		image.get_size() != TARGET
		or image.get_data() != viewport.get_texture().get_image().get_data()
	):
		push_error("Размер или повторный readback различаются")
		quit(2)
		return false
	var file := id + ".png"
	image.save_png(output.path_join(file))
	(
		frames
		. append(
			{
				"id": id,
				"file": file,
				"camera": [board.camera.x, board.camera.y],
				"sha256": FileAccess.get_sha256(output.path_join(file)),
				"repeat_equal": true,
			}
		)
	)
	return true


## Даёт renderer три полных кадра на смену режима до чтения GPU-текстуры.
func _readback(viewport: SubViewport, board: Board) -> Image:
	# Камера принадлежит CanvasItem, поэтому внутренние draw_set_transform модулей воды
	# не могут отменить её. Это также делает реальное движение видимым в framebuffer.
	board.position = -board.camera
	board.queue_redraw()
	for tick in 3:
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
