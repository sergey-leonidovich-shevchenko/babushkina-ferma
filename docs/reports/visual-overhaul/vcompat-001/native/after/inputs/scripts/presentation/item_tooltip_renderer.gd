extends RefCounted

const Paper := preload("res://scripts/presentation/paper_theme_palette.gd")

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const ItemPresentationSystem := preload("res://scripts/systems/item_presentation_system.gd")


## Возвращает ограниченные области карточки, включая резерв под сравнение и цену вместо свободно растущего текста.
static func content_layout(rect: Rect2, has_effect: bool, has_durability: bool) -> Dictionary:
	var inner := rect.grow(-14)
	var body_width := inner.size.x
	var layout := {
		"inner": inner,
		"icon": Rect2(inner.position, Vector2(52, 52)),
		"title": Rect2(inner.position + Vector2(64, 0), Vector2(body_width - 64, 40)),
		"rarity": Rect2(inner.position + Vector2(64, 44), Vector2(body_width - 64, 16)),
		"metadata": Rect2(inner.position + Vector2(0, 66), Vector2(body_width, 17)),
		"description": Rect2(inner.position + Vector2(0, 92), Vector2(body_width, 36)),
		"footer": Rect2(inner.position + Vector2(0, inner.size.y - 18), Vector2(body_width, 18)),
	}
	var cursor := 134.0
	if has_effect:
		layout.effect = Rect2(inner.position + Vector2(0, cursor), Vector2(body_width, 38))
		cursor += 44.0
	if has_durability:
		layout.durability = Rect2(inner.position + Vector2(0, cursor), Vector2(body_width, 26))
		cursor += 32.0
	layout.comparison = Rect2(inner.position + Vector2(0, cursor), Vector2(body_width, maxf(0, inner.size.y - cursor)))
	return layout


## Рисует читаемую карточку предмета с переносом названия, ровными отступами и ограниченным сравнением характеристик.
static func draw(game: Node, kind: String, rect: Rect2, amount: int = -1, draw_background: bool = false) -> void:
	if kind.is_empty(): return
	if draw_background: UiKitSystem.draw_nine_patch(game, "tooltip", rect)
	var effect := ItemPresentationSystem.effect_text(game, kind)
	var durability := ItemPresentationSystem.durability(game, kind)
	var layout := content_layout(rect, not effect.is_empty(), durability >= 0)
	var rarity_color := Paper.rarity_ink(ItemPresentationSystem.rarity(kind))
	game.draw_item_icon(kind, layout.icon)
	draw_text(game, game.inventory_item_name(kind), layout.title, 14, UiKitSystem.COLORS.ink, 2)
	draw_text(game, game.LocaleSystem.ui("item_rarity_" + ItemPresentationSystem.rarity(kind)), layout.rarity, 10, rarity_color)
	var metadata: String = game.LocaleSystem.ui("category_" + game.InventorySystem.category(kind))
	if amount >= 0: metadata += "  ·  ×%d" % amount
	draw_text(game, metadata, layout.metadata, 10, Color("6d593d"))
	game.draw_line(Vector2(layout.inner.position.x, layout.description.position.y - 7), Vector2(layout.inner.end.x, layout.description.position.y - 7), Color("b89b6b"), 1)
	draw_text(game, game.LocaleSystem.ui(game.InventorySystem.detail_key(kind)), layout.description, 11, Color("684b31"), 2)
	if not effect.is_empty():
		draw_text(game, effect, layout.effect, 11, Color("416036"), 2)
	if durability >= 0:
		var durability_rect: Rect2 = layout.durability
		draw_text(game, game.LocaleSystem.ui("item_durability", [durability]), Rect2(durability_rect.position, Vector2(durability_rect.size.x, 18)), 10, UiKitSystem.COLORS.ink)
		var track := Rect2(durability_rect.position + Vector2(0, 21), Vector2(durability_rect.size.x, 4))
		game.draw_rect(track, Color("b69765"))
		game.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(durability / 100.0, 0, 1), track.size.y)), Color("678c48") if durability > 20 else UiKitSystem.COLORS.danger)
	var comparison := ItemPresentationSystem.comparison(game, kind)
	if not comparison.is_empty():
		draw_comparison(game, comparison, layout.comparison)
	else:
		draw_text(game, game.LocaleSystem.ui("sell_value", [game.ShopSystem.sell_price(kind)]), layout.footer, 10, Color("765128"))


## Рисует дельты характеристик только внутри выделенной высоты; строки не могут перекрыть кнопки действий.
static func draw_comparison(game: Node, comparison: Dictionary, rect: Rect2) -> void:
	if rect.size.y < 18: return
	var title: String = game.LocaleSystem.ui("item_equipped") if bool(comparison.same) else game.LocaleSystem.ui("item_compare")
	draw_text(game, title, Rect2(rect.position, Vector2(rect.size.x, 18)), 10, Color("765a3c"))
	var rows: Array = comparison.rows
	var line_height := minf(20, (rect.size.y - 20) / maxf(rows.size(), 1))
	if line_height < 12: return
	for index in rows.size():
		var row: Dictionary = rows[index]
		var delta := int(row.delta)
		var suffix := "%+d%%" % delta if String(row.id) == "speed" else "%+d" % delta
		var value := "%d%%" % int(row.candidate) if String(row.id) == "speed" else str(row.candidate)
		var text := "%s  %s  (%s)" % [game.LocaleSystem.ui("item_stat_" + String(row.id)), value, suffix]
		var color := Color("416036") if delta > 0 else (UiKitSystem.COLORS.danger if delta < 0 else Color("6d593d"))
		draw_text(game, text, Rect2(rect.position + Vector2(0, 20 + index * line_height), Vector2(rect.size.x, line_height)), 10, color)


## Размещает текст по метрикам шрифта внутри прямоугольника, сохраняя отступ сверху при увеличении масштаба.
static func draw_text(game: Node, text: String, rect: Rect2, font_size: int, color: Color, lines: int = 1) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0: return
	var fitted: int = game.UiScaleSystem.fitted_multiline_font_size(game, game.UI_FONT, text, rect.size.x, rect.size.y, font_size)
	var baseline: float = game.UI_FONT.get_ascent(fitted)
	game.draw_ui_multiline_string(game.UI_FONT, rect.position + Vector2(0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, rect.size.y, font_size, lines, color)
