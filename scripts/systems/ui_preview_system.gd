extends RefCounted


## Настраивает запрошенный системный экран и при необходимости включает автоматический снимок.
static func configure(game: Node) -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--capture-hud" in arguments:
		game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.tutorial_visible = false; game.message = ""
		game.player = Vector2(1160, 650); game.set_meta("capture_hud_clean", true); game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/hud_ingame_preview.png")
		return
	if "--capture-language" in arguments:
		game.language_screen = true; game.title_screen = false; game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/language_ingame_preview.png")
		return
	if "--capture-defeat" in arguments:
		game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.tutorial_visible = false
		game.set_meta("capture_hud_clean", true); game.MenuSystem.open_defeat(game, "Пират-призрак", 5); game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/defeat_ingame_preview.png")
		return
	if not ("--settings-preview" in arguments or "--capture-settings" in arguments): return
	game.language_screen = false
	game.title_screen = false
	game.MenuSystem.open_pause(game)
	game.MenuSystem.open_settings(game, false)
	if "--capture-settings" in arguments:
		game.set_meta("capture_ui_frames", 6)
		game.set_meta("capture_ui_output", "res://assets/generated/ui/system_settings_ingame_preview.png")


## Убирает сюжетные карточки только из чистого эталона HUD после инициализации живого мира.
static func finalize(game: Node) -> void:
	if not game.has_meta("capture_hud_clean"): return
	var life: Dictionary = game.FarmLifeSystem.state(game)
	life.first_day = 6; life.cutscene = ""; life.cutscene_timer = 0.0
	game.message = ""; game.DiscoverySystem.dismiss(game)


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
