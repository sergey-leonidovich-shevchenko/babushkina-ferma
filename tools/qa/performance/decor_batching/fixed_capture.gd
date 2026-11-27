extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Mode := preload("res://tools/qa/performance/decor_batching/capture_mode.gd")
const Groups := preload("res://tools/qa/performance/decor_batching/flower_groups.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const GameScene := preload("res://scripts/game.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Props := preload("res://scripts/systems/village_prop_renderer.gd")
const Light := preload("res://scripts/presentation/lighting_quality.gd")
const OCCLUSION_FLOWER := Vector2(1128, 720)
const READY_DRAWS := 8
const READY_MIN_MS := 500
const READY_TIMEOUT_MS := 8000

var _output := ""
var _variant := ""
var _vsync := -1
var _game: GameScene
var _background: Mode.Background
var _candidate: Mode.Candidate
var _evidence := {}


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		_fail("expected output, profile and capture plan")
		return
	_output = args[0]
	var profile := args[1]
	_variant = OS.get_environment("VPERF006_VARIANT")
	if (
		DisplayServer.get_name() != "X11"
		or _variant not in Mode.VARIANTS
		or not _output.is_absolute_path()
		or OS.get_user_data_dir().get_file() != profile
		or FileAccess.file_exists("user://farm-save.json")
		or FileAccess.file_exists("user://farm-settings.cfg")
		or DirAccess.make_dir_absolute(_output) != OK
	):
		_fail("native X11 and a fresh isolated profile are required")
		return
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.title = "VPERF-006 | %s | fixed" % _variant
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 0
	_game = Points.create_game() as GameScene
	root.add_child(_game)
	current_scene = _game
	_background = _game.get_node("WorldBackground") as Mode.Background
	Mode.install(_background, _variant)
	_candidate = _background.cover_layer as Mode.Candidate
	root.mode = Window.MODE_WINDOWED
	root.size = Points.SIZE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	root.show()
	root.grab_focus()
	create_timer(150.0).timeout.connect(_fail.bind("fixed capture exceeded its deadline"))
	_evidence = {
		"variant": _variant,
		"profile": profile,
		"pid": OS.get_process_id(),
		"display": DisplayServer.get_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"engine_build": Engine.get_version_info().hash,
		"cases": {},
		"overlap": {},
	}
	var repetitions: int = plan.repetitions
	for spec: Dictionary in plan.cases:
		if not await _case(spec, repetitions):
			_fail("fixed case rejected: %s / %s" % [spec.id, _conditions()])
			return
	for spec: Dictionary in plan.overlap:
		if not await _overlap(spec):
			_fail("overlap rejected: %s / %s" % [spec.id, _conditions()])
			return
	if _variant == "baseline" and not await _negative_order():
		_fail("could not record the deliberately wrong depth order")
		return
	_evidence["complete"] = true
	_write()
	quit()


func _setup(player: Array, day: int) -> void:
	(
		Points
		. configure(
			_game,
			{
				"location": "overworld",
				"player": player,
				"facing": [0, 1],
				"day": day,
				"minutes": 780.0,
			}
		)
	)
	Reference.enable(_game, true)
	WorldProjection.set_reference_zoom(_game, 1.2)
	Light.set_profile(_game, Light.STANDARD)
	Pose.reset(_game)
	_game.update_camera()


func _conditions() -> Dictionary:
	return {
		"window": Points.pair(DisplayServer.window_get_size()),
		"framebuffer": Points.pair(root.get_texture().get_size()),
		"camera": Points.pair(_game.camera_offset),
		"player": Points.pair(Pose.ground(_game)),
		"focus": DisplayServer.window_is_focused(),
		"preset": Mode.preset(_background),
		"zoom_percent": roundi(WorldProjection.zoom(_game) * 100.0),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"vsync_requested": DisplayServer.VSYNC_ENABLED,
		"season": _background.season,
		"weather": _background.weather,
		"terrain_ready": _background.terrain_ready,
		"day": _game.day,
		"minutes": _game.game_minutes,
		"seed": _game.world_loot_seed,
		"light_standard": Light.profile(_game) == Light.STANDARD,
		"reduced_motion": _game.settings_state.reduced_motion,
		"reference_effects": Reference.effects_enabled(_game),
		"physics_processing": _game.is_physics_processing(),
	}


func _valid() -> bool:
	return (
		DisplayServer.window_is_focused()
		and DisplayServer.window_get_size() == Points.SIZE
		and root.size == Points.SIZE
		and Vector2i(root.get_texture().get_size()) == Points.SIZE
		and root.mode == Window.MODE_WINDOWED
		and (_vsync < 0 or DisplayServer.window_get_vsync_mode() == _vsync)
		and WorldProjection.zoom(_game) == 1.2
		and Mode.installed(_background, _variant)
	)


func _settle() -> bool:
	var started := Time.get_ticks_msec()
	var ready_draws := 0
	var previous_vsync := -1
	while Time.get_ticks_msec() - started <= READY_TIMEOUT_MS:
		_game.queue_redraw()
		await RenderingServer.frame_post_draw
		var current_vsync := DisplayServer.window_get_vsync_mode()
		if not _valid() or not _background.terrain_ready:
			ready_draws = 0
			continue
		ready_draws = ready_draws + 1 if previous_vsync == current_vsync else 1
		previous_vsync = current_vsync
		if ready_draws >= READY_DRAWS and Time.get_ticks_msec() - started >= READY_MIN_MS:
			_vsync = current_vsync
			return true
	return false


func _case(spec: Dictionary, repetitions: int) -> bool:
	var player: Array = spec.player
	_setup(player, 1)
	if _candidate != null:
		_candidate.set_capture_clip(Rect2())
	if not await _settle():
		return false
	var repaint := Rect2()
	if spec.repaint != null:
		var cell: Array = spec.repaint
		var x: float = cell[0]
		var y: float = cell[1]
		var width: float = cell[2]
		var height: float = cell[3]
		repaint = Rect2(x, y, width, height)
	var phase: String = spec.phase
	var samples := []
	for _index in repetitions:
		var sample := await _sample(phase, repaint)
		if sample.is_empty():
			return false
		samples.append(sample)
	if not await _settle():
		return false
	var id: String = spec.id
	var frame := _capture_frame(id, true)
	if frame.is_empty():
		return false
	_evidence.cases[id] = {
		"state": _conditions(),
		"geometry": _geometry(spec, repaint),
		"samples": samples,
		"frame": frame,
	}
	_write()
	return true


func _sample(phase: String, repaint: Rect2) -> Dictionary:
	_game.queue_redraw()
	await RenderingServer.frame_post_draw
	var previous_draw := Time.get_ticks_usec()
	var before := Mode.terrain(_background)
	var requested := Time.get_ticks_usec()
	if _candidate != null and phase != "warm_route":
		_candidate.set_capture_clip(repaint)
	if phase == "full_refresh":
		_background.refresh_terrain()
	elif phase == "local_refresh" and not _background.invalidate_terrain_rect(repaint):
		return {}
	var submitted := Time.get_ticks_usec()
	_game.queue_redraw()
	await RenderingServer.frame_post_draw
	var presented := Time.get_ticks_usec()
	var target: SubViewport = _background.terrain_viewport
	var statistics := {
		"previous_draw_usec": previous_draw,
		"requested_usec": requested,
		"submitted_usec": submitted,
		"presented_usec": presented,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"terrain_draw_calls":
		(
			target.get_render_info(
				Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
			)
			if phase != "warm_route"
			else null
		),
		"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"texture_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"before": before,
		"after": Mode.terrain(_background),
	}
	return statistics if _valid() and _background.terrain_ready else {}


func _geometry(spec: Dictionary, repaint: Rect2) -> Dictionary:
	var camera: Vector2 = _game.camera_offset
	var repainting := repaint.has_area()
	var clip := repaint if repainting else WorldProjection.view_rect(_game)
	var visible := []
	var submitted := []
	for anchor: Vector2 in Groups.Map.FLOWERS:
		var pair := [int(anchor.x), int(anchor.y)]
		if clip.intersects(Groups.Ambient.destination_rect(anchor)):
			visible.append(pair)
		if repainting and _variant == "baseline":
			submitted.append([pair])
	if repainting and _candidate != null:
		submitted = _candidate.capture_batches(true)
	var window := DisplayServer.window_get_size()
	var frame := Vector2i(root.get_texture().get_size())
	return {
		"phase": spec.phase,
		"window": [window.x, window.y],
		"framebuffer": [frame.x, frame.y],
		"camera": [roundi(camera.x), roundi(camera.y)],
		"zoom_percent": roundi(WorldProjection.zoom(_game) * 100.0),
		"repaint": Mode.region(_background.terrain_revision.last_completed) if repainting else null,
		"batches": submitted,
		"visible": visible,
	}


func _overlap(spec: Dictionary) -> bool:
	var player: Array = spec.player
	var day: int = spec.day
	_setup(player, day)
	if not await _settle():
		return false
	var record := _conditions()
	if spec.has("prop"):
		if not _record_prop(spec, record):
			return false
	elif spec.id == "winter":
		record["winter_batches"] = _winter_batches()
	var label: String = spec.id
	var frame := _capture_frame(label)
	if frame.is_empty():
		return false
	_evidence.overlap[label] = {"state": record, "frame": frame}
	_write()
	return true


func _winter_batches() -> Array:
	if _candidate != null:
		return _candidate.capture_batches(true)
	return (
		Groups.Map.FLOWERS
		if Groups.Ambient.is_visible_in_season("flowers", _background.season)
		else []
	)


func _record_prop(spec: Dictionary, record: Dictionary) -> bool:
	var position: Array = spec.position
	var target := Points.vector(position)
	for prop: Dictionary in Props.Layout.PROP_PLACEMENTS:
		if prop.kind != spec.prop or prop.position != target:
			continue
		var ground := target + Props.GROUND_OFFSET
		var body := Props.TreeOcclusion.hero_bounds(_game)
		var sprite := (
			Props.Bench.destination(ground)
			if prop.kind == "bench"
			else Props.Board.destination("board", ground)
		)
		record["prop_anchor"] = Points.pair(ground)
		record["prop_front"] = Props._in_front(target, Pose.ground(_game))
		record["sprite"] = Mode.region(sprite)
		record["hero_body"] = Mode.region(body)
		return body.intersects(sprite)
	return false


func _negative_order() -> bool:
	_setup(Points.pair(OCCLUSION_FLOWER + Vector2(0, 16)), 1)
	if not await _settle():
		return false
	var correct := _capture_frame("flower-order-correct")
	if correct.is_empty():
		return false
	var wrong := Node2D.new()
	wrong.z_index = 10
	wrong.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wrong.transform = WorldProjection.transform(_game)
	wrong.draw.connect(
		func() -> void:
			Groups.Ambient.draw_cell(wrong, "flowers", OCCLUSION_FLOWER, Mode.Candidate.FLOWER_TINT)
	)
	root.add_child(wrong)
	if not await _settle():
		return false
	var incorrect := _capture_frame("flower-order-wrong")
	if incorrect.is_empty():
		return false
	_evidence["negative_frames"] = {
		"flower-order-correct": correct,
		"flower-order-wrong": incorrect,
	}
	_evidence["negative_hero_body"] = Mode.region(Props.TreeOcclusion.hero_bounds(_game))
	_evidence["negative_camera"] = Points.pair(_game.camera_offset)
	return true


## Снимает окно и кеш в одном frame_post_draw и сохраняет SHA исходных PNG.
func _capture_frame(label: String, include_terrain: bool = false) -> Dictionary:
	var frame := {
		"view": label,
		"variant": _variant,
		"draw_id": Engine.get_frames_drawn(),
		"usec": Time.get_ticks_usec(),
		"camera": Points.pair(_game.camera_offset),
		"terrain_revision": _background.terrain_revision.revision,
	}
	var pngs := {"window": _png_sha256(root, label)}
	if include_terrain:
		pngs["terrain"] = _png_sha256(_background.terrain_viewport, label + "-terrain")
	if "" in pngs.values():
		return {}
	frame["sha256"] = pngs
	return frame


func _png_sha256(viewport: Viewport, name: String) -> String:
	var image := viewport.get_texture().get_image()
	var path := _output.path_join(name + ".png")
	if image == null or image.is_empty() or image.save_png(path) != OK:
		return ""
	return FileAccess.get_sha256(path)


func _write() -> void:
	var file := FileAccess.open(_output.path_join("fixed.json"), FileAccess.WRITE)
	if file != null:
		file.store_line(JSON.stringify(_evidence))


func _fail(reason: String) -> void:
	push_error("VPERF-006: " + reason)
	quit(2)
