# Нативный QA связывает два динамических Game-экземпляра с независимыми SubViewport.
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
const Context := preload("res://scripts/presentation/viewport_world_context.gd")
const Clock := preload("res://scripts/presentation/village_ground_clock.gd")
const Frame := preload("res://scripts/presentation/post_motion_frame.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Regions := preload("res://scripts/systems/village_region_system.gd")
const CASES := ["same-camera", "game-moves", "editor-and-pause", "map-entry", "map-return"]
const SOURCES := [
	"project.godot",
	"main.tscn",
	"scripts/core/game_bootstrap.gd",
	"scripts/core/game_preview_bootstrap.gd",
	"scripts/core/game_unhandled_input_router.gd",
	"scripts/game_core.gd",
	"scripts/state/world_state.gd",
	"scripts/presentation/post_motion_frame.gd",
	"scripts/presentation/village_ground_clock.gd",
	"scripts/presentation/viewport_world_context.gd",
	"scripts/presentation/village_terrain_canvas.gd",
	"scripts/systems/camera_system.gd",
	"scripts/systems/estate_system.gd",
	"scripts/systems/fence_system.gd",
	"scripts/systems/render_system.gd",
	"scripts/systems/save_system.gd",
	"scripts/systems/world_projection_system.gd",
	"scripts/world_background.gd",
	"tests/suites/post_motion_frame_suite.gd",
	"tests/suites/viewport_world_context_suite.gd",
	"tools/qa/world/render_order_game.gd",
	"tools/qa/world/test_viewport_isolation.py",
	"tools/qa/world/viewport_isolation_capture.gd",
	"tools/qa/world/viewport_isolation_review.gd",
	"tools/qa/world/viewport_isolation_verify.py",
	"tools/quality/godot.py",
	"tools/quality/test_quality.py",
]

var output := ""
var profile := ""
var base_commit := ""
var viewports: Array[SubViewport] = []
var games: Array[Node] = []
var labels: Array[Label] = []
var rows := []
var errors := []
var source_sha256 := {}
var reverse_isolation := {}


## Принимает только новый каталог и отдельный QA-профиль.
## Пользовательские слоты не открываются.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--base-commit="):
			base_commit = argument.trim_prefix("--base-commit=")
	if (
		output.is_empty()
		or not profile.begins_with("Codex-VRENDER-009-")
		or "/" in profile
		or "\\" in profile
		or base_commit.length() != 40
	):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_start.call_deferred()


## Собирает два настоящих мира.
## Проходит одинаковую камеру, движение, F12, паузу и переход карты.
func _start() -> void:
	if DisplayServer.get_name() == "headless" or DirAccess.dir_exists_absolute(output):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	for path in SOURCES:
		var value := FileAccess.get_sha256("res://" + path)
		if value.length() != 64:
			errors.append("cannot hash source " + path)
		source_sha256[path] = value
	root.title = "VRENDER-009 | Два независимых viewport"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 648)
	root.show()
	root.grab_focus()
	_build_surface()
	await _settle(1200)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 648)
	root.grab_focus()
	await _settle(900)
	for game in games:
		Points.configure(game, Points.registry().points[0])
		game.settings_state.reduced_motion = false
		WorldProjection.set_reference_zoom(game, 1.2)
		game.player = Vector2(696, 696)
		game.update_camera()
		Pose.reset(game)
	Clock.advance(games[0], 1.0)
	Clock.advance(games[1], 7.0)
	Frame.publish(games[0], 0.25)
	Frame.publish(games[1], 0.5)
	await _capture("same-camera")

	games[0].move_right_held = true
	for tick in 6:
		games[0]._physics_process(1.0 / 30.0)
		Pose.present(games[0], 0.5)
	games[0].clear_movement_keys()
	await _capture("game-moves")

	var game_before_preview := _observation(games[0])
	var preview_before_move := _observation(games[1])
	games[1].move_left_held = true
	for tick in 6:
		games[1]._physics_process(1.0 / 30.0)
		Pose.present(games[1], 0.5)
	games[1].clear_movement_keys()
	reverse_isolation = {
		"game_before": game_before_preview,
		"game_after": _observation(games[0]),
		"preview_before": preview_before_move,
		"preview_after": _observation(games[1]),
	}
	if reverse_isolation.game_before != reverse_isolation.game_after:
		errors.append("preview movement altered the active game world")
	games[0].LevelEditorSystem.toggle(games[0])
	games[0].CameraSystem.pan_editor(games[0], Vector2(96, 48))
	games[1].MenuSystem.open_pause(games[1])
	var frozen := [Clock.seconds(games[0]), Clock.seconds(games[1])]
	Clock.advance(games[0], 3.0)
	Clock.advance(games[1], 3.0)
	if frozen != [Clock.seconds(games[0]), Clock.seconds(games[1])]:
		errors.append("editor or pause advanced visual time")
	await _capture("editor-and-pause")

	games[0].LevelEditorSystem.toggle(games[0])
	games[1].MenuSystem.resume(games[1])
	games[0].player = Vector2(2232, 672)
	games[0].location_transition_armed = true
	games[0].location_transition_cooldown = 0.0
	Pose.reset(games[0])
	games[0]._physics_process(1.0 / 30.0)
	Pose.present(games[0], 1.0)
	if games[0].current_location != "village_market":
		errors.append("actual map entry failed")
	await _capture("map-entry")

	games[0].player = preload("res://scripts/systems/village_region_data.gd").port_position(
		"village_market", "left"
	)
	if not Regions.travel(games[0], "left"):
		errors.append("actual map return failed")
	Pose.reset(games[0])
	Frame.publish(games[0], 1.0 / 30.0)
	await _capture("map-return")
	var image_sha256 := {}
	for row in rows:
		image_sha256[row.composite_file] = FileAccess.get_sha256(
			output.path_join(row.composite_file)
		)
		for state in row.states:
			image_sha256[state.viewport_file] = FileAccess.get_sha256(
				output.path_join(state.viewport_file)
			)
	var document := {
		"task": "VRENDER-009",
		"base_commit": base_commit,
		"profile": profile,
		"engine": Engine.get_version_info().string,
		"display": DisplayServer.get_name(),
		"window": [root.size.x, root.size.y],
		"logical_viewport": [1152, 648],
		"composite_layout": "two 568x504 panels; each reads one 1152x648 SubViewport",
		"camera_contract": "same-camera compares both worlds before independent mutations",
		"provenance":
		{
			"schema": 1,
			"sources": source_sha256,
			"images": image_sha256,
			"launch":
			{
				"script": "tools/qa/world/viewport_isolation_capture.gd",
				"window": [1152, 648],
				"logical_viewport": [1152, 648],
				"cases": CASES,
				"profile": profile,
				"engine": Engine.get_version_info().string,
				"display": DisplayServer.get_name(),
			},
		},
		"coverage":
		["hero", "bush", "rails", "foreground", "HUD", "manual-pause", "F12", "map-entry-return"],
		"rows": rows,
		"reverse_isolation": reverse_isolation,
		"errors": errors,
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(document, "  ") + "\n"
	)
	print("VIEWPORT ISOLATION CAPTURE: ", rows.size(), " cases; ", errors)
	quit(0 if errors.is_empty() else 2)


## Создаёт два независимых render target без повторного использования игровых узлов.
func _build_surface() -> void:
	var surface := Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(surface)
	var background := ColorRect.new()
	background.color = Color("17221e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(background)
	for index in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1152, 648)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		surface.add_child(viewport)
		var game := Points.create_game()
		game.set_script(Observer)
		viewport.add_child(game)
		viewports.append(viewport)
		games.append(game)
		var preview := TextureRect.new()
		preview.position = Vector2(8 + index * 572, 54)
		preview.size = Vector2(564, 504)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = viewport.get_texture()
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(preview)
		var label := Label.new()
		label.position = Vector2(14 + index * 572, 12)
		label.size = Vector2(548, 34)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("f4e2b5"))
		surface.add_child(label)
		labels.append(label)
	var footer := Label.new()
	footer.position = Vector2(12, 574)
	footer.size = Vector2(1128, 56)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 16)
	footer.add_theme_color_override("font_color", Color("c9dbc3"))
	footer.text = (
		"Одинаковая начальная камера · разные владельцы, время и режимы · "
		+ "полный production draw"
	)
	surface.add_child(footer)


## Сохраняет composite и оба исходных viewport.
## Полные состояния записываются вокруг draw.
func _capture(id: String) -> void:
	for index in 2:
		var game: Node = games[index]
		labels[index].text = (
			"%s · %s · %.3f c"
			% ["ИГРА" if index == 0 else "ПРЕВЬЮ", game.current_location, Clock.seconds(game)]
		)
		game.draw_records.clear()
		game.observe_draw = true
		game.queue_redraw()
	await RenderingServer.frame_post_draw
	await process_frame
	for game in games:
		game.queue_redraw()
	await RenderingServer.frame_post_draw
	var states := []
	for index in 2:
		var game: Node = games[index]
		game.observe_draw = false
		var viewport_image := viewports[index].get_texture().get_image()
		var viewport_file := "%s-%s.png" % [id, "game" if index == 0 else "preview"]
		if viewport_image.save_png(output.path_join(viewport_file)) != OK:
			errors.append("cannot save " + viewport_file)
		var token := Context.read(game)
		var packet := Frame.read(game)
		var background := game.get_node("WorldBackground")
		(
			states
			. append(
				{
					"role": "game" if index == 0 else "preview",
					"owner": token,
					"location": game.current_location,
					"player": Points.pair(game.player),
					"camera": Points.pair(game.camera_offset),
					"seconds": Clock.seconds(game),
					"frame_owner": int(packet.get("owner", 0)),
					"frame_viewport_owner": int(packet.get("viewport_owner", 0)),
					"frame_background_owner": int(packet.get("background_owner", 0)),
					"background_position": Points.pair(background.position),
					"background_scale": Points.pair(background.scale),
					"editor": game.LevelEditorSystem.active(game),
					"pause": game.menu_state.pause_open,
					"save": game.SaveSystem.snapshot(game),
					"draws": game.draw_records.duplicate(true),
					"viewport_file": viewport_file,
					"viewport_size": Points.pair(viewport_image.get_size()),
				}
			)
		)
	var composite := root.get_texture().get_image()
	var composite_file := id + ".png"
	if composite.save_png(output.path_join(composite_file)) != OK:
		errors.append("cannot save " + composite_file)
	(
		rows
		. append(
			{
				"id": id,
				"states": states,
				"composite_file": composite_file,
				"composite_size": Points.pair(composite.get_size()),
			}
		)
	)


## Возвращает полный проверяемый срез одного мира без записи в него.
func _observation(game: Node) -> Dictionary:
	var token := Context.read(game)
	var packet := Frame.read(game)
	var background := game.get_node("WorldBackground")
	return {
		"owner": token,
		"location": game.current_location,
		"player": Points.pair(game.player),
		"camera": Points.pair(game.camera_offset),
		"seconds": Clock.seconds(game),
		"frame_owner": int(packet.get("owner", 0)),
		"frame_viewport_owner": int(packet.get("viewport_owner", 0)),
		"frame_background_owner": int(packet.get("background_owner", 0)),
		"background_position": Points.pair(background.position),
		"background_scale": Points.pair(background.scale),
		"save": game.SaveSystem.snapshot(game),
	}


## Ожидает оконный сервер без игровых физических тактов.
func _settle(milliseconds: int) -> void:
	var finish := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < finish:
		await process_frame
