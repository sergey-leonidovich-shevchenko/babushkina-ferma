extends RefCounted


## Рисует изменяемые объекты, встречи, босса и награду Лунной поляны.
static func draw(game: Node2D) -> void:
	if game.current_location != "moon_glade": return
	var state: Dictionary = game.state.world.moon_glade
	if not state.flower_collected:
		draw_event_sprite(game, 1, false, game.MoonGladeSystem.FLOWER_POSITION, Vector2(108, 108))
	draw_event_sprite(game, 2, false, game.MoonGladeSystem.CRYSTAL_POSITION, Vector2(138, 138), Color("d9fbff") if state.crystal_charged else Color(0.62, 0.65, 0.82, 0.72))
	for index in game.MoonGladeSystem.ECHO_POSITIONS.size():
		if not state.echoes[index] and state.crystal_charged:
			var pulse := 0.82 + sin(game.walk_animation_time * 3.0 + index) * 0.12
			draw_event_sprite(game, 0, true, game.MoonGladeSystem.ECHO_POSITIONS[index], Vector2(92, 104), Color(0.72, 0.82, 1.0, pulse))
	draw_event_sprite(game, 3, false, game.MoonGladeSystem.ALTAR_POSITION, Vector2(150, 150), Color.WHITE if state.altar_activated else Color(0.66, 0.66, 0.78, 0.72))
	if state.guardian_alive:
		draw_guardian(game, state)
	elif state.guardian_defeated:
		draw_event_sprite(game, 0, true, game.MoonGladeSystem.GUARDIAN_POSITION, Vector2(104, 108), Color(0.83, 0.91, 1.0, 0.34))
	draw_event_sprite(game, 3, true, game.MoonGladeSystem.CHEST_POSITION, Vector2(124, 112), Color(0.46, 0.50, 0.62, 0.52) if not state.guardian_defeated else (Color(0.72, 0.72, 0.78, 0.55) if state.chest_opened else Color.WHITE))
	if state.chest_opened:
		draw_event_sprite(game, 2, true, Vector2(2135, 650), Vector2(118, 116), Color(0.88, 0.94, 1.0, 0.76))


## Рисует Стража с пульсацией и полосой здоровья.
static func draw_guardian(game: Node2D, state: Dictionary) -> void:
	var position: Vector2 = game.MoonGladeSystem.GUARDIAN_POSITION
	var pulse := 1.0 + sin(game.walk_animation_time * 4.5) * 0.04
	var size := Vector2(138, 148) * pulse
	draw_event_sprite(game, 1, true, position, size, Color("eadfff"))
	var bar := Rect2(position + Vector2(-52, -94), Vector2(104, 9))
	game.draw_rect(bar, Color("251d38")); game.draw_rect(bar.grow(-2), Color("9d58ce"))
	game.draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * float(state.guardian_hp) / game.MoonGladeSystem.GUARDIAN_MAX_HP, bar.size.y - 4)), Color("7cf2e8"))
	game.draw_string(game.UI_FONT, position + Vector2(-80, -105), game.LocaleSystem.entity("eclipse_guardian"), HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color("f3eaff"))


## Рисует одну ячейку событийного атласа с точкой опоры у нижней границы.
static func draw_event_sprite(game: Node2D, column: int, bottom_row: bool, position: Vector2, size: Vector2, tint: Color = Color.WHITE) -> void:
	var rect := Rect2(position - Vector2(size.x * 0.5, size.y * 0.78), size)
	game.draw_texture_rect_region(game.VisualAssetSystem.ECLIPSE_ATLAS, rect, game.VisualAssetSystem.eclipse_source(column, bottom_row), tint)
