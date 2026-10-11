extends RefCounted

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const PANEL := Rect2(302, 176, 548, 296)
const TITLE := Rect2(330, 264, 164, 44)
const CONTEXT := Rect2(330, 309, 164, 36)
const SAVE_LABEL := Rect2(330, 380, 164, 30)
const SAVE_DETAILS := Rect2(330, 414, 164, 48)
const ITEMS := [Rect2(542, 204, 280, 48), Rect2(542, 262, 136, 48), Rect2(686, 262, 136, 48), Rect2(542, 318, 280, 48), Rect2(542, 392, 136, 48), Rect2(686, 392, 136, 48)]

## Возвращает общую область кнопки для рисунка, касаний и обратной связи нажатия.
static func item_rect(index: int) -> Rect2:
	return ITEMS[index] if index >= 0 and index < ITEMS.size() else Rect2()

## Возвращает внутреннюю область подписи, оставляя отдельные поля пиктограмме и клавише возврата.
static func label_rect(index: int) -> Rect2:
	var rect: Rect2 = ITEMS[index]
	if index == 0: return Rect2(rect.position + Vector2(34, 4), Vector2(rect.size.x - 80, 40))
	if index in [1, 2]: return Rect2(rect.position + Vector2(28, 4), Vector2(rect.size.x - 36, 40))
	return rect.grow(-8)

## Рисует выбранную горизонтальную паузу с контекстом слева и шестью действиями справа.
static func draw(game: Node) -> void:
	draw_backdrop(game)
	MoonStyle.panel(game, PANEL.grow(3), Color(0.025, 0.065, 0.045, 0.35), Color.TRANSPARENT, 8)
	MoonStyle.panel(game, PANEL)
	game.draw_line(Vector2(514, 204), Vector2(514, 444), Color("40583f"), 1.0)
	draw_moon(game, Vector2(342, 232))
	MoonStyle.title(game, TITLE, MoonStyle.sentence_case(game.LocaleSystem.ui("paused")), 32)
	multiline(game, CONTEXT, game.WorldSystem.name(game.current_location), MoonStyle.LABEL_SIZE, MoonStyle.MUTED)
	for index in ITEMS.size(): draw_action(game, index)
	game.draw_line(Vector2(542, 382), Vector2(822, 382), Color("40583f"), 1.0)
	var status: String = game.LocaleSystem.ui("last_save") if game.menu_state.notice.is_empty() else game.menu_state.notice
	multiline(game, SAVE_LABEL, status, MoonStyle.LABEL_SIZE, MoonStyle.MUTED if game.menu_state.notice.is_empty() else MoonStyle.ACCENT)
	multiline(game, SAVE_DETAILS, save_details(game), MoonStyle.LABEL_SIZE)

## Затемняет мир одним спокойным слоем, оставляя узнаваемый игровой фон.
static func draw_backdrop(game: Node) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.035, 0.086, 0.067, 0.58))

## Рисует постоянный акцент продолжения и различимый клавиатурный фокус любой другой команды.
static func draw_action(game: Node, index: int) -> void:
	var rect: Rect2 = ITEMS[index]
	var selected: bool = game.menu_state.pause_selected == index
	var primary := index == 0
	var fill: Color = MoonStyle.ACCENT if primary else (Color("46613d") if selected else MoonStyle.INSET)
	var border: Color = MoonStyle.TEXT if selected and primary else (MoonStyle.ACCENT if selected else MoonStyle.EDGE)
	if index >= 4 and not selected: fill = MoonStyle.PANEL; border = MoonStyle.PANEL
	MoonStyle.panel(game, rect, fill, border, 4)
	var ink: Color = MoonStyle.PANEL if primary else (MoonStyle.MUTED if index >= 4 and not selected else MoonStyle.TEXT)
	MoonStyle.text(game, label_rect(index), MoonStyle.sentence_case(game.LocaleSystem.ui(game.MenuSystem.PAUSE_ITEMS[index])), MoonStyle.BODY_SIZE, ink, HORIZONTAL_ALIGNMENT_LEFT if index <= 2 else HORIZONTAL_ALIGNMENT_CENTER)
	if index <= 2: draw_icon(game, rect.position + Vector2(18, 24), index, ink)
	if primary and not game.touch_controls_visible:
		var hint: String = "B" if game.get_meta("last_ui_input", "keyboard") == "gamepad" else "Esc"
		var hint_rect := Rect2(rect.position + Vector2(242, 15), Vector2(28, 18))
		MoonStyle.panel(game, hint_rect, MoonStyle.ACCENT, Color("799361"), 3)
		MoonStyle.text(game, hint_rect, hint, MoonStyle.HINT_SIZE, MoonStyle.PANEL, HORIZONTAL_ALIGNMENT_CENTER)

## Рисует небольшие пиктограммы продолжения, сохранения и папки в цвете подписи кнопки.
static func draw_icon(game: Node, center: Vector2, index: int, color: Color) -> void:
	if index == 0:
		game.draw_polyline(PackedVector2Array([center + Vector2(-4, -6), center + Vector2(5, 0), center + Vector2(-4, 6), center + Vector2(-4, -6)]), color, 1.0, true)
	elif index == 1:
		game.draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color, false, 1.0)
		game.draw_rect(Rect2(center + Vector2(-3, -6), Vector2(6, 4)), color, false, 1.0)
		game.draw_rect(Rect2(center + Vector2(-3, 1), Vector2(6, 5)), color, false, 1.0)
	else:
		game.draw_polyline(PackedVector2Array([center + Vector2(-6, 6), center + Vector2(-6, -5), center + Vector2(-1, -5), center + Vector2(1, -2), center + Vector2(6, -2), center + Vector2(6, 6), center + Vector2(-6, 6)]), color, 1.0, true)

## Рисует небольшой лунный знак без тяжёлой декоративной рамки.
static func draw_moon(game: Node, center: Vector2) -> void:
	game.draw_arc(center, 7, 0.15 * PI, 1.85 * PI, 20, MoonStyle.ACCENT, 1.0, true)
	game.draw_arc(center + Vector2(4, -3), 6, 0.32 * PI, 1.18 * PI, 16, MoonStyle.ACCENT, 1.0, true)

## Разделяет фактический день и время сохранения с его локацией, не подменяя пустой слот примером.
static func save_details(game: Node) -> String:
	var summary: String = game.MenuSystem.save_summary(game)
	var separator := summary.rfind(" • ")
	return summary.left(separator) + "\n" + summary.substr(separator + 3) if separator >= 0 else summary

## Вписывает локализованный текст в отведённую высоту и сохраняет все строки при увеличении масштаба.
static func multiline(game: Node, rect: Rect2, label: String, size: int, color: Color = MoonStyle.TEXT) -> void:
	var fitted: int = game.UiScaleSystem.fitted_multiline_font_size(game, game.UI_FONT, label, rect.size.x, rect.size.y, size)
	game.draw_multiline_string(game.UI_FONT, rect.position + Vector2(0, game.UI_FONT.get_ascent(fitted)), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, fitted, -1, color)

## Показывает подтверждение опасной команды в той же палитре, сохраняя начальный фокус на отмене.
static func draw_confirmation(game: Node, panel: Rect2, accept: Rect2, cancel: Rect2) -> void:
	draw_backdrop(game)
	MoonStyle.panel(game, panel)
	MoonStyle.title(game, Rect2(panel.position + Vector2(32, 26), Vector2(panel.size.x - 64, 38)), MoonStyle.sentence_case(game.LocaleSystem.ui("confirmation_title")), 26)
	multiline(game, Rect2(panel.position + Vector2(32, 82), Vector2(panel.size.x - 64, 64)), game.LocaleSystem.ui("confirm_" + game.menu_state.confirmation), MoonStyle.BODY_SIZE, MoonStyle.MUTED)
	MoonStyle.button(game, accept, MoonStyle.sentence_case(game.LocaleSystem.ui("yes")), game.menu_state.confirm_selected == 0)
	MoonStyle.button(game, cancel, MoonStyle.sentence_case(game.LocaleSystem.ui("no")), game.menu_state.confirm_selected == 1)
