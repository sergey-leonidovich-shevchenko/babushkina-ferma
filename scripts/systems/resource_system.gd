extends RefCounted

const RESOURCE_NAMES := {
	"stone": "камень",
	"crystal": "синий кристалл",
	"red_crystal": "красный кристалл",
	"green_crystal": "зелёный кристалл",
}

static func mine_nearby(game: Node) -> bool:
	var interaction: String = game.nearest_interaction()
	if not interaction.begins_with("resource:"):
		game.message = "Рядом нет залежей для добычи"
		return false
	return mine(game, int(interaction.get_slice(":", 1)))

static func mine(game: Node, index: int) -> bool:
	if not game.has_pickaxe or game.selected_tool != game.Tool.PICKAXE:
		game.message = "Для добычи выбери кирку [5]"
		return false
	if index < 0 or index >= game.resource_nodes.size():
		return false
	var resource: Dictionary = game.resource_nodes[index]
	if resource.hits <= 0 or resource.location != game.current_location or game.player.distance_to(resource.position) > 92.0:
		return false
	resource.hits -= 1
	if resource.kind == "stone":
		game.stone += 1
	elif resource.kind == "crystal":
		game.crystals += 1
	else:
		game.materials[resource.kind] = game.materials.get(resource.kind, 0) + 1
	game.message = "Добыт %s" % RESOURCE_NAMES.get(resource.kind, resource.kind)
	if resource.hits <= 0:
		game.message += ". Жила исчерпана"
	game.resource_nodes[index] = resource
	game.notify_tutorial("mine")
	return true
