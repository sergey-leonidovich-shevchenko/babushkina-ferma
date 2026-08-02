extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const TYPES := {
	"berries": {"name":"Ягодный куст","growth_minutes":360.0,"yield":3,"sell":4,"tree":false},
	"mushroom": {"name":"Грибная поляна","growth_minutes":720.0,"yield":2,"sell":7,"tree":false},
	"watermelon": {"name":"Арбузная бахча","growth_minutes":1080.0,"yield":2,"sell":10,"tree":false},
	"apple": {"name":"Яблоня","growth_minutes":1440.0,"yield":3,"sell":12,"tree":true},
	"nut": {"name":"Ореховое дерево","growth_minutes":2880.0,"yield":2,"sell":22,"tree":true},
}

static func total_minutes(game: Node) -> float:
	return float(game.day - 1) * 1440.0 + game.game_minutes

static func update(game: Node) -> void:
	var now := total_minutes(game)
	for index in game.food_nodes.size():
		var node: Dictionary = game.food_nodes[index]
		if not node.active and now >= float(node.get("ready_at", INF)):
			node.active = true
			node.ready_at = 0.0
			game.food_nodes[index] = node
			game.notify_tutorial("forage_regrow")

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
	game.award_xp(2, "Собирательство")
	game.SkillSystem.award_profession_xp(game, "farming", 2)
	game.message = "%s: %s ×%d" % [LocaleSystem.entity(node.kind), game.inventory_item_name(node.kind), amount]
	game.notify_tutorial("forage_harvest")
	if node.kind == "watermelon":
		game.notify_tutorial("watermelon")
	return true

static func duration_text(minutes: float) -> String:
	if minutes >= 1440.0:
		var days := int(minutes / 1440.0)
		return "%d дн." % days
	return "%d ч." % int(minutes / 60.0)

static func remaining_text(game: Node, node: Dictionary) -> String:
	if node.active:
		return "готово"
	var remaining := maxf(float(node.get("ready_at", 0.0)) - total_minutes(game), 0.0)
	var hours := ceili(remaining / 60.0)
	return "%d ч." % hours if hours < 24 else "%d дн. %d ч." % [hours / 24, hours % 24]

static func reset_all(game: Node) -> void:
	for index in game.food_nodes.size():
		game.food_nodes[index].active = true
		game.food_nodes[index].ready_at = 0.0
