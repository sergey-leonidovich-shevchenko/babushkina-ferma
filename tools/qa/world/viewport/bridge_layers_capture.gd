# Наблюдатель вызывает публичную композицию Game в двух независимых viewport.
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
const Observer := preload("res://tools/qa/world/render_order_game.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const Context := preload("res://scripts/presentation/viewport_world_context.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Frame := preload("res://scripts/presentation/post_motion_frame.gd")
const SIZE := Vector2i(1152, 648)
const SOURCES := [
	"project.godot",
	"main.tscn",
	"assets/game/locations/overworld/modular/bridge_modular_v1.png",
	"scripts/presentation/overworld_bridge_layers.gd",
	"scripts/presentation/post_motion_frame.gd",
	"scripts/presentation/village_ground_layer.gd",
	"scripts/presentation/village_terrain_canvas.gd",
	"scripts/systems/navigation_system.gd",
	"scripts/systems/presentation_pose_system.gd",
	"scripts/systems/render_system.gd",
	"scripts/systems/village_layout_system.gd",
	"scripts/systems/village_terrain_renderer.gd",
	"scripts/systems/water_topology.gd",
	"scripts/systems/world_projection_system.gd",
	"scripts/world_background.gd",
	"tools/qa/camera/visual_camera_points.gd",
	"tools/qa/world/render_order_game.gd",
	"tools/qa/world/viewport/bridge_layers_capture.gd",
]

var output := ""
var base := ""
var profile := ""
var games: Array[Node] = []
var errors: Array[String] = []
var captures := {}
var pairs := {}
var draw_checks: Array[Dictionary] = []
var passages: Array[Dictionary] = []


## Требует настоящий дисплей, отдельное сохранение и новый каталог результатов.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--base-commit="):
			base = argument.trim_prefix("--base-commit=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
	var profile_pattern := RegEx.create_from_string("^Codex-VRENDER-007-[a-zA-Z0-9-]+$")
	if (
		DisplayServer.get_name() == "headless"
		or not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or RegEx.create_from_string("^[0-9a-f]{40}$").search(base) == null
		or profile_pattern.search(profile) == null
	):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_run.call_deferred()


## Захватывает оба моста при попарно одинаковой камере, проверяет паузу, два мира и переход.
func _run() -> void:
	if DirAccess.make_dir_absolute(output) != OK:
		quit(2)
		return
	root.title = "VRENDER-007 | Настил и перила"
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.show()
	root.grab_focus()
	create_timer(100.0).timeout.connect(_timed_out, CONNECT_ONE_SHOT)
	games = [_new_world(0), _new_world(1)]
	var game := games[0]
	var preview := games[1]
	var background := game.get_node("WorldBackground")
	_pose(preview, Layout.bridge_navigation_rect(1).get_center(), Vector2.UP)
	await _draw(preview)
	_capture(preview, "neighbor-before")
	for index in Layout.BRIDGES.size():
		var passage := Layout.bridge_navigation_rect(index)
		_check_navigation(game, index, passage)
		var center := passage.get_center()
		var inset: float = game.PLAYER_RADIUS
		var left := Vector2(passage.position.x + inset, center.y)
		var right := Vector2(passage.end.x - inset, center.y)
		await _pair(game, index, "center", center, Vector2.DOWN)
		await _pair(game, index, "left", left, Vector2.DOWN)
		await _pair(game, index, "right", right, Vector2.UP)
		var post := Vector2(passage.position.x + 8.0, passage.end.y - 12.0)
		await _pair(game, index, "post", post, Vector2.DOWN)
		var south := Vector2(left.x, Layout.bridge_render_rect(index).end.y + 8.0)
		await _pair(game, index, "south", south, Vector2.UP)
	await _pair(game, 0, "unsplit-cache", Vector2(834, 456), Vector2.DOWN, "unsplit")
	await _pair(game, 1, "direct", Vector2(1638, 960), Vector2.UP, "direct")
	background.remove_meta("terrain_direct")
	background.set_ground_split(true)
	await _pair(game, 0, "settled", Vector2(834, 456), Vector2.DOWN)
	game.MenuSystem.open_pause(game)
	_expect(game.menu_state.pause_open and not Frame.publish(game, 0.2), "manual pause failed")
	await _draw(game)
	_capture(game, "pause")
	game.MenuSystem.resume(game)
	_expect(_transition(game, "cave_entrance", game.cave_entrance_position), "cannot leave map")
	await _draw(game)
	_capture(game, "cave")
	_expect(game.current_location == "cave", "wrong outbound location")
	_expect(_transition(game, "cave_exit", game.cave_exit_position), "cannot return to village")
	_pose(game, Vector2(834, 456), Vector2.DOWN)
	await _draw(game)
	_capture(game, "returned")
	var bridge_box := _bridge_pixels(game, 0)
	var returned := _frame(game).get_region(bridge_box)
	var settled := Image.load_from_file(output.path_join("1-settled-after.png"))
	_expect(
		returned.get_data() == settled.get_region(bridge_box).get_data(), "return changed bridge"
	)
	await _draw(preview)
	_capture(preview, "neighbor-after")
	_expect(captures["neighbor-before"] == captures["neighbor-after"], "neighbor changed")
	_finish()


## Создаёт видимый экран из настоящей сцены и включает наблюдатель её сохранения.
func _new_world(index: int) -> Node:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pane := TextureRect.new()
	pane.position = Vector2(8 + index * 572, 8)
	pane.size = Vector2(564, 632)
	pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pane.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(pane)
	pane.texture = viewport.get_texture()
	var game := Points.create_game()
	game.set_script(Observer)
	viewport.add_child(game)
	Points.configure(game, Points.registry().points[0])
	WorldProjection.set_reference_zoom(game, 1.2)
	return game


## Оставляет тот же игровой день, проекцию и направление при каждом парном захвате.
func _pose(game: Node, foot: Vector2, direction: Vector2) -> void:
	game.player = foot
	game.facing = direction
	game.update_camera()
	Pose.reset(game)


## Вызывает движение через настоящие коллизии и собирает отрицательные пробы в воде вдоль перил.
func _check_navigation(game: Node, index: int, passage: Rect2) -> void:
	var x := passage.get_center().x
	var start := Vector2(x, passage.position.y - 18)
	var finish := Vector2(x, passage.end.y + 18)
	game.player = start
	game.NavigationSystem.move(game, finish - start)
	var southbound: bool = game.player.is_equal_approx(finish)
	game.NavigationSystem.move(game, start - finish)
	var northbound: bool = game.player.is_equal_approx(start)
	var left_reason: String = game.NavigationSystem.walkability_reason(
		game, Vector2(passage.position.x - 1, passage.get_center().y)
	)
	var right_reason: String = game.NavigationSystem.walkability_reason(
		game, Vector2(passage.end.x + 1, passage.get_center().y)
	)
	(
		passages
		. append(
			{
				"bridge": index + 1,
				"southbound": southbound,
				"northbound": northbound,
				"left": left_reason,
				"right": right_reason,
			}
		)
	)
	_expect(southbound and northbound, "navigation failed on bridge %d" % (index + 1))
	_expect(left_reason == "water" and right_reason == "water", "rail became walkable")


## Включает прежний цельный слой и новый раздельный в одном мире с одинаковыми измерениями.
func _pair(
	game: Node, index: int, label: String, foot: Vector2, direction: Vector2, mode: String = "split"
) -> void:
	var background := game.get_node("WorldBackground")
	background.set_meta("terrain_direct", mode == "direct")
	background.set_ground_split(mode != "unsplit")
	_pose(game, foot, direction)
	var name := "%d-%s" % [index + 1, label]
	var previous: Dictionary = game.SaveSystem.snapshot(game)
	for separate in [false, true]:
		background.set_bridge_depth(separate)
		await _draw(game)
		_capture(game, name + ("-after" if separate else "-before"))
		_expect(background.terrain_ready, "terrain failed: " + name)
		_expect(game.SaveSystem.snapshot(game) == previous, "bridge switch changed save data")
	var bridge := Layout.bridge_render_rect(index)
	var pixel_box := Rect2(
		WorldProjection.world_to_screen(game, bridge.position),
		bridge.size * WorldProjection.zoom(game)
	)
	var foot_px := WorldProjection.world_to_screen(game, foot)
	pairs[name] = {
		"mode": mode,
		"camera": Points.pair(game.camera_offset),
		"bridge_origin": Points.pair(pixel_box.position),
		"bridge_size": Points.pair(pixel_box.size),
		"foot_pixels": Points.pair(foot_px),
		"direction": Points.pair(direction),
		"walkability": game.NavigationSystem.walkability_reason(game, foot),
	}
	_expect(pairs[name].walkability == "walkable", "unplayable probe: " + name)
	_compare_pair(game, name, pixel_box, label not in ["center", "south"])


## Ограничивает отличия двумя полосами перил. HUD и настил сверяются вместе с остальным кадром.
func _compare_pair(game: Node, name: String, bridge: Rect2, should_overlap: bool) -> void:
	var before := Image.load_from_file(output.path_join(name + "-before.png"))
	var after := _frame(game)
	var has_overlap := before.get_data() != after.get_data()
	_expect(has_overlap == should_overlap, "unexpected rail overlap: " + name)
	pairs[name].overlap = has_overlap
	var strip_width := 24.0 * WorldProjection.zoom(game)
	for x: float in [bridge.position.x, bridge.end.x - strip_width]:
		var low := Vector2i(Vector2(x, bridge.position.y).floor())
		var high := Vector2i(Vector2(x + strip_width, bridge.end.y).ceil())
		var bounds := Rect2i(low, high - low)
		before.fill_rect(bounds, Color.BLACK)
		after.fill_rect(bounds, Color.BLACK)
	var unchanged_outside := before.get_data() == after.get_data()
	pairs[name].other_pixels_equal = unchanged_outside
	_expect(unchanged_outside, "changed pixels outside the rails: " + name)


## Округляет экранную границу моста наружу для сравнения кадра после перехода.
func _bridge_pixels(game: Node, index: int) -> Rect2i:
	var bridge := Layout.bridge_render_rect(index)
	var low := Vector2i(WorldProjection.world_to_screen(game, bridge.position).floor())
	var high := Vector2i(WorldProjection.world_to_screen(game, bridge.end).ceil())
	return Rect2i(low, high - low)


## Проверяет снимки сохранения вокруг производственного draw и дожидается реально показанного кадра.
func _draw(game: Node) -> void:
	game.draw_records.clear()
	game.observe_draw = true
	game.queue_redraw()
	for index in 3:
		await RenderingServer.frame_post_draw
		await process_frame
	game.observe_draw = false
	_expect(not game.draw_records.is_empty(), "production draw did not run")
	for record in game.draw_records:
		var before := JSON.stringify(record.before, "", true, true).sha256_text()
		var after := JSON.stringify(record.after, "", true, true).sha256_text()
		(
			draw_checks
			. append(
				{
					"before": before,
					"after": after,
					"geometry_before": record.geometry_before,
					"geometry_after": record.geometry_after,
				}
			)
		)
		_expect(
			record.equal and record.geometry_equal and before == after,
			"draw mutated save data or geometry"
		)


## Пишет полный кадр и принадлежащую только его миру камеру.
func _capture(game: Node, name: String) -> void:
	var path := output.path_join(name + ".png")
	var image := _frame(game)
	_expect(image.get_size() == SIZE and image.save_png(path) == OK, "could not save " + name)
	captures[name] = {
		"png": FileAccess.get_sha256(path),
		"camera": Points.pair(game.camera_offset),
		"location": game.current_location,
		"owner": Context.read(game),
		"scale": WorldProjection.zoom(game),
	}


## Читает тот же кадр, который движок показал в соответствующем игровом viewport.
func _frame(game: Node) -> Image:
	return game.get_viewport().get_texture().get_image()


## Использует реальный переход карты с его собственной проверкой расстояния и задержки.
func _transition(game: Node, route: String, position: Vector2) -> bool:
	game.player = position
	game.update_camera()
	game.location_transition_armed = true
	game.location_transition_cooldown = 0.0
	return (
		game.LocationTransitionSystem.nearest_transition(game) == route
		and game.LocationTransitionSystem.update(game, 1.0 / 60.0)
	)


## Запоминает все ошибки вместо преждевременной остановки сравнения.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)


## Сохраняет причину отсутствующих кадров при потере окна или дисплея.
func _timed_out() -> void:
	errors.append("timeout waiting for native frames")
	_finish()


## Сохраняет источник каждой проверки и фактические настройки захвата.
func _finish() -> void:
	var sources := {}
	for path: String in SOURCES:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var data := {
		"base": base,
		"version": ProjectSettings.get_setting("application/config/version"),
		"godot": Engine.get_version_info(),
		"display": DisplayServer.get_name(),
		"profile": profile,
		"viewport": [SIZE.x, SIZE.y],
		"sources": sources,
		"captures": captures,
		"pairs": pairs,
		"draw_checks": draw_checks,
		"navigation": passages,
		"errors": errors,
	}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.close()
	for message in errors:
		push_error(message)
	print(
		(
			"VRENDER-007 %d pairs, %d draws, %d errors"
			% [pairs.size(), draw_checks.size(), errors.size()]
		)
	)
	quit(0 if errors.is_empty() else 1)
