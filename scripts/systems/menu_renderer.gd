extends RefCounted

const TITLE_PANEL := Rect2(746, 244, 360, 360)
const PAUSE_PANEL := Rect2(358, 92, 436, 464)
const SETTINGS_PANEL := Rect2(250, 54, 652, 540)
const TITLE_WORDMARK_RECT := Rect2(38, 34, 694, 72)
const TITLE_ITEM_ORIGIN := Vector2(814, 329)
const PAUSE_ITEM_ORIGIN := Vector2(388, 144)
const SETTINGS_ITEM_ORIGIN := Vector2(280, 112)
const TITLE_ITEM_SIZE := Vector2(254, 43)
const PAUSE_ITEM_SIZE := Vector2(376, 50)
const SETTINGS_ITEM_SIZE := Vector2(592, 48)


## Возвращает прямоугольник строки главного меню для отрисовки и единой hit-зоны.
static func title_item_rect(index: int) -> Rect2:
	return Rect2(TITLE_ITEM_ORIGIN + Vector2(0, index * 52), TITLE_ITEM_SIZE)


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


## Рисует книжное название с плотной тенью, тонким разделителем и спокойной строкой жанров.
static func draw_title_wordmark(game: Node) -> void:
	draw_outlined_string(game, TITLE_WORDMARK_RECT.position + Vector2(0, 57), game.LocaleSystem.ui("title"), TITLE_WORDMARK_RECT.size.x, 54, Color("fff1bd"), Color("3a1d12"), 3)
	draw_outlined_string(game, Vector2(70, 127), game.LocaleSystem.ui("title_subtitle"), 630, 24, Color("ffd277"), Color("321b14"), 2)
	game.draw_line(Vector2(172, 143), Vector2(598, 143), Color(0.94, 0.70, 0.30, 0.78), 2.0)
	game.draw_circle(Vector2(385, 143), 4.0, Color("ffe28b"))
	draw_outlined_string(game, Vector2(116, 172), game.LocaleSystem.ui("title_features"), 538, 16, Color("fff1cf"), Color(0.10, 0.06, 0.04, 0.92), 1)


## Рисует интерактивный список прямо в четырёх плашках деревянной доски фонового арта.
static func draw_title_menu(game: Node) -> void:
	draw_outlined_string(game, Vector2(850, 286), game.LocaleSystem.ui("main_menu"), 152, 16, Color("ffd881"), Color("32180e"))
	for index in game.MenuSystem.TITLE_ITEMS.size():
		var enabled: bool = index != 0 or game.MenuSystem.has_save(game)
		draw_title_item(game, title_item_rect(index), game.LocaleSystem.ui(game.MenuSystem.TITLE_ITEMS[index]), index == game.menu_state.title_selected, enabled)
	draw_notice(game, Vector2(794, 568), 294)


## Затемняет мир и рисует меню паузы либо открытую поверх него страницу настроек.
static func draw_pause_layer(game: Node) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.025, 0.022, 0.76))
	if game.menu_state.settings_open:
		draw_settings(game)
		return
	draw_panel(game, PAUSE_PANEL)
	game.draw_string(game.MENU_FONT, Vector2(388, 126), game.LocaleSystem.ui("paused"), HORIZONTAL_ALIGNMENT_CENTER, 376, 27, Color("fff0bd"))
	for index in game.MenuSystem.PAUSE_ITEMS.size():
		draw_item(game, pause_item_rect(index), game.LocaleSystem.ui(game.MenuSystem.PAUSE_ITEMS[index]), index == game.menu_state.pause_selected, true)
	draw_notice(game, Vector2(388, 532), 376)


## Рисует страницу параметров с текущими значениями звука, экрана и языка.
static func draw_settings(game: Node) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.025, 0.022, 0.82))
	draw_panel(game, SETTINGS_PANEL)
	game.draw_string(game.MENU_FONT, Vector2(280, 94), game.LocaleSystem.ui("settings"), HORIZONTAL_ALIGNMENT_CENTER, 592, 28, Color("fff0bd"))
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
	game.draw_rect(Rect2(rect.position + Vector2(5, 7), rect.size), Color(0.05, 0.025, 0.015, 0.58))
	game.draw_rect(rect, Color("32190f"))
	game.draw_rect(rect.grow(-4), Color("9a632d"))
	game.draw_rect(rect.grow(-8), Color("e1ad50"))
	game.draw_rect(rect.grow(-12), Color("4f2c18"))
	game.draw_rect(rect.grow(-18), Color("2b3528"))
	for corner in [rect.position + Vector2(9, 9), rect.position + Vector2(rect.size.x - 9, 9), rect.position + Vector2(9, rect.size.y - 9), rect.end - Vector2(9, 9)]:
		game.draw_circle(corner, 4.0, Color("ffd36b"))


## Рисует строку меню с различимыми состояниями выбора и недоступности.
static func draw_item(game: Node, rect: Rect2, label: String, selected: bool, enabled: bool) -> void:
	game.draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0.04, 0.02, 0.01, 0.52))
	game.draw_rect(rect, Color("efc766") if selected else Color("8e5a2a"))
	game.draw_rect(rect.grow(-3), Color("f2dca4") if selected else Color("5b351e"))
	game.draw_rect(rect.grow(-6), Color("fff0c0") if selected else Color("714526"), false, 1.0)
	var color := Color("3d2416") if selected else (Color("fff0cf") if enabled else Color("9b8a70"))
	game.draw_string(game.MENU_FONT, rect.position + Vector2(12, 32), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 24, 20, color)


## Подсвечивает готовую нарисованную плашку, не закрывая её древесно-пергаментную фактуру.
static func draw_title_item(game: Node, rect: Rect2, label: String, selected: bool, enabled: bool) -> void:
	if selected:
		var pulse := 0.18 + sin(Time.get_ticks_msec() / 240.0) * 0.04
		game.draw_rect(rect, Color(1.0, 0.82, 0.35, pulse))
		game.draw_rect(rect.grow(2), Color("ffd66d"), false, 2.0)
		var marker := PackedVector2Array([rect.position + Vector2(-13, rect.size.y * 0.5), rect.position + Vector2(-7, rect.size.y * 0.5 - 6), rect.position + Vector2(-1, rect.size.y * 0.5), rect.position + Vector2(-7, rect.size.y * 0.5 + 6)])
		game.draw_colored_polygon(marker, Color("ffd66d"))
	elif not enabled:
		game.draw_rect(rect, Color(0.18, 0.16, 0.13, 0.34))
	var text_color := Color("4a2816") if enabled else Color("8f8069")
	game.draw_string(game.MENU_FONT, rect.position + Vector2(9, 29) + Vector2(1, 2), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 18, 21, Color(1.0, 0.92, 0.72, 0.55))
	game.draw_string(game.MENU_FONT, rect.position + Vector2(9, 29), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 18, 21, text_color)


## Показывает результат сохранения, загрузки или применения параметров внутри текущего меню.
static func draw_notice(game: Node, position: Vector2, width: float) -> void:
	if not game.menu_state.notice.is_empty():
		game.draw_string(game.MENU_FONT, position, game.menu_state.notice, HORIZONTAL_ALIGNMENT_CENTER, width, 13, Color("ffe3a1"))


## Рисует строку с четырёхсторонней тёмной обводкой для читаемости на живом пейзаже.
static func draw_outlined_string(game: Node, baseline: Vector2, label: String, width: float, font_size: int, color: Color, outline: Color, outline_size: int = 1) -> void:
	game.draw_string_outline(game.MENU_FONT, baseline, label, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline_size, outline)
	game.draw_string(game.MENU_FONT, baseline, label, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
