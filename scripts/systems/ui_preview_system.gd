extends RefCounted


## Настраивает запрошенный системный экран и при необходимости включает автоматический снимок.
static func configure(game: Node) -> void:
	var arguments := OS.get_cmdline_user_args()
	if not ("--settings-preview" in arguments or "--capture-settings" in arguments): return
	game.language_screen = false
	game.title_screen = false
	game.MenuSystem.open_pause(game)
	game.MenuSystem.open_settings(game, false)
	if "--capture-settings" in arguments:
		game.set_meta("capture_ui_frames", 6)
		game.set_meta("capture_ui_output", "res://assets/generated/ui/system_settings_ingame_preview.png")


## Сохраняет системный UI-экран после стабилизации нескольких кадров и завершает режим предпросмотра.
static func update_capture(game: Node) -> bool:
	if not game.has_meta("capture_ui_frames"): return false
	var frames_left := int(game.get_meta("capture_ui_frames")) - 1
	game.set_meta("capture_ui_frames", frames_left)
	if frames_left > 0: return false
	game.remove_meta("capture_ui_frames")
	var output := ProjectSettings.globalize_path(String(game.get_meta("capture_ui_output")))
	game.remove_meta("capture_ui_output")
	var error := game.get_viewport().get_texture().get_image().save_png(output)
	if error != OK: push_error("Не удалось сохранить предпросмотр интерфейса: %s" % error)
	game.get_tree().quit()
	return true
