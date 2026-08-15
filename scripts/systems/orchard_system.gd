extends RefCounted

const TREE_ATLAS := preload("res://assets/game/environment/orchard/fruit_trees_4x4_v2.png")
const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
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
	# Взрослое дерево больше не проходит стадии роста повторно: таймер относится
	# только к новому урожаю и по завершении возвращает плоды на ту же крону.
	if current_stage >= 3:
		if ready_at <= 0.0: ready_at = now + float(data.get("growth_minutes", 1440.0))
		if now >= ready_at:
			node.active = true
			ready_at = 0.0
		node.stage = 3
		node.ready_at = ready_at
		return node
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


## Снимает плоды со взрослого дерева, не откатывая его к молодой стадии роста.
static func start_fruit_cycle(node: Dictionary, data: Dictionary, now: float) -> Dictionary:
	node.active = false
	node.stage = 3
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


## Возвращает отдельный прогресс плодоношения уже выросшего дерева.
static func fruit_progress(game: Node, node: Dictionary, data: Dictionary) -> float:
	if stage(node) < 3: return 0.0
	if bool(node.get("active", false)): return 1.0
	var duration := maxf(float(data.get("growth_minutes", 1440.0)), 1.0)
	var remaining := maxf(float(node.get("ready_at", 0.0)) - game.ForageSystem.total_minutes(game), 0.0)
	return clampf(1.0 - remaining / duration, 0.0, 1.0)


## Выбирает вид кроны отдельно от постоянной стадии дерева: листья, цветы или плоды.
static func visual_stage(game: Node, node: Dictionary, data: Dictionary) -> int:
	var current_stage := stage(node)
	if current_stage < 3: return current_stage
	if game.WorldEventSystem.season(game.day) == WINTER: return 1
	if bool(node.get("active", false)): return 3
	return 2 if fruit_progress(game, node, data) >= 0.55 else 1


## Возвращает ячейку атласа по породе и стадии без захвата соседних изображений.
static func source_rect(kind: String, current_stage: int, winter: bool = false) -> Rect2:
	if not handles(kind):
		return Rect2()
	var cell := Vector2(256,256)
	var visual_stage := clampi(current_stage, 0, 3)
	# Прямой запрос зимней плодоносящей колонки получает зелёную крону без плодов;
	# снег отрисовывается отдельным погодным слоем и не меняет геометрию дерева.
	if winter and visual_stage == 3:
		visual_stage = 1
	return Rect2(Vector2(visual_stage, int(SPECIES_ROWS[kind])) * cell, cell)


## Рассчитывает единый привязанный к земле прямоугольник каждой стадии дерева.
static func destination_rect(position: Vector2, current_stage: int) -> Rect2:
	var profiles:=["tree_sapling","tree_young","tree_flowering","tree_adult"]
	return WorldVisualProfileSystem.visual_rect(profiles[clampi(current_stage,0,3)],position+Vector2(0,18))


## Возвращает единое основание плодового дерева независимо от листьев, цветов или урожая.
static func collision_rect(position: Vector2, current_stage: int) -> Rect2:
	var profiles:=["tree_sapling","tree_young","tree_flowering","tree_adult"]
	return WorldVisualProfileSystem.collision_rect(profiles[clampi(current_stage,0,3)],position+Vector2(0,18))


## Подбирает сезонно-погодный цвет, сохраняя читаемость исходного пиксель-арта.
static func weather_tint(season: String, weather: String) -> Color:
	if season == WINTER: return Color("b9cee2")
	if season == "autumn": return Color("e7b36f")
	if weather == "storm": return Color("78939d")
	if weather == "rain": return Color("abc9c3")
	return Color.WHITE


## Высаживает новый фруктовый саженец на свободной обрабатываемой клетке мира.
static func plant_sapling(game: Node) -> bool:
	if not game.TalentSystem.has(game, "farm_orchard"):
		game.message = "Сначала изучи способность «Садовод»"
		return false
	if game.inventory_item_count("fruit_sapling") <= 0:
		game.message = "В рюкзаке нет фруктового саженца"
		return false
	if game.energy < 2:
		game.message = game.LocaleSystem.text("no_energy")
		return false
	var target: Dictionary = game.WorldFarmingSystem.target(game)
	if not bool(target.get("valid", false)):
		game.message = game.WorldFarmingSystem.blocked_message(game, String(target.get("reason", "location_blocked")))
		return false
	var position: Vector2 = Rect2(target.rect).get_center()
	for node in game.food_nodes:
		if String(node.get("location", "overworld")) == game.current_location and Vector2(node.position).distance_to(position) < 100.0:
			game.message = "Деревьям нужно свободное место вокруг"
			return false
	var planted_count: int = game.food_nodes.filter(func(node): return bool(node.get("planted_by_player", false))).size()
	var species: Array = SPECIES_ROWS.keys()
	var kind: String = String(species[planted_count % species.size()])
	var data: Dictionary = game.ForageSystem.TYPES[kind]
	game.food_nodes.append({"position":position, "location":game.current_location, "kind":kind, "active":false, "ready_at":game.ForageSystem.total_minutes(game) + stage_duration(data), "stage":0, "planted_by_player":true})
	game.change_inventory_count("fruit_sapling", -1)
	game.energy -= 2
	game.award_xp(5, "Посадка фруктового дерева")
	game.SkillSystem.award_profession_xp(game, "farming", 5)
	game.message = "Высажено дерево: %s" % game.inventory_item_name(kind)
	game.notify_tutorial("orchard_planting")
	return true


## Рисует одну стадию сада и отдельные анимированные детали снега, дождя и ветра.
static func draw_tree(game: Node2D, node: Dictionary) -> void:
	var current_stage := stage(node)
	var data: Dictionary = game.ForageSystem.TYPES[node.kind]
	var current_season: String = game.WorldEventSystem.season(game.day)
	var current_weather: String = game.WorldEventSystem.weather(game)
	var position: Vector2 = node.position
	var time := Time.get_ticks_msec() / 1000.0
	if current_weather in ["wind", "storm"]:
		position.x += roundf(sin(time * 2.4 + position.y * 0.01) * (2.0 if current_weather == "storm" else 1.0))
	var destination := destination_rect(position, current_stage)
	game.draw_texture_rect_region(TREE_ATLAS, destination, source_rect(node.kind, visual_stage(game,node,data), current_season == WINTER), weather_tint(current_season, current_weather))
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
