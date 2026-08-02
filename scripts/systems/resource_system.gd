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
		game.message = game.LocaleSystem.text("no_resource")
		return false
	return mine(game, int(interaction.get_slice(":", 1)))

static func mine(game: Node, index: int) -> bool:
	if not game.has_pickaxe or game.selected_tool != game.Tool.PICKAXE:
		game.message = game.LocaleSystem.text("need_pickaxe")
		return false
	if index < 0 or index >= game.resource_nodes.size():
		return false
	var resource: Dictionary = game.resource_nodes[index]
	if resource.hits <= 0 or resource.location != game.current_location or game.player.distance_to(resource.position) > 92.0:
		return false
	resource.hits -= 1
	var yield_count: int = game.SkillSystem.mined_count(game)
	if resource.kind == "stone":
		game.stone += yield_count
	elif resource.kind == "crystal":
		game.crystals += yield_count
	else:
		game.materials[resource.kind] = game.materials.get(resource.kind, 0) + yield_count
	game.award_xp(1)
	game.SkillSystem.award_profession_xp(game, "mining", 3)
	game.message = game.LocaleSystem.text("mined", [game.inventory_item_name(resource.kind), yield_count])
	if resource.hits <= 0:
		game.message += ". " + game.LocaleSystem.text("depleted")
	game.resource_nodes[index] = resource
	game.notify_tutorial("mine")
	if resource.kind in ["red_crystal", "green_crystal"]:
		game.notify_tutorial("colored_crystal")
	return true
