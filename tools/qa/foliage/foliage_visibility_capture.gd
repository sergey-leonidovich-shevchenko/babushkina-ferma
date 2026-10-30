extends SceneTree

const Review := preload("res://tests/helpers/foliage_visibility_scenario.gd")
const Observer := preload("res://tools/qa/foliage/foliage_visibility_game.gd")
const Budget := preload("res://tools/qa/foliage/foliage_visibility_budget.gd")
var output := ""
var profile := ""
var width := 1152
var game: Node
var records := []
var errors := []
var startup := []
var routes := []
var coverage := []
var serial := 0
var presents := 0


## Требует новый output/профиль и настоящий дисплей; никакие headless pixels не становятся GPU-приёмкой.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile = arg.trim_prefix("--profile=")
		elif arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output) or not profile.begins_with("Codex-VFOLIAGE-010-") or width not in [1152, 1280] or DisplayServer.get_name() == "headless":
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	if DirAccess.dir_exists_absolute(OS.get_user_data_dir()):
		quit(2)
		return
	_run.call_deferred()


## Снимает шесть неизменных маршрутов и крайние bounds; любой отказ прекращает серию с сохранением сырья.
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.frame_post_draw.connect(func(): presents += 1)
	Engine.max_fps = 60
	root.title = "VFOLIAGE-010 | visibility and rendering budget"
	if not await _prepare_window():
		errors.append("native window/focus did not settle")
		_write(false)
		quit(1)
		return
	for route in _routes():
		_create_game()
		routes.append(Review.pack(route))
		Review.place(game, route)
		for frame in 36:
			for tick in 2:
				if route.get("camera_only", false):
					Review.Scenario.step(game, Review.DT)
					game.camera_offset = route.camera_start + route.direction * Review.TRAVEL * (frame * 2 + tick + 1) / Review.FRAMES
					Review.Wind.WorldProjection.sync_background(game)
					Review.Wind.update(game)
				else: Review.advance(game, route.direction)
			await _capture(route.id, "full", frame)
			if frame in [0, 17, 35]:
				await _capture(route.id, "culled", frame)
				await _capture(route.id, "unculled", frame)
			if not errors.is_empty(): break
		if not route.get("camera_only", false) and game.player.distance_to(route.start + route.direction * Review.TRAVEL) > 0.01:
			errors.append(route.id + ": actual movement blocked")
		game.free()
		game = null
		_write(false)
		if not errors.is_empty():
			quit(1)
			return
	_create_game()
	for mode in ["normal", "low", "offscreen", "returned"]:
		game.set_meta(Review.Wind.QUALITY, "low" if mode == "low" else "normal")
		game.camera_offset = Vector2(-4000, -4000) if mode == "offscreen" else Review.Wind.placements()[6].anchor - Vector2(480, 270)
		Review.Wind.update(game)
		await _capture("cost", mode, 0)
	game.free()
	game = null
	coverage = await Budget.capture(self, output)
	_write(errors.is_empty())
	print("FOLIAGE VISIBILITY NATIVE: ", records.size(), " frames, ", coverage.size(), " coverage, errors=", errors)
	quit(0 if errors.is_empty() else 1)


## Дожидается устойчивой оконной геометрии и фокуса; каждый probe остаётся в протоколе.
func _prepare_window() -> bool:
	var started := Time.get_ticks_msec()
	var stable := -1
	while Time.get_ticks_msec() - started < 7000:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(width, width * 9 / 16)
		root.show()
		DisplayServer.window_move_to_foreground()
		root.grab_focus()
		await process_frame
		var image := root.get_texture().get_image()
		var ms := Time.get_ticks_msec() - started
		var valid := root.has_focus() and root.mode == Window.MODE_WINDOWED and root.size == Vector2i(width, width * 9 / 16) and image.get_size() == root.size
		startup.append({"ms": ms, "focused": root.has_focus(), "window": Review.pack(root.size), "image": Review.pack(image.get_size()), "windowed": root.mode == Window.MODE_WINDOWED})
		if not valid or ms < 1500: stable = -1
		elif stable < 0: stable = ms
		elif ms - stable >= 500: return true
	return false


## Создаёт обычный overworld; нативный наблюдатель добавляет только маркер и режим изолированного QA-слоя.
func _create_game() -> void:
	game = Review.Scenario.Points.create_game()
	game.set_script(Observer)
	root.add_child(game)
	Review.Scenario.Points.configure(game, Review.Scenario.Points.registry().points[0])
	game.settings_state.reduced_motion = false
	game.set_meta(&"camera_reference_zoom", 1.2)
	game.player = Review.Wind.placements()[6].anchor + Vector2(-12, 0)
	game.update_camera()
	Review.Scenario.Pose.reset(game)
	for index in 12: Review.Scenario.step(game, Review.DT)


## Определяет одни и те же маршруты до съёмки; пустая выборка становится явным отказом.
func _routes() -> Array:
	_create_game()
	var result := Review.routes(game)
	game.free()
	game = null
	if result.size() != 6: errors.append("six predeclared routes unavailable")
	return result


## Ждёт два настоящих present и уникальный16-битный маркер; physics между culling-парой не выполняется.
func _capture(route: String, mode: String, frame: int) -> void:
	serial += 1
	game.review_serial = serial
	game.review_isolated = mode in ["culled", "unculled"]
	game.review_unculled = mode == "unculled"
	game.review_draws.clear()
	var before := Review.Scenario.observe(game)
	var saved: Dictionary = game.SaveSystem.snapshot(game)
	var start := presents
	var first_draw := Engine.get_frames_drawn()
	game.queue_redraw()
	var deadline := Time.get_ticks_msec() + 5000
	while presents < start + 2 and Time.get_ticks_msec() < deadline: await process_frame
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var marker := 0
	for bit in 16:
		var pixel := image.get_pixel(int((bit * 72 + 36) * width / 1152.0), 2)
		if pixel == Color.WHITE: marker |= 1 << bit
		elif pixel != Color.MAGENTA: errors.append("invalid marker color: " + str(serial))
	if marker != serial or presents < start + 2 or Engine.get_frames_drawn() < first_draw + 2: errors.append("stale native frame: " + str(serial))
	if not root.has_focus() or root.mode != Window.MODE_WINDOWED or image.get_size() != Vector2i(width, width * 9 / 16) or root.size != image.get_size(): errors.append("native window/focus mismatch: " + str(serial))
	if before != Review.Scenario.observe(game) or saved != game.SaveSystem.snapshot(game): errors.append("draw mutated state: " + str(serial))
	var folder := output.path_join(route + "/" + mode)
	DirAccess.make_dir_recursive_absolute(folder)
	var relative := route + "/" + mode + "/%03d.png" % frame
	if image.save_png(output.path_join(relative)) != OK: errors.append("cannot save " + relative)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	records.append({"route": route, "mode": mode, "index": frame, "serial": serial, "image": relative, "rgba_sha256": hash.finish().hex_encode(), "focused": root.has_focus(), "windowed": root.mode == Window.MODE_WINDOWED, "size": Review.pack(image.get_size()), "presents": presents - start, "drawn_frames": Engine.get_frames_drawn() - first_draw, "draws": game.review_draws.duplicate(true), "state": Review.pack(before), "save_sha256": JSON.stringify(saved, "", true, true).sha256_text(), "budget": Budget.observe(game)})


## Сохраняет также неполный запуск; complete никогда не выставляется при ошибках.
func _write(complete: bool) -> void:
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify({"task": "VFOLIAGE-010", "complete": complete, "profile": profile, "width": width, "display": DisplayServer.get_name(), "engine": Engine.get_version_info(), "startup": startup, "routes": routes, "records": records, "coverage": coverage, "errors": errors}, "  ") + "\n")
