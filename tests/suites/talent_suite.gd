extends "res://tests/suites/suite_base.gd"

## Запускает сценарии дерева талантов и открываемых им игровых механик.
func run() -> void:
	test_dependent_talent_tree_and_permanent_effects()
	test_talent_unlocks_farming_fishing_cooking_and_traps()
	test_multirank_localization_respec_and_balance_debug()


## Сценарий: очко общего уровня открывает только доступный узел, а изученные боевые таланты постоянно меняют характеристики.
## Исходное состояние: герой второго уровня с тремя свободными очками и полностью закрытым деревом способностей.
## Ожидаемый результат: зависимость блокирует преждевременную покупку, после корневых узлов растут урон, скорость и здоровье.
func test_dependent_talent_tree_and_permanent_effects() -> void:
	var game := make_game()
	game.skill_points = 3
	var base_hp: int = game.player_max_hp
	expect(not game.TalentSystem.unlock(game, "combat_vitality") and game.skill_points == 3, "dependent talent cannot bypass its strength prerequisite")
	expect(game.TalentSystem.unlock(game, "combat_strength"), "root strength talent spends one common level point")
	expect(game.TalentSystem.unlock(game, "combat_vitality"), "vitality becomes available after strength")
	expect(game.TalentSystem.unlock(game, "combat_agility"), "independent agility branch can use the remaining point")
	expect(game.TalentSystem.combat_damage_bonus(game) == 1 and is_equal_approx(game.TalentSystem.movement_multiplier(game), 1.04), "combat talents expose rank-scaled damage and movement bonuses")
	expect(game.player_max_hp == base_hp + 10 and game.skill_points == 0, "vitality recalculates health and all three points are consumed")
	expect(game.tutorial_events_completed.has("talent_tree"), "first learned talent advances the dedicated tutorial")
	game.free()


## Сценарий: профессиональные ветви открывают широкую мотыгу, редкие культуры, кухню, сложную удочку и крабовую ловушку.
## Исходное состояние: герой с запасом очков и материалов находится у пруда; рецепты и весь предметный каталог загружены.
## Ожидаемый результат: способности меняют шаблон действий, создают новые предметы, ловушка приносит улов и всё сохраняется.
func test_talent_unlocks_farming_fishing_cooking_and_traps() -> void:
	var game := make_game()
	game.skill_points = 10
	expect(game.TalentSystem.unlock(game, "farm_wide_till") and game.TalentSystem.tilling_offsets(game).size() == 3, "wide furrow upgrades the hoe from one cell to three")
	expect(game.TalentSystem.unlock(game, "farm_field_master") and game.TalentSystem.tilling_offsets(game).size() == 9, "dependent field mastery upgrades the hoe to a three by three pattern")
	game.current_location = "forest"; game.energy = 12
	var field_center := Vector2i(-1, -1)
	for y in range(4, 20):
		for x in range(4, 40):
			var candidate := Vector2i(x, y)
			var all_clear := true
			for offset in game.TalentSystem.tilling_offsets(game):
				if game.WorldFarmingSystem.tillability_reason(game, "forest", candidate + offset) != "tillable": all_clear = false; break
			if all_clear: field_center = candidate; break
		if field_center.x >= 0: break
	var field_target := {"valid":true,"legacy":false,"cell":field_center,"key":game.WorldFarmingSystem.plot_key("forest",field_center),"rect":game.WorldFarmingSystem.cell_rect(field_center),"reason":"tillable"}
	expect(field_center.x >= 0 and game.WorldFarmingSystem.till_pattern(game, field_target) == 9 and game.state.world.world_plots.size() == 9, "field mastery actually creates nine persistent plots in one action")
	expect(not game.TalentSystem.can_plant_crop(game, "pumpkin"), "rare crop remains locked before orchard progression")
	expect(game.TalentSystem.unlock(game, "farm_orchard") and game.TalentSystem.unlock(game, "farm_exotic_crops") and game.TalentSystem.can_plant_crop(game, "pumpkin"), "orchard dependency unlocks rare crops")
	expect(game.TalentSystem.unlock(game, "farm_cooking"), "home cooking is an independent farming specialization")
	game.state.inventory.set_count("metal", 8); game.state.inventory.set_count("stone", 8)
	var cauldron_recipe: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "cauldron")
	expect(game.CraftingSystem.craft(game, cauldron_recipe) and game.inventory_item_count("cauldron") == 1, "cooking talent unlocks the portable cauldron recipe")
	game.hotbar_slots[0] = "cauldron"; game.selected_hotbar = 0
	expect(game.use_active_item() and game.crafting_open and game.crafting_station == "cauldron", "cauldron opens a separate cooking recipe station from the hotbar")
	var first_cooking_recipe: int = game.crafting_selected
	game.handle_crafting_input(joypad_button_event(JOY_BUTTON_DPAD_DOWN, true))
	expect(game.crafting_selected != first_cooking_recipe and game.crafting_recipe_at(Vector2(240, 180)) >= 0, "cauldron recipes are selectable by gamepad and share their hit rows with touch")
	game.crafting_open = false
	expect(game.TalentSystem.unlock(game, "fish_fine_rod") and game.TalentSystem.unlock(game, "fish_deep_water"), "fine tackle is required before deep-water fishing")
	expect(not game.TalentSystem.can_catch_fish(game, game.FishingSystem.fish_data("deep_pike")), "deep pike still requires the advanced physical rod")
	expect(game.TalentSystem.unlock(game, "craft_apprentice"), "craft apprentice opens advanced devices")
	game.state.inventory.set_count("wood", 12); game.state.inventory.set_count("metal", 8); game.state.inventory.set_count("fiber", 8)
	var rod_recipe: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "advanced_fishing_rod")
	expect(game.CraftingSystem.craft(game, rod_recipe) and game.TalentSystem.can_catch_fish(game, game.FishingSystem.fish_data("deep_pike")), "advanced rod recipe makes deep fish eligible")
	expect(game.TalentSystem.unlock(game, "fish_crab_traps"), "crab trap branch can be learned independently")
	game.state.inventory.set_count("crab_trap", 1); game.current_location = "overworld"; game.player = game.pond_position + Vector2(120, 0); game.facing = Vector2.LEFT
	expect(game.FishingSystem.use_crab_trap(game) and game.state.fishing.traps.size() == 1 and game.inventory_item_count("crab_trap") == 0, "placing a trap consumes its portable item and records a world object")
	game.day += 1
	expect(game.FishingSystem.use_crab_trap(game) and game.inventory_item_count("crab") == 1 and game.player_xp >= 8, "ready trap grants crab common XP and fishing mastery")
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	var loaded := make_game()
	expect(loaded.SaveSystem.apply(loaded, snapshot) and loaded.talent_levels.fish_crab_traps == 1 and loaded.state.fishing.traps.size() == 1, "talent tree and persistent trap survive save roundtrip")
	loaded.free()
	game.free()


## Сценарий: отдельные способности имеют несколько рангов, весь интерфейс локализован, а платный сброс возвращает очки.
## Исходное состояние: герой с четырьмя очками, пятьюстами монетами и открытой диагностической панелью.
## Ожидаемый результат: ранги суммируют эффект, тексты существуют на шести языках, сброс очищает билд и баланс отражает состояние.
func test_multirank_localization_respec_and_balance_debug() -> void:
	var game := make_game(); game.skill_points = 4; game.coins = game.TalentSystem.RESPEC_COST; var original_hp: int = game.player_max_hp
	expect(game.TalentSystem.max_rank("combat_strength") == 3 and game.TalentSystem.unlock(game,"combat_strength") and game.TalentSystem.unlock(game,"combat_strength"), "strength accepts a second rank instead of treating the node as binary")
	expect(game.TalentSystem.rank(game,"combat_strength") == 2 and game.TalentSystem.combat_damage_bonus(game) == 2, "two strength ranks provide two permanent damage")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current = locale
		expect(not game.TalentSystem.word(game,"combat_strength").is_empty() and not game.TalentSystem.word(game,"combat_strength",true).is_empty(), "talent name and description are localized for %s" % locale)
	game.LocaleSystem.current = "ru"
	var balance: Dictionary = game.DebugBalanceSystem.snapshot(game)
	expect(balance.damage == game.CombatSystem.player_attack_damage(game) and balance.spent_points == 2 and balance.xp_sources.has("крафт"), "debug balance snapshot reports live build and XP source data")
	game.DebugOverlaySystem.toggle(game); var debug_state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	expect(game.DebugOverlaySystem.handle_pointer(game,Rect2(794,454,150,28).get_center()) and bool(game.get_meta(game.DebugOverlaySystem.META_KEY).balance), "F10 balance button enables the live diagnostic card")
	expect(game.TalentSystem.respec(game) and game.TalentSystem.spent_points(game) == 0 and game.skill_points == 4 and game.coins == 0, "paid respec clears every rank and refunds all invested points")
	expect(game.tutorial_events_completed.has("talent_respec") and game.player_max_hp == original_hp, "respec recalculates resources and completes its tutorial step")
	game.free()
