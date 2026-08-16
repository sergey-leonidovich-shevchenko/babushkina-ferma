extends RefCounted

const TITLE_ITEMS := ["continue_game", "new_game", "settings", "exit_game"]
const PAUSE_ITEMS := ["resume", "save_game", "load_game", "settings", "return_main_menu", "exit_game"]
const SETTING_ITEMS := ["master_volume", "music_volume", "sfx_volume", "sound_enabled", "fullscreen", "vsync", "reduced_motion", "screen_shake", "high_contrast", "control_preset", "text_scale", "touch_scale", "language_option", "back"]

static var start_after_reload := false

class MenuState:
	var title_selected := 1
	var pause_open := false
	var pause_selected := 0
	var settings_open := false
	var settings_selected := 0
	var settings_from_title := true
	var notice := ""
	var quit_requested := false
	var confirmation := ""
	var confirm_selected := 1
	var defeat_open := false
	var defeat_source := ""
	var defeat_lost_coins := 0


## Подготавливает разумный первый выбор главного меню с учётом наличия сохранения.
static func prepare_title(game: Node, save_path: String = "") -> void:
	game.menu_state.title_selected = 0 if has_save(game, save_path) else 1
	game.menu_state.notice = ""
	game.menu_state.confirmation = ""


## Проверяет основной или переданный тестовый путь сохранения вместе с резервной копией.
static func has_save(game: Node, save_path: String = "") -> bool:
	var path: String = game.SaveSystem.SAVE_PATH if save_path.is_empty() else save_path
	return game.SaveSystem.has_save_at(path)


## Открывает паузу, закрывает движение и отмечает знакомство с системным меню в обучении.
static func open_pause(game: Node) -> bool:
	if game.title_screen or game.language_screen:
		return false
	game.menu_state.pause_open = true
	game.menu_state.settings_open = false
	game.menu_state.pause_selected = 0
	game.menu_state.notice = ""
	game.clear_movement_keys()
	game.notify_tutorial("pause_menu")
	game.queue_redraw()
	return true


## Возвращает игрока в мир без изменения сохранения или текущего прогресса.
static func resume(game: Node) -> void:
	game.menu_state.pause_open = false
	game.menu_state.settings_open = false
	game.menu_state.notice = ""
	game.queue_redraw()


## Открывает настройки поверх главного меню или паузы и запоминает точку возврата.
static func open_settings(game: Node, from_title: bool) -> void:
	game.menu_state.settings_open = true
	game.menu_state.settings_from_title = from_title
	game.menu_state.settings_selected = 0
	game.menu_state.notice = ""
	game.notify_tutorial("settings")
	game.queue_redraw()


## Закрывает настройки и возвращает фокус тому меню, из которого они были открыты.
static func close_settings(game: Node, path: String = "") -> void:
	var settings_path: String = game.SettingsSystem.SETTINGS_PATH if path.is_empty() else path
	game.SettingsSystem.save(game, settings_path)
	game.menu_state.settings_open = false
	game.menu_state.notice = game.LocaleSystem.text("settings_saved")
	game.queue_redraw()


## Перемещает выбор по списку, пропуская недоступное продолжение без файла сохранения.
static func move_selection(game: Node, delta: int, save_path: String = "") -> void:
	var field := "title_selected" if game.title_screen and not game.menu_state.pause_open else "pause_selected"
	var count := TITLE_ITEMS.size() if field == "title_selected" else PAUSE_ITEMS.size()
	var selected: int = game.menu_state.get(field)
	for ignored in count:
		selected = posmod(selected + delta, count)
		if field != "title_selected" or selected != 0 or has_save(game, save_path):
			break
	game.menu_state.set(field, selected)
	game.UiFeedbackSystem.focus(game, "%s:%d" % [field, selected])


## Выполняет выбранную команду главного меню и возвращает признак успешной операции.
static func activate_title(game: Node, save_path: String = "") -> bool:
	var path: String = game.SaveSystem.SAVE_PATH if save_path.is_empty() else save_path
	game.UiFeedbackSystem.press(game, game.MenuRenderer.title_item_rect(game.menu_state.title_selected))
	match TITLE_ITEMS[game.menu_state.title_selected]:
		"continue_game":
			if not game.SaveSystem.load_at(game, path):
				game.menu_state.notice = game.LocaleSystem.text("load_failed")
				return false
			game.title_screen = false
			game.menu_state.notice = game.LocaleSystem.text("loaded")
		"new_game": start_new_game(game)
		"settings": open_settings(game, true)
		"exit_game": request_confirmation(game, "exit_game")
	game.AudioSystem.update_context_music(game)
	game.queue_redraw()
	return true


## Выполняет выбранную команду паузы, используя атомарные сохранение и загрузку.
static func activate_pause(game: Node, save_path: String = "") -> bool:
	var path: String = game.SaveSystem.SAVE_PATH if save_path.is_empty() else save_path
	game.UiFeedbackSystem.press(game, game.MenuRenderer.pause_item_rect(game.menu_state.pause_selected))
	match PAUSE_ITEMS[game.menu_state.pause_selected]:
		"resume": resume(game)
		"save_game":
			var saved: bool = game.SaveSystem.save_at(game, path)
			game.menu_state.notice = game.LocaleSystem.text("saved" if saved else "save_failed")
			if saved: game.notify_tutorial("save")
			return saved
		"load_game":
			var loaded: bool = game.SaveSystem.load_at(game, path)
			game.menu_state.notice = game.LocaleSystem.text("loaded" if loaded else "load_failed")
			if loaded: resume(game)
			return loaded
		"settings": open_settings(game, false)
		"return_main_menu": request_confirmation(game, "return_main_menu")
		"exit_game": request_confirmation(game, "exit_game")
	game.queue_redraw()
	return true


## Запускает чистую сцену в приложении или снимает стартовый экран в изолированном тесте.
static func start_new_game(game: Node) -> void:
	game.menu_state.notice = ""
	if game.is_inside_tree():
		start_after_reload = true
		game.get_tree().reload_current_scene()
	else:
		game.title_screen = false
		game.AdventurePolishSystem.begin_new_game(game)


## Сообщает новой сцене, что перезагрузка была запрошена пунктом «Новая игра».
static func consume_new_game_request() -> bool:
	var requested := start_after_reload
	start_after_reload = false
	return requested


## Закрывает игровые окна и показывает главное меню без неявного сохранения прогресса.
static func return_to_title(game: Node) -> void:
	for field in ["shop_open", "inventory_open", "crafting_open", "storage_open", "forge_open", "contract_open", "quest_log_open", "skill_menu_open"]:
		game.set(field, false)
	game.menu_state.pause_open = false
	game.menu_state.settings_open = false
	game.title_screen = true
	prepare_title(game)
	game.AudioSystem.update_context_music(game)
	game.clear_movement_keys()


## Запрашивает штатное завершение приложения, сохраняя безопасный тестовый след без выхода из runner.
static func request_exit(game: Node) -> void:
	game.menu_state.quit_requested = true
	if game.is_inside_tree():
		game.get_tree().quit()


## Открывает безопасное подтверждение потенциально разрушительной системной команды.
static func request_confirmation(game: Node, action: String) -> void:
	game.menu_state.confirmation = action
	game.menu_state.confirm_selected = 1
	game.queue_redraw()


## Отменяет подтверждение без изменения текущего экрана или состояния мира.
static func cancel_confirmation(game: Node) -> void:
	game.menu_state.confirmation = ""
	game.menu_state.confirm_selected = 1
	game.queue_redraw()


## Выполняет подтверждённую команду ровно один раз и очищает модальное состояние.
static func confirm_action(game: Node) -> void:
	var action: String = game.menu_state.confirmation
	cancel_confirmation(game)
	if action == "return_main_menu": return_to_title(game)
	elif action == "exit_game": request_exit(game)


## Открывает модальный экран спасения после поражения и фиксирует фактическую потерю монет.
static func open_defeat(game: Node, source: String, lost_coins: int) -> void:
	game.menu_state.defeat_open = true
	game.menu_state.defeat_source = source
	game.menu_state.defeat_lost_coins = lost_coins
	game.clear_movement_keys()
	game.queue_redraw()


## Закрывает экран поражения после того, как игрок явно подтвердил продолжение.
static func acknowledge_defeat(game: Node) -> void:
	game.menu_state.defeat_open = false
	game.menu_state.defeat_source = ""
	game.menu_state.defeat_lost_coins = 0
	game.queue_redraw()


## Возвращает короткое описание единственного устойчивого слота сохранения для меню паузы.
static func save_summary(game: Node, save_path: String = "") -> String:
	var path: String = game.SaveSystem.SAVE_PATH if save_path.is_empty() else save_path
	if not game.SaveSystem.has_save_at(path): return game.LocaleSystem.ui("save_empty")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return game.LocaleSystem.ui("save_empty")
	var minutes := int(data.get("minutes", 360))
	var location: String = game.WorldSystem.name(String(data.get("location", "overworld")))
	return game.LocaleSystem.ui("save_summary", [int(data.get("day", 1)), minutes / 60, minutes % 60, location])


## Перемещает фокус по двум колонкам параметров, сохраняя логичный вертикальный цикл.
static func move_settings_selection(game: Node, delta: int) -> void:
	var index: int = game.menu_state.settings_selected
	var row := index / 2
	var column := index % 2
	var row_count := ceili(float(SETTING_ITEMS.size()) / 2.0)
	row += delta
	if row < 0: row = row_count - 1; column = posmod(column - 1, 2)
	elif row >= row_count: row = 0; column = (column + 1) % 2
	game.menu_state.settings_selected = mini(row * 2 + column, SETTING_ITEMS.size() - 1)
	game.UiFeedbackSystem.focus(game, "settings:%d" % game.menu_state.settings_selected)


## Изменяет выбранный параметр на один шаг, сразу применяет и сохраняет результат.
static func adjust_setting(game: Node, direction: int, path: String = "", apply_display: bool = true) -> void:
	var settings_path: String = game.SettingsSystem.SETTINGS_PATH if path.is_empty() else path
	game.UiFeedbackSystem.press(game, game.MenuRenderer.settings_item_rect(game.menu_state.settings_selected))
	match SETTING_ITEMS[game.menu_state.settings_selected]:
		"master_volume": game.settings_state.master_volume = clampf(game.settings_state.master_volume + direction * game.SettingsSystem.VOLUME_STEP, 0.0, 1.0)
		"music_volume": game.settings_state.music_volume = clampf(game.settings_state.music_volume + direction * game.SettingsSystem.VOLUME_STEP, 0.0, 1.0)
		"sfx_volume": game.settings_state.sfx_volume = clampf(game.settings_state.sfx_volume + direction * game.SettingsSystem.VOLUME_STEP, 0.0, 1.0)
		"sound_enabled": game.audio_enabled = not game.audio_enabled
		"fullscreen": game.settings_state.fullscreen_enabled = not game.settings_state.fullscreen_enabled
		"vsync": game.settings_state.vsync_enabled = not game.settings_state.vsync_enabled
		"reduced_motion": game.settings_state.reduced_motion = not game.settings_state.reduced_motion
		"screen_shake": game.settings_state.screen_shake_enabled = not game.settings_state.screen_shake_enabled
		"high_contrast": game.settings_state.high_contrast = not game.settings_state.high_contrast
		"control_preset": game.settings_state.control_preset = "left_handed" if game.settings_state.control_preset=="standard" else "standard"; game.InputSystem.apply_control_preset(game.settings_state.control_preset)
		"text_scale": game.settings_state.text_scale = game.UiScaleSystem.cycle_scale(game.settings_state.text_scale, direction, game.UiScaleSystem.TEXT_SCALES)
		"touch_scale": game.settings_state.touch_scale = game.UiScaleSystem.cycle_scale(game.settings_state.touch_scale, direction, game.UiScaleSystem.TOUCH_SCALES)
		"language_option":
			var next := posmod(game.LocaleSystem.index() + direction, game.LocaleSystem.LOCALES.size())
			game.LocaleSystem.set_locale(game.LocaleSystem.LOCALES[next], false)
		"back":
			close_settings(game, settings_path)
			return
	game.AudioSystem.apply_volumes(game)
	if apply_display: game.SettingsSystem.apply_display_settings(game)
	game.SettingsSystem.save(game, settings_path)
	game.menu_state.notice = game.LocaleSystem.text("settings_saved")


## Маршрутизирует клавиатуру, геймпад, мышь и касание в активный системный экран.
static func handle_input(game: Node, event: InputEvent, settings_path: String = "", apply_display: bool = true) -> bool:
	var command := -1
	if event is InputEventKey and event.pressed and not event.echo:
		command = int(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		command = {JOY_BUTTON_DPAD_UP:KEY_UP, JOY_BUTTON_DPAD_DOWN:KEY_DOWN, JOY_BUTTON_DPAD_LEFT:KEY_LEFT, JOY_BUTTON_DPAD_RIGHT:KEY_RIGHT, JOY_BUTTON_A:KEY_ENTER, JOY_BUTTON_B:KEY_ESCAPE, JOY_BUTTON_START:KEY_ESCAPE}.get(event.button_index, -1)
	elif (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point: Vector2 = event.position
		if game.menu_state.defeat_open:
			if game.MenuRenderer.DEFEAT_CONTINUE.has_point(point): acknowledge_defeat(game); return true
			return false
		if not game.menu_state.confirmation.is_empty():
			if game.MenuRenderer.CONFIRM_ACCEPT.has_point(point): game.menu_state.confirm_selected = 0; confirm_action(game); return true
			if game.MenuRenderer.CONFIRM_CANCEL.has_point(point): cancel_confirmation(game); return true
			return false
		if game.menu_state.settings_open:
			var setting_index: int = game.MenuRenderer.settings_item_at(point)
			if setting_index >= 0:
				game.menu_state.settings_selected = setting_index
				adjust_setting(game, 1, settings_path, apply_display)
				return true
		else:
			var item_index: int = game.MenuRenderer.title_item_at(point) if game.title_screen else game.MenuRenderer.pause_item_at(point)
			if item_index >= 0:
				if game.title_screen:
					game.menu_state.title_selected = item_index
					activate_title(game)
				else:
					game.menu_state.pause_selected = item_index
					activate_pause(game)
				return true
		return false
	if command < 0:
		return false
	if game.menu_state.defeat_open:
		if command in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]: acknowledge_defeat(game)
		return true
	if not game.menu_state.confirmation.is_empty():
		match command:
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN: game.menu_state.confirm_selected = 1 - game.menu_state.confirm_selected
			KEY_ENTER, KEY_SPACE:
				if game.menu_state.confirm_selected == 0: confirm_action(game)
				else: cancel_confirmation(game)
			KEY_ESCAPE: cancel_confirmation(game)
		game.queue_redraw()
		return true
	if game.menu_state.settings_open:
		match command:
			KEY_UP: move_settings_selection(game, -1)
			KEY_DOWN: move_settings_selection(game, 1)
			KEY_LEFT: adjust_setting(game, -1, settings_path, apply_display)
			KEY_RIGHT, KEY_ENTER, KEY_SPACE: adjust_setting(game, 1, settings_path, apply_display)
			KEY_ESCAPE: close_settings(game, settings_path)
	else:
		match command:
			KEY_UP: move_selection(game, -1)
			KEY_DOWN: move_selection(game, 1)
			KEY_ENTER, KEY_SPACE:
				if game.title_screen: activate_title(game)
				else: activate_pause(game)
			KEY_ESCAPE:
				if not game.title_screen: resume(game)
	game.queue_redraw()
	return true
