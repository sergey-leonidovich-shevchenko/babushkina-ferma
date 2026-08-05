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
	var state: Dictionary = game.get_meta("debug_playground"); var panel: Rect2 = game.DebugPlaygroundSystem.PANEL
	game.draw_rect(panel, Color(0.035,0.065,0.06,0.94)); game.draw_rect(panel, Color("d5a94d"), false, 3)
	var enemy: String = game.DebugPlaygroundSystem.ENEMIES[state.enemy_index]
	var lines := ["ПОЛИГОН ОТЛАДКИ", "FPS: %d · объектов: %d" % [Engine.get_frames_per_second(), game.enemy_nodes.size() + game.wildlife_nodes.size()], "Позиция: %d, %d · %s" % [game.player.x, game.player.y,"ПАУЗА" if state.paused else "RUN"], "День %d · %02d:%02d" % [game.day, int(game.game_minutes)/60, int(game.game_minutes)%60], "%s · %s" % [game.WorldEventSystem.season(game.day), game.WorldEventSystem.weather(game)], "Враг: %s · ур. %d" % [enemy, state.enemy_level], "Выбрано: %s" % state.selected, "F4 набор · F6 уровень · F7 анимация", "F8 телепорт · F9 квест · C коллизии", "PgUp/PgDn тип · I инспектор · F10 выход"]
	for index in lines.size(): game.draw_string(game.UI_FONT, panel.position + Vector2(20,34 + index * 21), lines[index], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 40, 15, Color("fff0c8") if index != 0 else Color("ffd36a"))
	draw_graph(game,state,Rect2(755,275,355,55))
	for button in game.DebugPlaygroundSystem.BUTTONS:
		game.draw_rect(button.rect,Color("3c6759")); game.draw_rect(button.rect,Color("d5a94d"),false,2); game.draw_string(game.UI_FONT,button.rect.position+Vector2(5,21),button.label,HORIZONTAL_ALIGNMENT_CENTER,button.rect.size.x-10,12,Color("fff0c8"))
	game.draw_string(game.UI_FONT,Vector2(755,520),"Последнее: %s" % state.command,HORIZONTAL_ALIGNMENT_LEFT,355,13,Color("ffd36a"))


## Рисует компактный график FPS за последние сто двадцать кадров.
static func draw_graph(game: Node2D, state: Dictionary, rect: Rect2) -> void:
	game.draw_rect(rect,Color("172824")); game.draw_line(rect.position+Vector2(0,rect.size.y*0.5),rect.position+Vector2(rect.size.x,rect.size.y*0.5),Color(0.7,0.8,0.6,0.22),1)
	var history: Array = state.get("frame_history", []); if history.size() < 2: return
	var points := PackedVector2Array()
	for index in history.size(): points.append(rect.position+Vector2(index*rect.size.x/119.0,rect.size.y-clampf(float(history[index]),0.0,120.0)*rect.size.y/120.0))
	game.draw_polyline(points,Color("82e6a5"),2)


## Рисует мировые хитбоксы, точки домов и маршруты ИИ поверх тестовой сцены.
static func draw_world_overlay(game: Node2D) -> void:
	if not game.DebugPlaygroundSystem.active(game): return
	var state: Dictionary = game.get_meta("debug_playground")
	if bool(state.routes):
		for enemy in game.enemy_nodes:
			if enemy.location == game.current_location: game.draw_line(enemy.home,enemy.position,Color(0.45,0.75,1.0,0.8),2); game.draw_line(enemy.position,enemy.action_target,Color(1.0,0.55,0.3,0.55),1)
		for animal in game.wildlife_nodes: game.draw_line(animal.home,animal.position,Color(0.75,0.8,0.35,0.55),1)
	if bool(state.hitboxes):
		game.draw_circle(game.player,game.PLAYER_RADIUS,Color("62e889"),false,3)
		for enemy in game.enemy_nodes:
			if enemy.location == game.current_location and enemy.alive: game.draw_circle(enemy.position,30,Color("ff605c"),false,3)
		for animal in game.wildlife_nodes: game.draw_circle(animal.position,24,Color("ffd45c"),false,2)
