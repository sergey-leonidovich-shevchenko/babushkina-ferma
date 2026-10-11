extends RefCounted

const UiKit := preload("res://scripts/systems/ui_kit_system.gd")
const HUD_RECT := Rect2(0, 0, 1152, 80)
const PORTRAIT := Rect2(16, 12, 58, 60)
const BARS := Rect2(74, 12, 214, 60)
const STATUS := Rect2(16, 12, 272, 60)
const PORTRAIT_IMAGE := Rect2(25, 16, 40, 40)
const LEVEL := Rect2(23, 56, 44, 12)
const EXPERIENCE := Rect2(26, 68, 38, 2)
const CLOCK := Rect2(842, 12, 164, 60)
const WEATHER := Rect2(853, 21, 23, 23)
const TIME := Rect2(883, 17, 111, 28)
const CALENDAR := Rect2(852, 47, 144, 16)
const LOCATION := Rect2(408, 12, 316, 32)
const LOCATION_TITLE := Rect2(438, 18, 273, 20)
const SUMMARY := Rect2(430, 48, 292, 20)
const SKILLS := Rect2(1020, 12, 48, 48)
const QUESTS := Rect2(1080, 12, 48, 48)
const TEXT := Color("f8e7c0")
const MUTED := Color("c7b68f")
const GOLD := Color("d4ad62")


## Возвращает одну из трёх ровных строк характеристик в общей компактной карточке.
static func stat_row(index: int) -> Rect2:
	return Rect2(86, 18 + index * 16, 190, 16)


## Разделяет название, тонкий индикатор и точное значение; цифры не накладываются на полосу.
static func stat_parts(row: Rect2) -> Dictionary:
	return {"label":Rect2(row.position, Vector2(20, row.size.y)), "track":Rect2(row.position + Vector2(24, 5), Vector2(row.size.x - 82, 7)), "value":Rect2(row.position + Vector2(row.size.x - 52, 0), Vector2(52, row.size.y))}


## Рисует небольшую древесную карточку из девяти участков готового арта, сохраняя масштаб её углов.
static func draw_panel(canvas: CanvasItem, rect: Rect2) -> void:
	var texture := UiKit.texture("panel_medium")
	var source_size := texture.get_size()
	var source_x := [0.0, 42.0, source_size.x - 42.0, source_size.x]
	var source_y := [0.0, 40.0, source_size.y - 36.0, source_size.y]
	var edge := minf(10.0, rect.size.y * 0.3)
	var target_x := [rect.position.x, rect.position.x + edge, rect.end.x - edge, rect.end.x]
	var target_y := [rect.position.y, rect.position.y + edge, rect.end.y - edge, rect.end.y]
	canvas.draw_rect(Rect2(rect.position + Vector2(0, 2), rect.size), Color(0.025, 0.02, 0.012, 0.30))
	for y in 3:
		for x in 3:
			var source := Rect2(source_x[x], source_y[y], source_x[x+1] - source_x[x], source_y[y+1] - source_y[y])
			var destination := Rect2(target_x[x], target_y[y], target_x[x+1] - target_x[x], target_y[y+1] - target_y[y])
			canvas.draw_texture_rect_region(texture, destination, source)
	canvas.draw_rect(rect.grow(-7), Color(0.10, 0.055, 0.03, 0.55))


## Вычисляет кегль и базовую линию по настоящим метрикам шрифта, учитывая обе границы и пользовательские 120%.
static func text_layout(game: Node, rect: Rect2, text: String, requested: int) -> Dictionary:
	var size: int = game.UiScaleSystem.fitted_font_size(game, game.UI_FONT, text, rect.size.x, requested)
	while size > 6 and game.UI_FONT.get_height(size) > rect.size.y: size -= 1
	var baseline := Vector2(rect.position.x, roundf(rect.position.y + (rect.size.y - game.UI_FONT.get_height(size)) * 0.5 + game.UI_FONT.get_ascent(size)))
	return {"size":size, "baseline":baseline, "bounds":rect}


## Центрирует подпись по высоте; повторного масштабирования шрифта после расчёта безопасной области нет.
static func draw_text(game: Node, rect: Rect2, text: String, requested: int, color: Color = TEXT, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var layout := text_layout(game, rect, text, requested)
	game.draw_string(game.UI_FONT, layout.baseline, text, alignment, rect.size.x, int(layout.size), color)


## Возвращает окрашенную область тонкой шкалы с ограничением значений для пустых и переполненных состояний.
static func fill_rect(track: Rect2, ratio: float) -> Rect2:
	var inner := track.grow(-1)
	return Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y))
