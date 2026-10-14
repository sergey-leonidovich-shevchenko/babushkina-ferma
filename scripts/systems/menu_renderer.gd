extends RefCounted

const TITLE_BUTTON_SELECTED_ART := preload("res://assets/game/ui/title/title_button_selected_v1.png")
const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const MoonPause := preload("res://scripts/presentation/moon_pause_renderer.gd")
const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const TITLE_PANEL := Rect2(746, 244, 360, 360)
const PAUSE_PANEL := MoonPause.PANEL
const SETTINGS_PANEL := Rect2(250, 18, 652, 612)
const LANGUAGE_PANEL := Rect2(210, 108, 732, 430)
const CONFIRM_PANEL := Rect2(326, 198, 500, 252)
const CONFIRM_ACCEPT := Rect2(372, 362, 190, 52)
const CONFIRM_CANCEL := Rect2(590, 362, 190, 52)
const TITLE_WORDMARK_RECT := Rect2(38, 34, 694, 72)
const TITLE_ITEM_ORIGIN := Vector2(814, 329)
const SETTINGS_ITEM_ORIGIN := Vector2(296, 102)
const TITLE_ITEM_SIZE := Vector2(222, 43)
const TITLE_SELECTED_ART_SIZE := Vector2(238, 56)
const SETTINGS_ITEM_SIZE := Vector2(272, 52)
const SETTINGS_ITEM_PITCH := Vector2(288, 64)
const TITLE_HIGHLIGHT_ALPHA_BASE := 0.90
const TITLE_HIGHLIGHT_ALPHA_PULSE := 0.08


## Возвращает прямоугольник строки главного меню для отрисовки и единой hit-зоны.
static func title_item_rect(index: int) -> Rect2:
	return Rect2(TITLE_ITEM_ORIGIN + Vector2(0, index * 52), TITLE_ITEM_SIZE)


## Центрирует отдельный спрайт выбранного состояния поверх настоящей нарисованной плашки.
static func title_selected_art_rect(item_rect: Rect2) -> Rect2:
	return Rect2(item_rect.get_center() - TITLE_SELECTED_ART_SIZE * 0.5, TITLE_SELECTED_ART_SIZE)


## Возвращает прямоугольник строки меню паузы для отрисовки и единой hit-зоны.
static func pause_item_rect(index: int) -> Rect2:
	return MoonPause.item_rect(index)


## Возвращает прямоугольник строки настроек для отрисовки и единой hit-зоны.
static func settings_item_rect(index: int) -> Rect2:
	return Rect2(SETTINGS_ITEM_ORIGIN + Vector2(index % 2, index / 2) * SETTINGS_ITEM_PITCH, SETTINGS_ITEM_SIZE)


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
	for index in 14:
		if settings_item_rect(index).has_point(point): return index
	return -1


## Рисует книжное название с плотной тенью, тонким разделителем и спокойной строкой жанров.
static func draw_title_wordmark(game: Node) -> void:
	draw_outlined_string(game, TITLE_WORDMARK_RECT.position + Vector2(0, 57), game.LocaleSystem.ui("title"), TITLE_WORDMARK_RECT.size.x, 54, Color("fff1bd"), Color("3a1d12"), 3)
	draw_outlined_string(game, Vector2(70, 127), game.LocaleSystem.ui("title_subtitle"), 630, 24, Color("ffd277"), Color("321b14"), 2)
	game.draw_line(Vector2(172, 143), Vector2(598, 143), Color(0.94, 0.70, 0.30, 0.78), 2.0)
	game.draw_circle(Vector2(385, 143), 4.0, Color("ffe28b"))
	draw_outlined_string(game, Vector2(116, 172), game.LocaleSystem.ui("title_features"), 538, 16, Color("fff1cf"), Color(0.10, 0.06, 0.04, 0.92), 1)


## Рисует светлое меню поверх фоновой иллюстрации, сохраняя прежние области нажатий.
static func draw_title_menu(game: Node) -> void:
	MoonStyle.panel(game,TITLE_PANEL)
	MoonStyle.title(game,Rect2(810,272,230,36),MoonStyle.sentence_case(game.LocaleSystem.ui("main_menu")),24)
	for index in game.MenuSystem.TITLE_ITEMS.size():
		var enabled: bool = index != 0 or game.MenuSystem.has_save(game)
		draw_title_item(game, title_item_rect(index), game.LocaleSystem.ui(game.MenuSystem.TITLE_ITEMS[index]), index == game.menu_state.title_selected, enabled)
	draw_notice(game, Vector2(794, 568), 294)


## Затемняет мир и рисует меню паузы либо открытую поверх него страницу настроек.
static func draw_pause_layer(game: Node) -> void:
	if game.menu_state.defeat_open:
		draw_defeat(game)
		return
	if game.menu_state.settings_open:
		draw_settings(game)
		return
	if not game.menu_state.confirmation.is_empty():
		MoonPause.draw_confirmation(game, CONFIRM_PANEL, CONFIRM_ACCEPT, CONFIRM_CANCEL)
	else:
		MoonPause.draw(game)


## Рисует страницу параметров с текущими значениями звука, экрана и языка.
static func draw_settings(game: Node) -> void:
	if game.menu_state.settings_from_title:
		game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.025, 0.022, 0.82))
		draw_panel(game, SETTINGS_PANEL)
		game.draw_ui_string(game.MENU_FONT, Vector2(280, 68), game.LocaleSystem.ui("settings"), HORIZONTAL_ALIGNMENT_CENTER, 592, 26, MoonStyle.TEXT)
	else:
		MoonPause.draw_backdrop(game)
		MoonStyle.panel(game, SETTINGS_PANEL)
		MoonStyle.title(game, Rect2(280, 40, 592, 38), MoonStyle.sentence_case(game.LocaleSystem.ui("settings")), 28)
	var values := [
		"%d%%" % game.SettingsSystem.percent(game.settings_state.master_volume),
		"%d%%" % game.SettingsSystem.percent(game.settings_state.music_volume),
		"%d%%" % game.SettingsSystem.percent(game.settings_state.sfx_volume),
		game.LocaleSystem.ui("enabled" if game.audio_enabled else "disabled"),
		game.LocaleSystem.ui("enabled" if game.settings_state.fullscreen_enabled else "disabled"),
		game.LocaleSystem.ui("enabled" if game.settings_state.vsync_enabled else "disabled"),
		game.LocaleSystem.ui("enabled" if game.settings_state.reduced_motion else "disabled"),
		game.LocaleSystem.ui("enabled" if game.settings_state.high_contrast else "disabled"),
		game.LocaleSystem.ui("left_handed_controls" if game.settings_state.control_preset=="left_handed" else "standard_controls"),
		"%d%%" % roundi(game.settings_state.text_scale * 100.0),
		"%d%%" % roundi(game.settings_state.touch_scale * 100.0),
		game.LocaleSystem.language_name(game.LocaleSystem.index()),
		"",
	]
	for index in game.MenuSystem.SETTING_ITEMS.size():
		draw_setting_card(game, settings_item_rect(index), game.LocaleSystem.ui(game.MenuSystem.SETTING_ITEMS[index]), values[index], index == game.menu_state.settings_selected)
	draw_notice(game, Vector2(280, 604), 592)


## Рисует выбор языка поверх атмосферного титульного фона теми же кнопками и рамкой, что системные меню.
static func draw_language_screen(game: Node) -> void:
	game.draw_texture_rect(game.TITLE_ART, Rect2(0, 0, 1152, 648), false)
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.018, 0.035, 0.03, 0.68))
	draw_panel(game, LANGUAGE_PANEL)
	game.draw_ui_string(game.MENU_FONT, Vector2(256, 176), game.LocaleSystem.ui("choose_language"), HORIZONTAL_ALIGNMENT_CENTER, 640, 30, MoonStyle.TEXT)
	for index in game.LocaleSystem.LOCALES.size():
		var rect: Rect2 = game.language_button_rect(index)
		UiKitSystem.draw_button(game, rect, index == game.language_selected, true, game.settings_state.reduced_motion, Time.get_ticks_msec())
		var color := UiKitSystem.COLORS.ink
		game.draw_ui_string(game.MENU_FONT, rect.position + Vector2(10, 37), "%d  %s" % [index + 1, game.LocaleSystem.language_name(index)], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20, 18, color)
	game.draw_ui_string(game.UI_FONT, Vector2(276, 500), game.LocaleSystem.ui("confirm"), HORIZONTAL_ALIGNMENT_CENTER, 600, 11, Color("6d4b2d"))


## Рисует двухстрочную карточку параметра с раздельной иерархией названия и текущего значения.
static func draw_setting_card(game: Node, rect: Rect2, label: String, value: String, selected: bool) -> void:
	if not game.menu_state.settings_from_title:
		MoonStyle.panel(game, rect, MoonStyle.SELECTED if selected else MoonStyle.INSET, MoonStyle.ACCENT if selected else MoonStyle.EDGE)
		if value.is_empty():
			MoonStyle.text(game, rect.grow(-8), MoonStyle.sentence_case(label), 13, MoonStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			MoonStyle.text(game, Rect2(rect.position + Vector2(12, 5), Vector2(rect.size.x - 24, 20)), MoonStyle.sentence_case(label), 11, MoonStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			MoonStyle.text(game, Rect2(rect.position + Vector2(12, 27), Vector2(rect.size.x - 24, 20)), "‹  %s  ›" % value, 13, MoonStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		return
	UiKitSystem.draw_inset_card(game,rect,selected)
	if value.is_empty():
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(44, 33), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 88, 11, UiKitSystem.COLORS.ink)
		return
	var display: String = "‹  %s  ›" % value
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(16, 22), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 32, 10, Color("6b482d"))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(16, 40), display, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 32, 12, UiKitSystem.COLORS.ink)


## Рисует модальное подтверждение выхода или возврата, сохраняя мир видимым и недоступным позади.
static func draw_confirmation(game: Node) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.015, 0.012, 0.58))
	UiKitSystem.draw_panel(game, CONFIRM_PANEL, false)
	game.draw_ui_string(game.MENU_FONT, Vector2(370, 258), game.LocaleSystem.ui("confirmation_title"), HORIZONTAL_ALIGNMENT_CENTER, 412, 24, MoonStyle.TEXT)
	game.draw_multiline_string(game.UI_FONT, Vector2(374, 294), game.LocaleSystem.ui("confirm_" + game.menu_state.confirmation), HORIZONTAL_ALIGNMENT_CENTER, 404, 13, 2, Color("4b3425"))
	UiKitSystem.draw_button(game, CONFIRM_ACCEPT, game.menu_state.confirm_selected == 0, true, game.settings_state.reduced_motion, Time.get_ticks_msec())
	UiKitSystem.draw_button(game, CONFIRM_CANCEL, game.menu_state.confirm_selected == 1, true, game.settings_state.reduced_motion, Time.get_ticks_msec())
	game.draw_ui_string(game.MENU_FONT, CONFIRM_ACCEPT.position + Vector2(8, 35), game.LocaleSystem.ui("yes"), HORIZONTAL_ALIGNMENT_CENTER, CONFIRM_ACCEPT.size.x - 16, 16, UiKitSystem.COLORS.ink)
	game.draw_ui_string(game.MENU_FONT, CONFIRM_CANCEL.position + Vector2(8, 35), game.LocaleSystem.ui("no"), HORIZONTAL_ALIGNMENT_CENTER, CONFIRM_CANCEL.size.x - 16, 16, UiKitSystem.COLORS.ink)


## Передаёт совместимый вызов компактному уведомлению без блокирующей панели поражения.
static func draw_defeat(game: Node) -> void:
	preload("res://scripts/presentation/recovery_notice_renderer.gd").draw(game)


## Рисует гладкую светлую панель системного окна в общей палитре интерфейса игры.
static func draw_panel(game: Node, rect: Rect2) -> void:
	UiKitSystem.draw_panel(game, rect, rect.size.x >= 420.0 or rect.size.y >= 300.0)


## Рисует строку меню с различимыми состояниями выбора и недоступности.
static func draw_item(game: Node, rect: Rect2, label: String, selected: bool, enabled: bool) -> void:
	UiKitSystem.draw_button(game, rect, selected, enabled, game.settings_state.reduced_motion, Time.get_ticks_msec())
	var color := UiKitSystem.COLORS.ink if enabled else UiKitSystem.COLORS.text_disabled
	game.draw_ui_string(game.MENU_FONT, rect.position + Vector2(12, rect.size.y * 0.63), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 24, 16, color)


## Рисует действие главного меню общей светлой кнопкой с различимым фокусом.
static func draw_title_item(game: Node, rect: Rect2, label: String, selected: bool, enabled: bool) -> void:
	MoonStyle.button(game,rect,label,selected,enabled)


## Возвращает прозрачность спокойного пульса отдельного спрайта выбранной плашки.
static func title_highlight_modulate(milliseconds: int, reduced_motion: bool = false) -> Color:
	var alpha := TITLE_HIGHLIGHT_ALPHA_BASE if reduced_motion else TITLE_HIGHLIGHT_ALPHA_BASE + sin(milliseconds / 260.0) * TITLE_HIGHLIGHT_ALPHA_PULSE
	return Color(1.0, 1.0, 1.0, alpha)


## Показывает результат сохранения, загрузки или применения параметров внутри текущего меню.
static func draw_notice(game: Node, position: Vector2, width: float) -> void:
	if not game.menu_state.notice.is_empty():
		if game.menu_state.settings_open and not game.menu_state.settings_from_title:
			MoonStyle.text(game, Rect2(position - Vector2(0, 18), Vector2(width, 28)), game.menu_state.notice, 13, MoonStyle.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			MoonStyle.text(game,Rect2(position-Vector2(0,18),Vector2(width,28)),game.menu_state.notice,13,MoonStyle.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)


## Рисует строку с четырёхсторонней тёмной обводкой для читаемости на живом пейзаже.
static func draw_outlined_string(game: Node, baseline: Vector2, label: String, width: float, font_size: int, color: Color, outline: Color, outline_size: int = 1) -> void:
	game.draw_string_outline(game.MENU_FONT, baseline, label, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline_size, outline)
	game.draw_ui_string(game.MENU_FONT, baseline, label, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
