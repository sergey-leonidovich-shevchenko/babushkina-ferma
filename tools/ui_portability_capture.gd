extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Observer := preload("res://tools/ui_portability_observer.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const BASELINE := "res://tests/fixtures/ui_portability/baseline.json"
var output := ""
var game: Node
var rows: Array[Dictionary] = []
var errors: Array[String] = []
var production_text: Dictionary


## Требует новое место вывода и отдельный профиль, сохраняя пользовательские слоты и настройки.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
	if output.is_empty() or DirAccess.dir_exists_absolute(output):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting(
		"application/config/custom_user_dir_name", "Codex-CI-UI-" + str(Time.get_ticks_usec())
	)
	_start.call_deferred()


## Снимает реальный HUD и полный UI-аудит на исходном текстовом payload и текущем коде без движения мира.
func _start() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	create_timer(90).timeout.connect(_timeout)
	DirAccess.make_dir_recursive_absolute(output)
	game = Points.create_game()
	game.set_script(Observer)
	root.add_child(game)
	current_scene = game
	Points.configure(game, Points.registry().points[0])
	game.settings_state.text_scale = 1.2
	game.tutorial_visible = true
	Reference.enable(game, true)
	root.title = "VFOLIAGE-006 | UI portability"
	root.mode = Window.MODE_WINDOWED
	root.size = Points.SIZE
	root.show()
	root.grab_focus()
	production_text = game.LocaleSystem.TUTORIAL.duplicate(true)
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	var baseline_text := production_text.duplicate(true)
	for key in baseline.tutorial:
		baseline_text[key] = baseline.tutorial[key].duplicate(true)
	game.LocaleSystem.TUTORIAL = baseline_text
	var before_audit: Dictionary = game.UiLayoutAuditSystem.project_report(game)
	for pair in [["ru", "player_contact"], ["ru", "fertilizer"], ["de", "player_contact"]]:
		await capture_case("baseline_text", pair[0], pair[1])
	game.LocaleSystem.TUTORIAL = production_text
	var after_audit: Dictionary = game.UiLayoutAuditSystem.project_report(game)
	for locale in game.LocaleSystem.LOCALES:
		for event in ["player_contact", "fertilizer"]:
			await capture_case("production", locale, event)
	var paths: Array[Dictionary] = []
	for family in game.UI_FONT.font_names:
		var path := OS.get_system_font_path(family, 500)
		paths.append(
			{
				"requested": family,
				"path": path,
				"file_sha256":
				digest(FileAccess.get_file_as_bytes(path)) if not path.is_empty() else ""
			}
		)
	var report := {
		"schema": 1,
		"purpose": "real_hud_text_portability_not_hardware_or_fps_acceptance",
		"engine": Engine.get_version_info(),
		"os": OS.get_name(),
		"display": DisplayServer.get_name(),
		"window": [root.size.x, root.size.y],
		"text_scale": 1.2,
		"profile": OS.get_user_data_dir().get_file(),
		"requested_font_paths": paths,
		"baseline_text_sha256": digest(FileAccess.get_file_as_bytes(BASELINE)),
		"before_audit": before_audit,
		"after_audit": after_audit,
		"cases": rows,
		"errors": errors,
	}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print(
		"UI PORTABILITY: ",
		JSON.stringify(
			{
				"before_issues": before_audit.issues,
				"after_issues": after_audit.issues,
				"rows": rows.size(),
				"fonts": paths,
				"errors": errors
			}
		)
	)
	game.free()
	quit(0 if errors.is_empty() and int(after_audit.failed) == 0 else 1)


## Сохраняет целый framebuffer и четыре настоящих вызова подсказки, сопоставляя общую геометрию и состояние.
func capture_case(phase: String, locale: String, event: String) -> void:
	game.LocaleSystem.set_locale(locale, false)
	for index in game.tutorial_steps.size():
		if game.tutorial_steps[index].event == event:
			game.tutorial_step = index
	game.watched_text = game.LocaleSystem.tutorial(event)
	for frame in 4:
		game.queue_redraw()
		await RenderingServer.frame_post_draw
	game.tutorial_draws.clear()
	var before: Dictionary = game.SaveSystem.snapshot(game)
	for frame in 4:
		game.queue_redraw()
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var name := phase + "-" + locale + "-" + event + ".png"
	image.save_png(output.path_join(name))
	var record := {
		"phase": phase,
		"locale": locale,
		"event": event,
		"text": game.watched_text,
		"frame": name,
		"file_sha256": digest(FileAccess.get_file_as_bytes(output.path_join(name))),
		"rgba_sha256": digest(image.get_data()),
		"image_size": [image.get_width(), image.get_height()],
		"before": before,
		"after": game.SaveSystem.snapshot(game),
		"draws": game.tutorial_draws.duplicate(true),
	}
	rows.append(record)
	if (
		record.before != record.after
		or record.image_size != [1152, 648]
		or game.tutorial_draws.size() != 4
	):
		errors.append(name + ": state/frame/callback mismatch")
	for draw in game.tutorial_draws:
		if draw.width != 268 or draw.height != 38 or draw.max_lines != 3:
			errors.append(name + ": actual HUD/audit geometry differs")
		if (
			phase == "production"
			and (draw.effective_size < 8 or draw.measured[1] > 38.1 or draw.line_count > 3)
		):
			errors.append(name + ": actual text is unreadable or clipped")
	print(
		"UI FRAME: ",
		name,
		" ",
		JSON.stringify(game.tutorial_draws[0] if not game.tutorial_draws.is_empty() else {})
	)


## Хеширует исходный файл или декодированный буфер без их смешения с PNG-сериализацией.
func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


## Завершает зависший графический стенд ошибкой вместо бесконечного ожидания framebuffer.
func _timeout() -> void:
	push_error("UI PORTABILITY: render timeout")
	quit(2)
