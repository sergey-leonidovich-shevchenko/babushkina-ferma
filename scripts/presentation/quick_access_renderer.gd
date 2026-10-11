extends RefCounted

const UiKit := preload("res://scripts/systems/ui_kit_system.gd")
const WORLD_PANEL := Rect2(310, 580, 532, 60)
const WORLD_ORIGIN := Vector2(318, 588)
const WORLD_SLOT_SIZE := Vector2(48, 48)
const WORLD_PITCH := 52.0
const SLOT_COUNT := 10
const INK := Color("fff1c8")
const OUTLINE := Color("33271e")


## Возвращает единую геометрию рисунка и зоны нажатия компактного мирового слота.
static func world_slot_rect(index: int) -> Rect2:
	return Rect2(WORLD_ORIGIN + Vector2(index * WORLD_PITCH, 0), WORLD_SLOT_SIZE)


## Рисует лёгкое основание и ровно одну рамку на слот, без запечённых ячеек и плашки названия.
static func draw_world(game: Node) -> void:
	preload("res://scripts/presentation/moon_theme.gd").panel(game,WORLD_PANEL,Color("1c3027"))
	for index in SLOT_COUNT:
		draw_slot(game, world_slot_rect(index), index)


## Рисует один слот с центрированным предметом, спокойной подписью клавиши и отдельной строкой количества.
## В рюкзаке сохраняется переданный больший размер, а спокойная поверхность общая для обеих панелей.
static func draw_slot(game: Node, rect: Rect2, index: int) -> void:
	var selected: bool = index == game.selected_hotbar
	var kind: String = game.hotbar_slots[index]
	var count: int = game.inventory_item_count(kind) if not kind.is_empty() else 0
	preload("res://scripts/presentation/moon_theme.gd").panel(game,rect,Color("4b663f") if selected else Color("2c4436"),Color("bdd495") if selected else Color("53694b"))
	if not kind.is_empty():
		game.draw_item_icon(kind, game.InterfaceRenderer.hotbar_icon_rect(rect))
	if kind.is_empty() or count <= 0:
		game.draw_rect(rect.grow(-5), Color(0.10, 0.07, 0.05, 0.42))
	# Выбор остаётся внутри рамки и читается даже на затемнённой пустой ячейке.
	if selected:
		game.draw_line(Vector2(rect.position.x + 10, rect.end.y - 3), Vector2(rect.end.x - 10, rect.end.y - 3), Color("ffe9a6"), 2.0)
	_draw_small_text(game, hotkey_rect(rect), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, 8)
	var quantity := quantity_text(count)
	if not kind.is_empty() and not quantity.is_empty():
		_draw_small_text(game, quantity_rect(rect), quantity, HORIZONTAL_ALIGNMENT_RIGHT, 9)
	var readiness: float = game.InterfaceRenderer.hotbar_readiness(game, kind)
	if not kind.is_empty() and readiness < 1.0:
		var track := readiness_rect(rect)
		game.draw_rect(track, Color("493325"))
		game.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(readiness, 0.0, 1.0), track.size.y)), Color("8cbd70").lerp(Color("ce6952"), 1.0 - readiness))


## Отводит клавише собственное верхнее поле без непрозрачной квадратной подложки.
static func hotkey_rect(slot: Rect2) -> Rect2:
	return Rect2(slot.position + Vector2(6, 4), Vector2(12, 11))


## Размещает количество над индикатором готовности, сохраняя отступ от правой рамки.
static func quantity_rect(slot: Rect2) -> Rect2:
	return Rect2(slot.end - Vector2(36, 19), Vector2(29, 11))


## Оставляет тонкой шкале отдельные два пикселя у нижней внутренней кромки.
static func readiness_rect(slot: Rect2) -> Rect2:
	return Rect2(Vector2(slot.position.x + 8, slot.end.y - 6), Vector2(slot.size.x - 16, 2))


## Скрывает единичные и пустые стопки; большие количества сокращает без округления вверх.
static func quantity_text(count: int) -> String:
	if count <= 1: return ""
	if count < 1000: return str(count)
	if count >= 1000000000: return "1B+"
	var divisor := 1000000 if count >= 1000000 else 1000
	var suffix := "M" if divisor == 1000000 else "k"
	var whole: int = count / divisor
	var tenth: int = (count % divisor) / (divisor / 10)
	return "%d.%d%s" % [whole, tenth, suffix] if whole < 10 and tenth > 0 else "%d%s" % [whole, suffix]


## Подбирает размер цифр по ширине и высоте при пользовательском масштабе текста до 120%.
static func label_font_size(game: Node, rect: Rect2, text: String, requested: int) -> int:
	return game.UiScaleSystem.fitted_multiline_font_size(game, game.UI_FONT, text, rect.size.x, rect.size.y, requested)


## Центрирует подпись по вертикали и добавляет тонкий тёмный контур вместо массивного бейджа.
static func _draw_small_text(game: Node, rect: Rect2, text: String, alignment: HorizontalAlignment, requested: int) -> void:
	var size := label_font_size(game, rect, text, requested)
	var font: Font = game.UI_FONT
	var baseline := rect.position + Vector2(0, (rect.size.y - font.get_height(size)) * 0.5 + font.get_ascent(size))
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		game.draw_string(font, baseline + offset, text, alignment, rect.size.x, size, OUTLINE)
	game.draw_string(font, baseline, text, alignment, rect.size.x, size, INK)
