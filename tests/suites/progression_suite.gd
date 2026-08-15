extends "res://tests/suites/suite_base.gd"

## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_character_level_skill_points_and_resource_attributes()
	test_profession_progress_and_gameplay_bonuses()
	test_progression_save_and_universal_skill_menu_input()
	test_regrowing_forage_harvest_value_and_sale()
	test_forage_atlas_cells_are_isolated_and_bottom_anchored()
	test_orchard_growth_weather_harvest_icons_and_save()
	test_seed_bag_catalog_shop_purchase_icons_and_save()
	test_crop_varieties_five_stages_seasons_regrowth_and_save()
	test_new_pixel_items_watermelon_shield_potion_and_lizard()
	test_animated_enemy_sprites_replace_primitives()
	test_unbounded_scrolling_inventory_and_forage_save()

## Сценарий: новый уровень выдаёт очко, а навыки здоровья, маны и выносливости меняют характеристики.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_character_level_skill_points_and_resource_attributes() -> void:
	var game := make_game()
	game.award_xp(50, "Проверка уровня")
	expect(game.player_level == 2 and game.player_xp == 0, "first RPG level requires fifty experience")
	expect(game.skill_points == 1 and game.SkillSystem.xp_to_next_character_level(2) == 75, "level grants a skill point and next threshold grows")
	expect(game.SkillSystem.allocate(game, "vitality"), "skill point can be assigned to vitality")
	expect(game.player_max_hp == 120 and game.skill_levels.vitality == 1, "vitality rank increases maximum health on top of level bonus")
	game.skill_points = 2
	game.player_mana = 1
	expect(game.SkillSystem.allocate(game, "mana"), "mana can be upgraded")
	expect(game.player_max_mana == 50 and game.player_mana == 11, "mana rank expands and refills the mana pool")
	var old_stamina_max: int = game.SkillSystem.max_stamina(game)
	expect(game.SkillSystem.allocate(game, "stamina"), "stamina can be upgraded")
	expect(game.SkillSystem.max_stamina(game) == old_stamina_max + 2, "stamina rank expands the action resource")
	game.player_mana = 0
	game.energy = 0
	game.SkillSystem.update_resources(game, 4.1)
	expect(game.player_mana > 0 and game.energy == 1, "mana and stamina recover over real time")
	game.free()

## Сценарий: практика развивает ремёсла, а ранги усиливают урожай, добычу, бой, рыбалку и крафт.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_profession_progress_and_gameplay_bonuses() -> void:
	var game := make_game()
	game.skill_xp.farming = 19
	expect(game.SkillSystem.award_profession_xp(game, "farming", 1), "profession practice raises its rank")
	expect(game.skill_levels.farming == 1 and game.skill_xp.farming == 0, "profession XP rolls into the next rank")
	game.skill_levels.farming = 3
	expect(game.SkillSystem.harvest_count(game) == 2, "farmer rank three grants extra harvest")
	game.skill_levels.mining = 3
	expect(game.SkillSystem.mined_count(game) == 2, "mining rank three grants extra ore")
	game.skill_levels.smithing = 3
	expect(game.SkillSystem.material_cost(game, 4) == 3, "smithing rank three discounts recipe materials")
	game.skill_levels.combat = 4
	expect(game.SkillSystem.combat_bonus(game) == 2, "combat ranks increase damage")
	game.skill_levels.fishing = 3
	expect(game.SkillSystem.fishing_wait(game) < 2.5, "fishing ranks shorten bite wait")
	game.current_location = "cave"
	game.selected_tool = game.Tool.PICKAXE
	game.player = game.resource_nodes[2].position
	game.mine_resource(2)
	expect(game.crystals == 2 and game.skill_xp.mining == 3 and game.player_xp == 1, "mining action applies yield bonus and both XP tracks")
	game.free()

## Сценарий: прогресс навыков сохраняется, а окно развития работает с клавиатурой, геймпадом и касанием.
## Исходное состояние: новая игра, изменённое сценарием состояние и отдельный тестовый путь сохранения.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_progression_save_and_universal_skill_menu_input() -> void:
	var game := make_game()
	game.skill_points = 2
	game.talent_levels.combat_strength = 1
	game.skill_levels.vitality = 2
	game.skill_levels.smithing = 1
	game.skill_xp.smithing = 9
	game.player_mana = 17
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.skill_points = 0
	game.talent_levels.combat_strength = 0
	game.skill_levels.vitality = 0
	game.skill_xp.smithing = 0
	game.player_mana = 0
	game.SaveSystem.apply(game, snapshot)
	expect(game.skill_points == 2 and game.skill_levels.vitality == 2 and game.talent_levels.combat_strength == 1, "save restores free points skill ranks and learned talents")
	expect(game.skill_xp.smithing == 9 and game.player_mana == 17, "save restores profession XP and current mana")
	game.open_skill_menu()
	expect(game.skill_menu_open, "K action opens the skill window")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	game.skill_menu_selected = 1
	game.handle_skill_menu_input(accept)
	expect(game.talent_levels.combat_agility == 1 and game.skill_points == 1, "gamepad assigns a selected root talent point")
	game.skill_menu_open = false
	var touch := InputEventScreenTouch.new()
	touch.position = game.InterfaceRenderer.SKILL_BUTTON.get_center()
	touch.pressed = true
	expect(game.handle_gamepad_and_touch(touch) and game.skill_menu_open, "touch HUD button opens character development")
	var talent_mouse := InputEventMouseButton.new()
	talent_mouse.button_index = MOUSE_BUTTON_LEFT
	talent_mouse.position = game.TalentRenderer.node_rect(3).get_center()
	talent_mouse.pressed = true
	expect(game.TalentRenderer.node_at(talent_mouse.position) == 3 and game.handle_gamepad_and_touch(talent_mouse), "tree uses one shared node geometry for rendering and pointer input")
	expect(game.talent_levels.combat_power_strike == 1 and game.skill_points == 0, "mouse click learns an available dependent talent without leaking through to the HUD")
	var legacy_snapshot: Dictionary = snapshot.duplicate(true)
	legacy_snapshot.erase("progression")
	game.SaveSystem.apply(game, legacy_snapshot)
	expect(game.skill_points == 0 and game.skill_levels.vitality == 0, "older saves migrate to default RPG skills")
	game.free()

## Сценарий: дикорастущие растения созревают по разным срокам, восстанавливаются и продаются по своей цене.
## Исходное состояние: новая игра с исходными грядками, растениями и нулевым прогрессом проверяемых таймеров.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_regrowing_forage_harvest_value_and_sale() -> void:
	var game := make_game()
	var forage: Dictionary = game.ForageSystem.TYPES
	expect(forage.berries.growth_minutes < forage.mushroom.growth_minutes and forage.mushroom.growth_minutes < forage.apple.growth_minutes and forage.apple.growth_minutes < forage.nut.growth_minutes, "forage crops have increasing hour and day growth times")
	expect(forage.berries.sell < forage.mushroom.sell and forage.mushroom.sell < forage.apple.sell and forage.apple.sell < forage.nut.sell, "slower forage crops sell for progressively more")
	var berry_index := 1
	game.player = game.food_nodes[berry_index].position
	var harvest_time: float = game.ForageSystem.total_minutes(game)
	expect(game.collect_food(berry_index), "ripe berry bush can be harvested with context action")
	expect(game.berries == 3 and not game.food_nodes[berry_index].active, "berry harvest enters inventory and empties the bush")
	expect(is_equal_approx(game.food_nodes[berry_index].ready_at, harvest_time + 360.0), "berry bush schedules regrowth in six game hours")
	game.game_minutes += 359.0
	game.ForageSystem.update(game)
	expect(not game.food_nodes[berry_index].active, "forage does not regrow before its timer")
	game.game_minutes += 2.0
	game.ForageSystem.update(game)
	expect(game.food_nodes[berry_index].active and game.tutorial_events_completed.has("forage_regrow"), "forage becomes harvestable after enough game time")
	game.shop_selected = 2
	var coins_before: int = game.coins
	expect(game.sell_selected_product(), "shop buys harvested berries")
	expect(game.coins == coins_before + forage.berries.sell and game.tutorial_events_completed.has("forage_sale"), "forage sale uses growth-based price and tutorial event")
	var apple: Dictionary = game.food_nodes[3]
	expect(not game.NavigationSystem.is_walkable(game, apple.position), "fruit trees remain solid world obstacles")
	game.current_location = "forest"
	game.player = game.food_nodes[4].position
	expect(game.collect_food(4), "forest berry bushes are harvestable outside the village")
	game.free()

## Сценарий: растения используют отдельные ячейки атласа и правильно привязаны к земле.
## Исходное состояние: новая игра с исходными грядками, растениями и нулевым прогрессом проверяемых таймеров.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_forage_atlas_cells_are_isolated_and_bottom_anchored() -> void:
	var game := make_game()
	var texture_size: Vector2 = game.PLANT_SHEET.get_size()
	var occupied_cells: Array[Rect2] = []
	for kind in ["berries", "apple", "nut"]:
		var layout: Dictionary = game.forage_sprite_layout(kind, Vector2(500, 400))
		var source: Rect2 = layout.source
		var destination: Rect2 = layout.destination
		expect(source.size == Vector2(72, 72), "%s uses one exact atlas cell without neighbouring tree parts" % kind)
		expect(source.position.x >= 0.0 and source.position.y >= 0.0 and source.end.x <= texture_size.x and source.end.y <= texture_size.y, "%s atlas cell stays inside the plant texture" % kind)
		expect(is_equal_approx(destination.get_center().x, 500.0) and is_equal_approx(destination.end.y, 418.0), "%s sprite remains centred and bottom-anchored to its world position" % kind)
		for occupied in occupied_cells:
			expect(not source.intersects(occupied), "%s uses an isolated growth-stage cell" % kind)
		occupied_cells.append(source)
	expect(game.forage_sprite_layout("mushroom", Vector2.ZERO).is_empty(), "separate mushroom texture does not accidentally sample the plant atlas")
	game.free()


## Сценарий: новые яблоня, груша, вишня и слива используют четыре стадии, погоду, урожай и сохранение.
## Исходное состояние: новая игра содержит молодой сад, зрелые лесные деревья и отдельные иконки трёх новых плодов.
## Ожидаемый результат: стадии не пересекаются в атласе, дерево взрослеет, зимой отдыхает, весной собирается и точно загружается.
func test_orchard_growth_weather_harvest_icons_and_save() -> void:
	var game := make_game(); var orchard = game.OrchardSystem
	expect(orchard.TREE_ATLAS.get_size() == Vector2(1024,1024), "fruit tree atlas is normalized to four strict rows and columns")
	var occupied: Array[Rect2] = []
	for kind in ["apple","pear","cherry","plum"]:
		for stage in 4:
			var source: Rect2 = orchard.source_rect(kind,stage)
			expect(source.size == Vector2(256,256), "%s stage %d uses one exact integer atlas cell" % [kind,stage])
			for previous in occupied: expect(not source.intersects(previous), "%s stage %d does not bleed into another tree cell" % [kind,stage])
			occupied.append(source)
	var anchor: Rect2 = orchard.destination_rect(Vector2(500,400),3)
	expect(anchor.get_center().x == 500.0 and anchor.end.y == 418.0, "all mature fruit trees share one centered ground anchor")
	var orchard_sizes := [Vector2(72,72),Vector2(120,120),Vector2(168,168),Vector2(192,192)]
	for stage in 4: expect(orchard.destination_rect(Vector2(500,400),stage).size == orchard_sizes[stage], "fruit tree stage %d follows the shared modular profile" % stage)
	expect(orchard.weather_tint("summer","clear") != orchard.weather_tint("autumn","clear") and orchard.weather_tint("winter","snow") != Color.WHITE, "season and weather select visibly different tree palettes")
	for kind in ["pear","cherry","plum"]: expect(game.VisualAssetSystem.has_item_icon(kind), "%s has a standalone centred inventory icon" % kind)
	var pear_index: int = game.food_nodes.find_custom(func(node): return node.kind == "pear" and node.location == "overworld")
	var pear: Dictionary = game.food_nodes[pear_index]; game.game_minutes = pear.ready_at + 1.0
	game.ForageSystem.update(game)
	expect(game.food_nodes[pear_index].stage == 1 and not game.food_nodes[pear_index].active, "young pear advances by exactly one visible growth stage")
	var cherry_index: int = game.food_nodes.find_custom(func(node): return node.kind == "cherry" and node.location == "forest")
	game.current_location = "forest"; game.player = game.food_nodes[cherry_index].position; game.day = 22
	expect(not game.collect_food(cherry_index) and game.inventory_item_count("cherry") == 0, "winter blocks fruit harvest even from a previously mature tree")
	game.day = 29; game.state.world.weather_day = 29; game.state.world.weather = "clear"
	expect(game.collect_food(cherry_index) and game.inventory_item_count("cherry") == 4, "spring harvest grants the configured cherry yield")
	expect(game.tutorial_events_completed.has("orchard_trees") and game.LocaleSystem.TUTORIAL.orchard_trees.size() == 6, "first orchard harvest completes its six-language tutorial step")
	var cherry_data: Dictionary = game.ForageSystem.TYPES.cherry
	expect(game.food_nodes[cherry_index].stage == 3 and not game.food_nodes[cherry_index].active, "harvest keeps the cherry tree permanently adult")
	expect(orchard.visual_stage(game,game.food_nodes[cherry_index],cherry_data) == 1, "freshly harvested adult tree uses the leafy crown without cherries")
	game.food_nodes[cherry_index].ready_at = game.ForageSystem.total_minutes(game) + cherry_data.growth_minutes * 0.4
	expect(orchard.visual_stage(game,game.food_nodes[cherry_index],cherry_data) == 2, "late fruit cycle switches the same adult tree from leaves to flowering")
	var snapshot: Dictionary = game.SaveSystem.snapshot(game); var loaded := make_game()
	expect(loaded.SaveSystem.apply(loaded,snapshot), "orchard snapshot loads through the common save system")
	expect(loaded.food_nodes[cherry_index].stage == 3 and loaded.food_nodes[cherry_index].ready_at == game.food_nodes[cherry_index].ready_at and loaded.inventory_item_count("cherry") == 4, "adult tree, fruit timer and harvested items survive save roundtrip")
	game.free(); loaded.free()

## Сценарий: арбуз, зелье, щит и луговой ящер работают в сборе, крафте, употреблении, бою и сохранении.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_new_pixel_items_watermelon_shield_potion_and_lizard() -> void:
	var game := make_game()
	expect(game.VisualAssetSystem.POTION_ATLAS.get_size() == Vector2(1254, 1254) and game.ITEM_OAK_SHIELD.get_size() == Vector2(64, 64), "potion atlas and shield are imported game textures")
	expect(game.ITEM_WATERMELON.get_size() == Vector2(64, 64) and game.ITEM_WATERMELON_SLICE.get_size() == Vector2(64, 64), "whole and sliced watermelon sprites are available")
	expect(game.FANTASY_WILDLIFE_ATLAS.get_size() == Vector2(2172, 724), "redrawn meadow lizard shares the coherent transparent wildlife atlas")
	expect(not FileAccess.file_exists("res://assets/game/wildlife/foxpool-yoshi-5994957.png"), "trademarked Yoshi download is not distributed with the game")
	var potion_recipe: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "healing_potion")
	game.berries = 2
	game.mushrooms = 1
	expect(game.CraftingSystem.craft(game, potion_recipe) and game.inventory_item_count("healing_potion") == 1, "berries and mushroom craft one healing potion")
	game.player_hp = 25
	expect(game.consume_item("healing_potion") and game.player_hp == 85 and game.tutorial_events_completed.has("potion"), "healing potion restores sixty HP and completes its tutorial step")
	var shield_recipe: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "oak_shield")
	game.wood = 4
	game.materials.metal = 2
	expect(game.CraftingSystem.craft(game, shield_recipe) and game.inventory_item_count("oak_shield") == 1, "wood and metal craft one oak shield")
	var hp_without_shield: int = game.player_max_hp
	expect(game.InventorySystem.equip(game, "oak_shield") and game.equipment.offhand == "oak_shield", "oak shield equips into its dedicated off-hand slot")
	expect(game.player_max_hp == hp_without_shield + 5 and game.InventorySystem.incoming_damage(game, 20) == 15, "equipped shield adds resilience and blocks five incoming damage")
	game.player = game.slime_position
	game.player_hp = 100
	game.slime_attack_timer = 1.49
	game.update_combat(0.02)
	expect(game.player_hp == 85, "oak shield reduces an actual slime hit from twenty to fifteen damage")
	var watermelon_index: int = game.food_nodes.find_custom(func(node): return node.kind == "watermelon" and node.location == "overworld")
	game.player = game.food_nodes[watermelon_index].position
	expect(game.collect_food(watermelon_index) and game.inventory_item_count("watermelon") == 2, "ripe watermelon patch yields two edible watermelons")
	expect(game.tutorial_events_completed.has("watermelon") and game.shop_products.any(func(product): return product.kind == "watermelon" and product.sell == 10), "watermelon has tutorial coverage and a shop sale price")
	game.player_hp = 50
	game.energy = 5
	expect(game.consume_item("watermelon") and game.player_hp == 75 and game.energy == 9, "watermelon restores health and stamina")
	var lizard_index: int = game.wildlife_nodes.find_custom(func(animal): return animal.kind == "lizard")
	game.current_location = game.wildlife_nodes[lizard_index].location
	game.player = game.wildlife_nodes[lizard_index].position
	game.wildlife_nodes[lizard_index].hp = 1
	expect(game.WildlifeSystem.attack(game, lizard_index), "meadow lizard can be encountered and hunted")
	expect(not game.wildlife_nodes[lizard_index].alive and game.dropped_items.any(func(item): return item.kind == "lizard_scale" and item.count == 2), "meadow lizard drops two crafting scales")
	expect(game.tutorial_events_completed.has("lizard") and game.WildlifeSystem.TYPES.size() == 5, "new wildlife is documented by tutorial and registered as the fifth species")
	var legacy_snapshot: Dictionary = game.SaveSystem.snapshot(game)
	legacy_snapshot.equipment.erase("offhand")
	expect(game.SaveSystem.apply(game, legacy_snapshot) and game.equipment.has("offhand") and not game.wildlife_nodes[lizard_index].alive, "older saves migrate the shield slot while preserving lizard state")
	game.free()

## Сценарий: шестнадцать мешков семян имеют отдельные иконки, доступны в лавке и сохраняются после покупки.
## Исходное состояние: новая игра, полный каталог магазина и достаточный запас монет; предметов нового сорта в рюкзаке нет.
## Ожидаемый результат: мешки не зависят от атласной разметки интерфейса, покупка выдаёт четыре семени, уменьшает запас и переживает загрузку.
func test_seed_bag_catalog_shop_purchase_icons_and_save() -> void:
	var game := make_game()
	var seed_kinds := ["seeds", "tomato_seeds", "cabbage_seeds", "wheat_seeds", "corn_seeds", "potato_seeds", "onion_seeds", "pumpkin_seeds", "strawberry_seeds", "beet_seeds", "pepper_seeds", "cucumber_seeds", "sunflower_seeds", "cotton_seeds", "melon_seeds", "herb_seeds"]
	var seed_products: Array = game.shop_products.filter(func(product): return product.get("seed", false))
	expect(seed_products.size() == 16 and game.shop_products[0].kind == "seeds", "shop exposes all sixteen seed bags without changing the historical carrot position")
	for kind in seed_kinds:
		var texture: Texture2D = game.VisualAssetSystem.item_texture(kind)
		expect(texture != null and texture.get_size() == Vector2(256, 256), "%s has an independent centred 256px icon" % kind)
		expect(game.LocaleSystem.ITEMS.has(kind) and game.LocaleSystem.ITEMS[kind].size() == 6, "%s is translated into all six supported languages" % kind)
	var tomato_index: int = game.shop_products.find_custom(func(product): return product.kind == "tomato_seeds")
	var price: int = game.shop_products[tomato_index].buy
	game.coins = 1000
	expect(game.ShopSystem.buy(game, tomato_index), "a new seed variety can be bought from the common shop flow")
	expect(game.inventory_item_count("tomato_seeds") == 4 and game.coins == 1000 - price, "one purchase grants four tomato seed bags and charges the declared price")
	expect(game.shop_products[tomato_index].stock == 7 and game.tutorial_events_completed.has("seed_catalog"), "seed stock decreases from eight and the catalog tutorial is completed")
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	var loaded := make_game()
	expect(loaded.SaveSystem.apply(loaded, snapshot), "save with purchased seed varieties loads through the common save system")
	expect(loaded.inventory_item_count("tomato_seeds") == 4 and loaded.inventory_slots.has("tomato_seeds"), "purchased seed variety and its inventory slot survive loading")
	loaded.free()
	game.free()

## Сценарий: каждый мешок сажает собственную пятистадийную культуру, а многолетники плодоносят повторно и меняют сезонный вид.
## Исходное состояние: летний день, подготовленные грядки, по одному мешку томата и клубники и полный каталог визуальных атласов.
## Ожидаемый результат: сорт хранится в грядке и сохранении, урожай соответствует семенам, несезонная посадка блокируется, клубника остаётся взрослой.
func test_crop_varieties_five_stages_seasons_regrowth_and_save() -> void:
	var game := make_game()
	expect(game.CropCatalogSystem.CROPS.size() == 16 and game.FarmVisualSystem.CROP_LAYOUT.size() == 16, "all sixteen seed varieties own crop rules and authored sprites")
	for crop_kind in game.CropCatalogSystem.CROPS:
		var texture: Texture2D = game.FarmVisualSystem.crop_texture(crop_kind)
		for stage in 5:
			var source: Rect2 = game.FarmVisualSystem.crop_source(stage, crop_kind, "summer")
			var cell_image: Image = texture.get_image().get_region(Rect2i(Vector2i(source.position),Vector2i(source.size)))
			expect(source.size == Vector2(64,64) and source.position.x >= 0 and source.position.y >= 0 and source.end.x <= texture.get_width() and source.end.y <= texture.get_height() and cell_image.get_used_rect().has_area(), "%s stage %d is nonempty and stays inside its atlas" % [crop_kind, stage])
	var cell := Vector2i.ZERO
	var plot: Dictionary = game.plots[cell]
	plot.tilled = true; game.day = 8; game.plots[cell] = plot
	game.state.inventory.set_count("tomato_seeds", 1); game.hotbar_slots[1] = "tomato_seeds"; game.select_hotbar(1)
	expect(game.selected_tool == game.Tool.SEEDS and game.FarmSystem.plant(game, plot), "a selected tomato bag behaves as the seed tool and plants in summer")
	expect(plot.crop_kind == "tomato" and game.inventory_item_count("tomato_seeds") == 0 and game.tutorial_events_completed.has("crop_variety"), "planting records the exact variety, consumes its bag and advances tutorial")
	plot.watered = true; game.plots[cell] = plot; game.update_crops(10.1); plot = game.plots[cell]; plot.watered = true; game.plots[cell] = plot; game.update_crops(10.0); plot = game.plots[cell]
	expect(plot.stage == 4 and game.FarmSystem.harvest(game, plot) and game.inventory_item_count("tomato") == 1, "tomato crosses all five stages and yields tomato rather than carrot")
	var strawberry_cell := Vector2i(1,0); var strawberry_plot: Dictionary = game.plots[strawberry_cell]
	strawberry_plot.tilled = true; game.state.inventory.set_count("strawberry_seeds",1); game.hotbar_slots[1] = "strawberry_seeds"
	expect(game.FarmSystem.plant(game, strawberry_plot), "summer allows planting the perennial strawberry")
	strawberry_plot.growth = game.GROWTH_DURATION; strawberry_plot.stage = 4
	expect(game.FarmSystem.harvest(game, strawberry_plot) and strawberry_plot.planted and strawberry_plot.stage == 2 and game.inventory_item_count("strawberry") == 1, "strawberry harvest keeps its adult crown for a new fruit cycle")
	expect(game.tutorial_events_completed.has("perennial_crop") and game.FarmVisualSystem.crop_source(4,"strawberry","summer") != game.FarmVisualSystem.crop_source(4,"strawberry","winter"), "perennial tutorial and four-season artwork are active")
	var pumpkin_plot: Dictionary = game.plots[Vector2i(2,0)]; pumpkin_plot.tilled = true; game.day = 1; game.state.inventory.set_count("pumpkin_seeds",1); game.hotbar_slots[1] = "pumpkin_seeds"
	expect(not game.FarmSystem.plant(game,pumpkin_plot) and game.inventory_item_count("pumpkin_seeds") == 1, "autumn pumpkin seed is preserved when planting is attempted in spring")
	game.day = 22; strawberry_plot.watered = true; var dormant_growth: float = strawberry_plot.growth; game.plots[strawberry_cell] = strawberry_plot; game.update_crops(5.0)
	expect(game.plots[strawberry_cell].growth == dormant_growth, "winter seasonal strawberry artwork accompanies genuinely paused growth")
	var snapshot: Dictionary = game.SaveSystem.snapshot(game); var loaded := make_game()
	expect(loaded.SaveSystem.apply(loaded,snapshot) and loaded.plots[strawberry_cell].crop_kind == "strawberry", "save roundtrip preserves the exact planted crop variety")
	for kind in ["strawberry","beet","pepper","cucumber","sunflower","melon","herbs"]: expect(game.VisualAssetSystem.has_item_icon(kind), "%s harvest has a standalone inventory icon" % kind)
	loaded.free(); game.free()

## Сценарий: все семейства врагов используют подходящие анимированные спрайты вместо примитивов.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_animated_enemy_sprites_replace_primitives() -> void:
	var game := make_game()
	expect(game.PREDATOR_PLANT_SHEET.get_width() == 256 and game.PREDATOR_PLANT_SHEET.get_height() == 256, "predator plant has a four-direction four-frame sprite sheet")
	expect(game.ORC_IDLE_SHEET.get_width() == 256 and game.ORC_IDLE_SHEET.get_height() == 256, "orc has a four-direction four-frame sprite sheet")
	expect(game.CAVE_GUARDIAN_TEXTURE.get_size() == Vector2(256, 256), "Depth Guardian is optimized to a compact transparent game texture")
	expect(game.SKELETON_WARRIOR_TEXTURE.get_size() == Vector2(256, 256) and game.CURSED_KNIGHT_TEXTURE.get_size() == Vector2(256, 256), "skeleton and cursed knight use compact transparent game textures")
	expect(game.enemy_sprite_texture("plant") == game.PREDATOR_PLANT_SHEET and game.enemy_sprite_texture("orc") == game.ORC_IDLE_SHEET and game.enemy_sprite_texture("cave_guardian") == game.CAVE_GUARDIAN_TEXTURE and game.enemy_sprite_texture("skeleton") == game.SKELETON_WARRIOR_TEXTURE and game.enemy_sprite_texture("undead") == game.CURSED_KNIGHT_TEXTURE, "all five modular enemy families render with real sprite textures")
	expect(game.enemy_direction_row(Vector2.DOWN) == 0 and game.enemy_direction_row(Vector2.UP) == 1 and game.enemy_direction_row(Vector2.LEFT) == 2 and game.enemy_direction_row(Vector2.RIGHT) == 3, "enemy idle animation faces the nearby player in all directions")
	game.free()

## Сценарий: рюкзак расширяется строками, прокручивается и сохраняет урожай с таймерами роста.
## Исходное состояние: новая игра, изменённое сценарием состояние и отдельный тестовый путь сохранения.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_unbounded_scrolling_inventory_and_forage_save() -> void:
	var game := make_game()
	var original_slots: int = game.inventory_slots.size()
	for kind in ["fiber","rare_seeds","metal","bones","ancient_key","blue_gem","moon_relic"]:
		expect(game.change_inventory_count(kind, 1), "new inventory category can be added: %s" % kind)
	expect(game.inventory_slots.size() > original_slots and game.inventory_slots.size() % game.InventorySystem.COLUMNS == 0, "inventory grows by complete rows without a slot limit")
	expect(game.inventory_slots.has("fiber") and game.inventory_slots.has("moon_relic"), "expanded inventory exposes all acquired material categories")
	for kind in game.state.inventory.counts:
		game.state.inventory.counts[kind] = 1
	game.InventorySystem.ensure_counted_items(game)
	game.open_inventory()
	expect(game.InventorySystem.max_scroll_row(game) > 0, "expanded inventory exposes vertical scrolling")
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(0, -50)
	expect(game.handle_gamepad_and_touch(drag) and game.inventory_scroll_row == 1, "touch drag scrolls the inventory down")
	game.inventory_selected = game.inventory_slots.size() - 1
	game.InventorySystem.keep_selection_visible(game)
	expect(game.inventory_scroll_row == game.InventorySystem.max_scroll_row(game), "keyboard or gamepad selection keeps the last row visible")
	game.inventory_open = false
	var nut_index := 2
	game.current_location = "overworld"
	game.player = game.food_nodes[nut_index].position
	game.collect_food(nut_index)
	var saved_ready_at: float = game.food_nodes[nut_index].ready_at
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.food_nodes[nut_index].active = true
	game.food_nodes[nut_index].ready_at = 0.0
	game.inventory_slots.resize(6)
	game.SaveSystem.apply(game, snapshot)
	expect(not game.food_nodes[nut_index].active and game.food_nodes[nut_index].ready_at == saved_ready_at, "save restores forage regrowth timers")
	expect(game.inventory_slots.size() > 30 and game.inventory_slots.has("moon_relic"), "save restores the dynamically expanded inventory")
	game.free()
