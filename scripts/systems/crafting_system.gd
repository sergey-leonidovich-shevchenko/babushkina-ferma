extends RefCounted

const RECIPES := [
	{"name":"Лесной меч", "inputs":{"slime":3,"wood":2}, "output":"sword", "count":1},
	{"name":"Кристальный меч", "inputs":{"sword":1,"crystal":5}, "output":"crystal_sword", "count":1},
	{"name":"Железный шлем", "inputs":{"metal":4,"stone":2}, "output":"iron_helmet", "count":1},
	{"name":"Доспех хранителя", "inputs":{"metal":8,"crystal":2}, "output":"guardian_armor", "count":1},
	{"name":"Алмазный талисман", "inputs":{"blue_gem":1,"metal":2}, "output":"crystal_ring", "count":1},
	{"name":"Лечебное зелье", "inputs":{"berries":2,"mushroom":1}, "output":"healing_potion", "count":1},
	{"name":"Дубовый щит", "inputs":{"wood":4,"metal":2}, "output":"oak_shield", "count":1}
]

static func can_craft(game: Node, recipe: Dictionary) -> bool:
	for kind in recipe.inputs:
		if game.inventory_item_count(kind) < game.SkillSystem.material_cost(game, recipe.inputs[kind]): return false
	return true

static func craft(game: Node, index: int) -> bool:
	if index < 0 or index >= RECIPES.size(): return false
	var recipe: Dictionary = RECIPES[index]
	if not can_craft(game, recipe):
		game.message = game.LocaleSystem.text("needs", [ingredients_text(game, recipe)])
		return false
	for kind in recipe.inputs: game.change_inventory_count(kind, -game.SkillSystem.material_cost(game, recipe.inputs[kind]))
	game.change_inventory_count(recipe.output, recipe.count)
	game.award_xp(4)
	game.SkillSystem.award_profession_xp(game, "smithing", 6)
	game.message = game.LocaleSystem.text("crafted", [game.inventory_item_name(recipe.output)])
	game.notify_tutorial("craft_window")
	return true

static func ingredients_text(game: Node, recipe: Dictionary) -> String:
	var parts: Array[String] = []
	for kind in recipe.inputs:
		parts.append("%s %d/%d" % [game.inventory_item_name(kind), game.inventory_item_count(kind), game.SkillSystem.material_cost(game, recipe.inputs[kind])])
	return ", ".join(parts)
