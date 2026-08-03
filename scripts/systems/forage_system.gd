extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const TYPES := {
	"berries": {"name":"Ягодный куст","growth_minutes":360.0,"yield":3,"sell":4,"tree":false},
	"mushroom": {"name":"Грибная поляна","growth_minutes":720.0,"yield":2,"sell":7,"tree":false},
	"watermelon": {"name":"Арбузная бахча","growth_minutes":1080.0,"yield":2,"sell":10,"tree":false},
	"apple": {"name":"Яблоня","growth_minutes":1440.0,"yield":3,"sell":12,"tree":true},
	"nut": {"name":"Ореховое дерево","growth_minutes":2880.0,"yield":2,"sell":22,"tree":true},
}
const SPAWNS := [
	{"position": Vector2(1680, 700), "location":"overworld", "kind":"mushroom", "active":true, "ready_at":0.0},
	{"position": Vector2(1780, 350), "location":"overworld", "kind":"berries", "active":true, "ready_at":0.0},
	{"position": Vector2(2010, 640), "location":"overworld", "kind":"nut", "active":true, "ready_at":0.0},
	{"position": Vector2(1640, 290), "location":"overworld", "kind":"apple", "active":true, "ready_at":0.0},
	{"position": Vector2(620, 690), "location":"forest", "kind":"berries", "active":true, "ready_at":0.0},
	{"position": Vector2(1420, 350), "location":"forest", "kind":"apple", "active":true, "ready_at":0.0},
	{"position": Vector2(1880, 680), "location":"forest", "kind":"nut", "active":true, "ready_at":0.0},
	{"position": Vector2(820, 700), "location":"overworld", "kind":"watermelon", "active":true, "ready_at":0.0},
	{"position": Vector2(1760, 740), "location":"forest", "kind":"watermelon", "active":true, "ready_at":0.0},
	{"position": Vector2(980, 720), "location":"forest", "kind":"mushroom", "active":true, "ready_at":0.0},
]


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_nodes() -> Array:
	return SPAWNS.duplicate(true)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func total_minutes(game: Node) -> float:
	return float(game.day - 1) * 1440.0 + game.game_minutes

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func update(game: Node) -> void:
	var now := total_minutes(game)
	for index in game.food_nodes.size():
		var node: Dictionary = game.food_nodes[index]
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
	if not node.active or node.get("location", "overworld") != game.current_location or game.player.distance_to(node.position) > 92.0:
		return false
	var data: Dictionary = TYPES[node.kind]
	var amount: int = data.yield
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
	if node.kind == "watermelon":
		game.notify_tutorial("watermelon")
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func duration_text(minutes: float) -> String:
	if minutes >= 1440.0:
		var days := int(minutes / 1440.0)
		return "%d дн." % days
	return "%d ч." % int(minutes / 60.0)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func remaining_text(game: Node, node: Dictionary) -> String:
	if node.active:
		return "готово"
	var remaining := maxf(float(node.get("ready_at", 0.0)) - total_minutes(game), 0.0)
	var hours := ceili(remaining / 60.0)
	return "%d ч." % hours if hours < 24 else "%d дн. %d ч." % [hours / 24, hours % 24]

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func reset_all(game: Node) -> void:
	for index in game.food_nodes.size():
		game.food_nodes[index].active = true
		game.food_nodes[index].ready_at = 0.0
