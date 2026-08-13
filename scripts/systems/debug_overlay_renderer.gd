extends RefCounted

const WALKABLE := Color("45df78")
const WATER := Color("3da9ff")
const STATIC_BLOCKED := Color("ee5360")
const DYNAMIC_BLOCKED := Color("ffad3d")
const INTERIOR_BLOCKED := Color("b679ff")
const PANEL_FILL := Color(0.025, 0.045, 0.05, 0.96)
const PANEL_BORDER := Color("78e2b1")
const DYNAMIC_REASONS := ["enemy", "guardian", "hazard", "resource", "loot", "forage", "village_event"]
const INTERIOR_REASONS := ["interior", "furniture", "storage"]


## Выбирает цвет клетки по категории реальной причины блокировки.
static func reason_color(reason: String) -> Color:
	if reason == "walkable": return WALKABLE
	if reason in ["water", "ship"]: return WATER
	if reason in DYNAMIC_REASONS: return DYNAMIC_BLOCKED
	if reason in INTERIOR_REASONS: return INTERIOR_BLOCKED
	return STATIC_BLOCKED


## Возвращает короткое русское описание причины для инспектора клетки.
static func reason_label(reason: String) -> String:
	var labels := {
		"walkable":"проходимо", "water":"вода", "ship":"вне палубы", "boundary":"граница мира",
		"building":"здание", "biome_prop":"объект биома", "event_prop":"объект события",
		"cave_prop":"скала пещеры", "village_event":"объект события", "scenic_prop":"декорация",
		"tree":"дерево", "fence":"забор", "world_prop":"объект мира", "enemy":"враг",
		"guardian":"страж", "hazard":"опасность", "resource":"ресурс", "loot":"контейнер",
		"forage":"растение", "interior":"стена помещения", "furniture":"мебель",
		"storage":"сундук", "debug_obstacle":"объект полигона",
	}
	return labels.get(reason, reason)


## Рисует кэшированную цветную сетку, точные хитбоксы, маршруты и подписи поверх мира.
static func draw_world(game: Node2D) -> void:
	if not game.DebugOverlaySystem.active(game): return
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	if bool(state.grid): draw_grid(game, state)
	if bool(state.routes): draw_routes(game)
	if bool(state.hitboxes): draw_hitboxes(game)
	if bool(state.labels): draw_labels(game)


## Накладывает полупрозрачный цвет и контур на каждую видимую клетку навигации.
static func draw_grid(game: Node2D, state: Dictionary) -> void:
	var opacity := float(state.opacity)
	var size := int(state.grid_size)
	for cell in state.get("cache", []):
		var color := reason_color(String(cell.reason)); color.a = opacity
		game.draw_rect(cell.rect, color)
		game.draw_rect(cell.rect, Color(color.r, color.g, color.b, minf(opacity + 0.18, 0.72)), false, 1.0)
	# Утолщённый контур объединяет четыре базовые клетки 24×24 в читаемый модуль 48×48.
	if size == game.SpatialGridSystem.BASE_CELL:
		var block: int = game.SpatialGridSystem.BLOCK_CELL
		var start_x: int = floori(game.camera_offset.x / block) * block
		var start_y: int = floori(game.camera_offset.y / block) * block
		var end_x: int = ceili((game.camera_offset.x + 1152.0) / block) * block
		var end_y: int = ceili((game.camera_offset.y + 648.0) / block) * block
		for y in range(start_y, end_y, block):
			for x in range(start_x, end_x, block):
				game.draw_rect(Rect2(x, y, block, block), Color(0.86, 1.0, 0.91, 0.34), false, 1.6)


## Показывает точные известные окружности и прямоугольники физических объектов.
static func draw_hitboxes(game: Node2D) -> void:
	game.draw_circle(game.player, game.PLAYER_RADIUS, WALKABLE, false, 3.0)
	for building_id in game.BuildingSystem.buildings_at(game.current_location):
		game.draw_rect(game.BuildingSystem.collision_rect(building_id), STATIC_BLOCKED, false, 3.0)
	for enemy in game.enemy_nodes:
		if enemy.alive and enemy.location == game.current_location: game.draw_circle(enemy.position, 30.0, DYNAMIC_BLOCKED, false, 3.0)
	for hazard in game.hazard_nodes:
		if hazard.location == game.current_location: game.draw_circle(hazard.position, 30.0, DYNAMIC_BLOCKED, false, 2.0)
	for node in game.resource_nodes:
		if node.hits > 0 and node.location == game.current_location: game.draw_circle(node.position, 30.0, Color("78d7ff"), false, 2.0)
	for tree in game.state.world.tree_nodes:
		if game.TreeSystem.is_solid(tree): game.draw_circle(tree.position + Vector2(0,35), 42.0, STATIC_BLOCKED, false, 2.0)


## Соединяет дома и цели мобильных существ линиями фактических runtime-маршрутов.
static func draw_routes(game: Node2D) -> void:
	for enemy in game.enemy_nodes:
		if enemy.alive and enemy.location == game.current_location:
			game.draw_line(enemy.home, enemy.position, Color(0.35,0.78,1.0,0.85), 2.0)
			game.draw_line(enemy.position, enemy.get("action_target", enemy.position), Color(1.0,0.55,0.25,0.75), 1.5)
	for animal in game.wildlife_nodes:
		if animal.get("location", "overworld") == game.current_location: game.draw_line(animal.home, animal.position, Color(0.85,0.90,0.35,0.72), 1.5)


## Подписывает тип и координаты ближайших динамических объектов без изменения их состояния.
static func draw_labels(game: Node2D) -> void:
	for enemy in game.enemy_nodes:
		if enemy.alive and enemy.location == game.current_location: draw_object_label(game, enemy.position, "%s L%d" % [enemy.kind, enemy.level])
	for node in game.resource_nodes:
		if node.hits > 0 and node.location == game.current_location: draw_object_label(game, node.position, String(node.kind))
	for animal in game.wildlife_nodes:
		if animal.get("location", "overworld") == game.current_location: draw_object_label(game, animal.position, String(animal.kind))


## Рисует одну компактную подпись объекта на контрастной плашке.
static func draw_object_label(game: Node2D, position: Vector2, text: String) -> void:
	var rect := Rect2(position + Vector2(-55,-68), Vector2(110,20))
	game.draw_rect(rect, Color(0.01,0.02,0.02,0.82))
	game.draw_string(game.UI_FONT, rect.position + Vector2(4,15), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 11, Color.WHITE)


## Рисует экранную панель, легенду, инспектор курсора, кнопки и график FPS.
static func draw_panel(game: Node2D) -> void:
	if not game.DebugOverlaySystem.active(game): return
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	var panel: Rect2 = game.DebugOverlaySystem.PANEL
	game.draw_rect(panel, PANEL_FILL); game.draw_rect(panel, PANEL_BORDER, false, 3.0)
	game.draw_string(game.UI_FONT, panel.position + Vector2(18,31), "DEBUG УРОВНЯ · F10", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 19, Color("caffdf"))
	var tile: Dictionary = game.DebugOverlaySystem.inspect_screen_point(game, game.get_local_mouse_position())
	var status := "ПАУЗА" if state.paused else "RUN"
	var lines := [
		"FPS %d · %s · %s" % [Engine.get_frames_per_second(), game.current_location, status],
		"Герой: %.0f, %.0f · радиус %.0f" % [game.player.x, game.player.y, game.PLAYER_RADIUS],
		"Курсор: %.0f, %.0f · тайл %d×%d" % [tile.center.x, tile.center.y, int(state.grid_size), int(state.grid_size)],
		"Результат: %s" % reason_label(tile.reason),
	]
	for index in lines.size(): game.draw_string(game.UI_FONT, panel.position + Vector2(18,61 + index*20), lines[index], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 13, Color("e9fff3"))
	draw_legend(game, panel.position + Vector2(18,151), float(state.opacity))
	for button in game.DebugOverlaySystem.BUTTONS: draw_button(game, button, state)
	game.draw_string(game.UI_FONT, panel.position + Vector2(18,386), "СЕРЫЕ ИНСТРУМЕНТЫ — В РАЗРАБОТКЕ", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 10, Color("81958d"))
	draw_graph(game, state, Rect2(panel.position + Vector2(20,466), Vector2(320,46)))
	game.draw_string(game.UI_FONT, panel.position + Vector2(18,548), "G сетка · H хитбоксы · P пути · L подписи", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 12, Color("a9d9c2"))
	game.draw_string(game.UI_FONT, panel.position + Vector2(18,568), "V noclip · Space пауза · . шаг · -/+ яркость", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 12, Color("a9d9c2"))


## Рисует четыре категории клеток с одинаковой прозрачностью текущего режима.
static func draw_legend(game: Node2D, origin: Vector2, opacity: float) -> void:
	var entries := [[WALKABLE,"проход"],[WATER,"вода"],[STATIC_BLOCKED,"статич."],[DYNAMIC_BLOCKED,"динамич."],[INTERIOR_BLOCKED,"интерьер"]]
	for index in entries.size():
		var x := origin.x + (index % 3) * 106; var y := origin.y + (index / 3) * 25
		var color: Color = entries[index][0]; color.a = maxf(opacity,0.5)
		game.draw_rect(Rect2(x,y,15,15),color); game.draw_string(game.UI_FONT,Vector2(x+21,y+13),entries[index][1],HORIZONTAL_ALIGNMENT_LEFT,82,11,Color("e9fff3"))


## Рисует кнопку панели и выделяет включённые логические режимы.
static func draw_button(game: Node2D, button: Dictionary, state: Dictionary) -> void:
	var enabled := bool(button.get("enabled", true))
	var action := String(button.action); var state_key := "paused" if action == "pause" else action
	var active := bool(state.get(state_key, false)) if state.has(state_key) else false
	var fill := Color("287856") if active else (Color("263f3a") if enabled else Color("1c2926"))
	var border := PANEL_BORDER if active else (Color("6f9585") if enabled else Color("45534e"))
	game.draw_rect(button.rect, fill); game.draw_rect(button.rect, border, false, 2.0)
	var label := String(button.label)
	if action == "grid_size": label = "СЕТКА %d px" % int(state.grid_size)
	game.draw_string(game.UI_FONT, button.rect.position + Vector2(5,19), label, HORIZONTAL_ALIGNMENT_CENTER, button.rect.size.x - 10, 10, Color.WHITE if enabled else Color("71817b"))


## Рисует историю FPS последних девяноста кадров с ориентиром шестидесяти кадров.
static func draw_graph(game: Node2D, state: Dictionary, rect: Rect2) -> void:
	game.draw_rect(rect, Color("102823")); game.draw_line(rect.position + Vector2(0,rect.size.y*0.5), rect.position + Vector2(rect.size.x,rect.size.y*0.5), Color(0.6,0.9,0.7,0.22), 1.0)
	var history: Array = state.get("frame_history", []); if history.size() < 2: return
	var points := PackedVector2Array()
	for index in history.size(): points.append(rect.position + Vector2(index * rect.size.x / 89.0, rect.size.y - clampf(float(history[index]),0.0,120.0) * rect.size.y / 120.0))
	game.draw_polyline(points, Color("62e89b"), 2.0)
