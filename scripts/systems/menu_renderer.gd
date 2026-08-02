extends RefCounted

const TITLE_PANEL := Rect2(374, 246, 404, 278)
const PAUSE_PANEL := Rect2(358, 92, 436, 464)
const SETTINGS_PANEL := Rect2(250, 54, 652, 540)
const TITLE_ITEM_ORIGIN := Vector2(394, 276)
const PAUSE_ITEM_ORIGIN := Vector2(388, 144)
const SETTINGS_ITEM_ORIGIN := Vector2(280, 112)
const TITLE_ITEM_SIZE := Vector2(364, 48)
const PAUSE_ITEM_SIZE := Vector2(376, 50)
const SETTINGS_ITEM_SIZE := Vector2(592, 48)


## Возвращает прямоугольник строки главного меню для отрисовки и единой hit-зоны.
static func title_item_rect(index: int) -> Rect2:
	return Rect2(TITLE_ITEM_ORIGIN + Vector2(0, index * 58), TITLE_ITEM_SIZE)


## Возвращает прямоугольник строки меню паузы для отрисовки и единой hit-зоны.
static func pause_item_rect(index: int) -> Rect2:
	return Rect2(PAUSE_ITEM_ORIGIN + Vector2(0, index * 60), PAUSE_ITEM_SIZE)


## Возвращает прямоугольник строки настроек для отрисовки и единой hit-зоны.
static func settings_item_rect(index: int) -> Rect2:
	return Rect2(SETTINGS_ITEM_ORIGIN + Vector2(0, index * 55), SETTINGS_ITEM_SIZE)


## Находит строку главного меню в экранной точке либо возвращает отсутствие попадания.
static func title_item_at(point: Vector2) -> int:
	for index in 4:
		if title_item_rect(index).has_point(point): return index
	return -1


## Находит строку меню паузы в экранной точке либо возвращает отсутствие попадания.
static func pause_item_at(point: Vector2) -> int:
	for index in 6:
		if pause_item_rect(index).has_point(point): return index
	return -1


## Находит строку настроек в экранной точке либо возвращает отсутствие попадания.
static func settings_item_at(point: Vector2) -> int:
	for index in 8:
		if settings_item_rect(index).has_point(point): return index
	return -1


## Рисует интерактивный список главного меню поверх титульного пейзажа.
static func draw_title_menu(game: Node) -> void:
	draw_panel(game, TITLE_PANEL)
	for index in game.MenuSystem.TITLE_ITEMS.size():
		var enabled: bool = index != 0 or game.MenuSystem.has_save(game)
		draw_item(game, title_item_rect(index), game.LocaleSystem.ui(game.MenuSystem.TITLE_ITEMS[index]), index == game.menu_state.title_selected, enabled)
	draw_notice(game, Vector2(394, 516), 364)


## Затемняет мир и рисует меню паузы либо открытую поверх него страницу настроек.
static func draw_pause_layer(game: Node) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.025, 0.022, 0.76))
	if game.menu_state.settings_open:
		draw_settings(game)
		return
	draw_panel(game, PAUSE_PANEL)
	game.draw_string(game.UI_FONT, Vector2(388, 126), game.LocaleSystem.ui("paused"), HORIZONTAL_ALIGNMENT_CENTER, 376, 27, Color("fff0bd"))
	for index in game.MenuSystem.PAUSE_ITEMS.size():
		draw_item(game, pause_item_rect(index), game.LocaleSystem.ui(game.MenuSystem.PAUSE_ITEMS[index]), index == game.menu_state.pause_selected, true)
	draw_notice(game, Vector2(388, 532), 376)


## Рисует страницу параметров с текущими значениями звука, экрана и языка.
static func draw_settings(game: Node) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.025, 0.022, 0.82))
	draw_panel(game, SETTINGS_PANEL)
	game.draw_string(game.UI_FONT, Vector2(280, 94), game.LocaleSystem.ui("settings"), HORIZONTAL_ALIGNMENT_CENTER, 592, 28, Color("fff0bd"))
	var values := [
		"%d%%" % game.SettingsSystem.percent(game.settings_state.master_volume),
		"%d%%" % game.SettingsSystem.percent(game.settings_state.music_volume),
		"%d%%" % game.SettingsSystem.percent(game.settings_state.sfx_volume),
		game.LocaleSystem.ui("enabled" if game.audio_enabled else "disabled"),
		game.LocaleSystem.ui("enabled" if game.settings_state.fullscreen_enabled else "disabled"),
		game.LocaleSystem.ui("enabled" if game.settings_state.vsync_enabled else "disabled"),
		game.LocaleSystem.language_name(game.LocaleSystem.index()),
		"",
	]
	for index in game.MenuSystem.SETTING_ITEMS.size():
		var label: String = game.LocaleSystem.ui(game.MenuSystem.SETTING_ITEMS[index])
		if not values[index].is_empty(): label += "    ‹  %s  ›" % values[index]
		draw_item(game, settings_item_rect(index), label, index == game.menu_state.settings_selected, true)
	draw_notice(game, Vector2(280, 570), 592)


## Рисует деревянную рамку системного окна в общей палитре интерфейса игры.
static func draw_panel(game: Node, rect: Rect2) -> void:
	game.draw_rect(rect, Color(0.055, 0.09, 0.08, 0.98))
	game.draw_rect(rect.grow(-5), Color("78563b"))
	game.draw_rect(rect.grow(-10), Color("172b26"))


## Рисует строку меню с различимыми состояниями выбора и недоступности.
static func draw_item(game: Node, rect: Rect2, label: String, selected: bool, enabled: bool) -> void:
	var border := Color("efc766") if selected else Color("365548")
	var fill := Color("f0dda9") if selected else Color("203b35")
	game.draw_rect(rect, border)
	game.draw_rect(rect.grow(-3), fill)
	var color := Color("3d342a") if selected else (Color("f8f1dc") if enabled else Color("75857b"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(12, 31), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 24, 18, color)


## Показывает результат сохранения, загрузки или применения параметров внутри текущего меню.
static func draw_notice(game: Node, position: Vector2, width: float) -> void:
	if not game.menu_state.notice.is_empty():
		game.draw_string(game.UI_FONT, position, game.menu_state.notice, HORIZONTAL_ALIGNMENT_CENTER, width, 13, Color("a9dfb8"))
