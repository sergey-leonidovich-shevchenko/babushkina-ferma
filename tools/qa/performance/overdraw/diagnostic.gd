extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Wind := preload("res://scripts/presentation/foliage_wind.gd")
const WindBudget := preload("res://tools/qa/foliage/foliage_visibility_budget.gd")
const Probe := preload("res://scripts/presentation/overworld_render_probe.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Clock := preload("res://scripts/presentation/village_ground_clock.gd")
const PostMotion := preload("res://scripts/presentation/post_motion_frame.gd")
const Save := preload("res://scripts/systems/save_system.gd")
const Background := preload("res://scripts/world_background.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const Water := preload("res://scripts/systems/water_map_registry.gd")
const Surface := preload("res://scripts/presentation/village_water_surface.gd")
const SIZE := Vector2i(1152, 648)
const CONTACT_WIND_SIZE := Vector2i(384, 192)
const CONTACT_CASE := "grass-contact"
const CONTACT_DEFAULT_CASE := "grass-contact-120"
const READY_DRAWS := 8
const READY_MIN_MS := 500
const READY_TIMEOUT_MS := 8000
const CASES := [
	["west-bridge", Vector2(864, 456), 1, 780.0, "normal", 1.2, 12.5],
	["east-bridge", Vector2(1608, 912), 1, 1200.0, "low", 1.2, 29.25],
	["dense-grass", Vector2(1944, 768), 1, 845.0, "normal", 1.2, 46.75],
	["still-bridge", Vector2(864, 456), 31, 780.0, "static", 1.0, 0.0],
	[CONTACT_CASE, Vector2(1955, 655), 1, 845.0, "normal", 1.0, 51.25],
	[CONTACT_DEFAULT_CASE, Vector2(1955, 655), 1, 845.0, "normal", 1.2, 51.25],
]

var output := ""
var profile := ""
var completed_draws := 0


class CoverageCard:
	extends Node2D
	var camera: Transform2D
	var polygons: Array[PackedVector2Array]

	func _draw() -> void:
		draw_set_transform_matrix(camera)
		for polygon in polygons:
			draw_colored_polygon(polygon, Color.WHITE)


class ContactComposite:
	extends Node2D
	var game: Node2D
	var rows: Array[Dictionary]

	func _draw() -> void:
		draw_set_transform_matrix(WorldProjection.transform(game))
		for row in rows:
			var kind: String = row.kind
			var position: Vector2 = row.position
			Wind.draw(game, kind, position, Color(1, 1, 1, 0.82), self)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		else:
			quit(2)
			return
	if (
		DisplayServer.get_name() != "X11"
		or OS.get_user_data_dir().get_file() != profile
		or RegEx.create_from_string("^Codex-VPERF-004-[a-f0-9]{32}$").search(profile) == null
		or FileAccess.file_exists(Save.SAVE_PATH)
		or not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or DirAccess.make_dir_absolute(output) != OK
	):
		quit(2)
		return
	_run.call_deferred()


## Неподвижные кадры и диагностические маски снимаются вне таймингов.
func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = SIZE
	root.title = "VPERF-004 | fixed views"
	root.show()
	root.grab_focus()
	var a := Terrain.WaterOcclusion.rectangle(Rect2(0, 0, 32, 32))
	var b := Terrain.WaterOcclusion.rectangle(Rect2(16, 16, 32, 32))
	var cards: Array[PackedVector2Array] = [a, b]
	var calibration: Array[Dictionary] = [{"polygons": cards, "channels": Vector3.ONE}]
	if not await _coverage_frame(calibration, Transform2D.IDENTITY, "calibration.png"):
		quit(2)
		return
	var receipt := []
	for case_data: Array in CASES:
		for trimmed: bool in [false, true]:
			var result: Dictionary = await _capture(case_data, trimmed)
			if result.is_empty():
				push_error("VPERF-004 fixed camera capture failed: " + str(case_data))
				quit(2)
				return
			receipt.append(result)
	var file := FileAccess.open(output.path_join("views.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(receipt) + "\n")
	quit()


func _capture(case_data: Array, trimmed: bool) -> Dictionary:
	var case_id: String = case_data[0]
	var player: Vector2 = case_data[1]
	var phase: float = case_data[6]
	var is_contact := case_id in [CONTACT_CASE, CONTACT_DEFAULT_CASE]
	var view := {
		"id": case_id,
		"player": Points.pair(player),
		"facing": [0, 1],
		"location": "overworld",
		"day": case_data[2],
		"minutes": case_data[3],
	}
	var game := Points.create_game() as Node2D
	if not trimmed:
		game.set_meta(Probe.FULL_COVERAGE, true)
	game.set_meta(Probe.FIXED_EFFECT_SECONDS, phase)
	game.set_meta(Surface.QUALITY, case_data[4])
	game.set_meta(Clock.META, phase - 0.25 if is_contact else phase)
	root.add_child(game)
	current_scene = game
	Points.configure(game, view)
	var settings: Object = game.get("settings_state")
	settings.set("reduced_motion", case_data[4] == "static")
	var zoom: float = case_data[5]
	WorldProjection.set_reference_zoom(game, zoom)
	# Игра хранит узлы презентации за фасадом; CameraSystem обновляет его штатным методом.
	game.call("update_camera")
	Pose.reset(game)
	if is_contact:
		# Сейчас камера и герой неподвижны. Два штатных визуальных такта поднимают контакт.
		for step in 2:
			if not PostMotion.publish(game, 0.125):
				game.free()
				return {}
			Wind.update(game)
	var background := game.get_node("WorldBackground") as Background
	var prefix := case_id + ("-trimmed" if trimmed else "-baseline")
	var readiness := await _settle_view(game, background)
	if readiness.ready != true:
		_report_view_failure(prefix, readiness)
		game.free()
		return {}
	var state := Points.snapshot(game, view)
	var unchanged := JSON.stringify(Save.snapshot(game), "", true, true).sha256_text()
	var image := root.get_texture().get_image()
	var image_size := image.get_size() if image != null else Vector2i.ZERO
	var capture_state := _window_state(background)
	var saved := ERR_UNAVAILABLE
	if image_size == SIZE and _ready_frame(capture_state):
		saved = image.save_png(output.path_join(prefix + "-frame.png"))
	if saved != OK:
		capture_state["image_size"] = Points.pair(image_size)
		capture_state["save_result"] = saved
		_report_view_failure(prefix, capture_state)
		game.free()
		return {}
	var owner := game.get_node_or_null(Wind.NAME) as Wind
	var contact := _contact_snapshot(game, owner)
	if contact.is_empty():
		game.free()
		return {}
	if is_contact and not await _contact_composite(game, owner, prefix):
		game.free()
		return {}
	var world_mask := await _world_coverage(game, background, owner, prefix)
	var wind_mask := await _wind_coverage(owner, prefix)
	var receipt := {
		"case": case_id,
		"trimmed": trimmed,
		"quality": case_data[4],
		"zoom": case_data[5],
		"live_seconds": Clock.seconds(game),
		"effect_seconds": Probe.effect_seconds(game),
		"state": state,
		"save": unchanged,
		"final_save": JSON.stringify(Save.snapshot(game), "", true, true).sha256_text(),
		"deck_trim": background.water_layer.trim_decks and background.water_surface.trim_decks,
		"wind_rows": owner.visible_rows.size() if owner != null else 0,
		"contact": contact,
		"framebuffer": Points.pair(image.get_size()),
		"display": DisplayServer.get_name(),
		"readiness": readiness,
	}
	game.free()
	return receipt if world_mask and wind_mask else {}


## Применяет оконный профиль после инициализации игры и ждёт серию стабильных нативных кадров.
func _settle_view(game: Node2D, background: Background) -> Dictionary:
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.show()
	root.grab_focus()
	completed_draws = 0
	RenderingServer.frame_post_draw.connect(_record_draw)
	var started := Time.get_ticks_msec()
	var deadline := started + READY_TIMEOUT_MS
	var retry_focus := started + 250
	var stable := 0
	var observed_draws := 0
	var observed := _window_state(background)
	var ready := false
	var elapsed := 0
	while Time.get_ticks_msec() < deadline and not ready:
		Wind.update(game)
		game.queue_redraw()
		# Таймер продолжает работать, даже если renderer перестал присылать frame_post_draw.
		await process_frame
		observed = _window_state(background)
		var now := Time.get_ticks_msec()
		elapsed = now - started
		var valid := _ready_frame(observed)
		if not valid:
			stable = 0
		if completed_draws != observed_draws:
			observed_draws = completed_draws
			if valid:
				stable += 1
			ready = stable >= READY_DRAWS and elapsed >= READY_MIN_MS and now < deadline
		if observed.focus == false and now >= retry_focus:
			root.grab_focus()
			retry_focus = now + 250
	RenderingServer.frame_post_draw.disconnect(_record_draw)
	observed["stable_draws"] = stable
	observed["callbacks"] = completed_draws
	observed["elapsed_ms"] = elapsed
	observed["ready"] = ready
	return observed


func _record_draw() -> void:
	completed_draws += 1


func _window_state(background: Background) -> Dictionary:
	return {
		"focus": DisplayServer.window_is_focused(),
		"visible": root.visible,
		"host_size": Points.pair(DisplayServer.window_get_size()),
		"window_size": Points.pair(root.size),
		"framebuffer": Points.pair(root.get_texture().get_size()),
		"window_mode": root.mode,
		"ground_ready": background.terrain_ready,
		"ground_split": background.ground_split,
		"water_visible": background.water_layer.is_visible_in_tree(),
		"terrain_requests": background.terrain_requests,
	}


func _ready_frame(observed: Dictionary) -> bool:
	var expected := Points.pair(SIZE)
	return (
		observed.focus == true
		and observed.visible == true
		and observed.host_size == expected
		and observed.window_size == expected
		and observed.framebuffer == expected
		and observed.window_mode == Window.MODE_WINDOWED
		and observed.ground_ready == true
		and observed.ground_split == true
		and observed.water_visible == true
		and observed.terrain_requests > 0
	)


func _report_view_failure(prefix: String, observed: Dictionary) -> void:
	var failure := {"view": prefix, "observed": observed}
	var file := FileAccess.open(output.path_join("window-error.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(failure) + "\n")
	push_error("VPERF-004 fixed view readiness: " + JSON.stringify(failure))


## Связывает записанные изгибы с фактическим uniform после кадра композита.
static func _contact_snapshot(game: Node2D, owner: Wind) -> Dictionary:
	if owner == null:
		return {"scale": 0, "frame": false, "bends": []}
	var contact_frame := PostMotion.read(game)
	for group: MultiMeshInstance2D in owner.batch.groups:
		var material := group.material as ShaderMaterial
		if material.get_shader_parameter("contact_bends") != owner.render_contacts:
			return {}
	var bends := []
	for index: int in owner.visible_rows:
		var bend: Vector2 = owner.render_contacts[index]
		bends.append([index, Points.pair(bend)])
	return {"scale": owner.batch.scale, "frame": contact_frame.get("active", false), "bends": bends}


## Вызывает тот же композитор на прозрачном target, чтобы проверять краевую альфу отдельно от земли.
func _contact_composite(game: Node2D, owner: Wind, prefix: String) -> bool:
	if owner == null:
		return false
	var wind: SubViewport = owner.batch.viewport
	var scale: int = owner.batch.scale
	var wind_image := wind.get_texture().get_image()
	if (
		wind_image == null
		or wind_image.get_size() != CONTACT_WIND_SIZE * scale
		or wind_image.save_png(output.path_join(prefix + "-wind-color.png")) != OK
	):
		return false
	var target := SubViewport.new()
	target.disable_3d = true
	target.transparent_bg = true
	target.size = SIZE
	target.canvas_item_default_texture_filter = (
		game.get_viewport().canvas_item_default_texture_filter
	)
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(target)
	var card := ContactComposite.new()
	card.game = game
	card.texture_filter = game.texture_filter
	card.texture_repeat = game.texture_repeat
	for index: int in owner.visible_rows:
		var row: Dictionary = owner.batch.rows[index]
		card.rows.append(row)
	target.add_child(card)
	for frame in 2:
		await RenderingServer.frame_post_draw
	var image := target.get_texture().get_image()
	var saved := (
		image.get_size() == SIZE
		and image.save_png(output.path_join(prefix + "-composite.png")) == OK
	)
	target.free()
	return saved


func _world_coverage(game: Node2D, background: Background, owner: Wind, prefix: String) -> bool:
	var surface: Array[PackedVector2Array] = []
	var snapshot := Water.visual("overworld")
	var regions: Array = snapshot.regions
	for region: Dictionary in regions:
		surface.append_array(
			Terrain.surface_region_polygons(region, true, background.water_surface.trim_decks)
		)
	var grass: Array[PackedVector2Array] = []
	if owner != null:
		for index: int in owner.visible_rows:
			var row: Dictionary = owner.batch.rows[index]
			var slot := Wind.Batch.slot(index)
			var crops: Dictionary = owner.batch.content
			var crop: Rect2 = crops.get(row.kind, Rect2(Vector2.ZERO, slot.size))
			var plant: Rect2 = row.rect
			grass.append(
				Terrain.WaterOcclusion.rectangle(Wind.Batch.world_destination(plant, crop))
			)
	var layers: Array[Dictionary] = [
		{"polygons": surface, "channels": Vector3(1, 0, 0)},
		{"polygons": grass, "channels": Vector3(0, 1, 0)},
		{
			"polygons": Terrain.surface_polygons(true, background.water_layer.trim_decks),
			"channels": Vector3(0, 0, 1)
		},
	]
	return await _coverage_frame(layers, WorldProjection.transform(game), prefix + "-world.png")


func _coverage_frame(layers: Array[Dictionary], camera: Transform2D, file: String) -> bool:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec3 channels;
void fragment() { COLOR = vec4(channels / 255.0, 1.0); }
"""
	var target := SubViewport.new()
	target.disable_3d = true
	target.transparent_bg = true
	target.size = SIZE
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(target)
	for layer in layers:
		var card := CoverageCard.new()
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("channels", layer.channels)
		card.material = material
		card.camera = camera
		card.polygons = layer.polygons
		target.add_child(card)
	for frame in 2:
		await RenderingServer.frame_post_draw
	var image := target.get_texture().get_image()
	var saved := image.get_size() == SIZE and image.save_png(output.path_join(file)) == OK
	target.free()
	return saved


func _wind_coverage(owner: Wind, prefix: String) -> bool:
	if owner == null:
		return true
	for group: MultiMeshInstance2D in owner.batch.groups:
		var material := group.material as ShaderMaterial
		material.shader = WindBudget.coverage_shader()
		material.set_shader_parameter("seconds", owner.last_seconds)
		material.set_shader_parameter("contact_bends", owner.render_contacts)
	var target: SubViewport = owner.batch.viewport
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for frame in 2:
		await RenderingServer.frame_post_draw
	return target.get_texture().get_image().save_png(output.path_join(prefix + "-wind.png")) == OK
