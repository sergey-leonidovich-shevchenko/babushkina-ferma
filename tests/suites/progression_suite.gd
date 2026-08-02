extends "res://tests/suites/suite_base.gd"

## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_character_level_skill_points_and_resource_attributes()
	test_profession_progress_and_gameplay_bonuses()
	test_progression_save_and_universal_skill_menu_input()
	test_regrowing_forage_harvest_value_and_sale()
	test_forage_atlas_cells_are_isolated_and_bottom_anchored()
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
	game.skill_levels.vitality = 2
	game.skill_levels.smithing = 1
	game.skill_xp.smithing = 9
	game.player_mana = 17
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.skill_points = 0
	game.skill_levels.vitality = 0
	game.skill_xp.smithing = 0
	game.player_mana = 0
	game.SaveSystem.apply(game, snapshot)
	expect(game.skill_points == 2 and game.skill_levels.vitality == 2, "save restores free points and skill ranks")
	expect(game.skill_xp.smithing == 9 and game.player_mana == 17, "save restores profession XP and current mana")
	game.open_skill_menu()
	expect(game.skill_menu_open, "K action opens the skill window")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	game.skill_menu_selected = 2
	game.handle_skill_menu_input(accept)
	expect(game.skill_levels.stamina == 1 and game.skill_points == 1, "gamepad assigns a selected skill point")
	game.skill_menu_open = false
	var touch := InputEventScreenTouch.new()
	touch.position = game.InterfaceRenderer.SKILL_BUTTON.get_center()
	touch.pressed = true
	expect(game.handle_gamepad_and_touch(touch) and game.skill_menu_open, "touch HUD button opens character development")
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

## Сценарий: арбуз, зелье, щит и луговой ящер работают в сборе, крафте, употреблении, бою и сохранении.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_new_pixel_items_watermelon_shield_potion_and_lizard() -> void:
	var game := make_game()
	expect(game.ITEM_HEALING_POTION.get_size() == Vector2(64, 64) and game.ITEM_OAK_SHIELD.get_size() == Vector2(64, 64), "potion and shield are compact imported game textures")
	expect(game.ITEM_WATERMELON.get_size() == Vector2(64, 64) and game.ITEM_WATERMELON_SLICE.get_size() == Vector2(64, 64), "whole and sliced watermelon sprites are available")
	expect(game.MEADOW_LIZARD.get_size() == Vector2(96, 64), "original meadow lizard has a compact transparent world sprite")
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
