extends "res://tests/suites/suite_base.gd"

const Pause := preload("res://scripts/presentation/moon_pause_renderer.gd")
const SettingsPath := "user://horizontal-pause-test-settings.cfg"

## Проверяет утверждённую горизонтальную композицию, пространственный ввод и полную остановку симуляции.
func run() -> void:
	test_pause_geometry_and_localized_labels()
	test_spatial_navigation_and_pointer_confirmation()
	test_system_pause_freezes_before_world_events()

## Сценарий: горизонтальная пауза показана на базовом холсте со всеми шестью языками и увеличенным текстом.
## Исходное состояние: кнопки используют общую геометрию рисунка и касаний, а подписи вписываются настоящими шрифтами.
## Ожидаемый результат: панель центрирована, кнопки не пересекаются и подписи остаются читаемыми при масштабе 120%.
func test_pause_geometry_and_localized_labels() -> void:
	var game := make_game()
	expect(Pause.PANEL.get_center() == Vector2(576, 324) and Pause.PANEL.size.x > Pause.PANEL.size.y, "horizontal pause centers on the native viewport")
	expect(Pause.PANEL.get_area() < 436 * 464 * 0.85, "horizontal pause leaves more visible world than the old frame")
	for index in 6:
		var rect: Rect2 = game.MenuRenderer.pause_item_rect(index)
		expect(Pause.PANEL.encloses(rect) and rect.size.x >= 48 and rect.size.y >= 48, "every pause action has a visible accessible touch target")
		expect(game.MenuRenderer.pause_item_at(rect.get_center()) == index, "pause pointer targets match the drawn buttons")
		for other in range(index + 1, 6): expect(not rect.intersects(game.MenuRenderer.pause_item_rect(other)), "pause actions never share a pointer region")
	expect(Pause.ITEMS[1].position.y == Pause.ITEMS[2].position.y and Pause.ITEMS[4].position.y == Pause.ITEMS[5].position.y, "save load and exit actions occupy two paired rows")
	expect(game.MenuRenderer.pause_item_at(Pause.TITLE.get_center()) == -1, "pause context is not an invisible action target")
	game.settings_state.text_scale = 1.2
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale, false)
		var checks: Array[Dictionary] = preload("res://scripts/presentation/moon_ui_audit.gd").check(game)
		var pause_checks := checks.filter(func(check): return String(check.code).contains(".pause_"))
		expect(pause_checks.size() == 9 and pause_checks.all(func(check): return bool(check.passed)), "horizontal pause labels fit real fonts in " + locale)
	game.LocaleSystem.set_locale("ru", false)
	game.free()

## Сценарий: игрок выбирает команды в двух колонках клавиатурой, геймпадом, мышью и касанием.
## Исходное состояние: пауза открывается на продолжении, опасные действия ещё не подтверждены.
## Ожидаемый результат: направления соответствуют рисунку и запоминают колонку, а отмена подтверждения сохраняет игру открытой.
func test_spatial_navigation_and_pointer_confirmation() -> void:
	var game := make_game()
	game.MenuSystem.open_pause(game)
	var steps := [[KEY_DOWN, 1], [KEY_RIGHT, 2], [KEY_DOWN, 3], [KEY_DOWN, 5], [KEY_LEFT, 4], [KEY_UP, 3], [KEY_UP, 1], [KEY_UP, 0], [KEY_UP, 4]]
	for step in steps:
		game.MenuSystem.handle_input(game, key_event(step[0], step[0], true), SettingsPath, false)
		expect(game.menu_state.pause_selected == step[1], "pause direction follows its visible row and column")
	game.MenuSystem.handle_input(game, joypad_button_event(JOY_BUTTON_DPAD_RIGHT, true), SettingsPath, false)
	expect(game.menu_state.pause_selected == 5, "controller Right reaches the paired exit action")
	game.MenuSystem.handle_input(game, joypad_button_event(JOY_BUTTON_DPAD_DOWN, true), SettingsPath, false)
	game.MenuSystem.handle_input(game, joypad_button_event(JOY_BUTTON_DPAD_DOWN, true), SettingsPath, false)
	expect(game.menu_state.pause_selected == 2, "vertical wrap retains the last selected column")
	var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = Pause.ITEMS[3].get_center()
	game.MenuSystem.handle_input(game, touch, SettingsPath, false)
	expect(game.menu_state.settings_open and not game.menu_state.settings_from_title, "touch opens settings from its visible pause action")
	game.MenuSystem.handle_input(game, key_event(KEY_ESCAPE, KEY_ESCAPE, true), SettingsPath, false)
	expect(game.menu_state.pause_open and not game.menu_state.settings_open, "return from settings preserves pause")
	var click := InputEventMouseButton.new(); click.pressed = true; click.button_index = MOUSE_BUTTON_LEFT; click.position = Pause.ITEMS[4].get_center()
	game.MenuSystem.handle_input(game, click, SettingsPath, false)
	expect(game.menu_state.confirmation == "return_main_menu" and game.menu_state.confirm_selected == 1, "mouse main-menu action initially selects safe cancellation")
	touch.position = game.MenuRenderer.CONFIRM_CANCEL.get_center(); game.MenuSystem.handle_input(game, touch, SettingsPath, false)
	expect(game.menu_state.confirmation.is_empty() and game.menu_state.pause_open and not game.title_screen, "touching cancellation returns to pause")
	touch.position = Pause.ITEMS[5].get_center(); game.MenuSystem.handle_input(game, touch, SettingsPath, false)
	expect(game.menu_state.confirmation == "exit_game" and not game.menu_state.quit_requested, "touching exit only opens confirmation")
	game.MenuSystem.handle_input(game, joypad_button_event(JOY_BUTTON_B, true), SettingsPath, false)
	game.MenuSystem.handle_input(game, joypad_button_event(JOY_BUTTON_B, true), SettingsPath, false)
	expect(not game.menu_state.pause_open and not game.menu_state.quit_requested, "controller Back cancels the prompt then resumes the world")
	game.free(); DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsPath))

## Сценарий: герой ставит игру на паузу рядом с врагом во время боевого эффекта и роста растения.
## Исходное состояние: сюжетные и боевые таймеры, мир и противник готовы обновляться очередным физическим кадром.
## Ожидаемый результат: пауза, настройки и подтверждение останавливают весь мир до событий, а эффекты интерфейса продолжают работать.
func test_system_pause_freezes_before_world_events() -> void:
	var game := make_game()
	game.FarmLifeSystem.state(game).cutscene = ""; game.FarmLifeSystem.state(game).first_day = 6
	game.tutorial_visible = false; game.game_minutes = 500; game.regeneration_timer = 7
	game.plots[Vector2i(0, 0)].planted = true; game.plots[Vector2i(0, 0)].watered = true; game.plots[Vector2i(0, 0)].tilled = true
	game.enemy_nodes[0].position = game.player + Vector2(12, 0); game.enemy_nodes[0].location = game.current_location; game.enemy_nodes[0].alive = true; game.enemy_nodes[0].attack_timer = 0.0
	game.AdventurePolishSystem.begin_action(game, "hit", game.player)
	game.MenuSystem.open_pause(game); game.ui_last_layer = "pause"; game.ui_transition_timer = 0.2
	for screen in ["pause", "settings", "confirmation"]:
		game.menu_state.settings_open = screen == "settings"
		game.menu_state.confirmation = "exit_game" if screen == "confirmation" else ""
		game.UiFeedbackSystem.update(game, 0.0)
		var saved: Dictionary = game.SaveSystem.snapshot(game)
		var feedback: Dictionary = game.state.player.feedback.duplicate(true)
		feedback.erase("combat_music")
		var enemies: Array = game.enemy_nodes.duplicate(true)
		for frame in 60: game.GameLoop.physics_process(game, 1.0 / 60.0)
		expect(game.SaveSystem.snapshot(game) == saved and game.enemy_nodes == enemies, "system screen freezes HP crops events cooldowns and enemies: " + screen)
		var after_feedback: Dictionary = game.state.player.feedback.duplicate(true); after_feedback.erase("combat_music")
		expect(after_feedback == feedback, "system screen freezes adventure action and camera timers: " + screen)
	expect(game.ui_transition_timer == 0.0, "interface transitions remain independent of paused world time")
	game.menu_state.confirmation = ""; game.menu_state.settings_open = false; game.MenuSystem.resume(game)
	game.GameLoop.physics_process(game, 0.1)
	expect(game.game_minutes > 500 and game.state.player.feedback.timer < 0.34, "resume restarts the world and action timers")
	game.free()
