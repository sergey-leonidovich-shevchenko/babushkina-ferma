extends "res://tests/suites/suite_base.gd"

## Запускает сценарии домашнего сундука, переноса предметов и улучшений кузницы.
func run() -> void:
	test_chest_can_be_crafted_or_bought_and_installs_at_home()
	test_home_chest_interaction_collision_and_transfers()
	test_storage_keyboard_gamepad_and_touch_input()
	test_forge_service_replaces_workbench_and_upgrades_weapons()
	test_armor_and_arrow_upgrades_change_live_stats()
	test_upgrade_cost_scaling_maximum_and_input()
	test_storage_and_forge_progress_are_saved_and_migrated()


## Сценарий: набор домашнего сундука можно получить двумя заявленными экономическими путями.
## Исходное состояние: две новые игры, в одной выданы материалы, во второй — деньги для лавки.
## Ожидаемый результат: крафт и покупка автоматически устанавливают единственный сундук и расходуют набор мебели.
func test_chest_can_be_crafted_or_bought_and_installs_at_home() -> void:
	var game := make_game()
	var chest_recipe: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "home_chest")
	game.change_inventory_count("plank", 8)
	game.change_inventory_count("nails", 6)
	expect(game.CraftingSystem.craft(game, chest_recipe), "home chest can be assembled from processed planks and forged nails")
	expect(game.home_chest_owned and game.inventory_item_count("home_chest") == 0, "crafted furnishing installs at home instead of occupying backpack")
	expect(game.tutorial_events_completed.has("chest_install"), "chest acquisition has an installation tutorial event")
	game.free()
	game = make_game()
	var chest_product: int = game.shop_products.find_custom(func(product): return product.kind == "home_chest")
	game.coins = 120
	expect(game.ShopSystem.buy(game, chest_product), "home chest can be bought in the village shop")
	expect(game.home_chest_owned and game.coins == 0, "purchased chest installs once and charges its full price")
	game.coins = 500
	game.wood = 20
	game.materials.metal = 10
	expect(not game.ShopSystem.buy(game, chest_product) and game.coins == 500, "installed home chest cannot be bought twice")
	expect(not game.CraftingSystem.craft(game, chest_recipe) and game.wood == 20, "installed home chest cannot be crafted twice")
	game.free()


## Сценарий: установленный сундук становится домашним препятствием и переносит предметы в обе стороны.
## Исходное состояние: герой находится дома, сундук установлен, в рюкзаке пять морковок и надет шлем.
## Ожидаемый результат: взаимодействие открывает окно, перенос меняет остатки, а убранная экипировка снимается.
func test_home_chest_interaction_collision_and_transfers() -> void:
	var game := make_game()
	game.home_chest_owned = true
	game.current_location = "cottage_interior"
	game.player = game.StorageSystem.CHEST_POSITION + Vector2(80, 0)
	expect(game.DiscoverySystem.scan_nearby(game) and game.discovery_current.id == "home_chest", "home chest explains itself when first approached")
	expect(game.nearest_interaction() == "home_chest" and game.perform_context_action(), "installed chest opens through contextual home interaction")
	expect(game.storage_open and game.tutorial_events_completed.has("chest_open"), "chest window and its tutorial open together")
	expect(not game.NavigationSystem.is_walkable(game, game.StorageSystem.CHEST_POSITION), "installed chest has a real interior collision")
	game.carrots = 5
	expect(game.StorageSystem.deposit(game, "carrot", 1), "one backpack item can be deposited")
	expect(game.carrots == 4 and game.state.storage.count("carrot") == 1, "deposit preserves the combined item count")
	expect(game.StorageSystem.deposit(game, "carrot", 4), "whole remaining stack can be deposited")
	expect(game.carrots == 0 and game.state.storage.count("carrot") == 5 and game.tutorial_events_completed.has("chest_deposit"), "whole stack enters chest and completes tutorial")
	expect(game.StorageSystem.withdraw(game, "carrot", 2), "part of a stored stack can be withdrawn")
	expect(game.carrots == 2 and game.state.storage.count("carrot") == 3 and game.tutorial_events_completed.has("chest_withdraw"), "withdraw restores backpack count without duplication")
	game.iron_helmet = 1
	game.InventorySystem.equip(game, "iron_helmet")
	game.StorageSystem.deposit(game, "iron_helmet", 1)
	expect(game.equipment.head.is_empty(), "storing the last equipped copy safely unequips it")
	game.free()


## Сценарий: сундук одинаково управляется клавиатурой, геймпадом и касанием.
## Исходное состояние: открытый сундук с морковью в рюкзаке и выбранной левой колонкой.
## Ожидаемый результат: Enter, D-pad/A и экранные области переключают колонки и переносят предметы.
func test_storage_keyboard_gamepad_and_touch_input() -> void:
	var game := make_game()
	game.home_chest_owned = true
	game.current_location = "cottage_interior"
	game.carrots = 3
	game.StorageSystem.open(game)
	game.storage_selected = game.StorageSystem.inventory_items(game).find("carrot")
	game.handle_storage_input(key_event(KEY_ENTER, KEY_ENTER, true))
	expect(game.carrots == 2 and game.state.storage.count("carrot") == 1, "keyboard transfers one selected item")
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	game.handle_storage_input(right)
	expect(game.storage_side == 1, "gamepad D-pad switches to chest column")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	game.handle_storage_input(accept)
	expect(game.carrots == 3 and game.state.storage.count("carrot") == 0, "gamepad A withdraws the selected item")
	game.storage_side = 0
	game.storage_selected = game.StorageSystem.inventory_items(game).find("carrot")
	expect(game.InputSystem.handle_storage_touch(game, game.InterfaceRenderer.STORAGE_TRANSFER_ALL.get_center()), "storage touch action is consumed")
	expect(game.carrots == 0 and game.state.storage.count("carrot") == 3, "touch button transfers the whole stack")
	game.free()


## Сценарий: наковальня кузницы открывает улучшения и повышает постоянный урон оружия.
## Исходное состояние: герой допущен в кузницу, имеет лесной меч и материалы первого уровня заточки.
## Ожидаемый результат: сервис открывает forge-окно, расходует материалы и увеличивает боевой бонус.
func test_forge_service_replaces_workbench_and_upgrades_weapons() -> void:
	var game := make_game()
	game.current_location = "forge_interior"
	game.player = game.BuildingSystem.INTERIORS.forge_interior.service_position
	expect(game.DiscoverySystem.scan_nearby(game) and game.discovery_current.id == "forge", "forge anvil explains upgrades when first approached")
	expect(game.nearest_interaction() == "interior_service:forge" and game.perform_context_action(), "forge anvil opens dedicated upgrade window")
	expect(game.forge_open and not game.crafting_open and game.tutorial_events_completed.has("forge_open"), "forge no longer opens ordinary workbench recipes")
	game.change_inventory_count("sword", 1)
	game.materials.metal = 2
	game.materials.stone = 1
	var sword_index: int = game.ForgeSystem.UPGRADES.find_custom(func(upgrade): return upgrade.kind == "sword")
	var bonus_before: int = game.ForgeSystem.weapon_damage_bonus(game, "forest_sword")
	expect(game.ForgeSystem.upgrade(game, sword_index), "forest sword accepts first sharpening")
	expect(game.ForgeSystem.level(game, "sword") == 1 and game.materials.metal == 0 and game.materials.stone == 0, "weapon upgrade consumes exact first-level materials")
	expect(game.ForgeSystem.weapon_damage_bonus(game, "forest_sword") == bonus_before + 1, "sharpening adds permanent sword damage")
	expect(game.tutorial_events_completed.has("weapon_sharpen") and game.skill_xp.smithing > 0, "weapon upgrade teaches feature and trains smithing")
	game.free()


## Сценарий: броня усиливает живые защитные характеристики, а заточка стрел повышает урон лука.
## Исходное состояние: надет шлем, имеются материалы, стрелы и охотничий лук.
## Ожидаемый результат: усиление пересчитывает HP и защиту, наконечники дают отдельный бонус дальнему оружию.
func test_armor_and_arrow_upgrades_change_live_stats() -> void:
	var game := make_game()
	game.iron_helmet = 1
	game.InventorySystem.equip(game, "iron_helmet")
	game.materials.metal = 3
	game.materials.stone = 1
	var helmet_index: int = game.ForgeSystem.UPGRADES.find_custom(func(upgrade): return upgrade.kind == "iron_helmet")
	var hp_before: int = game.player_max_hp
	expect(game.ForgeSystem.upgrade(game, helmet_index), "equipped helmet can be reinforced")
	expect(game.player_max_hp == hp_before + 2 and game.ForgeSystem.armor_defense_bonus(game) == 1, "helmet reinforcement updates health and defense immediately")
	expect(game.tutorial_events_completed.has("armor_upgrade"), "armor reinforcement completes its tutorial")
	game.change_inventory_count("bow", 1)
	game.materials.arrows = 5
	game.materials.metal = 1
	var arrows_index: int = game.ForgeSystem.UPGRADES.find_custom(func(upgrade): return upgrade.kind == "arrows")
	expect(game.ForgeSystem.upgrade(game, arrows_index), "five arrows and metal sharpen one permanent arrowhead level")
	expect(game.inventory_item_count("arrows") == 0 and game.ForgeSystem.weapon_damage_bonus(game, "bow") == 1, "sharpened arrowheads increase bow damage")
	expect(game.tutorial_events_completed.has("arrow_sharpen"), "arrowhead sharpening has a dedicated tutorial event")
	game.free()


## Сценарий: стоимость растёт по уровням, максимум равен трём, а интерфейс принимает универсальный ввод.
## Исходное состояние: герой владеет мечом и большим запасом материалов, forge-окно открыто.
## Ожидаемый результат: второй уровень дороже первого, четвёртый запрещён, клавиатура и тач выбирают строки.
func test_upgrade_cost_scaling_maximum_and_input() -> void:
	var game := make_game()
	game.current_location = "forge_interior"
	game.change_inventory_count("sword", 1)
	game.materials.metal = 100
	game.materials.stone = 100
	var index: int = game.ForgeSystem.UPGRADES.find_custom(func(upgrade): return upgrade.kind == "sword")
	var first_cost: Dictionary = game.ForgeSystem.costs(game, game.ForgeSystem.UPGRADES[index])
	game.ForgeSystem.upgrade(game, index)
	var second_cost: Dictionary = game.ForgeSystem.costs(game, game.ForgeSystem.UPGRADES[index])
	expect(second_cost.metal > first_cost.metal and second_cost.stone > first_cost.stone, "each next forge level costs more materials")
	game.ForgeSystem.upgrade(game, index)
	game.ForgeSystem.upgrade(game, index)
	expect(game.ForgeSystem.level(game, "sword") == 3 and not game.ForgeSystem.upgrade(game, index), "upgrade level is capped at three")
	game.open_forge()
	game.forge_selected = 0
	game.handle_forge_input(key_event(KEY_DOWN, KEY_DOWN, true))
	expect(game.forge_selected == 1, "keyboard moves forge selection")
	expect(game.InputSystem.handle_forge_touch(game, game.InterfaceRenderer.FORGE_ROWS.position + Vector2(20, 3 * 44 + 20)), "forge touch row is consumed")
	expect(game.forge_selected == 3, "touch selects the matching forge row")
	game.free()


## Сценарий: содержимое сундука и уровни кузницы переживают сохранение, а старый снимок получает значения по умолчанию.
## Исходное состояние: установленный сундук хранит ресурсы, меч заточен, затем создаётся снимок и его legacy-копия.
## Ожидаемый результат: актуальный снимок восстанавливает прогресс, старый остаётся загрузочным с пустыми новыми состояниями.
func test_storage_and_forge_progress_are_saved_and_migrated() -> void:
	var game := make_game()
	game.home_chest_owned = true
	game.state.storage.change("crystal", 7)
	game.state.forge.set_level("sword", 2)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.home_chest_owned = false
	game.home_chest_counts.clear()
	game.state.forge.set_level("sword", 0)
	expect(game.SaveSystem.apply(game, snapshot), "save with storage and forge progress loads")
	expect(game.home_chest_owned and game.state.storage.count("crystal") == 7, "save restores installed chest and contents")
	expect(game.ForgeSystem.level(game, "sword") == 2, "save restores forge upgrade levels")
	var legacy := snapshot.duplicate(true)
	legacy.erase("storage")
	legacy.erase("forge")
	expect(game.SaveSystem.apply(game, legacy), "older save without chest and forge data still loads")
	expect(not game.home_chest_owned and game.home_chest_counts.is_empty() and game.ForgeSystem.level(game, "sword") == 0, "legacy save migrates new systems to safe defaults")
	game.free()
