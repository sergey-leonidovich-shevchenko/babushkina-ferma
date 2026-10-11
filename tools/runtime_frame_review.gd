extends SceneTree

const GAME_SCENE := preload("res://main.tscn")
const Village := preload("res://scripts/systems/village_map_data.gd")
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 1200
const TOWN_SAMPLE_FRAMES := 1400
const SHORT_PROFILE_FRAMES := 420
const WORLD_SEED := 20260908
const MOVEMENT_KEYS := [KEY_A, KEY_D, KEY_W, KEY_S]

var game: Node
var frames := 0
var frame_ms: Array[float] = []
var frame_ms_by_location: Dictionary = {}
var slow_frames: Array[Dictionary] = []
var started := false
var previous_frame_usec := 0
var route: Array[Vector2] = []
var route_index := 0
var route_origin := Village.START
var route_ticks := 0
var route_finished := false
var held: Dictionary = {}
var route_observations: Array[Dictionary] = []
var save_fingerprints: Dictionary = {}
var profile_town := false
var profile_short := false
var simulation_started := false
var town_loops := 0
var monitor_frames: Array[Dictionary] = []


## Создаёт настоящую сцену для измерения кадров с графическим renderer после завершения инициализации дерева.
func _initialize() -> void:
	_start.call_deferred()


## Запускает воспроизводимый маршрут настоящими клавишами без открытия пользовательского сохранения.
func _start() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Для замера графики требуется настоящий renderer, а не --headless")
		quit(2)
		return
	profile_town = "--profile-town" in OS.get_cmdline_user_args()
	profile_short = profile_town and "--profile-shortcap" in OS.get_cmdline_user_args()
	for path in ["user://farm-save.json", "user://farm-save-2.json", "user://farm-save-3.json"]:
		save_fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	seed(WORLD_SEED)
	game = GAME_SCENE.instantiate()
	game.world_loot_seed = WORLD_SEED
	root.add_child(game)
	# Прогрев отрисовки не даёт медленному F10 лишние секунды прогулок NPC перед тем же маршрутом.
	game.set_physics_process(false)
	current_scene = game
	game.current_location = "overworld"
	game.player = Village.START
	game.language_screen = false; game.title_screen = false; game.tutorial_visible = false
	# Старый autoplay содержит старые координаты и телепорт; этот замер проходит новый чертёж настоящими клавишами.
	game.benchmark_autoplay = false; game.benchmark_elapsed = 0.0
	game.clear_movement_keys()
	game.InputSystem.apply_control_preset("standard")
	game.settings_state.screen_shake_enabled = false
	game.settings_state.text_scale = 1.0; game.settings_state.touch_scale = 1.0
	game.settings_state.reduced_motion = false; game.settings_state.high_contrast = false
	game.settings_state.master_volume = 1.0; game.settings_state.music_volume = 0.7; game.settings_state.sfx_volume = 0.9
	game.AudioSystem.set_enabled(game, true)
	game.LocaleSystem.set_locale("ru", false)
	game.set_meta("debug_inspector_cursor", Vector2(220, 220))
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	game.update_camera(); game.sync_background_location()
	if "--benchmark-debug-overlay" in OS.get_cmdline_user_args():
		if not game.DebugOverlaySystem.active(game): game.DebugOverlaySystem.toggle(game)
	else:
		if game.DebugOverlaySystem.active(game): game.DebugOverlaySystem.toggle(game)
	for index in [2, 3, 4, 5, 6, 7, 6, 5, 4]: route.append(Village.PATHS[0][index])
	if profile_town:
		for index in [3, 2]: route.append(Village.PATHS[0][index])
		route.append(Village.START)
	else:
		route.append(Village.PATHS[6][1]); route.append(Village.CAVE_ENTRANCE)
	physics_frame.connect(_drive_route)
	started = true


## Ведёт героя по одинаковым точкам нового чертежа; физический маршрут не зависит от частоты отрисовки.
func _drive_route() -> void:
	if not started or frames <= WARMUP_FRAMES or (route_finished and not profile_town): return
	if not simulation_started:
		simulation_started = true
		seed(WORLD_SEED)
		game.set_physics_process(true)
	route_ticks += 1
	game.benchmark_elapsed = float(route_ticks) / Engine.physics_ticks_per_second
	if game.current_location == "cave":
		route_finished = true
		_release_keys()
		route_observations.append({"checkpoint":"cave_entered", "seconds":game.benchmark_elapsed, "position":_point(game.player)})
		return
	if route_index >= route.size():
		if profile_town:
			town_loops += 1
			route_finished = true
			route_index = 0
			route_origin = game.player
			route_observations.append({"checkpoint":"town_loop_complete", "loop":town_loops, "seconds":game.benchmark_elapsed})
		else:
			_release_keys()
			return
	var target := route[route_index]
	var difference: Vector2 = target - game.player
	if difference.length() < 5.0:
		route_observations.append({"checkpoint":route_index, "seconds":game.benchmark_elapsed, "position":_point(game.player), "target":_point(target)})
		route_index += 1
		route_origin = game.player
		if route_index >= route.size():
			_release_keys()
			return
		target = route[route_index]
	# Упреждение вдоль начерченного отрезка не позволяет восьминаправленным клавишам срезать берег под 45°.
	var direction := route_origin.direction_to(target)
	var along: float = clampf((game.player - route_origin).dot(direction) + 18.0, 0.0, route_origin.distance_to(target))
	var steering: Vector2 = route_origin + direction * along - game.player
	_key(KEY_A, steering.x < -1.5)
	_key(KEY_D, steering.x > 1.5)
	_key(KEY_W, steering.y < -1.5)
	_key(KEY_S, steering.y > 1.5)


## Передаёт смену физической клавиши игровому обработчику без изменения позиции или обхода коллизий.
func _key(code: Key, pressed: bool) -> void:
	if bool(held.get(code, false)) == pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = pressed
	game._input(event)


## Отпускает клавиши в конце маршрута, сохраняя реальное состояние камеры и сцены для оставшихся кадров.
func _release_keys() -> void:
	for code in MOVEMENT_KEYS: _key(code, false)
	game.clear_movement_keys()


## Сохраняет координаты в виде компактного числового массива без зависимых от локали строк.
func _point(position: Vector2) -> Array:
	return [snappedf(position.x, 0.01), snappedf(position.y, 0.01)]


## Записывает длительность каждого реального кадра после прогрева и завершает ограниченный замер.
func _process(_delta: float) -> bool:
	if not started: return false
	var now := Time.get_ticks_usec()
	var elapsed_ms := (now - previous_frame_usec) / 1000.0
	previous_frame_usec = now
	frames += 1
	if frames <= WARMUP_FRAMES:
		# Диагностическая сетка прогревается, но игровой мир и его часы остаются на одном исходном кадре.
		if game.DebugOverlaySystem.active(game): game.DebugOverlaySystem.update(game, 1.0 / 60.0)
		game.queue_redraw()
		game.set_meta("runtime_profile_sections_us", {})
		return false
	frame_ms.append(elapsed_ms)
	if not frame_ms_by_location.has(game.current_location): frame_ms_by_location[game.current_location] = []
	frame_ms_by_location[game.current_location].append(elapsed_ms)
	if profile_town: _record_monitors(elapsed_ms)
	if elapsed_ms > 33.333:
		var overlay: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY, {})
		var build: Dictionary = overlay.get("grid_build", {})
		slow_frames.append({"frame": frames, "duration_ms": elapsed_ms, "location": game.current_location, "route_seconds": game.benchmark_elapsed, "route_checkpoint":route_index, "position":_point(game.player), "grid_pending": not build.is_empty(), "grid_cursor": int(build.get("cursor", 0)), "physics_frames": Engine.get_physics_frames()})
	var sample_limit := SHORT_PROFILE_FRAMES if profile_short else (TOWN_SAMPLE_FRAMES if profile_town else SAMPLE_FRAMES)
	if frame_ms.size() >= sample_limit:
		_finish()
		return true
	return false


## Сохраняет штатные Godot monitors и накопленные секционные таймеры root на каждом измеряемом кадре.
func _record_monitors(elapsed_ms: float) -> void:
	var overlay: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY, {})
	var grid: Texture2D = overlay.get("grid_texture")
	var lines: Texture2D = overlay.get("grid_lines_texture")
	var entry := {
		"frame":frames, "elapsed_ms":elapsed_ms, "physics_frame":Engine.get_physics_frames(),
		"route_seconds":game.benchmark_elapsed, "checkpoint":route_index, "position":_point(game.player),
		"location":game.current_location,
		"process_ms":Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"objects_drawn":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"grid_pending":not Dictionary(overlay.get("grid_build", {})).is_empty(),
		"dynamic_pending":not Dictionary(overlay.get("dynamic_build", {})).is_empty(),
		"cache_generation":int(overlay.get("cache_generation", 0)),
		"grid_signature":String(overlay.get("grid_texture_signature", "")),
		"grid_rid":str(grid.get_rid()) if grid != null else "null",
		"lines_rid":str(lines.get_rid()) if lines != null else "null",
		"sections_us":Dictionary(game.get_meta("runtime_profile_sections_us", {})).duplicate(true),
	}
	monitor_frames.append(entry)
	# Root может суммировать несколько физических тиков между render-кадрами в одном словаре без потери пиков.
	game.set_meta("runtime_profile_sections_us", {})


## Вычисляет среднее, перцентили и выбросы по всем кадрам, отдельно от средней частоты FPS.
func _statistics(samples: Array) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var sum := 0.0
	var slow := 0
	for value in sorted:
		sum += value
		if value > 33.333: slow += 1
	return {"mean_ms": sum / sorted.size(), "p50_ms": sorted[floori((sorted.size() - 1) * 0.50)], "p95_ms": sorted[floori((sorted.size() - 1) * 0.95)], "p99_ms": sorted[floori((sorted.size() - 1) * 0.99)], "max_ms": sorted.back(), "frames_over_33ms": slow}


## Сохраняет условия и полную статистику настоящего окна в отдельный JSON обычного режима или F10.
func _finish() -> void:
	started = false
	var debug_overlay := "--benchmark-debug-overlay" in OS.get_cmdline_user_args()
	var mode := "f10" if debug_overlay else "normal"
	var window_size := DisplayServer.window_get_size()
	var result := {"schema": 5, "mode": mode, "map_revision":Village.REVISION, "route": "Village.START → PATHS[0] nodes 2…7 (bridge + square) → nodes 6,5,4 → PATHS[6][1] → automatic cave entrance; physical keyboard input, no teleport", "seed":WORLD_SEED, "cursor":[220,220], "clock": "Time.get_ticks_usec between rendered SceneTree frames; not smoothed delta", "engine": Engine.get_version_info().string, "display_server": DisplayServer.get_name(), "gpu": RenderingServer.get_video_adapter_name(), "window_size": [window_size.x, window_size.y], "vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps, "physics_hz":Engine.physics_ticks_per_second, "warmup_frames": WARMUP_FRAMES, "sample_frames": frame_ms.size(), "render_frame": _statistics(frame_ms)}
	result.warmup_world_frozen = true
	result.town_loops = town_loops
	result.diagnostic_partial_route = profile_short
	# Только итоговый снимок: счётчики подтверждают работу нового кеша текста без дополнительной работы на каждом кадре.
	result.ui_text_metrics_cache = game.UiScaleSystem.TextMetrics.statistics()
	if profile_town:
		result.route = "Village.START → PATHS[0] nodes 2…7 → reverse nodes 6…2 → Village.START, repeating town loop; no cave and no teleport"
		result.monitors = monitor_frames
		result.monitor_note = "Godot monitor values are engine CPU counters, not per-script GPU timings; sections_us are optional accumulated instrumentation, reset after each render sample. Monitor collection itself adds small overhead."
	var route_valid: bool = route_finished and (not profile_town or (town_loops > 0 and game.current_location == "overworld" and frame_ms_by_location.size() == 1 and frame_ms_by_location.has("overworld")))
	result.route_finished = route_valid
	result.route_checkpoints = route_observations
	result.route_final_position = _point(game.player)
	result.route_final_location = game.current_location
	result.render_frame_by_location = {}
	for location in frame_ms_by_location:
		result.render_frame_by_location[location] = {"samples":frame_ms_by_location[location].size(), "statistics":_statistics(frame_ms_by_location[location])}
	result.profile = {"locale":"ru", "text_scale":1.0, "touch_scale":1.0, "screen_shake":false, "high_contrast":false, "reduced_motion":false, "audio_enabled":true}
	var unchanged := true
	for path in save_fingerprints:
		var current := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
		unchanged = unchanged and current == save_fingerprints[path]
	result.user_saves_unchanged = unchanged
	var filename := "native_profile_town_%s.json" if profile_town else "native_frames_%s.json"
	if profile_short: filename = "native_profile_town_%s_short.json"
	var output := FileAccess.open("res://docs/reports/" + filename % mode, FileAccess.WRITE)
	result.slow_frames = slow_frames
	if output == null:
		push_error("Не удалось сохранить нативный покадровый замер")
		quit(2)
		return
	output.store_string(JSON.stringify(result, "  ") + "\n")
	output.close()
	print("NATIVE FRAME REVIEW: %s" % JSON.stringify({"report":filename % mode,"mode":mode,"samples":frame_ms.size(),"route_finished":route_valid,"user_saves_unchanged":unchanged,"render_frame":result.render_frame}))
	# Короткая секционная диагностика не подменяет полную проверку маршрута: её файл явно помечен partial.
	var run_valid: bool = route_valid or (profile_short and game.current_location == "overworld" and frame_ms_by_location.size() == 1)
	quit(0 if run_valid and unchanged else 1)
