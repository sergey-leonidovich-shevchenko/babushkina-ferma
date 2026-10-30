extends SceneTree

const Scenario := preload("res://tests/helpers/foliage_pause_scenario.gd")
const Wind := Scenario.Wind
const Observer := preload("res://tools/qa/foliage/foliage_pause_game.gd")
const STAGES := ["before", "entered", "held", "resumed1", "resumed12"]
const COLORS := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN]
var output := ""
var profile := ""
var width := 1152
var game: Node
var records: Array = []
var errors: Array = []
var group_draws: Array = []
var presents := 0
var snapshots := {}
var startup_geometry: Array = []


## Требует отдельный свежий нативный профиль и output; headless никогда не подменяет GPU-съёмку.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="): profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--width="): width = int(argument.trim_prefix("--width="))
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output) or not profile.begins_with("Codex-VFOLIAGE-009-") or width not in [1152, 1280] or DisplayServer.get_name() == "headless":
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	if DirAccess.dir_exists_absolute(OS.get_user_data_dir()):
		quit(2)
		return
	_run.call_deferred()


## Снимает заранее заданные окна и пять фаз каждого режима, сохраняя каждый отказ без успешной подмены.
func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	RenderingServer.frame_post_draw.connect(_presented)
	Engine.max_fps = 60
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(width, width * 9 / 16)
	root.title = "VFOLIAGE-009 | pause clocks and actual native pixels"
	root.show()
	root.grab_focus()
	for index in 8: await process_frame
	if not await _prepare_window():
		errors.append("startup: native window/framebuffer did not settle")
		_write(false)
		quit(1)
		return
	for mode in Scenario.MODES:
		await _mode(mode)
		_write(false)
		if not errors.is_empty():
			quit(1)
			return
	_write(true)
	print("FOLIAGE PAUSE NATIVE: ", records.size(), " captures; ", errors)
	quit(0)


## Дожидается завершения оконного перехода macOS до матрицы; сохраняет каждый замер геометрии.
func _prepare_window() -> bool:
	var started := Time.get_ticks_msec()
	var stable_since := -1
	var requested := Vector2i(width, width * 9 / 16)
	while Time.get_ticks_msec() - started < 7000:
		if root.mode != Window.MODE_WINDOWED: root.mode = Window.MODE_WINDOWED
		if root.mode == Window.MODE_WINDOWED and root.size != requested: root.size = requested
		await process_frame
		var probe := root.get_texture().get_image()
		var actual := Vector2i(probe.get_width(), probe.get_height())
		var elapsed := Time.get_ticks_msec() - started
		var ready := root.mode == Window.MODE_WINDOWED and root.size == requested and actual == requested
		startup_geometry.append({"elapsed_ms": elapsed, "windowed": root.mode == Window.MODE_WINDOWED, "window": [root.size.x, root.size.y], "image": [actual.x, actual.y]})
		if not ready or elapsed < 1500:
			stable_since = -1
		elif stable_since < 0:
			stable_since = elapsed
		elif elapsed - stable_since >= 500:
			return true
	return false


## Подготавливает прежнюю сцену до первого draw; ручные физические шаги не являются FPS-тестом.
func _create_game() -> void:
	game = Scenario.Points.create_game()
	game.set_script(Observer)
	root.add_child(game)
	Scenario.Points.configure(game, Scenario.Points.registry().points[0])
	game.settings_state.reduced_motion = false
	game.set_meta(&"camera_reference_zoom", 1.2)
	game.player = Wind.placements()[6].anchor + Vector2(-12, 0)
	game.update_camera()
	Scenario.Pose.reset(game)
	for index in 12: Scenario.step(game, 1.0 / 60.0)
	for group in game.get_node(Wind.NAME).batch.groups:
		group.draw.connect(_group_draw.bind(group))


## Проверяет остановку на36 физических шагах и ровно один разрешённый шаг при первом возврате.
func _mode(mode: String) -> void:
	DisplayServer.window_move_to_foreground()
	root.grab_focus()
	var focus_deadline := Time.get_ticks_msec() + 3000
	while not root.has_focus() and Time.get_ticks_msec() < focus_deadline:
		await process_frame
	if not root.has_focus():
		errors.append(mode + ": actual native focus unavailable")
		return
	_create_game()
	await _capture(mode, "before")
	if not Scenario.enter(game, mode): errors.append(mode + ": existing UI/API failed")
	Scenario.step(game, 1.0 / 60.0)
	var frozen := Scenario.observe(game)
	var saved := JSON.stringify(game.SaveSystem.snapshot(game), "", true, true)
	await _capture(mode, "entered")
	var samples: Array = []
	for index in 36:
		Scenario.step(game, 1.0 / 60.0)
		var same := Scenario.observe(game) == frozen
		var same_save := JSON.stringify(game.SaveSystem.snapshot(game), "", true, true) == saved
		samples.append({"tick": index + 1, "delta": 1.0 / 60.0, "seconds": Wind.Clock.seconds(game), "visual_equal": same, "save_equal": same_save, "state_sha": _snapshot(Scenario.observe(game)), "save_sha": _snapshot(game.SaveSystem.snapshot(game))})
		if not same or not same_save: errors.append(mode + ": paused state changed at tick" + str(index + 1))
	await _capture(mode, "held")
	records.back()["paused_samples"] = samples
	Scenario.leave(game)
	if mode in ["cabinet", "storage"]:
		# Это существующее окно дома; возврат задан QA явно, штатный маршрут остаётся VRELEASE-003.
		game.current_location = "overworld"
		game.player = Wind.placements()[6].anchor + Vector2(-12, 0)
		game.sync_background_location()
		game.update_camera()
		Scenario.Pose.reset(game)
	Scenario.step(game, 1.0 / 60.0)
	if not is_equal_approx(Wind.Clock.seconds(game), float(frozen.seconds) + 1.0 / 60.0): errors.append(mode + ": resume accumulated pause debt")
	await _capture(mode, "resumed1")
	for index in 11: Scenario.step(game, 1.0 / 60.0)
	await _capture(mode, "resumed12")
	game.free()
	game = null


## Ждёт настоящий present с дедлайном; маркер и draw-state доказывают свежесть окна отдельно от target-паузы.
func _capture(mode: String, stage: String) -> void:
	var tag := mode + "/" + stage
	var color: Color = COLORS[STAGES.find(stage)]
	game.pause_review_tag = tag
	game.pause_review_color = color
	game.pause_review_draws.clear()
	group_draws.clear()
	var state := Scenario.observe(game)
	var saved: Dictionary = game.SaveSystem.snapshot(game)
	var before := Engine.get_frames_drawn()
	var first_present := presents
	game.queue_redraw()
	var deadline := Time.get_ticks_msec() + 5000
	while presents < first_present + 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	var image := root.get_texture().get_image()
	var native_fresh := false
	if not image.is_empty():
		for y in mini(64, image.get_height()):
			if image.get_pixel(mini(16, image.get_width() - 1), y).is_equal_approx(color): native_fresh = true
	var complete := presents >= first_present + 2 and Engine.get_frames_drawn() >= before + 2
	if not complete or not native_fresh: errors.append(tag + ": actual native present or phase pixels missing")
	if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(width, width * 9 / 16) or image.get_size() != root.size:
		errors.append(tag + ": actual native window/framebuffer dimensions differ")
	if Scenario.observe(game) != state or game.SaveSystem.snapshot(game) != saved: errors.append(tag + ": rendering changed game or visual state")
	var folder := output.path_join(mode).path_join(stage)
	DirAccess.make_dir_recursive_absolute(folder)
	if image.is_empty() or image.save_png(folder.path_join("window.png")) != OK: errors.append(tag + ": window image unavailable")
	var owner: Node = game.get_node(Wind.NAME)
	var target: Image = owner.batch.viewport.get_texture().get_image()
	if target.is_empty() or target.save_png(folder.path_join("target.png")) != OK: errors.append(tag + ": real foliage target unavailable")
	var row := {
		"mode": mode, "stage": stage, "tag": tag, "state_sha": _snapshot(state), "save_sha": _snapshot(saved),
		"save_after_sha": _snapshot(game.SaveSystem.snapshot(game)), "state_after_sha": _snapshot(Scenario.observe(game)),
		"marker_rgba8": [color.r8, color.g8, color.b8, color.a8], "marker_fresh": native_fresh,
		"frames_before": before, "frames_after": Engine.get_frames_drawn(), "present_complete": complete,
		"window_size": [root.size.x, root.size.y], "image_size": [image.get_width(), image.get_height()],
		"target_size": [target.get_width(), target.get_height()], "focused": root.has_focus(), "visible": root.visible,
		"windowed": root.mode == Window.MODE_WINDOWED,
		"game_draws": game.pause_review_draws.duplicate(true), "group_draws": group_draws.duplicate(true),
		"window": mode + "/" + stage + "/window.png", "target": mode + "/" + stage + "/target.png"
	}
	records.append(row)
	print("PAUSE_CAPTURE ", tag, " ", native_fresh, " ", complete)


## Сохраняет фактические shader-uniforms и индексы группы в момент production draw-сигнала.
func _group_draw(group: MultiMeshInstance2D) -> void:
	var indices: Array = []
	for index in group.multimesh.instance_count: indices.append(group.multimesh.get_instance_custom_data(index).g)
	group_draws.append({"name": group.name, "frame": Engine.get_process_frames(), "seconds": group.material.get_shader_parameter("seconds"), "indices": indices})


## Считает реальные завершения обновления viewport, не принимая CPU callback за готовое изображение.
func _presented() -> void:
	presents += 1


## Пишет полную частичную трассу после каждого режима, чтобы сбой не превращался в пропавшее измерение.
func _write(complete: bool) -> void:
	var result := {
		"task": "VFOLIAGE-009", "complete": complete, "profile": profile,
		"display": DisplayServer.get_name(), "engine": Engine.get_version_info(),
		"requested_width": width, "records": records, "snapshots": snapshots, "errors": errors,
		"startup_geometry": startup_geometry,
		"hardware_input_accepted": false, "performance_eligible": false,
		"protocol": "controlled actual callbacks and native GPU, fixed steps, no FPS or physical input admission"
	}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "  ", true, true) + "\n")


## Хранит каждый полный канонический снимок один раз; все ссылки проверяются по исходным UTF-8 байтам.
func _snapshot(value: Variant) -> String:
	var raw := JSON.stringify(value, "", true, true)
	var digest := raw.sha256_text()
	snapshots[digest] = raw
	return digest
