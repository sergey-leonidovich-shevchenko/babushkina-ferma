extends RefCounted

const META_KEY := "debug_overlay"
const GRID_SIZES := [25, 50, 100]
const REFRESH_INTERVAL := 0.14
const PANEL := Rect2(774, 58, 360, 522)
const BUTTONS := [
	{"rect":Rect2(794,274,150,30),"action":"grid","label":"СЕТКА"},
	{"rect":Rect2(964,274,150,30),"action":"hitboxes","label":"ХИТБОКСЫ"},
	{"rect":Rect2(794,312,150,30),"action":"routes","label":"МАРШРУТЫ"},
	{"rect":Rect2(964,312,150,30),"action":"labels","label":"ПОДПИСИ"},
	{"rect":Rect2(794,350,150,30),"action":"pause","label":"ПАУЗА"},
	{"rect":Rect2(964,350,150,30),"action":"step","label":"ШАГ КАДРА"},
	{"rect":Rect2(794,388,150,30),"action":"noclip","label":"NOCLIP"},
	{"rect":Rect2(964,388,150,30),"action":"grid_size","label":"РАЗМЕР СЕТКИ"},
	{"rect":Rect2(794,426,150,30),"action":"opacity_down","label":"ПРОЗРАЧНЕЕ"},
	{"rect":Rect2(964,426,150,30),"action":"opacity_up","label":"ЯРЧЕ"},
]


## Создаёт исходное состояние панели, не добавляемое в сохранение игры.
static func default_state() -> Dictionary:
	return {
		"open":true, "grid":true, "hitboxes":false, "routes":false, "labels":false,
		"paused":false, "step_requested":false, "noclip":false, "grid_size":50,
		"opacity":0.30, "refresh_left":0.0, "cache":[], "counts":{},
		"cache_location":"", "cache_camera":Vector2(-9999,-9999), "frame_history":[],
	}


## Проверяет, открыта ли диагностическая панель поверх текущей игровой локации.
static func active(game: Node) -> bool:
	return bool(game.get_meta(META_KEY, {}).get("open", false))


## Открывает или закрывает панель F11, сохраняя выбранные диагностические слои.
static func toggle(game: Node) -> void:
	var state: Dictionary = game.get_meta(META_KEY, default_state())
	state.open = not bool(state.get("open", false)) if game.has_meta(META_KEY) else true
	state.refresh_left = 0.0
	game.set_meta(META_KEY, state)
	if state.open: refresh_grid(game)
	game.message = "DEBUG: F11 — закрыть" if state.open else "Debug-панель закрыта"
	game.queue_redraw()


## Обновляет график FPS и кэш видимой навигационной сетки с ограниченной частотой.
static func update(game: Node, delta: float) -> void:
	if not active(game): return
	var state: Dictionary = game.get_meta(META_KEY)
	var history: Array = state.get("frame_history", [])
	history.append(clampf(Engine.get_frames_per_second(), 0.0, 120.0))
	if history.size() > 90: history.pop_front()
	state.frame_history = history
	state.refresh_left = float(state.get("refresh_left", 0.0)) - delta
	var camera_changed := Vector2(state.get("cache_camera", Vector2.ZERO)).distance_to(game.camera_offset) >= int(state.grid_size) * 0.5
	if bool(state.grid) and (state.refresh_left <= 0.0 or state.cache_location != game.current_location or camera_changed):
		game.set_meta(META_KEY, state)
		refresh_grid(game)
		return
	game.set_meta(META_KEY, state)


## Собирает только видимые клетки и реальные причины их блокировки из NavigationSystem.
static func refresh_grid(game: Node) -> void:
	if not active(game): return
	var state: Dictionary = game.get_meta(META_KEY)
	var size := int(state.get("grid_size", 50))
	var start_x := floori(game.camera_offset.x / size) * size - size
	var start_y := floori(game.camera_offset.y / size) * size - size
	var end_x := ceili((game.camera_offset.x + 1152.0) / size) * size + size
	var end_y := ceili((game.camera_offset.y + 648.0) / size) * size + size
	var cache: Array = []
	var counts := {}
	for y in range(start_y, end_y, size):
		for x in range(start_x, end_x, size):
			var reason: String = game.NavigationSystem.walkability_reason(game, Vector2(x + size * 0.5, y + size * 0.5))
			cache.append({"rect":Rect2(x,y,size,size), "reason":reason})
			counts[reason] = int(counts.get(reason, 0)) + 1
	state.cache = cache; state.counts = counts; state.cache_location = game.current_location
	state.cache_camera = game.camera_offset; state.refresh_left = REFRESH_INTERVAL
	game.set_meta(META_KEY, state)


## Перехватывает только команды панели, не заменяя управление игрой при закрытом окне.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle(game); return true
	if not active(game): return false
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
		match String(button.action):
			"grid", "hitboxes", "routes", "labels", "noclip": toggle_option(game, button.action)
			"pause": toggle_option(game, "paused")
			"step": request_step(game)
			"grid_size": cycle_grid_size(game)
			"opacity_down": change_opacity(game, -0.08)
			"opacity_up": change_opacity(game, 0.08)
		game.queue_redraw(); return true
	return true


## Переключает один булев диагностический слой и немедленно инвалидирует сетку.
static func toggle_option(game: Node, key: String) -> void:
	var state: Dictionary = game.get_meta(META_KEY)
	state[key] = not bool(state.get(key, false)); state.refresh_left = 0.0
	game.set_meta(META_KEY, state)


## Переключает размер проверяемой клетки между детальным, игровым и обзорным режимами.
static func cycle_grid_size(game: Node) -> void:
	var state: Dictionary = game.get_meta(META_KEY)
	var index := GRID_SIZES.find(int(state.grid_size))
	state.grid_size = GRID_SIZES[(index + 1) % GRID_SIZES.size()]; state.refresh_left = 0.0
	game.set_meta(META_KEY, state); refresh_grid(game)


## Изменяет прозрачность цветных клеток в безопасном читаемом диапазоне.
static func change_opacity(game: Node, amount: float) -> void:
	var state: Dictionary = game.get_meta(META_KEY)
	state.opacity = clampf(float(state.opacity) + amount, 0.10, 0.70)
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


## Возвращает мировую клетку и причину блокировки под указанной экранной точкой.
static func inspect_screen_point(game: Node, screen_point: Vector2) -> Dictionary:
	var state: Dictionary = game.get_meta(META_KEY, default_state())
	var size := int(state.get("grid_size", 50))
	var world: Vector2 = screen_point + Vector2(game.camera_offset)
	var origin: Vector2 = Vector2(floori(world.x / size) * size, floori(world.y / size) * size)
	var center: Vector2 = origin + Vector2.ONE * size * 0.5
	return {"origin":origin, "center":center, "reason":game.NavigationSystem.walkability_reason(game, center)}
