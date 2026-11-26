# Наблюдатель вызывает настоящий динамический фасад main.tscn.
@warning_ignore_start(
	"unsafe_call_argument",
	"unsafe_method_access",
	"unsafe_property_access",
	"untyped_declaration",
	"unsafe_cast"
)
extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Clock := preload("res://scripts/presentation/village_ground_clock.gd")
const Wind := preload("res://scripts/presentation/foliage_wind.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Version := preload("res://scripts/presentation/visual_version.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const Ambient := preload("res://scripts/systems/village_ambient_renderer.gd")
const Teleport := preload("res://scripts/systems/qa_teleport_system.gd")
const TeleportInput := preload("res://scripts/systems/qa_teleport_input.gd")
const OLD_SLOT := "res://tests/fixtures/saves/v1-core.json"
const START := Vector2(1944, 780)
const BRIDGE_X := 1588.0
const BRIDGE_RAIL_X := 1578.0
const HZ := 30
const FRAME_TICKS := 3
const WALK_LIMIT := HZ * 7
const STALL_LIMIT := 8

var output := ""
var profile := ""
var mode := ""
var size := Vector2i.ZERO
var game: Node
var rows: Array[Dictionary] = []
var errors: Array[String] = []
var tick := 0
var old_slot_sha := ""
var old_slot_valid := false


## Съёмка принимает только нативное окно с уже действующим временным профилем.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		elif arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg == "--wide":
			size = Vector2i(1280, 720)
	if size == Vector2i.ZERO:
		size = Vector2i(1152, 648)
	if (
		OS.get_name() != "Linux"
		or DisplayServer.get_name() != "X11"
		or output.is_empty()
		or DirAccess.dir_exists_absolute(output)
		or FileAccess.file_exists(output)
		or not profile.begins_with("Codex-VRELEASE-003-")
		or OS.get_user_data_dir().get_file() != profile
		or mode not in ["live", "static"]
	):
		quit(2)
		return
	_run.call_deferred()


## Один и тот же маршрут выполняется в каждом профиле через физический цикл игры.
func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(output.path_join("frames")) != OK:
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = size
	root.title = "VRELEASE-003 | " + mode
	root.show()
	game = Points.create_game()
	root.add_child(game)
	current_scene = game
	var start: Dictionary = Points.registry().points[0].duplicate()
	start.player = Points.pair(START)
	Points.configure(game, start)
	# Изолируем маршрут графики от единственного местного противника в этом профиле.
	game.slime_alive = false
	game.remove_meta(&"camera_reference_zoom")
	game.settings_state.reduced_motion = mode == "static"
	game.settings_state.vsync_enabled = false
	game.WorkshopSystem.state(game, "pottery")
	game.change_inventory_count(Teleport.KIND, 1)
	game.update_camera()
	Pose.reset(game)
	await _settle()
	_require(game.is_position_walkable(START), "initial waypoint is blocked")
	await _hold("idle", 36)
	if not await _outdoor_route():
		_write()
		return
	_require(await _pause(), "pause menu entry failed")
	await _move_through_locations()
	await _check_old_slot()
	await _rollback()
	_write()


## Подходит к перилам боком на середине настила, пока передний слой перекрывает силуэт.
func _outdoor_route() -> bool:
	var waypoints := {
		"grass": Vector2(1776, START.y),
		"bank": Vector2(BRIDGE_X, START.y),
		"bridge-approach": Vector2(BRIDGE_X, 840),
		"bridge-north": Vector2(BRIDGE_X, 936),
	}
	for label: String in waypoints:
		if not await _walk_outside(label, waypoints[label]):
			return false
	if not await _walk_outside("bridge-rail", Vector2(BRIDGE_RAIL_X, game.player.y)):
		return false
	await _hold("bridge-rail", 9)
	return await _walk_outside("bridge-crossing", Vector2(BRIDGE_X, 1080))


func _walk_outside(label: String, target: Vector2) -> bool:
	await _walk(label, target)
	_require(game.current_location == "overworld", "unexpected transition at " + label)
	return errors.is_empty()


## Выбирает направление движения к точке. Координаты изменяет только физический цикл.
func _walk(label: String, target: Vector2) -> void:
	var initial_world: String = game.current_location
	var stalled := 0
	for _step in WALK_LIMIT:
		var previous := Vector2(game.player)
		var offset := target - previous
		if offset.length() <= 7.0 or game.current_location != initial_world:
			break
		game.move_left_held = offset.x < -4.0
		game.move_right_held = offset.x > 4.0
		game.move_up_held = offset.y < -4.0
		game.move_down_held = offset.y > 4.0
		await _step_and_sample(label)
		if game.current_location != initial_world:
			break
		var displacement := previous.distance_to(game.player)
		if displacement > 2.0 * game.speed / HZ:
			_require(false, "unexpected position jump at " + label)
			break
		stalled = stalled + 1 if is_zero_approx(displacement) else 0
		if stalled >= STALL_LIMIT:
			break
	game.clear_movement_keys()
	_require(
		game.current_location != initial_world or Vector2(game.player).distance_to(target) <= 7.0,
		"%s blocked at %s toward %s" % [label, game.player, target]
	)
	await _frame(label)


## Проверяет и удержание настоящей паузы, и первый такт после выхода.
func _pause() -> bool:
	_key(KEY_ESCAPE)
	if not game.menu_state.pause_open:
		return false
	await _hold("pause", 33)
	await _frame("pause")
	game.MenuSystem.resume(game)
	await _hold("resume", 12)
	return not game.menu_state.pause_open


## Камень использует существующий выбор и подтверждение, двери используют игровое движение.
func _move_through_locations() -> void:
	await _teleport("cottage_interior")
	await _hold("interior", 18)
	await _walk("exit-door", game.BuildingSystem.INTERIORS.cottage_interior.exit)
	_require(game.current_location == "overworld", "ordinary exit did not reach overworld")
	await _settle()
	await _hold("outside", 18)
	await _walk("enter-door", game.BuildingSystem.BUILDINGS.cottage.door)
	_require(game.current_location == "cottage_interior", "ordinary entry did not reach the house")
	await _hold("returned-interior", 12)
	await _teleport("overworld")
	await _hold("returned-overworld", 15)


func _teleport(target: String) -> void:
	if not Teleport.open(game):
		_require(false, "teleport menu failed to open: " + target)
		return
	var index := Teleport.entries(game).find(target)
	_require(index >= 0, "missing teleport target: " + target)
	Teleport.select(game, index)
	await _hold("teleport-menu-" + target, 18)
	_key(KEY_ENTER)
	_require(
		game.current_location == target and not Teleport.active(game), "teleport failed: " + target
	)
	await _settle()
	await _frame("teleport-arrival-" + target)


## Старый слот читается как fixture; выход проверяется той же системой переходов.
func _check_old_slot() -> void:
	old_slot_sha = FileAccess.get_sha256(OLD_SLOT)
	var source := FileAccess.get_file_as_string(OLD_SLOT)
	var old: Dictionary = JSON.parse_string(source)
	var loaded: bool = game.SaveSystem.load_at(game, OLD_SLOT)
	game.title_screen = false
	game.language_screen = false
	game.update_camera()
	old_slot_valid = (
		loaded
		and game.current_location == old.location
		and game.day == int(old.day)
		and game.coins == int(old.coins)
		and Points.pair(game.player) == old.player
		and game.inventory_item_count("wood") == int(old.counts.wood)
	)
	_require(old_slot_valid, "legacy slot values differ")
	await _hold("legacy-interior", 9)
	await _walk("legacy-exit", game.BuildingSystem.INTERIORS.cottage_interior.exit)
	_require(game.current_location == "overworld", "legacy slot ordinary exit failed")
	_require(old_slot_sha == FileAccess.get_sha256(OLD_SLOT), "legacy fixture modified")
	await _settle()


## Сравнивает ту же камеру до отключения общего флага и после его восстановления.
func _rollback() -> void:
	game.settings_state.reduced_motion = true
	# Дождь из слота v1 показан на предыдущем отрезке. Для сравнения пикселей фиксируем ясную погоду.
	game.state.world.weather_day = game.day
	game.state.world.weather = "clear"
	game.sync_background_environment()
	game.message = ""
	await _settle()
	await _frame("rollback-on")
	Version.set_enabled(game, false)
	await _settle()
	await _frame("rollback-off")
	game.remove_meta(Version.FLAG)
	game.get_node("WorldBackground").refresh_terrain()
	await _settle()
	await _frame("rollback-restored")


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	if not TeleportInput.handle(game, event):
		game._unhandled_input(event)


func _hold(label: String, length: int) -> void:
	for _step in length:
		await _step_and_sample(label)


func _step_and_sample(label: String) -> void:
	var before: String = game.current_location
	game._physics_process(1.0 / HZ)
	Pose.present(game, 1.0)
	game._process(0.0)
	tick += 1
	if game.current_location != before:
		await _settle()
	if tick % FRAME_TICKS == 0:
		await _frame(label)


## Даёт асинхронной видимой земле закончить собственную отрисовку при остановленных тактах.
func _settle() -> void:
	game._process(0.0)
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var background := game.get_node("WorldBackground")
		if (
			not Version.enabled(game)
			or game.current_location != "overworld"
			or background.terrain_ready
		):
			for _present in 5:
				await process_frame
			return
	_require(false, "terrain did not settle")


## Сохраняет нативный framebuffer и координаты его областей из общей проекции мира.
func _frame(label: String) -> void:
	var before := _save_digest()
	var start_draws := Engine.get_frames_drawn()
	for _draw in 2:
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	await process_frame
	var draw_count := Engine.get_frames_drawn() - start_draws
	var image := root.get_texture().get_image()
	var window := DisplayServer.window_get_size()
	if (
		image.is_empty()
		or image.get_size() != size
		or window != size
		or not root.visible
		or draw_count < 2
		or before != _save_digest()
	):
		_require(false, "invalid native frame at " + label)
		return
	var path := "frames/%04d.png" % rows.size()
	if image.save_png(output.path_join(path)) != OK:
		_require(false, "PNG write failed: " + path)
		return
	var background := game.get_node("WorldBackground")
	var surface: Node2D = background.water_surface
	var water_visible: bool = surface.is_visible_in_tree()
	var river := surface.get_node("RiverCurrent") as Node2D
	var river_material := river.material as ShaderMaterial
	var water_animated := water_visible and river_material != null
	var bridge := Layout.bridge_navigation_rect(1)
	rows.append(
		{
			"label": label,
			"tick": tick,
			"file": path,
			"location": game.current_location,
			"player": Points.pair(game.player),
			"ground": Points.pair(Pose.ground(game)),
			"facing": Points.pair(game.facing),
			"camera": Points.pair(game.camera_offset),
			"zoom": WorldProjection.zoom(game),
			"minutes": game.game_minutes,
			"hp": game.player_hp,
			"world_seconds": Clock.seconds(game),
			"paused": game.menu_state.pause_open,
			"teleport_open": Teleport.active(game),
			"water_visible": water_visible,
			"water_animated": water_animated,
			"water_phase":
			river_material.get_shader_parameter("flow_phase") if water_animated else null,
			"grass": Wind.statistics(game),
			"bridge_deck":
			game.current_location == "overworld" and bridge.has_point(Pose.ground(game)),
			"rail_split": background.split_bridge_rails and Version.enabled(game),
			"modern": Version.enabled(game),
			"save_sha256": before,
			"native_draws": draw_count,
			"regions":
			{
				"grass": _project_rect(Ambient.destination_rect(Vector2(1944, 648))),
				"water": _project_rect(Rect2(1840, 934, 60, 34))
			}
		}
	)


func _project_rect(rect: Rect2) -> Array:
	var logical := Rect2(
		WorldProjection.world_to_screen(game, rect.position), rect.size * WorldProjection.zoom(game)
	)
	var native := root.get_stretch_transform() * logical
	return Points.pair(native.position) + Points.pair(native.size)


func _save_digest() -> String:
	return JSON.stringify(game.SaveSystem.snapshot(game), "", true, true).sha256_text()


func _require(condition: bool, problem: String) -> void:
	if not condition and problem not in errors:
		errors.append(problem)
		print("PILOT FAILED: ", problem)


func _write() -> void:
	var manifest := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if manifest == null:
		quit(2)
		return
	manifest.store_string(
		(
			JSON.stringify(
				{
					"schema": 1,
					"task": "VRELEASE-003",
					"mode": mode,
					"profile": profile,
					"display": DisplayServer.get_name(),
					"rendering_method": RenderingServer.get_current_rendering_method(),
					"window": Points.pair(size),
					"engine": Engine.get_version_info().string,
					"seed": Points.SEED,
					"physics_hz": HZ,
					"video_hz": float(HZ) / FRAME_TICKS,
					"legacy_sha256": old_slot_sha,
					"legacy_valid": old_slot_valid,
					"frames": rows,
					"errors": errors
				},
				"",
				true,
				true
			)
			+ "\n"
		)
	)
	print(
		"MOVING PILOT: ",
		mode,
		" / ",
		size,
		" / ",
		rows.size(),
		" frames / ",
		errors.size(),
		" errors"
	)
	quit(0 if errors.is_empty() else 2)
