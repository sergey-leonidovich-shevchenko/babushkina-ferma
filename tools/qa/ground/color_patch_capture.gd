extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/render_order_game.gd")
const ProjectionSystem := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Regions := preload("res://scripts/systems/village_region_data.gd")
const RoadBoard := preload("res://tools/qa/ground/road_network_board.gd")
const GameScript := preload("res://scripts/game.gd")
const BackgroundScript := preload("res://scripts/world_background.gd")
var folder := ""
var profile := ""
var size := Vector2i(1152, 648)
var virtual_display := false
var game: GameScript
var background: BackgroundScript
var rows: Array[Dictionary] = []
var errors: Array[String] = []


## Разрешает только свежий изолированный профиль и настоящее графическое окно.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			folder = arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		elif arg == "--wide":
			size = Vector2i(1280, 720)
		elif arg == "--virtual-display":
			virtual_display = true
	if (
		folder.is_empty()
		or not profile.begins_with("Codex-VGROUND-002-")
		or "/" in profile
		or "\\" in profile
	):
		push_error("Fresh separate output/profile required")
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_start.call_deferred()


## Снимает одинаковую камеру, четыре сезона, шесть биомов и пять типов дорожного контакта.
func _start() -> void:
	if virtual_display and OS.get_environment("CI") != "true":
		push_error("Virtual display is restricted to isolated CI")
		quit(2)
		return
	if (
		DisplayServer.get_name() == "headless"
		or DirAccess.dir_exists_absolute(folder)
		or not OS.get_user_data_dir().ends_with(profile)
		or FileAccess.file_exists("user://farm-settings.cfg")
	):
		push_error("Native display and unused isolated paths required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	game = Points.create_game() as GameScript
	game.set_script(Observer)
	root.add_child(game)
	current_scene = game
	var camera_point: Dictionary = Points.registry().points[0]
	Points.configure(game, camera_point)
	ProjectionSystem.set_reference_zoom(game, 1.2)
	background = game.get_node("WorldBackground") as BackgroundScript
	root.title = "VGROUND-002 | biome colour patches"
	root.mode = Window.MODE_WINDOWED
	root.size = size
	root.show()
	root.grab_focus()
	await _settle(1000)
	root.mode = Window.MODE_WINDOWED
	await _settle(800)
	root.size = size
	root.show()
	root.grab_focus()
	await _settle(800)
	# The game boots fullscreen by default and macOS completes that transition
	# asynchronously.  Wait for the real host window instead of accepting a
	# correctly sized stretch texture inside a fullscreen window.
	for attempt in 15:
		if root.mode == Window.MODE_WINDOWED and DisplayServer.window_get_size() == size:
			break
		root.mode = Window.MODE_WINDOWED
		root.size = size
		root.show()
		root.grab_focus()
		await _settle(200)
	if root.mode != Window.MODE_WINDOWED or DisplayServer.window_get_size() != size:
		push_error("Native window size did not settle")
		quit(2)
		return
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for season: String in ["spring", "summer", "autumn", "winter"]:
		background.set_environment(season, "clear")
		await _pair(season, "overworld", Vector2(600.25, 700.25))
	background.set_environment("spring", "clear")
	var locations: Array[String] = []
	locations.assign(Regions.IDS)
	for location: String in locations:
		await _location(location)
		if location != "overworld":
			await _legacy_paths(location)
	await _board(
		"biomes-spring",
		preload("res://tools/qa/ground/color_patch_board.gd").new(),
		Vector2i(1152, 648)
	)
	var roads := RoadBoard.new()
	roads.kind = "after"
	roads.season = "spring"
	await _board("road-shapes-spring", roads, Vector2i(1152, 1152), Vector2.ONE * 1.2)
	roads = RoadBoard.new()
	roads.kind = "after"
	roads.season = "winter"
	await _board("road-shapes-winter", roads, Vector2i(1152, 1152), Vector2.ONE * 1.2)
	_write(
		"capture.json",
		{
			"task": "VGROUND-002",
			"profile": profile,
			"window": Points.pair(size),
			"engine": Engine.get_version_info().string,
			"display": DisplayServer.get_name(),
			"driver": RenderingServer.get_current_rendering_driver_name(),
			"rows": rows,
			"errors": errors,
			"simulation_frozen": true,
			"performance_eligible": false,
			"gpu_time_ms": null,
			"road_shapes": ["straight", "t", "turn", "dead_end", "corner"],
			"biomes": preload("res://scripts/systems/village_map_data.gd").GROUND_BIOMES,
			"virtual_display": virtual_display,
		}
	)
	quit(0 if errors.is_empty() else 2)


## Сохраняет до/после с полностью одинаковой позой, камерой, сезоном и снимком состояния.
func _pair(id: String, location: String, player: Vector2) -> void:
	game.current_location = location
	background.set_location(location)
	game.player = player
	game.facing = Vector2.DOWN
	game.update_camera()
	Pose.reset(game)
	for enabled: bool in [false, true]:
		background.set_ground_color_patches(enabled)
		await _wait_for_terrain(id + ("-after" if enabled else "-before"))
		await _shot(id + ("-after" if enabled else "-before"))


## Снимает каждый биом на общей центральной камере после его штатной сборки в кеш.
func _location(location: String) -> void:
	var player := Vector2(600.25, 700.25) if location == "overworld" else Vector2(1008.25, 624.25)
	if location == "village_river":
		player = Vector2(624.25, 624.25)
	await _pair("biome-" + location, location, player)


## Доказывает одинаковый прежний материал отдельной village-карты в кеше и прямом пути.
func _legacy_paths(location: String) -> void:
	game.current_location = location
	background.set_location(location)
	game.player = (
		Vector2(624.25, 624.25) if location == "village_river" else Vector2(1008.25, 624.25)
	)
	game.facing = Vector2.DOWN
	game.update_camera()
	Pose.reset(game)
	background.set_ground_color_patches(true)
	background.remove_meta(&"terrain_direct")
	await _wait_for_terrain("legacy-cached-" + location)
	await _shot("legacy-cached-" + location)
	background.set_meta(&"terrain_direct", true)
	await _redraw(8)
	await _shot("legacy-direct-" + location)
	background.remove_meta(&"terrain_direct")


## Ждёт завершения одноразового GPU-кеша, а не угадывает его готовность числом кадров.
func _wait_for_terrain(id: String) -> void:
	for attempt in 60:
		await _redraw(1)
		if background.terrain_ready:
			await _redraw(2)
			return
	errors.append(id + ": terrain cache did not settle")


## Записывает настоящий кадр и полные команды штатного draw-наблюдателя.
func _shot(id: String) -> void:
	game.message = ""
	game.set(&"observe_draw", false)
	await _redraw(1)
	var draw_records: Array = game.get(&"draw_records")
	draw_records.clear()
	game.set(&"observe_draw", true)
	await _redraw(4)
	game.set(&"observe_draw", false)
	var image := root.get_texture().get_image()
	image.save_png(folder.path_join(id + ".png"))
	_write(id + "-draws.json", draw_records)
	if (
		image.get_size() != size
		or DisplayServer.window_get_size() != size
		or (not virtual_display and not DisplayServer.window_is_focused())
	):
		errors.append(id + ": readback/window/focus changed")
	(
		rows
		. append(
			{
				"id": id,
				"readback": Points.pair(image.get_size()),
				"camera": Points.pair(game.camera_offset),
				"player": Points.pair(game.player),
				"location": game.current_location,
				"season": background.season,
				"weather": background.weather,
				"patches": background.ground_color_patches,
				"direct": background.get_meta(&"terrain_direct", false) == true,
				"snapshot": game.SaveSystem.snapshot(game),
				"focused": DisplayServer.window_is_focused(),
				"physical": Points.pair(DisplayServer.window_get_size()),
				"zoom": game.get_meta(&"camera_reference_zoom"),
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			}
		)
	)


## Снимает QA-лист с реального GPU readback и без выдачи его за игровой FPS-допуск.
func _board(id: String, board: Node2D, target: Vector2i, scale: Vector2 = Vector2.ONE) -> void:
	var view := SubViewport.new()
	view.size = target
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	board.scale = scale
	root.add_child(view)
	view.add_child(board)
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	if image.get_size() != target:
		errors.append(id + ": board size changed")
	image.save_png(folder.path_join(id + ".png"))
	view.queue_free()
	await process_frame


## Ждёт заданное число настоящих GPU callbacks.
func _redraw(count: int) -> void:
	if not virtual_display:
		DisplayServer.window_move_to_foreground()
		root.grab_focus()
	for index in count:
		game.queue_redraw()
		await process_frame
		RenderingServer.force_draw(false)


## Даёт оконному серверу закончить размещение окна без замера FPS.
func _settle(milliseconds: int) -> void:
	var deadline := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		game.queue_redraw()
		await RenderingServer.frame_post_draw


## Сохраняет JSON только во внешний свежий каталог QA.
func _write(name: String, value: Variant) -> void:
	FileAccess.open(folder.path_join(name), FileAccess.WRITE).store_string(
		JSON.stringify(value) + "\n"
	)
