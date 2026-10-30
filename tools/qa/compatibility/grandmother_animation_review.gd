extends SceneTree

const Scene := preload("res://main.tscn")
const Visual := preload("res://scripts/systems/grandmother_visual_system.gd")
const Legacy := preload("res://assets/game/characters/directional/npc_grandmother_walk_8dir.png")
const DIRECTIONS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
const LABELS := ["DOWN", "LEFT", "RIGHT", "UP"]
const OUTPUT := "res://assets/generated/level_drafts/grandmother_review"
const FRAME_FPS := 8.0
var game: Node2D
var failures := 0


class PoseCanvas extends Node2D:


	## Показывает новые четыре ракурса и старые проблемные левые ряды без ручной обработки PNG.
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1200, 840), Color("233630"))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(24, 31), "GRANDMOTHER / ACTUAL RUNTIME POSES / FIXED FEET", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("f0dba5"))
		draw_string(font, Vector2(24, 54), "Native size. Orange line = logical position + (0,24). No per-frame resizing.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c8b998"))
		for row in 4:
			draw_string(font, Vector2(24, 129 + row * 127), LABELS[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e7d9bb"))
			for column in 4:
				var feet := Vector2(280 + column * 246, 177 + row * 127)
				_backdrop(feet, "FRAME %d" % column, false)
				var pose: Dictionary = Visual.pose(DIRECTIONS[row], (column + 0.05) / FRAME_FPS, true)
				Visual.draw_pose(self, feet - Vector2(0, 24), pose)
				_baseline(feet)
		for row in 2:
			draw_string(font, Vector2(24, 646 + row * 127), ["LEFT", "UP-LEFT"][row], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e7d9bb"))
			for column in 4:
				var feet := Vector2(238 + column * 246, 690 + row * 127)
				_backdrop(feet, "OLD %d" % column, true)
				_backdrop(feet + Vector2(100, 0), "NEW %d" % column, true)
				var source := Rect2(column * 222, (2 + row) * 222, 222, 222)
				draw_texture_rect_region(Legacy, Rect2(feet - Vector2(48, 96), Vector2(96, 96)), source)
				var direction := Vector2.LEFT if row == 0 else Vector2(-1, -1)
				Visual.draw_pose(self, feet + Vector2(100, -24), Visual.pose(direction, (column + 0.05) / FRAME_FPS, true))
				_baseline(feet)
				_baseline(feet + Vector2(100, 0))


	## Подложка позволяет заметить остатки зелёного matte и нарисованной шахматной прозрачности.
	func _backdrop(feet: Vector2, label: String, compact: bool) -> void:
		var width := 96.0 if compact else 170.0
		var rect := Rect2(feet - Vector2(width * 0.5, 104), Vector2(width, 112))
		draw_rect(rect, Color("405449"))
		draw_rect(Rect2(rect.position, Vector2(width * 0.5, rect.size.y)), Color("d7c1a0"))
		draw_string(ThemeDB.fallback_font, feet + Vector2(-35, 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d8c9a6"))


	## Рисует общую опору поверх рисунка, чтобы смещение ног было видно на каждом кадре.
	func _baseline(feet: Vector2) -> void:
		draw_line(feet - Vector2(43, 0), feet + Vector2(43, 0), Color("eab268"), 1)
		draw_line(feet - Vector2(0, 5), feet + Vector2(0, 5), Color("eab268"), 1)


## Ожидает готовности настоящего окна и не вызывает пользовательскую загрузку или сохранение.
func _initialize() -> void:
	_run.call_deferred()


## Снимает шестнадцать игровых кадров и одну витрину тем же production-рендерером бабушки.
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Проверке бабушки нужен native renderer, не --headless")
		quit(2)
		return
	var saves_before := _save_fingerprints()
	game = Scene.instantiate(); root.add_child(game); current_scene = game
	game.set_process(false); game.set_physics_process(false)
	# Выход macOS из fullscreen асинхронный, поэтому размер задаётся после оконного перехода.
	game.settings_state.fullscreen_enabled = false
	root.mode = Window.MODE_WINDOWED
	await create_timer(0.4).timeout
	root.size = Vector2i(1152, 648); root.content_scale_size = Vector2i(1152, 648)
	game.language_screen = false; game.title_screen = false; game.tutorial_visible = false
	game.current_location = "overworld"; game.settings_state.screen_shake_enabled = false
	game.day = 1; game.game_minutes = 600; game.state.world.weather_day = 1; game.state.world.weather = "clear"
	game.set_meta("capture_first_level_clean", true)
	game.state.world.estate.event = ""; game.FarmLifeSystem.state(game).cutscene = ""
	var grandmother: Dictionary = game.npc_movement.grandmother
	game.player = Vector2(grandmother.position) + Vector2(115, 45)
	game.camera_offset = Vector2(grandmother.position) - Vector2(500, 340)
	game.get_node("WorldBackground").position = -game.camera_offset
	game.sync_background_location(); game.sync_background_environment()
	Visual.warmup()
	for row in 4:
		for frame in 4:
			grandmother.direction = DIRECTIONS[row]; grandmother.moving = true
			game.walk_animation_time = (frame + 0.05) / FRAME_FPS
			game.queue_redraw(); game.get_node("WorldBackground").queue_redraw()
			await _capture("ingame_%s_%d" % [LABELS[row].to_lower(), frame])
	game.hide()
	root.size = Vector2i(1200, 840); root.content_scale_size = Vector2i(1200, 840)
	var canvas := PoseCanvas.new(); root.add_child(canvas)
	await _capture("contact_sheet")
	var saves_unchanged := saves_before == _save_fingerprints()
	print("GRANDMOTHER REVIEW: saves unchanged=", saves_unchanged, ", capture failures=", failures)
	quit(0 if saves_unchanged and failures == 0 else 1)


## Сохраняет только реально нарисованный viewport; файлы арта не изменяются.
func _capture(label: String) -> void:
	var expected := Vector2i(1200,840) if label == "contact_sheet" else Vector2i(1152,648)
	var image: Image
	# macOS может прислать ещё одно событие размера уже после первых кадров выхода из fullscreen.
	for attempt in 6:
		root.size = expected; root.content_scale_size = expected
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		image = root.get_texture().get_image()
		if image.get_size() == expected: break
		await create_timer(0.2).timeout
	var path := "%s_%s.png" % [OUTPUT, label]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK or image.get_size() != expected: failures += 1
	print("GRANDMOTHER CAPTURE ", label, ": ", error, " size=", image.get_size())


## Проверяет все три пользовательских слота до и после изолированного native-прогона.
func _save_fingerprints() -> Dictionary:
	var result := {}
	for path in ["user://farm-save.json", "user://farm-save-2.json", "user://farm-save-3.json"]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result
