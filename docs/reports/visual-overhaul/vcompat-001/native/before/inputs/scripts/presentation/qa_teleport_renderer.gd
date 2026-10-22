extends RefCounted

const System := preload("res://scripts/systems/qa_teleport_system.gd")
const Locale := preload("res://scripts/systems/qa_teleport_locale.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const PANEL := Rect2(150, 72, 852, 506)
const CLOSE := Rect2(944, 88, 38, 34)
const SEARCH := Rect2(174, 176, 548, 34)
const LIST := Rect2(174, 222, 548, 296)
const USE := Rect2(748, 476, 230, 42)

## Возвращает одинаковые прямоугольники разделов для рисунка и всех устройств ввода.
static func tab_rect(index: int) -> Rect2:
	return Rect2(174+index*161, 130, 151, 32)

## Возвращает одну видимую строку непрерывно прокручиваемого списка.
static func row_rect(index: int) -> Rect2:
	return Rect2(LIST.position+Vector2(0, index*37), Vector2(548, 34))

## Рисует спокойное пергаментное окно поверх остановленного мира без новых растровых ресурсов.
static func draw(game: Node2D) -> void:
	if not System.active(game): return
	var value := System.state(game); var ids := System.entries(game)
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.04,0.04,0.07,0.72))
	Style.panel(game, PANEL)
	Style.title(game, Rect2(174, 92, 710, 32), Locale.text(game, "title"), 23)
	Style.button(game, CLOSE, "×")
	for index in System.GROUPS.size(): Style.button(game, tab_rect(index), Locale.text(game, System.GROUPS[index]), value.group == System.GROUPS[index])
	Style.panel(game, SEARCH, Style.INSET, Style.ACCENT if value.searching else Style.EDGE)
	Style.text(game, SEARCH.grow(-8), ("▏" if value.searching else "")+String(value.query) if not String(value.query).is_empty() or value.searching else Locale.text(game,"search"), 13, Style.TEXT if value.searching else Style.MUTED)
	for row in System.ROWS:
		var index: int = value.scroll+row
		if index >= ids.size(): break
		var id: String = ids[index]; var rect := row_rect(row)
		Style.panel(game, rect, Style.SELECTED if value.selected == index else Style.INSET)
		Style.text(game, rect.grow(-8), game.LocaleSystem.location(id), 13)
	if ids.is_empty(): Style.text(game, LIST, Locale.text(game,"empty"), 14, Style.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if ids.size() > System.ROWS:
		var size: float = LIST.size.y*System.ROWS/float(ids.size())
		game.draw_rect(Rect2(728, LIST.position.y, 3, LIST.size.y), Style.TRACK)
		game.draw_rect(Rect2(728, LIST.position.y+(LIST.size.y-size)*value.scroll/float(ids.size()-System.ROWS), 3, size), Style.ACCENT)
	game.draw_item_icon(System.KIND, Rect2(824, 178, 64, 64))
	if not ids.is_empty():
		var id: String = ids[clampi(value.selected,0,ids.size()-1)]
		Style.text(game, Rect2(748, 250, 230, 36), game.LocaleSystem.location(id), 16, Style.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		Style.text(game, Rect2(748, 287, 230, 24), id, 11, Style.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	game.draw_ui_multiline_string(game.UI_FONT, Vector2(748, 338), Locale.text(game,"detail"), HORIZONTAL_ALIGNMENT_LEFT, 230, 124, 13, 7, Style.MUTED)
	Style.button(game, USE, Locale.text(game,"use"), true, not ids.is_empty())
	Style.text(game, Rect2(174, 535, 804, 22), String(value.notice) if not String(value.notice).is_empty() else Locale.text(game,"hint"), 11, Style.DANGER if not String(value.notice).is_empty() else Style.MUTED)
