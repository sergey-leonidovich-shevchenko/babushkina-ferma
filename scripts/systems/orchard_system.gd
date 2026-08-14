extends RefCounted

const TREE_ATLAS := preload("res://assets/game/environment/orchard/fruit_trees_clear.png")
const SPECIES_ROWS := {"apple":0, "pear":1, "cherry":2, "plum":3}
const STAGE_COUNT := 4
const WINTER := "winter"


## Проверяет, принадлежит ли предмет новому семейству плодовых деревьев.
static func handles(kind: String) -> bool:
	return SPECIES_ROWS.has(kind)


## Возвращает сохранённую стадию дерева с защитой от старых сохранений.
static func stage(node: Dictionary) -> int:
	return clampi(int(node.get("stage", 3 if bool(node.get("active", false)) else 2)), 0, 3)


## Делит полный цикл взросления на три одинаковых перехода между четырьмя стадиями.
static func stage_duration(data: Dictionary) -> float:
	return maxf(float(data.get("growth_minutes", 1440.0)) / 3.0, 1.0)


## Продвигает дерево на одну или несколько стадий; зимой календарный рост приостановлен.
static func update_node(game: Node, node: Dictionary, data: Dictionary, now: float) -> Dictionary:
	if bool(node.get("active", false)) or game.WorldEventSystem.season(game.day) == WINTER:
		return node
	var current_stage := stage(node)
	var ready_at := float(node.get("ready_at", 0.0))
	if ready_at <= 0.0:
		ready_at = now + stage_duration(data)
	while current_stage < 3 and now >= ready_at:
		current_stage += 1
		if current_stage >= 3:
			node.active = true
			ready_at = 0.0
		else:
			ready_at += stage_duration(data)
	node.stage = current_stage
	node.ready_at = ready_at
	return node


## Переводит собранное взрослое дерево в фазу повторного цветения до следующего урожая.
static func start_fruit_cycle(node: Dictionary, data: Dictionary, now: float) -> Dictionary:
	node.active = false
	node.stage = 2
	node.ready_at = now + float(data.get("growth_minutes", 1440.0))
	return node


## Запрещает зимний сбор: зрелые плоды сохраняются до весеннего оттаивания.
static func can_harvest(game: Node, node: Dictionary) -> bool:
	return bool(node.get("active", false)) and game.WorldEventSystem.season(game.day) != WINTER


## Возвращает прогресс внутри текущей стадии для интерфейса и отладочного инспектора.
static func growth_progress(game: Node, node: Dictionary, data: Dictionary) -> float:
	var current_stage := stage(node)
	if current_stage >= 3:
		return 1.0
	var duration := stage_duration(data)
	var remaining := maxf(float(node.get("ready_at", 0.0)) - game.ForageSystem.total_minutes(game), 0.0)
	var local_progress := clampf(1.0 - remaining / duration, 0.0, 1.0)
	return clampf((float(current_stage) + local_progress) / 3.0, 0.0, 1.0)


## Возвращает ячейку атласа по породе и стадии без захвата соседних изображений.
static func source_rect(kind: String, current_stage: int, winter: bool = false) -> Rect2:
	if not handles(kind):
		return Rect2()
	var cell := TREE_ATLAS.get_size() / Vector2(STAGE_COUNT, SPECIES_ROWS.size())
	var visual_stage := clampi(current_stage, 0, 3)
	# Зимой плодоносящая колонка заменяется цветущей: светлые точки становятся снегом,
	# а яркие плоды не просвечивают через морозный погодный слой.
	if winter and visual_stage == 3:
		visual_stage = 2
	return Rect2(Vector2(visual_stage, int(SPECIES_ROWS[kind])) * cell, cell)


## Рассчитывает единый привязанный к земле прямоугольник каждой стадии дерева.
static func destination_rect(position: Vector2, current_stage: int) -> Rect2:
	var sizes := [Vector2(68, 72), Vector2(108, 112), Vector2(142, 146), Vector2(154, 158)]
	var size: Vector2 = sizes[clampi(current_stage, 0, 3)]
	return Rect2(position - Vector2(size.x * 0.5, size.y - 18.0), size)


## Подбирает сезонно-погодный цвет, сохраняя читаемость исходного пиксель-арта.
static func weather_tint(season: String, weather: String) -> Color:
	if season == WINTER: return Color("b9cee2")
	if season == "autumn": return Color("e7b36f")
	if weather == "storm": return Color("78939d")
	if weather == "rain": return Color("abc9c3")
	return Color.WHITE


## Рисует одну стадию сада и отдельные анимированные детали снега, дождя и ветра.
static func draw_tree(game: Node2D, node: Dictionary) -> void:
	var current_stage := stage(node)
	var current_season: String = game.WorldEventSystem.season(game.day)
	var current_weather: String = game.WorldEventSystem.weather(game)
	var position: Vector2 = node.position
	var time := Time.get_ticks_msec() / 1000.0
	if current_weather in ["wind", "storm"]:
		position.x += roundf(sin(time * 2.4 + position.y * 0.01) * (2.0 if current_weather == "storm" else 1.0))
	var destination := destination_rect(position, current_stage)
	game.draw_texture_rect_region(TREE_ATLAS, destination, source_rect(node.kind, current_stage, current_season == WINTER), weather_tint(current_season, current_weather))
	_draw_weather_details(game, destination, current_stage, current_season, current_weather, time)


## Добавляет погоду поверх кроны, не меняя коллизию и точку опоры дерева.
static func _draw_weather_details(game: Node2D, rect: Rect2, current_stage: int, season: String, weather: String, time: float) -> void:
	if season == WINTER:
		var cap_count := maxi(current_stage + 1, 2)
		for index in cap_count:
			var x := rect.position.x + rect.size.x * (float(index + 1) / float(cap_count + 1))
			var y := rect.position.y + rect.size.y * (0.24 + 0.08 * (index % 2))
			game.draw_circle(Vector2(x, y), 3.0 + current_stage, Color("edf7ff"))
		return
	if weather in ["rain", "storm"]:
		for index in maxi(current_stage + 1, 2):
			var phase := fposmod(time * 48.0 + index * 17.0 + rect.position.x, rect.size.y * 0.65)
			var drop := rect.position + Vector2(rect.size.x * (0.25 + 0.22 * index), 8.0 + phase)
			game.draw_line(drop, drop + Vector2(-2, 6), Color(0.65, 0.88, 1.0, 0.72), 1.5)
	if weather in ["wind", "storm"] and current_stage > 0:
		var leaf := rect.position + Vector2(rect.size.x + fposmod(time * 28.0, 18.0), rect.size.y * 0.42)
		game.draw_circle(leaf, 2.5, Color("739f42"))
