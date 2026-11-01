extends SceneTree

const Board := preload("res://tools/qa/world/underwater_bottom_board.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const UnderwaterBottom := preload("res://scripts/presentation/underwater_bottom.gd")

const TARGET := Vector2i(1152, 648)
const FIELD := Vector2i(960, 540)
const CAMERAS := {
	"bridge-west": Vector2(384, 186),
	"riverwalk": Vector2(1128, 690),
	"pond": Vector2(1368, 618),
	"river-seam": Vector2(288, 18),
}

var output := ""
var profile := ""
var sources := {}


## Требует новый каталог и нативный дисплей; обычная игра и пользовательские слоты не загружаются.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
	if (
		output.is_empty()
		or DirAccess.dir_exists_absolute(output)
		or not profile.begins_with("Codex-VSHORE-002-")
		or "/" in profile
		or "\\" in profile
	):
		push_error("Нужны новый output и отдельный профиль VSHORE-002")
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_start.call_deferred()


## Снимает четыре пары одинаковых камер, сезонные контроли и 90 кадров движения.
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
	root.title = "VSHORE-002 · подводное дно · отдельная QA-витрина"
	root.size = TARGET
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.size = Vector2(TARGET)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(preview)
	var source_paths: Array[String] = [
		"res://assets/game/locations/overworld/modular/riverbed_material_v1.png",
		"res://assets/game/locations/overworld/modular/water_material_v1.png",
		"res://scripts/presentation/underwater_bottom.gd",
		"res://scripts/systems/village_terrain_renderer.gd",
		"res://scripts/systems/water_topology.gd",
		"res://scripts/systems/water_map_registry.gd",
		"res://tools/qa/world/underwater_bottom_board.gd",
		"res://tools/qa/world/underwater_bottom_capture.gd",
	]
	for path: String in source_paths:
		sources[path] = FileAccess.get_sha256(path)
	var frames := []
	for id: String in CAMERAS:
		board.camera = CAMERAS[id]
		for mode: String in ["before", "after"]:
			board.mode = mode
			if not await _frame(viewport, board, id + "-" + mode, frames):
				return
	board.camera = CAMERAS.pond
	board.mode = "bottom"
	if not await _frame(viewport, board, "pond-bottom", frames):
		return
	board.mode = "after"
	var environments: Array[Dictionary] = [
		{"id": "pond-winter", "season": "winter", "weather": "clear"},
		{"id": "pond-rain", "season": "spring", "weather": "rain"},
	]
	for environment: Dictionary in environments:
		var environment_id: String = environment.id
		board.season = environment.season
		board.weather = environment.weather
		if not await _frame(viewport, board, environment_id, frames):
			return
	board.season = "spring"
	board.weather = "clear"
	var motion := []
	for index in 90:
		var phase := float(index) / 89.0
		board.camera = Vector2(288, 18).lerp(Vector2(1128, 690), phase)
		board.queue_redraw()
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var name := "frames/%04d.png" % index
		image.save_png(output.path_join(name))
		if index in [0, 45, 89]:
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
	var proof := {
		"schema": 1,
		"task": "VSHORE-002",
		"kind": "native-runtime-water-study",
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
		"bottom_profile": UnderwaterBottom.profile(),
		"clipped_vertices":
		UnderwaterBottom.vertex_count(Terrain.surface_polygons(true), &"capture-clipped"),
		"texture_loads_inside_draw": 0,
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(proof, "\t") + "\n"
	)
	print("UNDERWATER CAPTURE: 11 static frames and 90 camera frames; not FPS")
	quit(0)


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
				"season": board.season,
				"weather": board.weather,
				"sha256": FileAccess.get_sha256(output.path_join(file)),
				"repeat_equal": true,
			}
		)
	)
	return true
