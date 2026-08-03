extends RefCounted


## Рисует улики, ритуал, трёхфазного Регента и два финальных алтаря выбора.
static func draw(game: Node2D) -> void:
	var state: Dictionary = game.state.world.castle_campaign
	if not game.CastleCampaignSystem.available(game) or state.completed: return
	if game.current_location == "castle_hall" and state.stage == 0:
		draw_marker(game, game.CastleCampaignSystem.COUNCIL_POSITION, Color("efc867"), game.LocaleSystem.ui("castle_marker_council"))
	elif game.current_location == "castle_upper" and state.stage == 1:
		for index in game.CastleCampaignSystem.CLUE_POSITIONS.size():
			if not state.clues[index]: draw_marker(game, game.CastleCampaignSystem.CLUE_POSITIONS[index], Color("90d9e8"), game.LocaleSystem.ui("castle_marker_clue"))
	elif game.current_location == "castle_dungeon":
		if state.stage == 2: draw_marker(game, game.CastleCampaignSystem.RITUAL_POSITION, Color("bd75e8"), game.LocaleSystem.ui("castle_marker_ritual"))
		if state.boss_alive: draw_boss(game, state)
		if state.stage == 4:
			draw_marker(game, game.CastleCampaignSystem.SEAL_ALTAR_POSITION, Color("7fc7e8"), game.LocaleSystem.ui("castle_marker_seal"))
			draw_marker(game, game.CastleCampaignSystem.POWER_ALTAR_POSITION, Color("d26bd9"), game.LocaleSystem.ui("castle_marker_power"))


## Рисует интерактивный пьедестал кампании без нового движущегося персонажа.
static func draw_marker(game: Node2D, position: Vector2, color: Color, label: String) -> void:
	var pulse := 25.0 + sin(game.walk_animation_time * 3.0) * 4.0
	game.draw_circle(position, pulse, Color(color, 0.22), false, 4.0)
	game.draw_colored_polygon(PackedVector2Array([position + Vector2(-18, 14), position + Vector2(18, 14), position + Vector2(11, -12), position + Vector2(-11, -12)]), Color(color, 0.78))
	game.draw_string(game.UI_FONT, position + Vector2(-70, 42), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color("fff0cf"))


## Рисует силуэт босса, радиус телеграфа и полосу текущей фазы.
static func draw_boss(game: Node2D, state: Dictionary) -> void:
	var position: Vector2 = game.CastleCampaignSystem.BOSS_POSITION
	var phase: int = int(state.boss_phase)
	var color: Color = [Color("785397"), Color("a6508e"), Color("d25267")][phase - 1]
	if state.telegraph > 0.0:
		game.draw_circle(position, 125.0 + phase * 24.0, Color(color, 0.16), false, 6.0)
	game.draw_circle(position - Vector2(0, 38), 34, color)
	game.draw_rect(Rect2(position + Vector2(-38, -8), Vector2(76, 78)), color)
	game.draw_colored_polygon(PackedVector2Array([position + Vector2(-48, 70), position + Vector2(48, 70), position + Vector2(0, 22)]), Color(color, 0.86))
	var bar := Rect2(position + Vector2(-65, -92), Vector2(130, 11))
	game.draw_rect(bar, Color("20182b")); game.draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * float(state.boss_hp) / game.CastleCampaignSystem.BOSS_MAX_HP, 7)), color)
	game.draw_string(game.UI_FONT, position + Vector2(-90, -103), "%s • %s" % [game.LocaleSystem.entity("shadow_regent"), game.LocaleSystem.ui("boss_phase", [phase])], HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color("fff0ef"))
