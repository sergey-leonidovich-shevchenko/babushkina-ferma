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


## Усиливает различимость категорий сетки для включённого режима высокой контрастности.
static func accessible_reason_color(game: Node, reason: String) -> Color:
	if not game.settings_state.high_contrast: return reason_color(reason)
	if reason=="walkable": return Color("00ff70")
	if reason in ["water","ship"]: return Color("00b7ff")
	if reason in DYNAMIC_REASONS: return Color("ffe600")
	if reason in INTERIOR_REASONS: return Color("d878ff")
	return Color("ff2855")


## Возвращает короткое русское описание причины для инспектора клетки.
static func reason_label(reason: String) -> String:
	var labels := {
		"walkable":"проходимо", "water":"вода", "ship":"вне палубы", "boundary":"граница мира",
		"building":"здание", "biome_prop":"объект биома", "event_prop":"объект события",
		"cave_prop":"скала пещеры", "village_event":"объект события", "scenic_prop":"декорация",
		"tree":"дерево", "fence":"забор", "player_fence":"построенный забор", "world_prop":"объект мира", "enemy":"враг",
		"guardian":"страж", "hazard":"опасность", "resource":"ресурс", "loot":"контейнер",
		"forage":"растение", "interior":"стена помещения", "furniture":"мебель",
		"storage":"сундук", "debug_obstacle":"объект полигона",
		"tillable":"можно вспахать", "location_blocked":"локация запрещена", "paved_road":"каменная дорога", "bridge":"мост",
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
	game.DebugObjectInspectorRenderer.draw_world(game)


## Накладывает полупрозрачный цвет и контур на каждую видимую клетку навигации.
static func draw_grid(game: Node2D, state: Dictionary) -> void:
	var texture := grid_texture(game, state)
	var cache_rect := Rect2(state.get("cache_rect", Rect2()))
	if texture != null and cache_rect.has_area(): game.draw_texture_rect(texture,cache_rect,false)
	var lines:=grid_lines_texture(game,state)
	if lines!=null and cache_rect.has_area():
		var period:=float(lines.get_width()); var line_start:=Vector2(floorf(cache_rect.position.x/period)*period,floorf(cache_rect.position.y/period)*period)
		var line_end:=Vector2(ceilf(cache_rect.end.x/period)*period,ceilf(cache_rect.end.y/period)*period)
		game.draw_texture_rect(lines,Rect2(line_start,line_end-line_start),true)
	for key in state.get("dynamic_cells",[]):
		var cell:Dictionary=state.get("cache_cells",{}).get(key,{})
		if not cell.is_empty() and String(cell.reason)=="enemy":
			var color:=accessible_reason_color(game,"enemy"); color.a=float(state.opacity)
			game.draw_rect(cell.rect,color)


## Собирает цветные клетки в одну маленькую texture-карту и повторно использует её между кадрами.
static func grid_texture(game: Node2D, state: Dictionary) -> Texture2D:
	var columns := int(state.get("cache_columns",0)); var rows := int(state.get("cache_rows",0))
	if columns<=0 or rows<=0 or state.get("cache",[]).is_empty(): return null
	var signature := "%d|%.2f|%s|%s"%[int(state.get("cache_generation",0)),float(state.opacity),str(state.get("farming",false)),str(game.settings_state.high_contrast)]
	var cached: Texture2D = state.get("grid_texture")
	if cached!=null and String(state.get("grid_texture_signature",""))==signature: return cached
	var image:=Image.create(columns,rows,false,Image.FORMAT_RGBA8); var farming:=bool(state.get("farming",false)); var opacity:=float(state.opacity)
	var cells:Array=state.get("cache",[])
	for index in mini(cells.size(),columns*rows):
		var cell:Dictionary=cells[index]; var reason:=String(cell.get("farming_reason","location_blocked")) if farming else String(cell.reason)
		if reason=="enemy": reason="walkable"
		var color:=farming_reason_color(reason) if farming else accessible_reason_color(game,reason); color.a=opacity
		image.set_pixel(index%columns,index/columns,color)
	var texture:=ImageTexture.create_from_image(image)
	state.grid_texture=texture; state.grid_texture_signature=signature; game.set_meta(game.DebugOverlaySystem.META_KEY,state)
	return texture


## Создаёт повторяемую прозрачную текстуру тонкой сетки и усиленных блоков 48×48 без сотен draw-вызовов.
static func grid_lines_texture(game:Node2D,state:Dictionary)->Texture2D:
	var size:=int(state.grid_size); var opacity:=float(state.opacity); var signature:String="%d|%.2f"%[size,opacity]
	var cached:Texture2D=state.get("grid_lines_texture")
	if cached!=null and String(state.get("grid_lines_signature",""))==signature: return cached
	var period:int=game.SpatialGridSystem.BLOCK_CELL if size==game.SpatialGridSystem.BASE_CELL else size
	var image:=Image.create(period,period,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	var thin:=Color(0.92,1.0,0.95,minf(opacity+0.12,0.48)); var strong:=Color(0.86,1.0,0.91,minf(opacity+0.20,0.58))
	for coordinate in period:
		image.set_pixel(coordinate,0,strong); image.set_pixel(0,coordinate,strong)
	if size==game.SpatialGridSystem.BASE_CELL:
		for coordinate in period:
			image.set_pixel(coordinate,size,thin); image.set_pixel(size,coordinate,thin)
	var texture:=ImageTexture.create_from_image(image); state.grid_lines_texture=texture; state.grid_lines_signature=signature; game.set_meta(game.DebugOverlaySystem.META_KEY,state)
	return texture


## Выбирает цвет режима пахотности: зелёный для земли, красный для запрета и синий для воды.
static func farming_reason_color(reason: String) -> Color:
	if reason == "tillable" or reason == "legacy_plot": return WALKABLE
	if reason in ["water", "bridge", "ship"]: return WATER
	return STATIC_BLOCKED


## Показывает точные известные окружности и прямоугольники физических объектов.
static func draw_hitboxes(game: Node2D) -> void:
	game.draw_circle(game.player, game.PLAYER_RADIUS, WALKABLE, false, 3.0)
	for building_id in game.BuildingSystem.buildings_at(game.current_location):
		for solid in game.BuildingSystem.collision_rects(building_id): game.draw_rect(solid,STATIC_BLOCKED,false,3.0)
		game.draw_rect(game.BuildingSystem.door_rect(building_id),WALKABLE if game.BuildingSystem.can_enter(game,building_id) else STATIC_BLOCKED,false,3.0)
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
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(4,15), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 11, Color.WHITE)


## Рисует экранную панель, легенду, инспектор курсора, кнопки и график FPS.
static func draw_panel(game: Node2D) -> void:
	if not game.DebugOverlaySystem.active(game): return
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	var panel: Rect2 = game.DebugOverlaySystem.PANEL
	game.DebugUiKitSystem.draw_panel(game,panel)
	game.draw_ui_string(game.UI_FONT, panel.position + Vector2(18,31), "DEBUG УРОВНЯ · F10", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 19, Color("caffdf"))
	var pointer: Vector2 = game.get_meta("debug_inspector_cursor",game.get_local_mouse_position())
	var target: Dictionary = game.DebugObjectInspectorSystem.hovered_object(game,pointer)
	if not target.is_empty():
		game.DebugObjectInspectorRenderer.draw_info(game,panel,target)
		draw_lower_panel(game,state,panel)
		game.DebugMissionRenderer.draw(game)
		if bool(state.get("balance", false)): draw_balance(game)
		return
	var tile: Dictionary = game.DebugOverlaySystem.inspect_screen_point(game,pointer)
	var status := "ПАУЗА" if state.paused else "RUN"
	var lines := [
		"FPS %d · %s · %s" % [Engine.get_frames_per_second(), game.current_location, status],
		"Герой: %.0f, %.0f · радиус %.0f" % [game.player.x, game.player.y, game.PLAYER_RADIUS],
		"Курсор: %.0f, %.0f · тайл %d×%d" % [tile.center.x, tile.center.y, int(state.grid_size), int(state.grid_size)],
		"Результат: %s" % reason_label(tile.reason),
		"Пахотность: %s" % reason_label(String(tile.get("farming_reason", "нет данных"))),
	]
	for index in lines.size(): game.draw_ui_string(game.UI_FONT, panel.position + Vector2(18,61 + index*20), lines[index], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 13, Color("e9fff3"))
	draw_legend(game, panel.position + Vector2(18,151), float(state.opacity))
	draw_lower_panel(game,state,panel)
	game.DebugMissionRenderer.draw(game)
	if bool(state.get("balance", false)): draw_balance(game)


## Рисует общие кнопки, график и подсказки ниже взаимозаменяемых INFO/навигационных данных.
static func draw_lower_panel(game: Node2D, state: Dictionary, panel: Rect2) -> void:
	for button in game.DebugOverlaySystem.BUTTONS: draw_button(game, button, state)
	game.draw_ui_string(game.UI_FONT, panel.position + Vector2(18,500), "СЕРЫЕ ИНСТРУМЕНТЫ — В РАЗРАБОТКЕ", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 10, Color("81958d"))
	draw_graph(game, state, Rect2(panel.position + Vector2(20,512), Vector2(320,40)))
	game.draw_ui_string(game.UI_FONT, panel.position + Vector2(18,572), "G сетка · H хитбоксы · P пути · L подписи", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 10, Color("a9d9c2"))
	game.draw_ui_string(game.UI_FONT, panel.position + Vector2(18,590), "V noclip · Space пауза · . шаг · -/+ яркость", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 10, Color("a9d9c2"))


## Рисует отдельную карточку живого баланса поверх локации по запросу тестировщика.
static func draw_balance(game: Node2D) -> void:
	var rect := Rect2(24, 78, 410, 252)
	game.DebugUiKitSystem.draw_panel(game,rect)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(18,32), "БАЛАНС · ТЕКУЩИЙ БИЛД", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x-36, 17, Color("caffdf"))
	var lines: Array[String] = game.DebugBalanceSystem.lines(game)
	for index in lines.size(): game.draw_ui_string(game.UI_FONT, rect.position + Vector2(18,64+index*25), lines[index], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x-36, 13, Color("e9fff3"))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(18,226), "Источники XP: посадка 1 · урожай 3 · крафт 4 · ловушка 8", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x-36, 10, Color("91b3a4"))


## Рисует четыре категории клеток с одинаковой прозрачностью текущего режима.
static func draw_legend(game: Node2D, origin: Vector2, opacity: float) -> void:
	var entries := [[WALKABLE,"проход"],[WATER,"вода"],[STATIC_BLOCKED,"статич."],[DYNAMIC_BLOCKED,"динамич."],[INTERIOR_BLOCKED,"интерьер"]]
	for index in entries.size():
		var x := origin.x + (index % 3) * 106; var y := origin.y + (index / 3) * 25
		var color: Color = entries[index][0]; color.a = maxf(opacity,0.5)
		game.draw_rect(Rect2(x,y,15,15),color); game.draw_ui_string(game.UI_FONT,Vector2(x+21,y+13),entries[index][1],HORIZONTAL_ALIGNMENT_LEFT,82,11,Color("e9fff3"))


## Рисует кнопку панели и выделяет включённые логические режимы.
static func draw_button(game: Node2D, button: Dictionary, state: Dictionary) -> void:
	var enabled := bool(button.get("enabled", true))
	var action := String(button.action); var state_key := "paused" if action == "pause" else action
	var active := bool(state.get(state_key, false)) if state.has(state_key) else false
	var label := String(button.label)
	if action == "grid_size": label = "СЕТКА %d px" % int(state.grid_size)
	game.DebugUiKitSystem.draw_button(game,button.rect,label,active,enabled)


## Рисует историю FPS последних девяноста кадров с ориентиром шестидесяти кадров.
static func draw_graph(game: Node2D, state: Dictionary, rect: Rect2) -> void:
	game.DebugUiKitSystem.draw_readout(game,rect); game.draw_line(rect.position + Vector2(0,rect.size.y*0.5), rect.position + Vector2(rect.size.x,rect.size.y*0.5), Color(0.6,0.9,0.7,0.22), 1.0)
	var history: Array = state.get("frame_history", []); if history.size() < 2: return
	var points := PackedVector2Array()
	for index in history.size(): points.append(rect.position + Vector2(index * rect.size.x / 89.0, rect.size.y - clampf(float(history[index]),0.0,120.0) * rect.size.y / 120.0))
	game.draw_polyline(points, Color("62e89b"), 2.0)
