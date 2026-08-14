extends RefCounted

const RECIPES := [
	{"name":"Лесной меч", "inputs":{"slime":3,"wood":2}, "output":"sword", "count":1},
	{"name":"Кристальный меч", "inputs":{"sword":1,"crystal":5}, "output":"crystal_sword", "count":1},
	{"name":"Железный шлем", "inputs":{"metal":4,"stone":2}, "output":"iron_helmet", "count":1},
	{"name":"Доспех хранителя", "inputs":{"metal":8,"crystal":2}, "output":"guardian_armor", "count":1},
	{"name":"Алмазный талисман", "inputs":{"blue_gem":1,"metal":2}, "output":"crystal_ring", "count":1},
	{"name":"Лечебное зелье", "inputs":{"berries":2,"mushroom":1}, "output":"healing_potion", "count":1},
	{"name":"Дубовый щит", "inputs":{"wood":4,"metal":2}, "output":"oak_shield", "count":1},
	{"name":"Домашний сундук", "inputs":{"wood":10,"metal":3}, "output":"home_chest", "count":1},
	{"name":"Стрелы", "inputs":{"wood":2,"metal":1}, "output":"arrows", "count":10},
	{"name":"Зелье маны", "inputs":{"crystal":1,"berries":1}, "output":"mana_potion", "count":1},
	{"name":"Зелье энергии", "inputs":{"nut":2,"orange":1}, "output":"energy_potion", "count":1},
	{"name":"Зелье невидимости", "inputs":{"ectoplasm":1,"mushroom":2}, "output":"invisibility_potion", "count":1},
	{"name":"Зелье силы", "inputs":{"raw_meat":1,"nut":2}, "output":"strength_potion", "count":1},
	{"name":"Зелье регенерации", "inputs":{"berries":3,"mushroom":2}, "output":"regeneration_potion", "count":1},
	{"name":"Зелье скорости", "inputs":{"lizard_scale":1,"mushroom":1}, "output":"speed_potion", "count":1},
	{"name":"Зелье защиты", "inputs":{"stone":2,"metal":1}, "output":"defense_potion", "count":1},
	{"name":"Крепкая верёвка", "inputs":{"fiber":2}, "output":"rope", "count":1},
	{"name":"Мука", "inputs":{"wheat":2}, "output":"flour", "count":1},
	{"name":"Сливочное масло", "inputs":{"milk":2}, "output":"butter", "count":1},
	{"name":"Домашний сыр", "inputs":{"milk":3}, "output":"cheese", "count":1},
	{"name":"Деревенский хлеб", "inputs":{"flour":2}, "output":"bread", "count":1},
	{"name":"Яблочный пирог", "inputs":{"apple":2,"flour":1,"butter":1}, "output":"pie", "count":1},
	{"name":"Ягодное варенье", "inputs":{"berries":3,"honey":1}, "output":"jam", "count":1},
	{"name":"Овощной суп", "inputs":{"carrot":1,"potato":1,"onion":1}, "output":"soup", "count":1},
	{"name":"Омлет с зеленью", "inputs":{"egg":2,"milk":1}, "output":"omelet", "count":1},
	{"name":"Кукурузный хлеб", "inputs":{"corn":2,"flour":1}, "output":"cornbread", "count":1},
	{"name":"Полевой букет", "inputs":{"flower":3,"fiber":1}, "output":"bouquet", "count":1},
	{"name":"Дубовый стол", "inputs":{"wood":8}, "output":"rustic_table", "count":1},
	{"name":"Резной стул", "inputs":{"wood":4}, "output":"wooden_chair", "count":1},
	{"name":"Тканый ковёр", "inputs":{"fiber":5,"wool":2}, "output":"woven_rug", "count":1},
	{"name":"Папоротник в горшке", "inputs":{"fiber":2,"flower":2,"stone":1}, "output":"potted_fern", "count":1},
	{"name":"Деревянный шкаф", "inputs":{"wood":10,"metal":2}, "output":"wooden_wardrobe", "count":1},
	{"name":"Секции забора", "inputs":{"wood":2}, "output":"fence_kit", "count":8},
	{"name":"Набор калитки", "inputs":{"wood":3,"metal":1}, "output":"gate_kit", "count":1},
]

## Проверяет условие «возможности крафта» без изменения состояния.
static func can_craft(game: Node, recipe: Dictionary) -> bool:
	if recipe.output == "home_chest" and game.home_chest_owned:
		return false
	for kind in recipe.inputs:
		if game.inventory_item_count(kind) < game.SkillSystem.material_cost(game, recipe.inputs[kind]): return false
	return true

## Выполняет операцию «крафта» и возвращает результат согласно контракту метода.
static func craft(game: Node, index: int) -> bool:
	if index < 0 or index >= RECIPES.size(): return false
	var recipe: Dictionary = RECIPES[index]
	if recipe.output == "home_chest" and game.home_chest_owned:
		game.message = game.LocaleSystem.text("chest_already_owned")
		return false
	if not can_craft(game, recipe):
		game.message = game.LocaleSystem.text("needs", [ingredients_text(game, recipe)])
		return false
	for kind in recipe.inputs: game.change_inventory_count(kind, -game.SkillSystem.material_cost(game, recipe.inputs[kind]))
	game.change_inventory_count(recipe.output, recipe.count)
	if recipe.output == "home_chest": game.StorageSystem.install(game)
	game.award_xp(4)
	game.SkillSystem.award_profession_xp(game, "smithing", 6)
	game.message = game.LocaleSystem.text("crafted", [game.inventory_item_name(recipe.output)])
	game.play_sfx("craft")
	game.notify_tutorial("craft_window")
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func ingredients_text(game: Node, recipe: Dictionary) -> String:
	var parts: Array[String] = []
	for kind in recipe.inputs:
		parts.append("%s %d/%d" % [game.inventory_item_name(kind), game.inventory_item_count(kind), game.SkillSystem.material_cost(game, recipe.inputs[kind])])
	return ", ".join(parts)
