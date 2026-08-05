extends RefCounted

const LOCATION := "debug_playground"
const WEATHER := ["clear", "rain", "wind", "storm", "snow"]
const ENEMIES := ["plant", "orc", "skeleton", "undead", "cave_guardian", "pirate", "zombie_pirate", "sea_ghost"]
const TELEPORTS := [Vector2(370,310),Vector2(910,310),Vector2(1450,310),Vector2(1990,310),Vector2(570,850),Vector2(1260,850),Vector2(1980,850)]
const OBSTACLES := [Rect2(690,210,150,260),Rect2(1220,210,170,260),Rect2(1720,210,180,260),Rect2(880,720,210,170)]
const WATER_CENTER := Vector2(1530,850)
const WATER_RADIUS := 125.0
const SHOWCASE_POSITIONS := [Vector2(240,450),Vector2(430,450),Vector2(620,450),Vector2(500,260),Vector2(680,260)]
const PANEL := Rect2(735, 72, 395, 558)
const BUTTONS := [
	{"rect":Rect2(755,345,170,30),"action":"time","label":"ВРЕМЯ +1 ЧАС"},{"rect":Rect2(940,345,170,30),"action":"weather","label":"ПОГОДА"},
	{"rect":Rect2(755,383,170,30),"action":"season","label":"СЕЗОН"},{"rect":Rect2(940,383,170,30),"action":"spawn","label":"СОЗДАТЬ ВРАГА"},
	{"rect":Rect2(755,421,170,30),"action":"pause","label":"ПАУЗА / ПУСК"},{"rect":Rect2(940,421,170,30),"action":"step","label":"ШАГ КАДРА"},
	{"rect":Rect2(755,459,170,30),"action":"hitboxes","label":"ХИТБОКСЫ"},{"rect":Rect2(940,459,170,30),"action":"routes","label":"МАРШРУТЫ"},
]

## Проверяет, открыт ли изолированный полигон и должны ли его команды иметь приоритет над игрой.
static func active(game: Node) -> bool:
	return game.current_location == LOCATION


## Продвигает кадры витрины, сохраняя фиксированные позиции для покадрового сравнения.
static func update(game: Node, delta: float) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); var history: Array = state.get("frame_history", [])
	history.append(clampf(Engine.get_frames_per_second(),0.0,120.0)); if history.size() > 120: history.pop_front()
	state.frame_history = history; game.set_meta("debug_playground", state)
	for index in game.wildlife_nodes.size():
		var animal: Dictionary = game.wildlife_nodes[index]; animal.animation += delta; game.wildlife_nodes[index] = animal


## Открывает полигон, сохраняет точку возврата и размещает витрину пяти животных.
static func configure(game: Node) -> void:
	var previous := {"snapshot":game.SaveSystem.snapshot(game),"weather":game.state.world.weather,"weather_day":game.state.world.weather_day,"discovery":game.discovery_current.duplicate(true),"discovery_timer":game.discovery_timer,"slime":[game.slime_alive,game.slime_hp]}
	game.set_meta("debug_playground", {"return":previous,"enemy_index":0,"enemy_level":1,"teleport_index":0,"collision":true,"animation_index":0,"command":"Полигон готов","paused":false,"step_requested":false,"hitboxes":true,"routes":true,"inspector":true,"selected":"герой","frame_history":[]})
	game.language_screen = false; game.title_screen = false; game.tutorial_visible = false; game.current_location = LOCATION; game.player = Vector2(250,300)
	game.enemy_nodes.clear()
	var showcase: Array = []
	for kind in game.WildlifeSystem.TYPES:
		for animal in game.WildlifeSystem.default_animals():
			if animal.kind == kind: showcase.append(animal); break
	for index in showcase.size(): showcase[index].location = LOCATION; showcase[index].position = SHOWCASE_POSITIONS[index]; showcase[index].home = showcase[index].position; showcase[index].panic = 0.0
	game.wildlife_nodes = showcase; game.discovery_current.clear(); game.discovery_timer = 0.0; game.sync_background_location(); game.update_camera(); game.message = "DEBUG PLAYGROUND · F10 — выход"
	game.notify_tutorial("debug_inspector")


## Возвращает героя в сохранённую перед полигоном локацию.
static func leave(game: Node) -> void:
	var state: Dictionary = game.get_meta("debug_playground", {})
	var previous: Dictionary = state.get("return", {})
	game.remove_meta("debug_playground"); game.wildlife_nodes = game.WildlifeSystem.default_animals(); game.enemy_nodes = game.CombatSystem.default_enemies()
	if previous.has("snapshot"): game.SaveSystem.apply(game, previous.snapshot); game.state.world.weather = previous.weather; game.state.world.weather_day = previous.weather_day; game.discovery_current = previous.discovery.duplicate(true); game.discovery_timer = previous.discovery_timer; game.slime_alive = previous.slime[0]; game.slime_hp = previous.slime[1]
	else: game.current_location = "overworld"; game.player = Vector2(330,1010); game.sync_background_location(); game.update_camera()


## Перехватывает функциональные клавиши стенда, чтобы тесты не меняли сохранение и обычный интерфейс.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not active(game): return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: return handle_pointer(game, event.position)
	if not (event is InputEventKey and event.pressed and not event.echo): return false
	match event.keycode:
		KEY_F10: leave(game)
		KEY_F1: game.game_minutes = fposmod(game.game_minutes + 60.0, 1440.0); set_command(game, "Время +1 час")
		KEY_F2: cycle_weather(game)
		KEY_F3: cycle_season(game)
		KEY_F4: game.grant_tester_kit(); set_command(game, "Выдан полный тестовый набор")
		KEY_F5: spawn_enemy(game)
		KEY_F6: change_enemy_level(game, 1)
		KEY_F7: cycle_animation(game)
		KEY_F8: teleport(game)
		KEY_F9: cycle_quest(game)
		KEY_C: toggle_collisions(game)
		KEY_SPACE: toggle_pause(game)
		KEY_PERIOD: request_step(game)
		KEY_H: toggle_overlay(game, "hitboxes")
		KEY_P: toggle_overlay(game, "routes")
		KEY_I: toggle_overlay(game, "inspector")
		KEY_PAGEUP: change_enemy_kind(game, 1)
		KEY_PAGEDOWN: change_enemy_kind(game, -1)
		_: return false
	game.sync_background_location(); game.queue_redraw(); return true


## Возвращает дельту симуляции, останавливая мир или пропуская ровно один фиксированный кадр.
static func simulation_delta(game: Node, delta: float) -> float:
	var state: Dictionary = game.get_meta("debug_playground", {})
	if not bool(state.get("paused", false)): return delta
	if bool(state.get("step_requested", false)):
		state.step_requested = false; game.set_meta("debug_playground", state); return 1.0 / 12.0
	return 0.0


## Переключает остановку симуляции стенда без остановки интерфейса и графика FPS.
static func toggle_pause(game: Node) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); state.paused = not bool(state.paused); game.set_meta("debug_playground",state); set_command(game,"Симуляция: %s" % ("ПАУЗА" if state.paused else "ЗАПУЩЕНА"))


## Запрашивает один фиксированный кадр и автоматически оставляет стенд на паузе.
static func request_step(game: Node) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); state.paused = true; state.step_requested = true; game.set_meta("debug_playground",state); set_command(game,"Покадровый шаг 1/12 с")


## Переключает выбранный диагностический слой хитбоксов, маршрутов или инспектора.
static func toggle_overlay(game: Node, key: String) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); state[key] = not bool(state.get(key,true)); game.set_meta("debug_playground",state); set_command(game,"Слой %s: %s" % [key,"ВКЛ" if state[key] else "ВЫКЛ"])


## Обрабатывает клики по кнопкам панели и выбирает ближайший мировой объект инспектора.
static func handle_pointer(game: Node, point: Vector2) -> bool:
	for button in BUTTONS:
		if not button.rect.has_point(point): continue
		match String(button.action):
			"time": game.game_minutes = fposmod(game.game_minutes + 60.0,1440.0)
			"weather": cycle_weather(game)
			"season": cycle_season(game)
			"spawn": spawn_enemy(game)
			"pause": toggle_pause(game)
			"step": request_step(game)
			"hitboxes": toggle_overlay(game,"hitboxes")
			"routes": toggle_overlay(game,"routes")
		game.queue_redraw(); return true
	var world: Vector2 = point + game.camera_offset; var nearest_distance := 72.0; var selected := "герой"
	for enemy in game.enemy_nodes:
		var distance: float = world.distance_to(enemy.position)
		if distance < nearest_distance: nearest_distance = distance; selected = "%s ур.%d HP %d/%d" % [enemy.kind,enemy.level,enemy.hp,enemy.max_hp]
	for animal in game.wildlife_nodes:
		var distance: float = world.distance_to(animal.position)
		if distance < nearest_distance: nearest_distance = distance; selected = "%s · %s" % [animal.kind,animal.visual_state]
	var state: Dictionary = game.get_meta("debug_playground"); state.selected = selected; game.set_meta("debug_playground",state); game.queue_redraw(); return true


## Переключает погоду вручную, сохраняя выбранное значение на текущий игровой день.
static func cycle_weather(game: Node) -> void:
	var next: String = WEATHER[(WEATHER.find(game.WorldEventSystem.weather(game)) + 1) % WEATHER.size()]
	game.state.world.weather = next; game.state.world.weather_day = game.day; set_command(game, "Погода: %s" % next)


## Переводит календарь на первый день следующего сезона без изменения времени суток.
static func cycle_season(game: Node) -> void:
	var current: int = game.WorldEventSystem.SEASONS.find(game.WorldEventSystem.season(game.day)); game.day = ((current + 1) % 4) * game.WorldEventSystem.DAYS_PER_SEASON + 1
	game.state.world.weather_day = 0; set_command(game, "Сезон: %s" % game.WorldEventSystem.season(game.day))


## Создаёт выбранного противника с корректным уровнем и полным runtime-состоянием боя.
static func spawn_enemy(game: Node) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); var kind: String = ENEMIES[state.enemy_index]; var level: int = state.enemy_level
	var hp: int = game.CombatSystem.max_hp(kind, level)
	game.enemy_nodes.append({"kind":kind,"location":LOCATION,"position":game.player + Vector2(180,0),"home":game.player + Vector2(180,0),"level":level,"max_hp":hp,"hp":hp,"alive":true,"direction":Vector2.LEFT,"moving":false,"attack_timer":2.0,"visual_state":"idle","visual_time":0.0,"action_kind":game.CombatSystem.enemy_action_kind(kind),"action_target":game.player})
	set_command(game, "Создан %s · уровень %d" % [kind, level])


## Повышает уровень следующего создаваемого врага по кольцу от первого до пятого.
static func change_enemy_level(game: Node, step: int) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); state.enemy_level = posmod(int(state.enemy_level) - 1 + step, 5) + 1; game.set_meta("debug_playground", state); set_command(game, "Уровень врага: %d" % state.enemy_level)


## Выбирает семейство врага без немедленного создания экземпляра.
static func change_enemy_kind(game: Node, step: int) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); state.enemy_index = posmod(int(state.enemy_index) + step, ENEMIES.size()); game.set_meta("debug_playground", state); set_command(game, "Тип врага: %s" % ENEMIES[state.enemy_index])


## Последовательно показывает idle, бег, бегство, атаку, урон и смерть на всей витрине животных.
static func cycle_animation(game: Node) -> void:
	var states := ["idle","run","flee","attack","hurt","death"]; var debug: Dictionary = game.get_meta("debug_playground"); debug.animation_index = (int(debug.animation_index) + 1) % states.size(); game.set_meta("debug_playground", debug)
	for index in game.wildlife_nodes.size(): var animal: Dictionary = game.wildlife_nodes[index]; animal.visual_state = states[debug.animation_index]; animal.alive = animal.visual_state != "death"; animal.direction = Vector2.from_angle(index * TAU / 8.0); animal.state_timer = 999.0; game.wildlife_nodes[index] = animal
	set_command(game, "Анимация животных: %s" % states[debug.animation_index])


## Перемещает героя между зонами проверки камеры, воды, стен и проходов.
static func teleport(game: Node) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); state.teleport_index = (int(state.teleport_index) + 1) % TELEPORTS.size(); game.set_meta("debug_playground", state); game.player = TELEPORTS[state.teleport_index]; game.update_camera(); set_command(game, "Телепорт: точка %d" % (state.teleport_index + 1))


## Переводит первое сюжетное задание между доступным, активным и завершённым состояниями.
static func cycle_quest(game: Node) -> void:
	var key: String = game.mission_states.keys()[0]; var states := [game.QuestSystem.AVAILABLE, game.QuestSystem.ACTIVE, game.QuestSystem.COMPLETED]; game.mission_states[key] = states[(states.find(game.mission_states[key]) + 1) % states.size()]; set_command(game, "Квест %s: %s" % [key, game.mission_states[key]])


## Включает или выключает тестовые препятствия, не затрагивая коллизии обычных локаций.
static func toggle_collisions(game: Node) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); state.collision = not bool(state.collision); game.set_meta("debug_playground", state); set_command(game, "Коллизии: %s" % ("ВКЛ" if state.collision else "ВЫКЛ"))


## Проверяет границы, прямоугольные препятствия и тестовый водоём стенда.
static func is_walkable(game: Node, position: Vector2, radius: float) -> bool:
	var state: Dictionary = game.get_meta("debug_playground", {"collision":true})
	if not bool(state.collision): return true
	for rect in OBSTACLES:
		if game.NavigationSystem.circle_intersects_rect(position, radius, rect): return false
	return position.distance_to(WATER_CENTER) >= WATER_RADIUS + radius


## Сохраняет последнюю выполненную команду для панели диагностики.
static func set_command(game: Node, value: String) -> void:
	var state: Dictionary = game.get_meta("debug_playground"); state.command = value; game.set_meta("debug_playground", state); game.message = value
