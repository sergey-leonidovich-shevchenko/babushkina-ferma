extends SceneTree

const Board := preload("res://tools/qa/world/water_topology_mask_board.gd")
const WaterData := preload("res://scripts/systems/water_layout_data.gd")
const WaterMapRegistry := preload("res://scripts/systems/water_map_registry.gd")
const WaterTopology := preload("res://scripts/systems/water_topology.gd")

const TARGET := Vector2i(1152, 648)
const FIELD := Vector2i(960, 540)
const CAMERAS := {
	"bridge-west": Vector2(384, 186),
	"river-turn": Vector2(816, 396),
	"pond": Vector2(1368, 618),
	"chunk-boundary": Vector2(288, 18),
}

var output := ""
var profile := ""


## Требует новый каталог и отдельный нативный профиль, не загружая игру или пользовательский слот.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
	if (
		output.is_empty()
		or DirAccess.dir_exists_absolute(output)
		or not profile.begins_with("Codex-VSHORE-003-")
		or "/" in profile
		or "\\" in profile
	):
		push_error("Нужны новый output и отдельный профиль VSHORE-003")
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_start.call_deferred()


## Снимает четыре пары одинаковых камер и 72 кадра движения вдоль канонической поверхности.
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
	root.title = "VSHORE-003 · WaterTopology · изолированная QA-витрина"
	root.size = TARGET
	root.position = Vector2i(-5000, -5000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.size = Vector2(TARGET)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(preview)
	var sources := _sources()
	var frames := []
	for camera_id: String in CAMERAS:
		board.camera = CAMERAS[camera_id]
		for mode: String in ["topology", "runtime"]:
			board.mode = mode
			if not await _frame(viewport, board, camera_id + "-" + mode, frames):
				return
	board.mode = "runtime"
	var motion := []
	for index in 72:
		var phase := float(index) / 71.0
		board.camera = CAMERAS["chunk-boundary"].lerp(CAMERAS["pond"], phase)
		board.queue_redraw()
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var name := "frames/%04d.png" % index
		image.save_png(output.path_join(name))
		if index in [0, 36, 71]:
			image.save_png(output.path_join("motion-%03d.png" % index))
		(
			motion
			. append(
				{
					"frame": index,
					"camera": [board.camera.x, board.camera.y],
					"file": name,
					"sha256": FileAccess.get_sha256(output.path_join(name)),
				}
			)
		)
	var plan: WaterTopology = WaterMapRegistry.geometry("overworld")
	var snapshot: Dictionary = WaterMapRegistry.visual("overworld")
	var regions: Array = snapshot.regions
	var polygons: Array = snapshot.polygons
	var shore_spans: Array = snapshot.shore_spans
	var builds_before: int = plan.visual_builds
	for repeat in 120:
		WaterMapRegistry.visual("overworld")
	var proof := {
		"schema": 1,
		"task": "VSHORE-003",
		"kind": "native-water-topology-mask-study",
		"native_gameplay": false,
		"runtime_integration": true,
		"performance_eligible": false,
		"fixed_clock_video": true,
		"profile": profile,
		"target": [TARGET.x, TARGET.y],
		"field": [FIELD.x, FIELD.y],
		"zoom": 1.2,
		"camera_pairs": CAMERAS,
		"frames": frames,
		"motion": motion,
		"fps": 30,
		"engine": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"sources": sources,
		"topology":
		{
			"revision": snapshot.revision,
			"cells": plan.cell_count(),
			"regions": regions.size(),
			"polygons": polygons.size(),
			"shore_spans": shore_spans.size(),
			"visual_builds": plan.visual_builds,
			"repeated_reads": 120,
			"rebuilds_during_repeated_reads": plan.visual_builds - builds_before,
			"bridge_surface": _bridge_surface(plan),
			"chunk_boundary_surface":
			[plan.has_surface(Vector2(372, 252)), plan.has_surface(Vector2(396, 252))],
		},
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(proof, "\t") + "\n"
	)
	print("WATER TOPOLOGY CAPTURE: 8 static frames and 72 camera frames; not FPS")
	quit(0)


## Подписывает только файлы, реально участвующие в нативной композиции и маске.
func _sources() -> Dictionary:
	var result := {}
	for path: String in [
		"res://assets/game/locations/overworld/modular/riverbed_material_v1.png",
		"res://assets/game/locations/overworld/modular/water_material_v1.png",
		"res://scripts/presentation/underwater_bottom.gd",
		"res://scripts/systems/village_terrain_renderer.gd",
		"res://scripts/systems/water_layout_data.gd",
		"res://scripts/systems/water_map_registry.gd",
		"res://scripts/systems/water_topology.gd",
		"res://scripts/systems/water_visual_system.gd",
		"res://tools/qa/world/water_topology_mask_board.gd",
		"res://tools/qa/world/water_topology_mask_capture.gd",
	]:
		result[path] = FileAccess.get_sha256(path)
	return result


## Проверяет, что оба настила перекрывают, но не вырезают поверхность.
func _bridge_surface(plan: WaterTopology) -> Array[bool]:
	var result: Array[bool] = []
	for bridge: Rect2 in WaterData.HOME_BRIDGES:
		result.append(
			(
				plan.has_surface(bridge.get_center())
				and plan.on_bridge(bridge.get_center())
				and not plan.blocks_movement(bridge.get_center(), 18.0)
			)
		)
	return result


## Сверяет настоящий framebuffer и повторный readback неподвижной сцены.
func _frame(viewport: SubViewport, board: Board, id: String, frames: Array) -> bool:
	board.queue_redraw()
	for tick in 3:
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
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
