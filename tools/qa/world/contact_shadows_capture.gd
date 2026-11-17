extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/render_order_game.gd")
const WorldSpace := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const LOCATIONS := {
	"farm": Vector2(816, 1020),
	"street": Vector2(870, 471),
	"grove": Vector2(1848, 1140),
}

var output := ""
var profile := ""
var normal_motion := false
var game: Observer
var frames: Dictionary = {}
var failures: Array[String] = []


## Запускает только нативное окно с отдельным профилем и новым каталогом кадров.
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		if argument == "--normal-motion":
			normal_motion = true
	if (
		not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or not profile.begins_with("Codex-VSHADOW-002-")
		or not profile.is_valid_filename()
		or DisplayServer.get_name() == "headless"
	):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	if OS.get_user_data_dir().get_file() != profile:
		quit(2)
		return
	_start.call_deferred()


## Снимает реальные грядки, улицу и рощу с неизменной симуляцией и камерой 120%.
func _start() -> void:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	var scene := Points.create_game()
	scene.set_script(Observer)
	game = scene as Observer
	game.world_loot_seed = Points.SEED
	root.add_child(game)
	current_scene = game
	var point: Dictionary = Points.registry().points[0]
	Points.configure(game, point)
	game.FirstChapterSystem.state(game).bridge_repaired = true
	WorldSpace.set_reference_zoom(game, WorldSpace.REFERENCE_ZOOM)
	root.title = "VSHADOW-002 | Контактные тени"
	root.mode = Window.MODE_WINDOWED
	root.size = Points.SIZE
	root.show()
	root.grab_focus()
	await create_timer(1.5).timeout
	game.settings_state.reduced_motion = not normal_motion
	root.mode = Window.MODE_WINDOWED
	await create_timer(1.0).timeout
	root.size = Points.SIZE
	root.grab_focus()
	await create_timer(1.5).timeout
	for location: String in LOCATIONS:
		game.player = LOCATIONS[location]
		game.facing = Vector2.DOWN
		game.update_camera()
		Pose.reset(game)
		for minutes: int in [720, 1140]:
			game.game_minutes = minutes
			game.sync_background_environment()
			await _capture("%s-%d" % [location, minutes])
	var manifest := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if manifest == null:
		quit(2)
		return
	(
		manifest
		. store_line(
			(
				JSON
				. stringify(
					{
						"task": "VSHADOW-002",
						"display": DisplayServer.get_name(),
						"engine": Engine.get_version_info().string,
						"renderer": RenderingServer.get_current_rendering_method(),
						"motion": "normal" if normal_motion else "reduced",
						"frames": frames,
						"failures": failures,
					},
					"\t"
				)
			)
		)
	)
	print("CONTACT SHADOWS NATIVE: ", frames.size(), " frames, ", failures)
	quit(0 if failures.is_empty() else 2)


## Привязывает каждый кадр к фактическому профилю камеры, опорным точкам и снимку игры.
func _capture(id: String) -> void:
	var scene_state := Points.snapshot(game, {"id": id})
	if scene_state.walkable != "walkable":
		failures.append(id + ": " + str(scene_state.walkable))
		return
	for pass_id: int in 5:
		game.queue_redraw()
		await RenderingServer.frame_post_draw
	var before: Dictionary = game.SaveSystem.snapshot(game)
	game.draw_records.clear()
	game.observe_draw = true
	for pass_id: int in 2:
		game.queue_redraw()
		await RenderingServer.frame_post_draw
	game.observe_draw = false
	var frame := root.get_texture().get_image()
	var equal: bool = before == game.SaveSystem.snapshot(game)
	for record: Dictionary in game.draw_records:
		equal = equal and record.equal and record.geometry_equal
	if (
		frame == null
		or game.draw_records.size() != 2
		or not equal
		or not root.visible
		or DisplayServer.window_get_size() != Points.SIZE
	):
		(
			failures
			. append(
				(
					"%s: image=%s, callbacks=%d, state=%s, visible=%s, window=%s"
					% [
						id,
						frame != null,
						game.draw_records.size(),
						equal,
						root.visible,
						DisplayServer.window_get_size(),
					]
				)
			)
		)
		return
	if frame.save_png(output.path_join(id + ".png")) != OK:
		failures.append(id + ": PNG write failed")
		return
	var anchors := {
		"hero": WorldSpace.world_to_screen(game, Pose.ground(game)),
		"table": WorldSpace.world_to_screen(game, game.workbench_position + Vector2(0, 24)),
		"post": WorldSpace.world_to_screen(game, Vector2(768, 576)),
		"tree": WorldSpace.world_to_screen(game, game.TreeSystem.ground_anchor(Map.TREES[7])),
	}
	var screen_anchors: Dictionary = {}
	for name: String in anchors:
		var anchor: Vector2 = anchors[name]
		screen_anchors[name] = Points.pair(anchor)
	frames[id] = {
		"snapshot": scene_state,
		"save_unchanged": equal,
		"size": Points.pair(Vector2(frame.get_size())),
		"window": Points.pair(Vector2(DisplayServer.window_get_size())),
		"callbacks": game.draw_records.size(),
		"zoom": WorldSpace.zoom(game),
		"reduced_motion": game.settings_state.reduced_motion,
		"anchors": screen_anchors,
		"contacts_in_world": _contacts_in_world(),
	}


## Указывает допустимые области пиксельного сравнения по фактическим опорам мира.
func _contacts_in_world() -> Array[Dictionary]:
	var contacts: Array[Dictionary] = [
		_contact("hero", Pose.ground(game)),
		_contact("table", game.workbench_position + Vector2(0, 24)),
		_contact("tree", Map.SEASONAL_TREE),
	]
	for prop: Dictionary in Layout.PROP_PLACEMENTS:
		if prop.kind == "lamp":
			var position: Vector2 = prop.position
			contacts.append(_contact("post", position + Vector2(0, 24)))
	for position: Vector2 in Map.BORDER_TREES:
		contacts.append(_contact("tree", game.TreeSystem.ground_anchor(position)))
	for item: Dictionary in game.state.world.tree_nodes:
		var stage: int = item.stage
		if stage == 3:
			var position: Vector2 = item.position
			contacts.append(_contact("tree", game.TreeSystem.ground_anchor(position)))
	return contacts


## Записывает экранную точку опоры через игровую проекцию камеры.
func _contact(kind: String, ground: Vector2) -> Dictionary:
	return {"kind": kind, "anchor": Points.pair(WorldSpace.world_to_screen(game, ground))}
