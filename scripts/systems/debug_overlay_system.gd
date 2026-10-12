extends RefCounted

const META_KEY := "debug_overlay"
const SpatialGridSystem := preload("res://scripts/systems/spatial_grid_system.gd")
const GridBuildSystem := preload("res://scripts/systems/debug_grid_build_system.gd")
const DynamicGridSystem := preload("res://scripts/systems/debug_dynamic_grid_system.gd")
const GRID_SIZES := SpatialGridSystem.DEBUG_SIZES
const REFRESH_INTERVAL := 0.20
const VIEWPORT_SIZE := Vector2(1152, 648)
const CACHE_MARGIN_CELLS := 6
const INSPECT_CACHE_META := "debug_navigation_inspect_cache"
const INSPECT_REFRESH_MSEC := 100
const PANEL := Rect2(774, 26, 360, 596)
const BUTTONS := [
	{"rect":Rect2(794,246,150,34),"action":"grid","label":"СЕТКА","enabled":true},
	{"rect":Rect2(964,246,150,34),"action":"hitboxes","label":"ХИТБОКСЫ","enabled":true},
	{"rect":Rect2(794,284,150,34),"action":"routes","label":"МАРШРУТЫ","enabled":true},
	{"rect":Rect2(964,284,150,34),"action":"labels","label":"ПОДПИСИ","enabled":true},
	{"rect":Rect2(794,322,150,34),"action":"pause","label":"ПАУЗА","enabled":true},
	{"rect":Rect2(964,322,150,34),"action":"step","label":"ШАГ КАДРА","enabled":true},
	{"rect":Rect2(794,360,150,34),"action":"noclip","label":"NOCLIP","enabled":true},
	{"rect":Rect2(964,360,150,34),"action":"grid_size","label":"РАЗМЕР СЕТКИ","enabled":true},
	{"rect":Rect2(794,398,150,34),"action":"opacity_down","label":"ПРОЗРАЧНЕЕ","enabled":true},
	{"rect":Rect2(964,398,150,34),"action":"opacity_up","label":"ЯРЧЕ","enabled":true},
	{"rect":Rect2(794,436,150,34),"action":"farming","label":"ПАХОТНАЯ ЗЕМЛЯ","enabled":true},
	{"rect":Rect2(964,436,150,34),"action":"level_editor","label":"КОНСТРУКТОР","enabled":true},
	{"rect":Rect2(794,474,150,34),"action":"balance","label":"БАЛАНС","enabled":true},
	{"rect":Rect2(964,474,150,34),"action":"save_patch","label":"СОХРАНИТЬ ПАТЧ","enabled":false},
]


## Создаёт исходное состояние панели, не добавляемое в сохранение игры.
static func default_state() -> Dictionary:
	return {
		"open":true, "grid":true, "hitboxes":false, "routes":false, "labels":false, "farming":false, "balance":false,
		"paused":false, "step_requested":false, "noclip":false, "grid_size":SpatialGridSystem.DEFAULT_DEBUG_SIZE,
		"opacity":0.22, "refresh_left":0.0, "cache":[], "counts":{},
		"cache_location":"", "cache_camera":Vector2(-9999,-9999), "cache_rect":Rect2(), "cache_columns":0, "cache_rows":0,
		"cache_generation":0, "cache_cells":{}, "cache_grid_size":0, "cache_farming":false, "cache_invalidated":true, "grid_build":{},
		"dynamic_cells":[], "dynamic_build":{}, "grid_texture":null, "grid_texture_signature":"", "grid_lines_texture":null, "grid_lines_signature":"", "frame_history":[],
		"missions_expanded":false, "mission_page":0, "mission_details":"", "mission_completion":{},
	}


## Проверяет, открыта ли диагностическая панель поверх текущей игровой локации.
static func active(game: Node) -> bool:
	return bool(game.get_meta(META_KEY, {}).get("open", false))


## Открывает или закрывает панель F10/F11, сохраняя выбранные диагностические слои.
static func toggle(game: Node) -> void:
	var state: Dictionary = game.get_meta(META_KEY, default_state())
	state.open = not bool(state.get("open", false)) if game.has_meta(META_KEY) else true
	state.refresh_left = 0.0; state.cache_invalidated = true
	game.set_meta(META_KEY, state)
	if state.open: refresh_grid(game)
	game.message = "DEBUG: F10 — закрыть" if state.open else "Debug-панель закрыта"
	game.queue_redraw()


## Обновляет график FPS и кэш видимой навигационной сетки с ограниченной частотой.
static func update(game: Node, delta: float, render_frame: int = -1) -> void:
	if not active(game): return
	var state: Dictionary = game.get_meta(META_KEY)
	state.refresh_left = float(state.get("refresh_left", 0.0)) - delta
	# Физический catch-up не получает повторный бюджет сетки за каждый тик одного медленного render-кадра.
	# Офлайн-расчёт допускает явный frame-clock либо последовательное завершение вне дерева.
	var frame := render_frame
	if frame < 0 and game.is_inside_tree(): frame = Engine.get_process_frames()
	if frame >= 0 and not claim_render_frame_budget(state, frame):
		game.set_meta(META_KEY, state)
		return
	var history: Array = state.get("frame_history", [])
	history.append(clampf(Engine.get_frames_per_second(), 0.0, 120.0))
	if history.size() > 90: history.pop_front()
	state.frame_history = history
	if bool(state.grid) and GridBuildSystem.pending_is_current(game, state):
		game.set_meta(META_KEY, state)
		GridBuildSystem.advance(game)
		return
	var cached_rect := Rect2(state.get("cache_rect", Rect2()))
	var visible_rect := Rect2(Vector2(game.camera_offset), VIEWPORT_SIZE)
	var camera_changed := not cached_rect.has_area() or not cached_rect.grow(-int(state.grid_size)*2).encloses(visible_rect)
	if bool(state.grid) and (bool(state.get("cache_invalidated",false)) or state.cache_location != game.current_location or camera_changed):
		game.set_meta(META_KEY, state)
		refresh_grid(game)
		return
	if bool(state.grid) and not state.get("dynamic_build", {}).is_empty():
		game.set_meta(META_KEY, state); DynamicGridSystem.advance(game); return
	if bool(state.grid) and state.refresh_left<=0.0:
		game.set_meta(META_KEY,state); refresh_dynamic_cells(game); return
	game.set_meta(META_KEY, state)


## Разрешает единственный пакет F10 за render-кадр, не умножая его бюджет физическим догоняющим циклом.
static func claim_render_frame_budget(state: Dictionary, frame: int) -> bool:
	if int(state.get("last_grid_render_frame", -1)) == frame: return false
	state.last_grid_render_frame = frame
	return true


## Ставит видимую область в очередь и рассчитывает первый небольшой пакет без остановки игры.
static func refresh_grid(game: Node) -> void:
	if not active(game): return
	var state: Dictionary = game.get_meta(META_KEY)
	var size := int(state.get("grid_size", 50))
	var margin := size * CACHE_MARGIN_CELLS
	var start_x := floori(game.camera_offset.x / size) * size - margin
	var start_y := floori(game.camera_offset.y / size) * size - margin
	var end_x := ceili((game.camera_offset.x + VIEWPORT_SIZE.x) / size) * size + margin
	var end_y := ceili((game.camera_offset.y + VIEWPORT_SIZE.y) / size) * size + margin
	var include_farming := bool(state.get("farming", false))
	GridBuildSystem.begin(game, state, Rect2(start_x,start_y,end_x-start_x,end_y-start_y), size, include_farming)
	GridBuildSystem.advance(game)


## Классифицирует одну новую клетку, не рассчитывая пахотность для обычного навигационного режима.
static func classify_cell(game:Node,x:int,y:int,size:int,include_farming:bool)->Dictionary:
	var center:=Vector2(x+size*0.5,y+size*0.5); var reason:String=game.NavigationSystem.walkability_reason(game,center); var farming_reason:=""
	if include_farming:
		farming_reason=game.WorldFarmingSystem.tillability_reason(game,game.current_location,game.WorldFarmingSystem.cell_at(center))
	return {"rect":Rect2(x,y,size,size),"reason":reason,"farming_reason":farming_reason}


## Запускает ограниченный пакет клеток вокруг врагов, не блокируя кадр полным периодическим пересчётом.
static func refresh_dynamic_cells(game:Node)->void:
	if not active(game): return
	var state: Dictionary = game.get_meta(META_KEY)
	if not DynamicGridSystem.is_current(game, state): DynamicGridSystem.begin(game, state)
	DynamicGridSystem.advance(game)


## Возвращает небольшой набор клеток вокруг текущих позиций подвижных противников.
static func dynamic_cells(game:Node,size:int)->Array[Vector2i]:
	var result:Array[Vector2i]=[]; var positions:Array[Vector2]=[]
	if game.current_location=="overworld" and game.slime_alive: positions.append(game.slime_position)
	for enemy in game.enemy_nodes:
		if enemy.alive and enemy.location==game.current_location: positions.append(enemy.position)
	for position in positions:
		var origin:=Vector2i(floori(position.x/size)*size,floori(position.y/size)*size)
		for offset_y in range(-2,3):
			for offset_x in range(-2,3):
				var key:=origin+Vector2i(offset_x*size,offset_y*size)
				if key not in result: result.append(key)
	return result


## Перехватывает только команды панели, не заменяя управление игрой при закрытом окне.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F10, KEY_F11]:
		toggle(game); return true
	if not active(game): return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game.DebugMissionSystem.handle_pointer(game, event.position): return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and PANEL.has_point(event.position):
		return handle_pointer(game, event.position)
	if not (event is InputEventKey and event.pressed and not event.echo): return false
	match event.keycode:
		KEY_G: toggle_option(game, "grid")
		KEY_H: toggle_option(game, "hitboxes")
		KEY_P: toggle_option(game, "routes")
		KEY_L: toggle_option(game, "labels")
		KEY_V: toggle_option(game, "noclip")
		KEY_SPACE: toggle_option(game, "paused")
		KEY_PERIOD: request_step(game)
		KEY_MINUS: change_opacity(game, -0.08)
		KEY_EQUAL: change_opacity(game, 0.08)
		_: return false
	game.queue_redraw(); return true


## Выполняет команду кнопки, по которой тестер щёлкнул внутри панели.
static func handle_pointer(game: Node, point: Vector2) -> bool:
	for button in BUTTONS:
		if not button.rect.has_point(point): continue
		if not bool(button.get("enabled", true)): return true
		match String(button.action):
			"grid", "hitboxes", "routes", "labels", "noclip", "farming", "balance": toggle_option(game, button.action)
			"level_editor": game.LevelEditorSystem.toggle(game)
			"pause": toggle_option(game, "paused")
			"step": request_step(game)
			"grid_size": cycle_grid_size(game)
			"opacity_down": change_opacity(game, -0.08)
			"opacity_up": change_opacity(game, 0.08)
		game.queue_redraw(); return true
	return true


## Сообщает интерфейсу и тестам, доступна ли команда для изменения прямо сейчас.
static func button_enabled(action: String) -> bool:
	for button in BUTTONS:
		if String(button.action) == action: return bool(button.get("enabled", true))
	return false


## Переключает один булев диагностический слой и немедленно инвалидирует сетку.
static func toggle_option(game: Node, key: String) -> void:
	var state: Dictionary = game.get_meta(META_KEY)
	state[key] = not bool(state.get(key, false)); state.refresh_left = 0.0
	if key in ["farming", "grid"]:
		state.cache_invalidated=true; state.grid_texture = null; state.grid_texture_signature = ""
	game.set_meta(META_KEY, state)


## Переключает размер проверяемой клетки между детальным, игровым и обзорным режимами.
static func cycle_grid_size(game: Node) -> void:
	var state: Dictionary = game.get_meta(META_KEY)
	var index := GRID_SIZES.find(int(state.grid_size))
	state.grid_size = GRID_SIZES[(index + 1) % GRID_SIZES.size()]; state.refresh_left = 0.0; state.cache_invalidated=true
	game.set_meta(META_KEY, state); refresh_grid(game)


## Изменяет прозрачность цветных клеток в безопасном читаемом диапазоне.
static func change_opacity(game: Node, amount: float) -> void:
	var state: Dictionary = game.get_meta(META_KEY)
	state.opacity = clampf(float(state.opacity) + amount, 0.10, 0.70)
	state.grid_texture = null; state.grid_texture_signature = ""; state.grid_lines_texture=null; state.grid_lines_signature=""
	game.set_meta(META_KEY, state)


## Запрашивает ровно один фиксированный кадр, сохраняя симуляцию на паузе.
static func request_step(game: Node) -> void:
	var state: Dictionary = game.get_meta(META_KEY)
	state.paused = true; state.step_requested = true
	game.set_meta(META_KEY, state)


## Возвращает рабочую дельту либо ноль для паузы и фиксированную дельту для шага.
static func simulation_delta(game: Node, delta: float) -> float:
	if not active(game): return delta
	var state: Dictionary = game.get_meta(META_KEY)
	if not bool(state.paused): return delta
	if bool(state.step_requested):
		state.step_requested = false; game.set_meta(META_KEY, state); return 1.0 / 12.0
	return 0.0


## Проверяет режим прохождения сквозь препятствия без подмены диагностической карты.
static func noclip(game: Node) -> bool:
	return active(game) and bool(game.get_meta(META_KEY).get("noclip", false))


## Возвращает точную клетку курсора, обновляя дорогую пахотность не чаще 10 раз в секунду внутри одной клетки.
static func inspect_screen_point(game: Node, screen_point: Vector2) -> Dictionary:
	var state: Dictionary = game.get_meta(META_KEY, default_state())
	var size := int(state.get("grid_size", 50))
	var world: Vector2 = screen_point + Vector2(game.camera_offset)
	var origin: Vector2 = Vector2(floori(world.x / size) * size, floori(world.y / size) * size)
	var center: Vector2 = origin + Vector2.ONE * size * 0.5
	var now := Time.get_ticks_msec()
	var cached: Dictionary = game.get_meta(INSPECT_CACHE_META, {})
	var signature := "%s|%s|%d|%d" % [game.current_location, str(origin), size, int(state.get("cache_generation", 0))]
	if String(cached.get("signature", "")) == signature and now - int(cached.get("time", 0)) < INSPECT_REFRESH_MSEC:
		return cached.result
	var farming_reason: String = game.WorldFarmingSystem.tillability_reason(game, game.current_location, game.WorldFarmingSystem.cell_at(center))
	var result := {"origin":origin, "center":center, "reason":game.NavigationSystem.walkability_reason(game, center), "farming_reason":farming_reason}
	game.set_meta(INSPECT_CACHE_META, {"signature": signature, "time": now, "result": result})
	return result
