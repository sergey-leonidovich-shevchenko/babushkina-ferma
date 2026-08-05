extends RefCounted

## Рисует контрастный измерительный пол, тестовые препятствия и водоём полигона.
static func draw_background(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.WORLD_SIZE), Color("263b37"))
	for x in range(0, int(canvas.WORLD_SIZE.x), 64): canvas.draw_line(Vector2(x,0), Vector2(x,canvas.WORLD_SIZE.y), Color(0.48,0.67,0.58,0.12), 1)
	for y in range(0, int(canvas.WORLD_SIZE.y), 64): canvas.draw_line(Vector2(0,y), Vector2(canvas.WORLD_SIZE.x,y), Color(0.48,0.67,0.58,0.12), 1)
	for rect in canvas.DebugPlaygroundSystem.OBSTACLES: canvas.draw_rect(rect, Color("6d5543")); canvas.draw_rect(rect, Color("e8bf72"), false, 4)
	canvas.draw_circle(canvas.DebugPlaygroundSystem.WATER_CENTER, canvas.DebugPlaygroundSystem.WATER_RADIUS, Color("367f9b")); canvas.draw_circle(canvas.DebugPlaygroundSystem.WATER_CENTER, canvas.DebugPlaygroundSystem.WATER_RADIUS, Color("9fd5d3"), false, 5)
	canvas.draw_string(canvas.UI_FONT, Vector2(70,140), "DEBUG PLAYGROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("ffe39b"))


## Рисует поверх HUD список команд и живые показатели производительности и состояния.
static func draw_overlay(game: Node2D) -> void:
	if not game.DebugPlaygroundSystem.active(game): return
	var state: Dictionary = game.get_meta("debug_playground"); var panel := Rect2(735,72,395,500)
	game.draw_rect(panel, Color(0.035,0.065,0.06,0.94)); game.draw_rect(panel, Color("d5a94d"), false, 3)
	var enemy: String = game.DebugPlaygroundSystem.ENEMIES[state.enemy_index]
	var lines := ["ПОЛИГОН ОТЛАДКИ", "FPS: %d · объектов: %d" % [Engine.get_frames_per_second(), game.enemy_nodes.size() + game.wildlife_nodes.size()], "Позиция: %d, %d" % [game.player.x, game.player.y], "День %d · %02d:%02d" % [game.day, int(game.game_minutes)/60, int(game.game_minutes)%60], "%s · %s" % [game.WorldEventSystem.season(game.day), game.WorldEventSystem.weather(game)], "Враг: %s · ур. %d" % [enemy, state.enemy_level], "Коллизии: %s" % ("ВКЛ" if state.collision else "ВЫКЛ"), "", "F1  время +1 час", "F2  следующая погода", "F3  следующий сезон", "F4  выдать все предметы", "F5  создать выбранного врага", "F6  изменить уровень врага", "PgUp/PgDn  семейство врага", "F7  анимации животных", "F8  телепорт по зонам", "F9  состояние квеста", "C    коллизии", "F10  вернуться в игру", "", "Последнее: %s" % state.command]
	for index in lines.size(): game.draw_string(game.UI_FONT, panel.position + Vector2(20,34 + index * 21), lines[index], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 40, 15, Color("fff0c8") if index != 0 else Color("ffd36a"))
