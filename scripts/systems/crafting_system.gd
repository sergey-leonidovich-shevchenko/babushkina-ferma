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
	{"name":"Яблочный пирог", "inputs":{"apple":2,"flour":1,"butter":1}, "output":"pie", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"name":"Ягодное варенье", "inputs":{"berries":3,"honey":1}, "output":"jam", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"name":"Овощной суп", "inputs":{"carrot":1,"potato":1,"onion":1}, "output":"soup", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"name":"Омлет с зеленью", "inputs":{"egg":2,"milk":1}, "output":"omelet", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"name":"Кукурузный хлеб", "inputs":{"corn":2,"flour":1}, "output":"cornbread", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"name":"Полевой букет", "inputs":{"flower":3,"fiber":1}, "output":"bouquet", "count":1},
	{"name":"Дубовый стол", "inputs":{"wood":8}, "output":"rustic_table", "count":1},
	{"name":"Резной стул", "inputs":{"wood":4}, "output":"wooden_chair", "count":1},
	{"name":"Тканый ковёр", "inputs":{"fiber":5,"wool":2}, "output":"woven_rug", "count":1},
	{"name":"Папоротник в горшке", "inputs":{"fiber":2,"flower":2,"stone":1}, "output":"potted_fern", "count":1},
	{"name":"Деревянный шкаф", "inputs":{"wood":10,"metal":2}, "output":"wooden_wardrobe", "count":1},
	{"name":"Секции забора", "inputs":{"wood":2}, "output":"fence_kit", "count":8},
	{"name":"Набор калитки", "inputs":{"wood":3,"metal":1}, "output":"gate_kit", "count":1},
	{"name":"Походный котелок", "inputs":{"metal":5,"stone":3}, "output":"cauldron", "count":1, "talent":"farm_cooking"},
	{"name":"Улучшенная удочка", "inputs":{"wood":3,"metal":3,"fiber":2}, "output":"advanced_fishing_rod", "count":1, "talents":["fish_fine_rod","craft_apprentice"]},
	{"name":"Крабовая ловушка", "inputs":{"wood":4,"fiber":2}, "output":"crab_trap", "count":1, "talent":"fish_crab_traps"},
	{"name":"Фруктовый саженец", "inputs":{"wood":2,"rare_seeds":1}, "output":"fruit_sapling", "count":1, "talent":"farm_orchard"},
]

## Возвращает индексы рецептов, относящихся к открытому верстаку или котелку.
static func visible_indices(game: Node) -> Array[int]:
	var result: Array[int] = []
	for index in RECIPES.size():
		if String(RECIPES[index].get("station", "workbench")) == game.crafting_station:
			result.append(index)
	return result

## Открывает нужную станцию и выбирает первый относящийся к ней рецепт.
static func open(game: Node, station: String = "workbench") -> void:
	game.crafting_open = true
	game.crafting_station = station
	var visible := visible_indices(game)
	game.crafting_selected = visible[0] if not visible.is_empty() else 0
	game.clear_movement_keys()
	game.message = game.LocaleSystem.text("recipe_select")

## Обрабатывает клавиатуру и геймпад общего окна верстака или котелка.
static func handle_input(game: Node, event: InputEvent) -> void:
	var move_offset := 0
	var accept := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_C]: game.crafting_open = false
		elif event.keycode == KEY_UP: move_offset = -1
		elif event.keycode == KEY_DOWN: move_offset = 1
		elif event.keycode in [KEY_ENTER, KEY_E]: accept = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_Y]: game.crafting_open = false
		elif event.button_index == JOY_BUTTON_DPAD_UP: move_offset = -1
		elif event.button_index == JOY_BUTTON_DPAD_DOWN: move_offset = 1
		elif event.button_index == JOY_BUTTON_A: accept = true
	else:
		return
	var visible := visible_indices(game)
	if move_offset != 0 and not visible.is_empty():
		var selected_position := maxi(visible.find(game.crafting_selected), 0)
		game.crafting_selected = visible[posmod(selected_position + move_offset, visible.size())]
	if accept: craft(game, game.crafting_selected)
	game.queue_redraw()

## Находит видимый рецепт под указателем по общей геометрии строк обеих станций.
static func recipe_at(game: Node, position: Vector2) -> int:
	if position.x < 220.0 or position.x > 932.0 or position.y < 164.0 or position.y >= 551.0:
		return -1
	var visible := visible_indices(game)
	var selected_position := maxi(visible.find(game.crafting_selected), 0)
	var first_position := clampi(selected_position - 4, 0, maxi(0, visible.size() - 9))
	var visible_position := first_position + int((position.y - 164.0) / 43.0)
	return visible[visible_position] if visible_position >= 0 and visible_position < visible.size() else -1

## Проверяет условие «возможности крафта» без изменения состояния.
static func can_craft(game: Node, recipe: Dictionary) -> bool:
	if not game.TalentSystem.recipe_unlocked(game, recipe):
		return false
	if recipe.output == "home_chest" and game.home_chest_owned:
		return false
	for kind in recipe.inputs:
		if game.inventory_item_count(kind) < game.TalentSystem.recipe_material_cost(game, recipe.inputs[kind]): return false
	return true

## Выполняет операцию «крафта» и возвращает результат согласно контракту метода.
static func craft(game: Node, index: int) -> bool:
	if index < 0 or index >= RECIPES.size(): return false
	var recipe: Dictionary = RECIPES[index]
	if not game.TalentSystem.recipe_unlocked(game, recipe):
		game.message = "Сначала изучи нужную способность в дереве [K]"
		return false
	if recipe.output == "home_chest" and game.home_chest_owned:
		game.message = game.LocaleSystem.text("chest_already_owned")
		return false
	if not can_craft(game, recipe):
		game.message = game.LocaleSystem.text("needs", [ingredients_text(game, recipe)])
		return false
	for kind in recipe.inputs: game.change_inventory_count(kind, -game.TalentSystem.recipe_material_cost(game, recipe.inputs[kind]))
	game.state.player.craft_count += 1
	var crafted_count: int = int(recipe.count)
	if game.TalentSystem.has(game, "craft_master") and game.state.player.craft_count % 5 == 0:
		crafted_count += int(recipe.count)
	game.change_inventory_count(recipe.output, crafted_count)
	if recipe.output == "home_chest": game.StorageSystem.install(game)
	game.award_xp(4)
	game.SkillSystem.award_profession_xp(game, "smithing", 6)
	game.message = game.LocaleSystem.text("crafted", [game.inventory_item_name(recipe.output)])
	game.play_sfx("craft")
	game.notify_tutorial("craft_window")
	if game.crafting_station == "cauldron": game.notify_tutorial("cooking")
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func ingredients_text(game: Node, recipe: Dictionary) -> String:
	var parts: Array[String] = []
	for kind in recipe.inputs:
		parts.append("%s %d/%d" % [game.inventory_item_name(kind), game.inventory_item_count(kind), game.TalentSystem.recipe_material_cost(game, recipe.inputs[kind])])
	return ", ".join(parts)
