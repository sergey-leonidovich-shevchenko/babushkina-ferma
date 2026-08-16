extends RefCounted


## Рисует изменяемые объекты, встречи, босса и награду Лунной поляны.
static func draw(game: Node2D) -> void:
	if game.current_location != "moon_glade": return
	var state: Dictionary = game.state.world.moon_glade
	if not state.flower_collected:
		game.EnvironmentVisualSystem.draw(game,"moon_flower",game.MoonGladeSystem.FLOWER_POSITION)
	game.EnvironmentVisualSystem.draw(game,"moon_crystal",game.EnvironmentVisualSystem.MOON_SOLID_BASES[0],Color("d9fbff") if state.crystal_charged else Color(0.62,0.65,0.82,0.72))
	for index in game.MoonGladeSystem.ECHO_POSITIONS.size():
		if not state.echoes[index] and state.crystal_charged:
			var pulse := 0.82 + sin(game.walk_animation_time * 3.0 + index) * 0.12
			game.EnvironmentVisualSystem.draw(game,"moon_echo",game.MoonGladeSystem.ECHO_POSITIONS[index],Color(0.72,0.82,1.0,pulse))
	game.EnvironmentVisualSystem.draw(game,"moon_altar",game.EnvironmentVisualSystem.MOON_SOLID_BASES[1],Color.WHITE if state.altar_activated else Color(0.66,0.66,0.78,0.72))
	if state.guardian_alive:
		draw_guardian(game, state)
	elif state.guardian_defeated:
		game.EnvironmentVisualSystem.draw(game,"moon_echo",game.MoonGladeSystem.GUARDIAN_POSITION,Color(0.83,0.91,1.0,0.34))
	game.EnvironmentVisualSystem.draw(game,"moon_chest",game.EnvironmentVisualSystem.MOON_SOLID_BASES[2],Color(0.46,0.50,0.62,0.52) if not state.guardian_defeated else (Color(0.72,0.72,0.78,0.55) if state.chest_opened else Color.WHITE))
	if state.chest_opened:
		game.EnvironmentVisualSystem.draw(game,"moon_stag",Vector2(2135,650),Color(0.88,0.94,1.0,0.76))


## Рисует Стража с пульсацией и полосой здоровья.
static func draw_guardian(game: Node2D, state: Dictionary) -> void:
	var position: Vector2 = game.MoonGladeSystem.GUARDIAN_POSITION
	if float(state.guardian_hurt_timer) > 0.0: position += Vector2.RIGHT * sin(float(state.guardian_hurt_timer) / 0.32 * PI) * 13.0
	var pulse := 1.0 + sin(game.walk_animation_time * 4.5) * 0.04
	if float(state.guardian_windup) > 0.0:
		var windup_progress := 1.0 - float(state.guardian_windup) / 0.48
		game.draw_circle(game.MoonGladeSystem.GUARDIAN_POSITION, game.MoonGladeSystem.GUARDIAN_ATTACK_RANGE, Color(0.42, 0.92, 1.0, 0.16 + windup_progress * 0.22), false, 5.0)
		pulse += windup_progress * 0.12
	game.EnvironmentVisualSystem.draw(game,"moon_guardian",position,Color("ff7676") if float(state.guardian_hurt_timer) > 0.0 else Color("eadfff"),pulse)
	var visual:Rect2=game.EnvironmentVisualSystem.visual_rect("moon_guardian",position,pulse); var bar:=Rect2(Vector2(position.x-52,visual.position.y-14),Vector2(104,9))
	game.draw_rect(bar, Color("251d38")); game.draw_rect(bar.grow(-2), Color("9d58ce"))
	game.draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * float(state.guardian_hp) / game.MoonGladeSystem.GUARDIAN_MAX_HP, bar.size.y - 4)), Color("7cf2e8"))
	game.draw_ui_string(game.UI_FONT,Vector2(position.x-80,bar.position.y-11),game.LocaleSystem.entity("eclipse_guardian"),HORIZONTAL_ALIGNMENT_CENTER,160,14,Color("f3eaff"))
