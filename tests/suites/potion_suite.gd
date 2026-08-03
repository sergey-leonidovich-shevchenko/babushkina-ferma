extends "res://tests/suites/suite_base.gd"


## Запускает сценарии мгновенных зелий, бафов, невидимости, защиты, крафта и сохранения.
func run() -> void:
	test_instant_restore_potions_respect_resource_caps()
	test_invisibility_suppresses_aggro_and_breaks_on_attack()
	test_timed_buffs_regenerate_accelerate_and_reduce_damage()
	test_potion_catalog_crafting_visuals_and_save_roundtrip()
	test_household_food_chain_is_tradeable_craftable_and_edible()


## Сценарий: лечебное, мановое и энергетическое зелья восстанавливают разные ресурсы.
## Исходное состояние: здоровье, мана и энергия снижены, в рюкзаке лежит по одному зелью.
## Ожидаемый результат: каждый ресурс растёт до своего предела, а предмет расходуется ровно один раз.
func test_instant_restore_potions_respect_resource_caps() -> void:
	var game := make_game(); game.player_hp = 50; game.player_mana = 15; game.energy = 3
	for kind in ["healing_potion","mana_potion","energy_potion"]: game.change_inventory_count(kind, 1)
	expect(game.consume_item("healing_potion") and game.player_hp == 100, "healing potion restores health without exceeding maximum")
	expect(game.consume_item("mana_potion") and game.player_mana == game.player_max_mana, "mana potion restores the blue resource")
	expect(game.consume_item("energy_potion") and game.energy == 11, "energy potion restores eight stamina without exceeding its resource cap")
	expect(game.inventory_item_count("healing_potion") == 0 and game.inventory_item_count("mana_potion") == 0 and game.inventory_item_count("energy_potion") == 0, "instant potions consume one inventory unit each")
	game.free()


## Сценарий: невидимый герой проходит рядом с врагом, а затем сам начинает бой.
## Исходное состояние: корсар расположен рядом, эффект невидимости активирован на восемнадцать секунд.
## Ожидаемый результат: враг не движется и не атакует, первая атака героя снимает скрытность.
func test_invisibility_suppresses_aggro_and_breaks_on_attack() -> void:
	var game := make_game(); game.current_location = "pirate_ship"
	var index: int = game.enemy_nodes.find_custom(func(enemy): return enemy.kind == "pirate")
	game.player = game.enemy_nodes[index].position + Vector2(70, 0); game.change_inventory_count("invisibility_potion", 1)
	expect(game.consume_item("invisibility_potion") and game.invisibility_timer == 18.0, "invisibility potion starts exact stealth duration")
	var before: Vector2 = game.enemy_nodes[index].position; var hp_before: int = game.player_hp
	game.CombatSystem.update(game, 1.0)
	expect(game.enemy_nodes[index].position == before and game.player_hp == hp_before, "invisible hero causes neither enemy chase nor attack")
	expect(game.CombatSystem.attack(game, index) and game.invisibility_timer == 0.0, "hero attack immediately breaks invisibility")
	expect(game.tutorial_events_completed.has("invisibility"), "first stealth potion completes dedicated tutorial step")
	game.free()


## Сценарий: четыре временных зелья включают силу, регенерацию, скорость и защиту.
## Исходное состояние: герой ранен, все четыре предмета выданы, входящий урон не усилен экипировкой.
## Ожидаемый результат: таймеры запускаются, регенерация лечит, защита вычитает четыре урона.
func test_timed_buffs_regenerate_accelerate_and_reduce_damage() -> void:
	var game := make_game(); game.player_hp = 50
	for kind in ["strength_potion","regeneration_potion","speed_potion","defense_potion"]:
		game.change_inventory_count(kind, 1); expect(game.consume_item(kind), "timed potion can be consumed: %s" % kind)
	expect(game.strength_timer == 30.0 and game.speed_timer == 25.0 and game.defense_timer == 30.0, "combat movement and defense buffs use distinct durations")
	game.update_status_effects(2.1)
	expect(game.player_hp == 60 and game.regeneration_timer > 17.0, "regeneration potion heals five health each elapsed second")
	var incoming: int = game.CombatSystem.damage_player(game, 10, "Тест")
	expect(incoming == 6, "defense potion reduces incoming damage by four with minimum damage preserved")
	game.free()


## Сценарий: восемь зелий имеют иконки, локализацию, рецепты и сохраняемые таймеры.
## Исходное состояние: каталоги контента загружены, два эффекта активны перед созданием снимка.
## Ожидаемый результат: наборы совпадают, атлас валиден, а восстановленная игра продолжает эффекты.
func test_potion_catalog_crafting_visuals_and_save_roundtrip() -> void:
	var game := make_game(); var potion_ids: Array = game.PotionSystem.POTIONS.keys()
	expect(potion_ids.size() == 8 and game.VisualAssetSystem.POTION_CELLS.size() == 8, "eight potion mechanics map one-to-one to generated icons")
	for kind in potion_ids:
		expect(game.InventorySystem.ITEM_DATA.has(kind) and game.LocaleSystem.ITEMS.has(kind), "potion is inventory-ready and translated: %s" % kind)
		expect(game.VisualAssetSystem.potion_source(kind).size == Vector2(313.5,627.0), "potion owns a valid atlas cell: %s" % kind)
	for kind in potion_ids.filter(func(id): return id != "healing_potion"):
		expect(game.CraftingSystem.RECIPES.any(func(recipe): return recipe.output == kind), "advanced potion has a workbench recipe: %s" % kind)
	game.invisibility_timer = 12.0; game.defense_timer = 21.0
	var restored := make_game(); expect(game.SaveSystem.apply(restored, game.SaveSystem.snapshot(game)), "save with active potion effects loads")
	expect(restored.invisibility_timer == 12.0 and restored.defense_timer == 21.0, "active stealth and defense timers survive save roundtrip")
	game.free(); restored.free()


## Сценарий: новые продукты покупаются, перерабатываются, употребляются и продаются общими системами.
## Исходное состояние: герой ранен, имеет достаточно монет, а лавка и верстак используют расширенные каталоги.
## Ожидаемый результат: помидор лечит, молоко превращается в сыр, блюдо и материал имеют рецепты и цены.
func test_household_food_chain_is_tradeable_craftable_and_edible() -> void:
	var game := make_game(); game.coins = 200; game.player_hp = 50
	var tomato_product: int = game.shop_products.find_custom(func(product): return product.kind == "tomato")
	expect(tomato_product >= 0 and game.ShopSystem.buy(game, tomato_product), "village shop sells newly introduced farm produce")
	expect(game.consume_item("tomato") and game.player_hp == 60, "new raw produce uses shared food effect pipeline")
	game.change_inventory_count("milk", 3)
	var cheese_recipe: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "cheese")
	expect(cheese_recipe >= 0 and game.CraftingSystem.craft(game, cheese_recipe) and game.inventory_item_count("cheese") == 1, "three milk units craft one farm cheese")
	for output in ["rope","flour","butter","bread","pie","jam","soup","omelet","cornbread","bouquet"]:
		expect(game.CraftingSystem.RECIPES.any(func(recipe): return recipe.output == output) and game.ShopSystem.sell_price(output) > 0, "household output has recipe and sale value: %s" % output)
	game.free()
