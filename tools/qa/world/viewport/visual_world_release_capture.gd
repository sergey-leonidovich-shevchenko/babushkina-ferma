# Диагностика обращается к композиционному Game и реальным данным его наблюдателя.
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
const Frame := preload("res://scripts/presentation/post_motion_frame.gd")
const Clock := preload("res://scripts/presentation/village_ground_clock.gd")
const Contact := preload("res://scripts/presentation/foliage_contact.gd")
const Wind := preload("res://scripts/presentation/foliage_wind.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Regions := preload("res://scripts/systems/village_region_data.gd")
const Occlusion := preload("res://scripts/systems/tree_occlusion_system.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const SIZE := Vector2i(1152, 648)
const SOURCE_PATHS := [
	"project.godot",
	"main.tscn",
	"scripts/game_core.gd",
	"scripts/world_background.gd",
	"scripts/presentation/terrain_local_revision.gd",
	"scripts/presentation/foliage_wind.gd",
	"scripts/presentation/foliage_wind_batch.gd",
	"scripts/presentation/post_motion_frame.gd",
	"scripts/systems/location_transition_system.gd",
	"scripts/systems/interior_visual_system.gd",
	"scripts/systems/workshop_system.gd",
	"scripts/systems/tree_occlusion_system.gd",
	"tools/qa/world/render_order_game.gd",
	"tools/qa/camera/visual_camera_points.gd",
	"tools/qa/world/viewport/visual_world_release_capture.gd"
]

var output := ""
var profile := ""
var base_commit := ""
var errors: Array[String] = []
var transitions: Array[Dictionary] = []
var images := {}
var snapshots := {}
var review_controls := {}
var draw_pairs := 0
var disposed_worlds := 0
var viewports: Array[SubViewport] = []


## Запускает только нативный захват с отдельными сохранениями и пустым каталогом вывода.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--base-commit="):
			base_commit = argument.trim_prefix("--base-commit=")
	var commit_pattern := RegEx.create_from_string("^[a-f0-9]{40}$")
	if (
		DisplayServer.get_name() == "headless"
		or not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or not profile.begins_with("Codex-VRENDER-010-")
		or profile.contains("/")
		or profile.contains("\\")
		or commit_pattern.search(base_commit) == null
	):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	_run.call_deferred()


## Проверяет 25 двусторонних маршрутов, откат визуального ресурса и изоляцию соседнего окна.
func _run() -> void:
	if DirAccess.make_dir_absolute(output) != OK:
		quit(2)
		return
	root.title = "VRENDER-010 | Выход из визуального мира"
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.show()
	root.grab_focus()
	create_timer(105.0).timeout.connect(_timed_out, CONNECT_ONE_SHOT)
	var control := _create_world(0)
	var preview := _create_world(1)
	_configure(control, Vector2(696, 696), 2.0)
	_configure(preview, Vector2(696, 696), 7.0)
	await _settle_tree_fade([control, preview])
	await _draw_worlds([control, preview])
	_capture(control, 0, "overworld-before")
	_capture(preview, 1, "preview-before")
	var preview_before := _world_state(preview)
	var terrain_ids := _terrain_ids(control)

	for index in 25:
		await _round_trip(control, index, terrain_ids)
		if _world_state(preview) != preview_before:
			errors.append(
				"preview owner, hero, configuration or materials changed on trip %d" % index
			)

	_configure(control, Vector2(696, 696), 2.0)
	await _settle_tree_fade([control, preview])
	await _draw_worlds([control, preview])
	_capture(control, 0, "overworld-after")
	_capture(preview, 1, "preview-after")
	_expect(
		images["overworld-before"].pixels == images["overworld-after"].pixels,
		"same-camera village after 50 transitions changed pixels"
	)
	_expect(
		images["preview-before"].pixels == images["preview-after"].pixels,
		"neighbor viewport pixels changed"
	)
	await _fallback(control)
	await _reattach(control)
	await _pause(control)
	_expect(_world_state(preview) == preview_before, "fallback or pause changed neighbor world")
	_expect(transitions.size() == 50, "the requested 50 transitions did not complete")
	_dispose(control)
	_expect(_world_state(preview) == preview_before, "destroying the game affected preview")
	_dispose(preview)
	_finish()


func _create_world(index: int) -> Node:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewports.append(viewport)
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
	return game


func _configure(game: Node, player: Vector2, seconds: float) -> void:
	Points.configure(game, Points.registry().points[0])
	game.settings_state.reduced_motion = false
	WorldProjection.set_reference_zoom(game, 1.2)
	game.player = player
	game.update_camera()
	Pose.reset(game)
	game.set_meta(Clock.META, seconds - 0.25)
	Frame.publish(game, 0.25)
	Wind.update(game)


func _round_trip(game: Node, index: int, terrain_ids: Array[int]) -> void:
	var background := game.get_node("WorldBackground")
	var target := "cave"
	var outbound := "cave_entrance"
	var inbound := "cave_exit"
	var position: Vector2 = game.cave_entrance_position
	match index % 5:
		0:
			target = "village_market"
			outbound = "village_passage:right"
			inbound = "village_passage:left"
			position = Regions.port_position("overworld", "right")
		1:
			target = "cottage_interior"
			outbound = "building:cottage"
			inbound = "interior_exit"
			position = game.BuildingSystem.BUILDINGS.cottage.door
	var roots := Wind.placements()
	var contact_position := Vector2(roots[0].anchor) + Vector2(12, 0)
	_configure(game, contact_position, 2.0)
	Frame.publish(game, 0.25)
	Wind.update(game)
	var active_owner := game.get_node_or_null(Wind.NAME)
	_expect(active_owner != null, "trip %d has no original foliage owner" % index)
	if active_owner != null:
		_expect(
			not active_owner.recovery.entries.is_empty(), "trip %d did not bend foliage" % index
		)
	var foliage_ids := _foliage_ids(game)
	await _draw_worlds([game])
	_expect(background.terrain_ready, "trip %d did not prepare outgoing terrain" % index)
	if index % 2 == 0:
		background.refresh_terrain()
	else:
		background.invalidate_terrain_rect(Rect2(144, 816, 48, 48))
		background.invalidate_terrain_rect(Rect2(600, 550, 48, 48))
	var before := _terrain_state(background)
	var prior_completed: int = background.terrain_revision.full_paints
	_expect(
		before.queued and (before.full or before.local), "trip %d did not queue terrain" % index
	)
	var left := _activate(game, outbound, position)
	var departed := _terrain_state(background)
	var context_intact := _terrain_ids(game) == terrain_ids
	var foliage_parked := _foliage_parked(game, foliage_ids)
	var old_contact_cleared := not game.has_meta(Frame.META)
	var old_depth_cleared := not game.has_meta(Occlusion.META_KEY)
	_expect(left and game.current_location == target, "outbound %d failed" % index)
	_expect(
		context_intact and foliage_parked and old_contact_cleared and old_depth_cleared,
		"outbound %d leaked owner/contact" % index
	)
	if target == "village_market":
		_expect(
			departed.full and not departed.local and departed.pending == 0,
			"outbound %d stale local regions" % index
		)
	else:
		_expect(
			_inactive(departed) and not departed.active_layers,
			"outbound %d still scheduled old terrain" % index
		)
	await _draw_worlds([game])
	if target == "village_market":
		_expect(background.terrain_ready, "market terrain did not complete")
	else:
		_expect(
			(
				_inactive(_terrain_state(background))
				and background.terrain_revision.full_paints == prior_completed
			),
			"destination drew cancelled terrain"
		)
	transitions.append(
		{
			"route": outbound,
			"from": "overworld",
			"to": target,
			"before": before,
			"after": departed,
			"foliage_parked": foliage_parked,
			"contact_cleared": old_contact_cleared,
			"depth_cleared": old_depth_cleared,
			"same_bounded_terrain_resources": context_intact
		}
	)
	if index == 0:
		_capture(game, 0, "market")
	elif index == 1:
		_capture(game, 0, "cottage")
	elif index == 2:
		_capture(game, 0, "cave")
	match target:
		"village_market":
			position = Regions.port_position(target, "left")
		"cottage_interior":
			position = game.BuildingSystem.INTERIORS.cottage_interior.exit
		_:
			position = game.cave_exit_position
	var returned := _activate(game, inbound, position)
	_expect(returned and game.current_location == "overworld", "return %d failed" % index)
	var return_state := _terrain_state(background)
	_expect(return_state.full and not return_state.ready, "return %d reused old terrain" % index)
	_expect(
		not game.has_meta(Frame.META) and _foliage_parked(game, foliage_ids),
		"return %d reused hero contact" % index
	)
	await _draw_worlds([game])
	_expect(
		background.terrain_ready and _terrain_ids(game) == terrain_ids,
		"return %d did not rebuild bounded terrain" % index
	)
	transitions.append({"route": inbound, "from": target, "to": "overworld", "after": return_state})


func _activate(game: Node, route: String, position: Vector2) -> bool:
	game.player = position
	game.update_camera()
	game.location_transition_armed = true
	game.location_transition_cooldown = 0.0
	if game.LocationTransitionSystem.nearest_transition(game) != route:
		return false
	return game.LocationTransitionSystem.update(game, 1.0 / 60.0)


func _fallback(game: Node) -> void:
	var background := game.get_node("WorldBackground")
	background.set_meta("terrain_direct", true)
	background.queue_redraw()
	await _settle_tree_fade([game])
	await _draw_worlds([game])
	_capture(game, 0, "explicit-direct")
	background.remove_meta("terrain_direct")
	var material: ShaderMaterial = background.terrain_erase.material
	var shader := material.shader
	var completed: int = background.terrain_revision.full_paints
	var ready_state := _terrain_state(background)
	_expect(
		ready_state.ready and not ready_state.queued and not ready_state.handler,
		"shader-loss control requires a ready idle cache"
	)
	material.shader = null
	background.queue_redraw()
	await _check_fallback(game, "missing-shader-ready", completed)
	review_controls["ready_shader_loss"] = {
		"before": ready_state,
		"after": _terrain_state(background),
		"water_visible": background.water_layer.visible
	}
	material.shader = shader
	await _restore_cache(game, "resource-restored-ready")

	completed = background.terrain_revision.full_paints
	background.refresh_terrain()
	material.shader = null
	await _check_fallback(game, "missing-shader", completed)
	_expect(
		background.invalidate_terrain_rect(Rect2(144, 816, 48, 48)),
		"fallback declined valid local input"
	)
	_expect(_inactive(_terrain_state(background)), "missing shader rearmed GPU work")
	material.shader = shader
	await _restore_cache(game, "resource-restored")


func _check_fallback(game: Node, name: String, completed: int) -> void:
	var background := game.get_node("WorldBackground")
	await _settle_tree_fade([game])
	await _draw_worlds([game])
	_expect(
		(
			_inactive(_terrain_state(background))
			and not background.water_layer.visible
			and background.terrain_revision.full_paints == completed
		),
		name + " kept the cache, water layer or incomplete pass"
	)
	_capture(game, 0, name)
	_expect(
		images["explicit-direct"].pixels == images[name].pixels,
		name + " pixels differ from direct draw"
	)


func _restore_cache(game: Node, name: String) -> void:
	var background := game.get_node("WorldBackground")
	background.refresh_terrain()
	await _settle_tree_fade([game])
	await _draw_worlds([game])
	_expect(background.terrain_ready, "restored shader could not rebuild cache")
	_capture(game, 0, name)
	_expect(
		images["overworld-after"].pixels == images[name].pixels, name + " changed the cached scene"
	)


func _pause(game: Node) -> void:
	var before := Clock.seconds(game)
	game.MenuSystem.open_pause(game)
	_expect(
		game.menu_state.pause_open and not Frame.publish(game, 0.2),
		"manual pause advanced visual frame"
	)
	Wind.update(game)
	await _draw_worlds([game])
	_expect(before == Clock.seconds(game), "manual pause advanced clock")
	_capture(game, 0, "paused")
	game.MenuSystem.resume(game)


func _reattach(game: Node) -> void:
	var background := game.get_node("WorldBackground")
	for request: String in ["full", "local"]:
		background.refresh_terrain()
		game.remove_child(background)
		var before := _terrain_state(background)
		var revision: Dictionary = background.terrain_revision.snapshot()
		var requests: int = background.terrain_requests
		_expect(_inactive(before), "detached background kept rendering")
		_expect(Context.read(game).is_empty(), "detached background still owns the game draw")
		if request == "full":
			background.refresh_terrain()
		else:
			_expect(
				not background.invalidate_terrain_rect(Rect2(144, 816, 48, 48)),
				"detached local request was accepted"
			)
		var after := _terrain_state(background)
		_expect(
			(
				after == before
				and revision == background.terrain_revision.snapshot()
				and requests == background.terrain_requests
			),
			"detached %s request scheduled work" % request
		)
		game.add_child(background)
		var attached := _terrain_state(background)
		_expect(
			attached.full and attached.queued and attached.handler,
			"attach did not schedule a new pass"
		)
		game.sync_background_location()
		game.update_camera()
		await _draw_worlds([game])
		_expect(
			background.terrain_ready and not Context.read(game).is_empty(),
			"reattached background could not resume"
		)
		review_controls["detached_" + request] = {
			"before": before,
			"after": after,
			"attached": attached,
			"completed": _terrain_state(background)
		}


func _draw_worlds(games: Array) -> void:
	for game in games:
		game.draw_records.clear()
		game.observe_draw = true
		game.queue_redraw()
	for index in 3:
		await RenderingServer.frame_post_draw
		await process_frame
	for game in games:
		game.observe_draw = false
		_expect(not game.draw_records.is_empty(), "actual game draw was not observed")
		for pair in game.draw_records:
			draw_pairs += 1
			if not pair.equal or not pair.geometry_equal:
				var changed := []
				for key in pair.before:
					if pair.before[key] != pair.after.get(key):
						changed.append(key)
				errors.append(
					(
						"draw on %s changed snapshot %s, geometry_equal=%s"
						% [pair.geometry_before.location, changed, pair.geometry_equal]
					)
				)


## Дожидается затухания кроны штатным движением альфы.
func _settle_tree_fade(games: Array) -> void:
	for step in 4:
		await create_timer(0.12).timeout
		for game in games:
			game.queue_redraw()
		await RenderingServer.frame_post_draw


func _capture(game: Node, index: int, name: String) -> void:
	var image := viewports[index].get_texture().get_image()
	var file := name + ".png"
	_expect(
		image.get_size() == SIZE and image.save_png(output.path_join(file)) == OK,
		"cannot save " + file
	)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(image.get_data())
	images[name] = {
		"file": file,
		"png": FileAccess.get_sha256(output.path_join(file)),
		"pixels": digest.finish().hex_encode(),
		"world": _world_state(game)
	}
	snapshots[name] = game.draw_records.duplicate(true)


func _world_state(game: Node) -> Dictionary:
	return {
		"owner": Context.read(game),
		"location": game.current_location,
		"camera": Points.pair(game.camera_offset),
		"player": Points.pair(game.player),
		"seconds": Clock.seconds(game),
		"foliage": _foliage_ids(game),
		"terrain": _terrain_ids(game)
	}


func _terrain_state(background: Node) -> Dictionary:
	var revision: Dictionary = background.terrain_revision.snapshot()
	return {
		"ready": background.terrain_ready,
		"full": revision.full_pending,
		"local": revision.active.has_area(),
		"pending": revision.pending.size(),
		"queued": background.terrain_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"handler": RenderingServer.frame_post_draw.is_connected(background._terrain_rendered),
		"active_layers":
		(
			background.water_layer.visible
			or background.cover_layer.visible
			or background.cutout_layer.visible
		)
	}


func _inactive(state: Dictionary) -> bool:
	return not (
		state.ready
		or state.full
		or state.local
		or state.pending > 0
		or state.queued
		or state.handler
	)


func _terrain_ids(game: Node) -> Array[int]:
	var background := game.get_node("WorldBackground")
	return [
		background.terrain_viewport.get_instance_id(),
		background.cutout_layer.material.get_instance_id(),
		background.terrain_erase.material.get_instance_id()
	]


func _foliage_ids(game: Node) -> Array[int]:
	var owner := game.get_node_or_null(Wind.NAME)
	var result: Array[int] = []
	if owner != null:
		result = [owner.get_instance_id(), owner.batch.viewport.get_instance_id()]
		for group in owner.batch.groups:
			result.append(group.material.get_instance_id())
	return result


func _foliage_parked(game: Node, previous: Array[int]) -> bool:
	var owner := game.get_node_or_null(Wind.NAME)
	return (
		owner != null
		and _foliage_ids(game) == previous
		and owner.visible_rows.is_empty()
		and owner.batch.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED
		and owner.recovery.entries.is_empty()
		and owner.last_contacts == Contact.empty()
		and owner.render_contacts == Contact.empty()
	)


func _dispose(game: Node) -> void:
	var resource_ids := _terrain_ids(game) + _foliage_ids(game)
	game.free()
	if resource_ids.all(func(id: int) -> bool: return not is_instance_id_valid(id)):
		disposed_worlds += 1
	else:
		errors.append("closed world kept a viewport or material")


func _expect(condition: bool, error: String) -> void:
	if not condition:
		errors.append(error)


func _timed_out() -> void:
	errors.append("native renderer stopped drawing")
	_finish()


func _finish() -> void:
	var sources := {}
	for path in SOURCE_PATHS:
		sources[path] = FileAccess.get_sha256("res://" + path)
		_expect(sources[path].length() == 64, "cannot hash " + path)
	var report := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if report == null:
		quit(2)
		return
	report.store_string(
		(
			JSON.stringify(
				{
					"task": "VRENDER-010",
					"base_commit": base_commit,
					"profile": profile,
					"engine": Engine.get_version_info().string,
					"display": DisplayServer.get_name(),
					"adapter": RenderingServer.get_video_adapter_name(),
					"logical_viewport": Points.pair(SIZE),
					"visible_window": Points.pair(root.size),
					"sources": sources,
					"images": images,
					"transitions": transitions,
					"real_draw_pairs": draw_pairs,
					"disposed_worlds": disposed_worlds,
					"review_controls": review_controls,
					"errors": errors
				},
				"  "
			)
			+ "\n"
		)
	)
	var observations := FileAccess.open(output.path_join("draw-snapshots.json"), FileAccess.WRITE)
	if observations == null:
		quit(2)
		return
	observations.store_string(JSON.stringify(snapshots) + "\n")
	print(
		(
			"VISUAL WORLD RELEASE: %d transitions, %d draw pairs; %s"
			% [transitions.size(), draw_pairs, errors]
		)
	)
	quit(0 if errors.is_empty() else 2)
