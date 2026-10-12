extends RefCounted

const BASE_RECIPES := [
	{"name":"Лесной меч", "inputs":{"slime":3,"wood":2}, "output":"sword", "count":1},
	{"name":"Распилить бревно", "inputs":{"log":1}, "output":"plank", "count":4, "category":"processing"},
	{"name":"Выковать гвозди", "inputs":{"metal":1}, "output":"nails", "count":8, "category":"processing"},
	{"name":"Железное копьё", "inputs":{"plank":2,"metal":4,"nails":2}, "output":"iron_spear", "count":1, "category":"equipment"},
	{"name":"Кузнечный молот", "inputs":{"plank":2,"metal":6,"stone":4}, "output":"war_hammer", "count":1, "category":"equipment"},
	{"name":"Лунный посох", "inputs":{"plank":2,"crystal":4,"blue_gem":1}, "output":"moon_staff", "count":1, "category":"equipment"},
	{"name":"Кристальный меч", "inputs":{"sword":1,"crystal":5}, "output":"crystal_sword", "count":1},
	{"name":"Железный шлем", "inputs":{"metal":4,"stone":2}, "output":"iron_helmet", "count":1},
	{"name":"Доспех хранителя", "inputs":{"metal":8,"crystal":2}, "output":"guardian_armor", "count":1},
	{"name":"Алмазный талисман", "inputs":{"blue_gem":1,"metal":2}, "output":"crystal_ring", "count":1},
	{"name":"Лечебное зелье", "inputs":{"berries":2,"mushroom":1}, "output":"healing_potion", "count":1},
	{"name":"Дубовый щит", "inputs":{"plank":4,"nails":3,"metal":1}, "output":"oak_shield", "count":1, "category":"equipment"},
	{"name":"Домашний сундук", "inputs":{"plank":8,"nails":6}, "output":"home_chest", "count":1, "category":"construction"},
	{"name":"Стрелы", "inputs":{"wood":2,"metal":1}, "output":"arrows", "count":10},
	{"name":"Зелье маны", "inputs":{"crystal":1,"berries":1}, "output":"mana_potion", "count":1},
	{"name":"Зелье энергии", "inputs":{"nut":2,"orange":1}, "output":"energy_potion", "count":1},
	{"name":"Зелье невидимости", "inputs":{"ectoplasm":1,"mushroom":2}, "output":"invisibility_potion", "count":1},
	{"name":"Зелье силы", "inputs":{"raw_meat":1,"nut":2}, "output":"strength_potion", "count":1},
	{"name":"Зелье регенерации", "inputs":{"berries":3,"mushroom":2}, "output":"regeneration_potion", "count":1},
	{"name":"Зелье скорости", "inputs":{"lizard_scale":1,"mushroom":1}, "output":"speed_potion", "count":1},
	{"name":"Зелье защиты", "inputs":{"stone":2,"metal":1}, "output":"defense_potion", "count":1},
	{"name":"Крепкая верёвка", "inputs":{"fiber":2}, "output":"rope", "count":1},
	{"name":"Мука", "inputs":{"wheat":2}, "output":"flour", "count":1,"station":"cauldron","category":"food"},
	{"name":"Сливочное масло", "inputs":{"milk":2}, "output":"butter", "count":1,"station":"cauldron","category":"food"},
	{"name":"Домашний сыр", "inputs":{"milk":3}, "output":"cheese", "count":1,"station":"cauldron","category":"food"},
	{"name":"Деревенский хлеб", "inputs":{"flour":2}, "output":"bread", "count":1,"station":"cauldron","category":"food"},
	{"name":"Яблочный пирог", "inputs":{"apple":2,"flour":1,"butter":1}, "output":"pie", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"name":"Ягодное варенье", "inputs":{"berries":3,"honey":1}, "output":"jam", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"name":"Овощной суп", "inputs":{"carrot":1,"potato":1,"onion":1}, "output":"soup", "count":1, "station":"cauldron","category":"food"},
	{"name":"Омлет с зеленью", "inputs":{"egg":2,"milk":1}, "output":"omelet", "count":1, "station":"cauldron","category":"food"},
	{"name":"Кукурузный хлеб", "inputs":{"corn":2,"flour":1}, "output":"cornbread", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"name":"Полевой букет", "inputs":{"flower":3,"fiber":1}, "output":"bouquet", "count":1},
	{"name":"Дубовый стол", "inputs":{"plank":6,"nails":4}, "output":"rustic_table", "count":1, "category":"construction"},
	{"name":"Резной стул", "inputs":{"plank":3,"nails":2}, "output":"wooden_chair", "count":1, "category":"construction"},
	{"name":"Тканый ковёр", "inputs":{"cloth":2,"yarn":1}, "output":"woven_rug", "count":1},
	{"name":"Папоротник в горшке", "inputs":{"fiber":2,"flower":2,"stone":1}, "output":"potted_fern", "count":1},
	{"name":"Деревянный шкаф", "inputs":{"plank":10,"nails":8}, "output":"wooden_wardrobe", "count":1, "category":"construction"},
	{"name":"Секции забора", "inputs":{"plank":2,"nails":4}, "output":"fence_kit", "count":8, "category":"construction"},
	{"name":"Набор калитки", "inputs":{"plank":3,"nails":4}, "output":"gate_kit", "count":1, "category":"construction"},
	{"name":"Походный котелок", "inputs":{"metal":5,"stone":3}, "output":"cauldron", "count":1, "talent":"farm_cooking"},
	{"name":"Улучшенная удочка", "inputs":{"plank":2,"metal":3,"fiber":2}, "output":"advanced_fishing_rod", "count":1, "talents":["fish_fine_rod","craft_apprentice"]},
	{"name":"Крабовая ловушка", "inputs":{"plank":3,"rope":2,"nails":2}, "output":"crab_trap", "count":1, "talent":"fish_crab_traps", "category":"construction"},
	{"name":"Фруктовый саженец", "inputs":{"wood":2,"rare_seeds":1}, "output":"fruit_sapling", "count":1, "talent":"farm_orchard"},
	{"name":"Корм для двора","inputs":{"wheat":2,"fiber":1},"output":"animal_feed","count":2,"category":"processing"},
	{"name":"Домашний майонез","inputs":{"egg":1},"output":"mayonnaise","count":1,"station":"cauldron","category":"food"},
	{"name":"Молочные блинчики","inputs":{"flour":1,"egg":1,"milk":1},"output":"pancakes","count":1,"station":"cauldron","category":"food"},
	{"name":"Молочная каша","inputs":{"wheat":2,"milk":1},"output":"porridge","count":1,"station":"cauldron","category":"food"},
	{"name":"Трюфельная похлёбка","inputs":{"truffle":1,"milk":1,"mushroom":1},"output":"truffle_soup","count":1,"station":"cauldron","category":"food","talent":"farm_cooking"},
	{"name":"Пряжа","inputs":{"wool":1},"output":"yarn","count":2,"category":"processing"},
	{"name":"Ткань","inputs":{"yarn":2,"cotton":1},"output":"cloth","count":1,"category":"processing"},
]
const MAX_BATCH := 99

const Alchemy := preload("res://scripts/systems/alchemy_system.gd")
const Furnace := preload("res://scripts/systems/furnace_system.gd")
static var RECIPES: Array = BASE_RECIPES + preload("res://scripts/systems/alchemy_recipe_data.gd").recipes() + Furnace.Data.recipes()

## Разделяет точный расход кухонных продуктов и экономию сырья ремесленного таланта на верстаке.
static func material_cost(game: Node, recipe: Dictionary, kind: String) -> int:
	return int(recipe.inputs[kind]) if recipe.get("station","workbench")!="workbench" else game.TalentSystem.recipe_material_cost(game,int(recipe.inputs[kind]))

## Возвращает индексы рецептов, относящихся к открытому верстаку или котелку.
static func visible_indices(game: Node) -> Array[int]:
	var result: Array[int] = []
	for index in RECIPES.size():
		if String(RECIPES[index].get("station", "workbench")) == game.crafting_station:
			var filter_id:=String(game.get_meta("alchemy_filter","all"))
			if game.crafting_station!="alchemy" or filter_id=="all" or RECIPES[index].get("alchemy_group","")==filter_id: result.append(index)
	return result

## Открывает нужную станцию и выбирает первый относящийся к ней рецепт.
static func open(game: Node, station: String = "workbench") -> void:
	game.crafting_open = true
	game.crafting_station = station
	var visible := visible_indices(game)
	game.crafting_selected = visible[0] if not visible.is_empty() else 0
	for index in visible:
		if game.TalentSystem.recipe_unlocked(game,RECIPES[index]): game.crafting_selected=index; break
	for index in visible:
		if can_craft(game,RECIPES[index]): game.crafting_selected=index; break
	game.clear_movement_keys()
	game.message = game.LocaleSystem.text("recipe_select")

## Обрабатывает клавиатуру и геймпад общего окна верстака или котелка.
static func handle_input(game: Node, event: InputEvent) -> void:
	if game.crafting_station=="furnace" and Furnace.handle_controls(game,event): return
	var move_offset := 0
	var accept := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB and game.crafting_station=="alchemy": Alchemy.cycle_filter(game,-1 if event.shift_pressed else 1); return
		if event.keycode in [KEY_ESCAPE, KEY_C]: game.crafting_open = false
		elif event.keycode == KEY_UP: move_offset = -1
		elif event.keycode == KEY_DOWN: move_offset = 1
		elif event.keycode in [KEY_ENTER, KEY_E]:
			if event.shift_pressed: craft_many(game, game.crafting_selected, max_craftable(game, RECIPES[game.crafting_selected])); game.queue_redraw(); return
			accept = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER] and game.crafting_station=="alchemy": Alchemy.cycle_filter(game,-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1); return
		if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_Y]: game.crafting_open = false
		elif event.button_index == JOY_BUTTON_DPAD_UP: move_offset = -1
		elif event.button_index == JOY_BUTTON_DPAD_DOWN: move_offset = 1
		elif event.button_index == JOY_BUTTON_A: accept = true
		elif event.button_index == JOY_BUTTON_X: craft_many(game, game.crafting_selected, max_craftable(game, RECIPES[game.crafting_selected])); game.queue_redraw(); return
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
	if position.x < 210.0 or position.x > 680.0 or position.y < 164.0 or position.y >= 551.0:
		return -1
	var visible := visible_indices(game)
	var selected_position := maxi(visible.find(game.crafting_selected), 0)
	var first_position := clampi(selected_position - 4, 0, maxi(0, visible.size() - 9))
	var visible_position := first_position + int((position.y - 164.0) / 43.0)
	return visible[visible_position] if visible_position >= 0 and visible_position < visible.size() else -1

## Проверяет условие «возможности крафта» без изменения состояния.
static func can_craft(game: Node, recipe: Dictionary) -> bool:
	if recipe.get("station","workbench")!=game.crafting_station: return false
	if game.crafting_station=="furnace" and not Furnace.can_enqueue(game,recipe): return false
	if game.crafting_station=="alchemy" and (not Alchemy.at_station(game) or not Alchemy.unlocked(game,recipe)): return false
	if not game.TalentSystem.recipe_unlocked(game, recipe):
		return false
	if recipe.output == "home_chest" and game.home_chest_owned:
		return false
	for kind in recipe.inputs:
		if game.inventory_item_count(kind) < material_cost(game,recipe,kind): return false
	return true

## Вычисляет число полных партий рецепта, доступных из текущего запаса материалов.
static func max_craftable(game: Node, recipe: Dictionary) -> int:
	if not can_craft(game,recipe) or recipe.inputs.is_empty(): return 0
	if recipe.output == "home_chest" and game.home_chest_owned: return 0
	var result := MAX_BATCH
	for kind in recipe.inputs:
		var cost := material_cost(game,recipe,kind)
		result = mini(result, floori(float(game.inventory_item_count(kind)) / float(maxi(cost, 1))))
	if game.crafting_station=="furnace": result=mini(result,int(Furnace.state(game).level)-Furnace.state(game).queue.size())
	return mini(result, 1) if recipe.output == "home_chest" else result

## Выполняет операцию «крафта» и возвращает результат согласно контракту метода.
static func craft(game: Node, index: int) -> bool:
	if index < 0 or index >= RECIPES.size(): return false
	var recipe: Dictionary = RECIPES[index]
	if game.crafting_station=="furnace" and recipe.get("station","")=="furnace": return Furnace.enqueue(game,recipe)
	if recipe.get("station","workbench")!=game.crafting_station:
		game.message=game.LocaleSystem.ui("craft_wrong_station",[station_name(game,String(recipe.get("station","workbench")))]); return false
	if not game.TalentSystem.recipe_unlocked(game, recipe):
		game.message = game.LocaleSystem.ui("craft_locked")
		return false
	if recipe.output == "home_chest" and game.home_chest_owned:
		game.message = game.LocaleSystem.text("chest_already_owned")
		return false
	if not can_craft(game, recipe):
		game.message = production_summary(game,recipe) if game.crafting_station=="alchemy" else game.LocaleSystem.text("needs", [ingredients_text(game, recipe)])
		return false
	for kind in recipe.inputs: game.change_inventory_count(kind, -material_cost(game,recipe,kind))
	if not game.state.player.profile.has("workbench_crafts"): game.state.player.profile.workbench_crafts=game.state.player.craft_count
	if game.crafting_station=="workbench": game.state.player.profile.workbench_crafts=int(game.state.player.profile.workbench_crafts)+1
	game.state.player.craft_count += 1
	var crafted_count: int = int(recipe.count)
	if game.crafting_station=="workbench" and game.TalentSystem.has(game, "craft_master") and int(game.state.player.profile.workbench_crafts) % 5 == 0:
		crafted_count += int(recipe.count)
	game.change_inventory_count(recipe.output, crafted_count)
	if recipe.output == "home_chest": game.StorageSystem.install(game)
	if game.crafting_station=="alchemy": Alchemy.record_craft(game,recipe)
	else:
		game.award_xp(4)
		game.SkillSystem.award_profession_xp(game,"farming" if game.crafting_station=="cauldron" else "smithing",3 if game.crafting_station=="cauldron" else 6)
	game.message = game.LocaleSystem.text("crafted", [game.inventory_item_name(recipe.output)])
	game.play_sfx("craft")
	game.notify_tutorial("craft_window")
	if recipe.output in ["plank","nails"]: game.notify_tutorial("lumber_process")
	if recipe.output=="animal_feed": game.notify_tutorial("animal_feed_recipe")
	if recipe.output in ["yarn","cloth","woven_rug"]: game.notify_tutorial("textile_chain")
	if game.crafting_station == "cauldron": game.notify_tutorial("cooking")
	return true

## Создаёт несколько полных партий одного рецепта, останавливаясь до первого недоступного повтора.
static func craft_many(game: Node, index: int, requested: int) -> int:
	if index < 0 or index >= RECIPES.size(): return 0
	var crafted_batches := 0
	var target: int = mini(maxi(requested, 0), max_craftable(game, RECIPES[index]))
	for _batch in target:
		if not craft(game, index): break
		crafted_batches += 1
	if crafted_batches > 1:
		game.message = game.LocaleSystem.ui("furnace_queued_many",[crafted_batches]) if game.crafting_station=="furnace" else game.LocaleSystem.text("crafted_many", [game.inventory_item_name(RECIPES[index].output), crafted_batches])
	return crafted_batches

## Возвращает понятное назначение рецепта для карточки выбранного изделия.
static func category_name(game: Node, recipe: Dictionary) -> String:
	if recipe.get("station","")=="furnace": return game.LocaleSystem.ui("furnace_service")
	if recipe.get("station","")=="alchemy": return game.LocaleSystem.ui("alchemy_"+String(recipe.alchemy_group))
	if recipe.get("station","workbench")=="cauldron": return game.LocaleSystem.ui("craft_category_food")
	var category: String = String(recipe.get("category", "general"))
	return game.LocaleSystem.ui("craft_category_%s" % category)

## Описывает выход партии и возможное число повторов для подробной карточки рецепта.
static func production_summary(game: Node, recipe: Dictionary) -> String:
	if recipe.get("station","")=="furnace": return Furnace.summary(game,recipe)
	if recipe.get("station","")=="alchemy":
		if not Alchemy.at_station(game): return game.LocaleSystem.ui("alchemy_station_need")
		if Alchemy.rank(game)<int(recipe.alchemy_rank): return game.LocaleSystem.ui("alchemy_rank_need",[recipe.alchemy_rank,Alchemy.rank(game)])
		if recipe.get("laboratory",false) and game.state.world.estate.level<4: return game.LocaleSystem.ui("alchemy_lab_need")
		for kind in recipe.inputs:
			if game.inventory_item_count(kind)<int(recipe.inputs[kind]): return game.LocaleSystem.text("needs",[ingredients_text(game,recipe)])
	if not game.TalentSystem.recipe_unlocked(game,recipe): return game.LocaleSystem.ui("craft_locked")
	if recipe.get("station","workbench")!=game.crafting_station: return game.LocaleSystem.ui("craft_wrong_station",[station_name(game,String(recipe.get("station","workbench")))])
	var summary:String=game.LocaleSystem.ui("craft_output_summary", [int(recipe.count), max_craftable(game, recipe)])
	if not recipe.get("byproducts",{}).is_empty(): summary=game.LocaleSystem.ui("alchemy_batch_summary",[int(recipe.count),max_craftable(game,recipe)])
	for kind in recipe.get("byproducts",{}): summary+="\n"+game.LocaleSystem.ui("alchemy_byproduct",[game.inventory_item_name(kind),recipe.byproducts[kind]])
	return summary

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func ingredients_text(game: Node, recipe: Dictionary, compact:bool=false) -> String:
	var parts: Array[String] = []
	for kind in recipe.inputs:
		var item_name:String=game.LocaleSystem.crafting_ingredient(String(kind)) if compact else game.inventory_item_name(kind)
		parts.append("%s %d/%d" % [item_name, game.inventory_item_count(kind), material_cost(game,recipe,kind)])
	return ", ".join(parts)

## Даёт строке рецепта и аудиту одинаковое краткое описание без нечитаемой длинной смеси.
static func row_ingredients_text(game: Node, recipe: Dictionary) -> String:
	if recipe.get("station","")=="furnace" and recipe.inputs.size()>1: return game.LocaleSystem.ui("furnace_mix",[recipe.inputs.size(),recipe.furnace_level])
	return game.LocaleSystem.ui("alchemy_mix_summary",[recipe.inputs.size(),recipe.alchemy_rank]) if recipe.get("station","")=="alchemy" and recipe.inputs.size()>1 else ingredients_text(game,recipe,true)


## Называет физическую станцию для ошибки рецепта без неверного упоминания верстака.
static func station_name(game: Node, station: String) -> String:
	if station=="furnace": return game.LocaleSystem.ui("furnace_service")
	return game.LocaleSystem.ui("alchemy_service" if station=="alchemy" else ("cauldron_title" if station=="cauldron" else "workbench"))
