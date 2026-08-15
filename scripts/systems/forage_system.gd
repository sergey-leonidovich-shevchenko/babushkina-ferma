extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
const OrchardSystem := preload("res://scripts/systems/orchard_system.gd")
const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")

const TYPES := {
	"berries": {"name":"Ягодный куст","growth_minutes":360.0,"yield":3,"sell":4,"tree":false},
	"mushroom": {"name":"Грибная поляна","growth_minutes":720.0,"yield":2,"sell":7,"tree":false},
	"watermelon": {"name":"Арбузная бахча","growth_minutes":1080.0,"yield":2,"sell":10,"tree":false},
	"apple": {"name":"Яблоня","growth_minutes":1440.0,"yield":3,"sell":12,"tree":true,"orchard":true},
	"pear": {"name":"Грушевое дерево","growth_minutes":1800.0,"yield":3,"sell":15,"tree":true,"orchard":true},
	"cherry": {"name":"Вишнёвое дерево","growth_minutes":2160.0,"yield":4,"sell":18,"tree":true,"orchard":true},
	"plum": {"name":"Сливовое дерево","growth_minutes":2880.0,"yield":3,"sell":24,"tree":true,"orchard":true},
	"nut": {"name":"Ореховое дерево","growth_minutes":2880.0,"yield":2,"sell":22,"tree":true},
}
const SPAWNS := [
	{"position": Vector2(1880, 515), "location":"overworld", "kind":"mushroom", "active":true, "ready_at":0.0},
	{"position": Vector2(1740, 410), "location":"overworld", "kind":"berries", "active":true, "ready_at":0.0},
	{"position": Vector2(2050, 995), "location":"overworld", "kind":"nut", "active":true, "ready_at":0.0},
	{"position": Vector2(1850, 930), "location":"overworld", "kind":"apple", "active":true, "ready_at":0.0, "stage":3},
	{"position": Vector2(620, 690), "location":"forest", "kind":"berries", "active":true, "ready_at":0.0},
	{"position": Vector2(1420, 350), "location":"forest", "kind":"apple", "active":true, "ready_at":0.0, "stage":3},
	{"position": Vector2(1880, 680), "location":"forest", "kind":"nut", "active":true, "ready_at":0.0},
	{"position": Vector2(340, 1080), "location":"overworld", "kind":"watermelon", "active":true, "ready_at":0.0},
	{"position": Vector2(1760, 740), "location":"forest", "kind":"watermelon", "active":true, "ready_at":0.0},
	{"position": Vector2(980, 720), "location":"forest", "kind":"mushroom", "active":true, "ready_at":0.0},
	# Новые узлы добавлены после исторического каталога: индексы старых сохранений остаются стабильными.
	{"position": Vector2(1980, 930), "location":"overworld", "kind":"pear", "active":false, "ready_at":960.0, "stage":0},
	{"position": Vector2(2120, 930), "location":"overworld", "kind":"cherry", "active":false, "ready_at":1080.0, "stage":1},
	{"position": Vector2(2260, 930), "location":"overworld", "kind":"plum", "active":false, "ready_at":1200.0, "stage":2},
	{"position": Vector2(1580, 350), "location":"forest", "kind":"pear", "active":true, "ready_at":0.0, "stage":3},
	{"position": Vector2(1740, 350), "location":"forest", "kind":"cherry", "active":true, "ready_at":0.0, "stage":3},
	{"position": Vector2(1900, 350), "location":"forest", "kind":"plum", "active":true, "ready_at":0.0, "stage":3},
]


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_nodes() -> Array:
	return SPAWNS.duplicate(true)


## Выбирает модульный визуальный класс гриба, бахчи, куста или дикого дерева.
static func profile_id(kind: String) -> String:
	if kind=="mushroom": return "forage_patch"
	if bool(TYPES.get(kind,{}).get("tree",false)): return "forage_tree"
	return "forage_crop"


## Возвращает единую линию земли для всех недревесных собираемых объектов.
static func ground_anchor(position: Vector2) -> Vector2:
	return position+Vector2(0,24)


## Строит модульный прямоугольник гриба, бахчи, ягодного куста или дикого орешника.
static func destination_rect(node: Dictionary) -> Rect2:
	return WorldVisualProfileSystem.visual_rect(profile_id(String(node.kind)),ground_anchor(Vector2(node.position)))


## Строит основание собираемого объекта из того же профиля, который используется renderer-ом.
static func collision_rect(node: Dictionary) -> Rect2:
	return WorldVisualProfileSystem.collision_rect(profile_id(String(node.kind)),ground_anchor(Vector2(node.position)))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func total_minutes(game: Node) -> float:
	return float(game.day - 1) * 1440.0 + game.game_minutes

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func update(game: Node) -> void:
	var now := total_minutes(game)
	for index in game.food_nodes.size():
		var node: Dictionary = game.food_nodes[index]
		var data: Dictionary = TYPES[node.kind]
		if OrchardSystem.handles(node.kind):
			var was_active: bool = node.active
			node = OrchardSystem.update_node(game, node, data, now)
			game.food_nodes[index] = node
			if not was_active and node.active: game.notify_tutorial("forage_regrow")
			continue
		if not node.active and now >= float(node.get("ready_at", INF)):
			node.active = true
			node.ready_at = 0.0
			game.food_nodes[index] = node
			game.notify_tutorial("forage_regrow")

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func collect(game: Node, index: int) -> bool:
	if index < 0 or index >= game.food_nodes.size():
		return false
	var node: Dictionary = game.food_nodes[index]
	if not is_collectable(game, node) or node.get("location", "overworld") != game.current_location or game.player.distance_to(node.position) > 92.0:
		if OrchardSystem.handles(node.kind) and node.active and game.WorldEventSystem.season(game.day) == "winter":
			game.message = "Зимой плодовые деревья отдыхают до весны"
		return false
	var data: Dictionary = TYPES[node.kind]
	var amount: int = data.yield
	if OrchardSystem.handles(node.kind):
		node = OrchardSystem.start_fruit_cycle(node, data, total_minutes(game))
	else:
		node.active = false
		node.ready_at = total_minutes(game) + float(data.growth_minutes)
	game.food_nodes[index] = node
	game.change_inventory_count(node.kind, amount)
	var quality: String = game.EstateSystem.record_quality(game, node.kind, amount)
	game.award_xp(2, "Собирательство")
	game.SkillSystem.award_profession_xp(game, "farming", 2)
	game.message = "%s: %s ×%d • %s" % [LocaleSystem.entity(node.kind), game.inventory_item_name(node.kind), amount, game.LocaleSystem.ui("quality_%s" % quality)]
	game.play_sfx("harvest")
	game.notify_tutorial("forage_harvest")
	if OrchardSystem.handles(node.kind): game.notify_tutorial("orchard_trees")
	if node.kind == "watermelon":
		game.notify_tutorial("watermelon")
	return true

## Проверяет фактическую готовность растения с учётом зимнего покоя фруктового сада.
static func is_collectable(game: Node, node: Dictionary) -> bool:
	return OrchardSystem.can_harvest(game, node) if OrchardSystem.handles(String(node.get("kind", ""))) else bool(node.get("active", false))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func duration_text(minutes: float) -> String:
	if minutes >= 1440.0:
		var days := int(minutes / 1440.0)
		return "%d дн." % days
	return "%d ч." % int(minutes / 60.0)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func remaining_text(game: Node, node: Dictionary) -> String:
	if node.active:
		return "до весны" if OrchardSystem.handles(node.kind) and game.WorldEventSystem.season(game.day) == "winter" else "готово"
	var remaining := maxf(float(node.get("ready_at", 0.0)) - total_minutes(game), 0.0)
	var hours := ceili(remaining / 60.0)
	return "%d ч." % hours if hours < 24 else "%d дн. %d ч." % [hours / 24, hours % 24]

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func reset_all(game: Node) -> void:
	for index in game.food_nodes.size():
		game.food_nodes[index].active = true
		game.food_nodes[index].ready_at = 0.0
		if OrchardSystem.handles(game.food_nodes[index].kind): game.food_nodes[index].stage = 3
