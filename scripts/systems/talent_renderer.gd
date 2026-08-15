extends RefCounted

const PANEL := Rect2(54, 34, 1044, 578)
const COLUMN_WIDTH := 244.0
const COLUMN_GAP := 10.0
const NODE_HEIGHT := 62.0
const NODE_GAP := 7.0
const RESPEC_BUTTON := Rect2(832, 548, 230, 28)


## Возвращает прямоугольник узла дерева, общий для мыши, касания и отрисовки.
static func node_rect(index: int) -> Rect2:
	var column := index / 5
	var row := index % 5
	return Rect2(72 + column * (COLUMN_WIDTH + COLUMN_GAP), 164 + row * (NODE_HEIGHT + NODE_GAP), COLUMN_WIDTH, NODE_HEIGHT)


## Находит узел дерева под экранной точкой или возвращает минус один.
static func node_at(point: Vector2) -> int:
	for index in 20:
		if node_rect(index).has_point(point):
			return index
	return -1


## Рисует четыре связанные ветви, общий опыт и подробности выбранной способности.
static func draw(game: Node2D) -> void:
	game.draw_rect(PANEL, Color("2c1b12"))
	game.draw_rect(PANEL.grow(-5), Color("835124"))
	game.draw_rect(Rect2(64, 44, 1024, 558), Color("ead39b"))
	game.draw_rect(Rect2(64, 44, 1024, 84), Color("593118"))
	game.draw_string(game.UI_FONT, Vector2(86, 80), game.TalentSystem.word(game, "title"), HORIZONTAL_ALIGNMENT_LEFT, 480, 25, Color("fff0bd"))
	game.draw_string(game.UI_FONT, Vector2(750, 76), game.LocaleSystem.ui("level_points", [game.player_level, game.skill_points]).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 312, 16, Color("f7cc63"))
	_draw_xp_bar(game)
	for group_index in game.TalentSystem.GROUPS.size():
		var group: Dictionary = game.TalentSystem.GROUPS[group_index]
		var header := Rect2(72 + group_index * (COLUMN_WIDTH + COLUMN_GAP), 134, COLUMN_WIDTH, 26)
		game.draw_rect(header, Color("68401f"))
		game.draw_string(game.UI_FONT, header.position + Vector2(8, 18), "%s  %s" % [group.icon, game.TalentSystem.word(game, "group_%s" % group.id)], HORIZONTAL_ALIGNMENT_CENTER, header.size.x - 16, 12, Color("fff0bd"))
	_draw_dependencies(game)
	for index in game.TalentSystem.TALENTS.size():
		_draw_node(game, index)
	_draw_selected_details(game)


## Рисует прогресс до следующего общего уровня, включая максимальный уровень героя.
static func _draw_xp_bar(game: Node2D) -> void:
	var needed: int = game.SkillSystem.xp_to_next_character_level(game.player_level)
	var ratio := 1.0 if game.player_level >= game.SkillSystem.MAX_CHARACTER_LEVEL else clampf(float(game.player_xp) / float(needed), 0.0, 1.0)
	var bar := Rect2(750, 91, 312, 14)
	game.draw_rect(bar, Color("2d2119"))
	game.draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * ratio, bar.size.y - 4)), Color("76a852"))
	var label := "МАКСИМАЛЬНЫЙ УРОВЕНЬ" if game.player_level >= game.SkillSystem.MAX_CHARACTER_LEVEL else "XP %d / %d" % [game.player_xp, needed]
	game.draw_string(game.UI_FONT, Vector2(750, 119), label, HORIZONTAL_ALIGNMENT_RIGHT, 312, 11, Color("f5dfac"))


## Рисует линии зависимостей до карточек-потомков внутри каждой профессии.
static func _draw_dependencies(game: Node2D) -> void:
	for index in game.TalentSystem.TALENTS.size():
		var talent: Dictionary = game.TalentSystem.TALENTS[index]
		for required_id in talent.requires:
			var parent_index: int = game.TalentSystem.TALENTS.find_custom(func(candidate): return candidate.id == required_id)
			if parent_index < 0:
				continue
			var parent := node_rect(parent_index)
			var child := node_rect(index)
			var active: bool = game.TalentSystem.has(game, String(required_id))
			game.draw_line(Vector2(parent.get_center().x, parent.end.y), Vector2(child.get_center().x, child.position.y), Color("6e9b55") if active else Color("8f7653"), 3.0)


## Рисует один талант с различимыми состояниями: открыт, доступен, закрыт и выбран.
static func _draw_node(game: Node2D, index: int) -> void:
	var talent: Dictionary = game.TalentSystem.TALENTS[index]
	var rect := node_rect(index)
	var selected: bool = index == game.skill_menu_selected
	var current_rank: int = game.TalentSystem.rank(game, String(talent.id))
	var learned: bool = current_rank > 0
	var available: bool = game.TalentSystem.can_unlock(game, String(talent.id))
	var outer := Color("efc75f") if selected else Color("59402a")
	var inner := Color("b9d184") if learned else (Color("f5d77c") if available else Color("c8b58a"))
	game.draw_rect(rect, outer)
	game.draw_rect(rect.grow(-3), inner)
	game.draw_circle(rect.position + Vector2(26, 31), 17, Color("3f5a34") if learned else Color("6e5030"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(10, 37), String(talent.icon), HORIZONTAL_ALIGNMENT_CENTER, 32, 18, Color("fff4cd"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(50, 24), game.TalentSystem.word(game, String(talent.id)), HORIZONTAL_ALIGNMENT_LEFT, 178, 14, Color("3d2c20"))
	var status: String = game.TalentSystem.word(game, "rank", false, [current_rank, game.TalentSystem.max_rank(String(talent.id))]) if learned else (game.TalentSystem.word(game, "available") if available else game.TalentSystem.word(game, "locked"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(50, 47), status, HORIZONTAL_ALIGNMENT_LEFT, 178, 10, Color("41613f") if learned else Color("755238"))


## Показывает эффект и необходимые предшествующие способности выбранного узла.
static func _draw_selected_details(game: Node2D) -> void:
	var talent: Dictionary = game.TalentSystem.at(game.skill_menu_selected)
	var rect := Rect2(72, 516, 1008, 70)
	game.draw_rect(rect, Color("6a4325"))
	game.draw_rect(rect.grow(-3), Color("f4e1af"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(14, 25), game.TalentSystem.word(game, String(talent.id), true), HORIZONTAL_ALIGNMENT_LEFT, 650, 13, Color("4a3525"))
	var missing: Array[String] = game.TalentSystem.missing_requirements(game, String(talent.id))
	var hint: String = game.TalentSystem.word(game, "learn_hint") if missing.is_empty() else game.TalentSystem.word(game, "need", false, [game.TalentSystem.requirement_names(game, missing)])
	game.draw_string(game.UI_FONT, rect.position + Vector2(14, 50), hint, HORIZONTAL_ALIGNMENT_LEFT, 650, 11, Color("795534"))
	game.draw_rect(RESPEC_BUTTON, Color("80502f")); game.draw_rect(RESPEC_BUTTON, Color("d7aa52"), false, 2.0)
	game.draw_string(game.UI_FONT, RESPEC_BUTTON.position + Vector2(6, 19), game.TalentSystem.word(game, "respec", false, [game.TalentSystem.RESPEC_COST]), HORIZONTAL_ALIGNMENT_CENTER, RESPEC_BUTTON.size.x - 12, 10, Color("fff0bd"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(690, 22), game.TalentSystem.word(game, "close"), HORIZONTAL_ALIGNMENT_RIGHT, 294, 10, Color("795534"))
