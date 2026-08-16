class_name TalentRenderer
extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")

const PANEL := Rect2(28, 24, 1096, 600)
const TITLE_RIBBON := Rect2(330, 36, 492, 58)
const TREE_PANEL := Rect2(320, 104, 784, 480)
const COLUMN_WIDTH := 184.0
const COLUMN_GAP := 8.0
const NODE_HEIGHT := 46.0
const NODE_GAP := 6.0
const RESPEC_BUTTON := Rect2(860, 532, 220, 38)
const CLOSE_BUTTON := Rect2(1060, 40, 48, 48)


## Возвращает прямоугольник узла дерева, общий для мыши, касания и отрисовки.
static func node_rect(index: int) -> Rect2:
	var column := index / 5
	var row := index % 5
	return Rect2(332 + column * (COLUMN_WIDTH + COLUMN_GAP), 166 + row * (NODE_HEIGHT + NODE_GAP), COLUMN_WIDTH, NODE_HEIGHT)


## Находит узел дерева под экранной точкой или возвращает минус один.
static func node_at(point: Vector2) -> int:
	for index in 20:
		if node_rect(index).has_point(point): return index
	return -1


## Рисует книгу развития с карточкой героя, эффектами, группой и четырьмя связанными ветвями способностей.
static func draw(game: Node2D) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.015, 0.02, 0.015, 0.72))
	UiKitSystem.draw_panel(game, PANEL)
	UiKitSystem.draw_nine_patch(game, "quest_ribbon", TITLE_RIBBON)
	game.draw_string(game.UI_FONT, TITLE_RIBBON.position + Vector2(24, 39), game.TalentSystem.word(game, "title"), HORIZONTAL_ALIGNMENT_CENTER, TITLE_RIBBON.size.x - 48, 20, UiKitSystem.COLORS.text_light)
	game.draw_texture_rect(UiKitSystem.texture("close_button"), CLOSE_BUTTON, false)
	game.draw_string(game.UI_FONT, CLOSE_BUTTON.position + Vector2(7, 34), "×", HORIZONTAL_ALIGNMENT_CENTER, CLOSE_BUTTON.size.x - 14, 24, Color("fff0cf"))
	game.CharacterUiRenderer.draw(game)
	UiKitSystem.draw_panel(game, TREE_PANEL, false)
	draw_tree_header(game)
	draw_dependencies(game)
	for index in game.TalentSystem.TALENTS.size(): draw_node(game, index)
	draw_selected_details(game)


## Рисует названия четырёх профессий и общий счёт свободных очков над деревом.
static func draw_tree_header(game: Node2D) -> void:
	for group_index in game.TalentSystem.GROUPS.size():
		var group: Dictionary = game.TalentSystem.GROUPS[group_index]
		var header := Rect2(332 + group_index * (COLUMN_WIDTH + COLUMN_GAP), 116, COLUMN_WIDTH, 40)
		UiKitSystem.draw_nine_patch(game, "tab_selected" if group_index == game.skill_menu_selected / 5 else "tab_normal", header)
		game.draw_string(game.UI_FONT, header.position + Vector2(10, 27), "%s  %s" % [group.icon, game.TalentSystem.word(game, "group_%s" % group.id)], HORIZONTAL_ALIGNMENT_CENTER, header.size.x - 20, 10, Color("fff0cf"))
	UiKitSystem.draw_nine_patch(game, "badge", Rect2(874, 62, 168, 42))
	game.draw_string(game.UI_FONT, Vector2(888, 89), game.LocaleSystem.ui("level_points", [game.player_level, game.skill_points]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 9, Color("70452b"))


## Рисует линии зависимостей под карточками, отличая уже выполненные связи от закрытых.
static func draw_dependencies(game: Node2D) -> void:
	for index in game.TalentSystem.TALENTS.size():
		var talent: Dictionary = game.TalentSystem.TALENTS[index]
		for required_id in talent.requires:
			var parent_index: int = game.TalentSystem.TALENTS.find_custom(func(candidate): return candidate.id == required_id)
			if parent_index < 0: continue
			var parent := node_rect(parent_index)
			var child := node_rect(index)
			var active: bool = game.TalentSystem.has(game, String(required_id))
			game.draw_line(Vector2(parent.get_center().x, parent.end.y - 2), Vector2(child.get_center().x, child.position.y + 2), Color("76a45c") if active else Color("887254"), 3.0)


## Рисует одну художественную карточку таланта с внутренним фокусом и понятным состоянием.
static func draw_node(game: Node2D, index: int) -> void:
	var talent: Dictionary = game.TalentSystem.TALENTS[index]
	var talent_id := String(talent.id)
	var rect := node_rect(index)
	var selected: bool = index == game.skill_menu_selected
	var current_rank: int = game.TalentSystem.rank(game, talent_id)
	var learned: bool = current_rank > 0
	var available: bool = game.TalentSystem.can_unlock(game, talent_id)
	UiKitSystem.draw_button(game, rect, selected, true, game.settings_state.reduced_motion, Time.get_ticks_msec())
	if learned: game.draw_rect(rect.grow(-7), Color(0.24, 0.44, 0.21, 0.24))
	elif not available: game.draw_rect(rect.grow(-7), Color(0.12, 0.10, 0.08, 0.34))
	UiKitSystem.draw_nine_patch(game, "badge", Rect2(rect.position + Vector2(8, 7), Vector2(32, 32)))
	game.draw_string(game.UI_FONT, rect.position + Vector2(11, 30), String(talent.icon), HORIZONTAL_ALIGNMENT_CENTER, 26, 13, Color("70452b"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(46, 20), game.TalentSystem.word(game, talent_id), HORIZONTAL_ALIGNMENT_LEFT, 128, 10, UiKitSystem.COLORS.ink)
	var status: String = game.TalentSystem.word(game, "rank", false, [current_rank, game.TalentSystem.max_rank(talent_id)]) if learned else (game.TalentSystem.word(game, "available") if available else game.TalentSystem.word(game, "locked"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(46, 36), status, HORIZONTAL_ALIGNMENT_LEFT, 128, 8, Color("526b42") if learned else Color("80563b"))


## Показывает описание выбранной способности, зависимость, управление и отдельный сброс очков.
static func draw_selected_details(game: Node2D) -> void:
	var talent: Dictionary = game.TalentSystem.at(game.skill_menu_selected)
	var rect := Rect2(332, 432, 748, 138)
	UiKitSystem.draw_nine_patch(game, "tooltip", rect)
	game.draw_string(game.UI_FONT, rect.position + Vector2(20, 28), game.TalentSystem.word(game, String(talent.id)), HORIZONTAL_ALIGNMENT_LEFT, 488, 15, UiKitSystem.COLORS.ink)
	game.draw_multiline_string(game.UI_FONT, rect.position + Vector2(20, 54), game.TalentSystem.word(game, String(talent.id), true), HORIZONTAL_ALIGNMENT_LEFT, 488, 11, 3, Color("5e4633"))
	var missing: Array[String] = game.TalentSystem.missing_requirements(game, String(talent.id))
	var hint: String = game.TalentSystem.word(game, "learn_hint") if missing.is_empty() else game.TalentSystem.word(game, "need", false, [game.TalentSystem.requirement_names(game, missing)])
	game.draw_string(game.UI_FONT, rect.position + Vector2(20, 118), hint, HORIZONTAL_ALIGNMENT_LEFT, 480, 9, Color("80593a"))
	UiKitSystem.draw_button(game, RESPEC_BUTTON, false, game.TalentSystem.spent_points(game) > 0 and game.coins >= game.TalentSystem.RESPEC_COST, game.settings_state.reduced_motion)
	game.draw_string(game.UI_FONT, RESPEC_BUTTON.position + Vector2(10, 25), game.TalentSystem.word(game, "respec", false, [game.TalentSystem.RESPEC_COST]), HORIZONTAL_ALIGNMENT_CENTER, RESPEC_BUTTON.size.x - 20, 8, UiKitSystem.COLORS.text_light)
	game.draw_string(game.UI_FONT, Vector2(856, 514), game.TalentSystem.word(game, "close"), HORIZONTAL_ALIGNMENT_RIGHT, 216, 8, Color("76543b"))
