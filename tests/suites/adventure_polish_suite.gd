extends "res://tests/suites/suite_base.gd"

## Запускает сценарии создания героя, диалогов, боевых подсказок, отклика, экономики и прочности.
func run() -> void:
	test_character_creation_and_specialization()
	test_branching_quest_dialogue_relationship_and_memory()
	test_target_lock_telegraph_and_action_feedback()
	test_adaptive_combat_music_returns_to_location_theme()
	test_durability_repair_and_backpack_upgrade()
	test_limited_daily_shop_stock()
	test_adventure_progress_survives_save_cycle()


## Сценарий: новая игра сначала создаёт героя и только после подтверждения выдаёт один стартовый бонус.
## Исходное состояние: титульный экран без активного профиля, выбран новый запуск вне SceneTree.
## Ожидаемый результат: открывается отдельное окно, поля меняются с клавиатуры, подтверждение закрывает его и применяет специализацию.
func test_character_creation_and_specialization() -> void:
	var game := make_game(); game.title_screen = true
	game.MenuSystem.start_new_game(game)
	expect(not game.title_screen and game.AdventurePolishSystem.has_modal(game), "new game opens character creation before gameplay")
	var old_name: String = game.state.player.profile.name
	game.AdventurePolishSystem.handle_input(game, key_event(KEY_RIGHT, KEY_RIGHT, true))
	expect(game.state.player.profile.name != old_name, "creation keyboard cycles the selected profile field")
	game.state.player.adventure_ui.creation_field = 4; game.state.player.profile.specialization = "farmer"
	var seeds_before: int = game.seeds
	game.AdventurePolishSystem.handle_input(game, key_event(KEY_ENTER, KEY_ENTER, true))
	expect(game.state.player.profile.created and not game.AdventurePolishSystem.has_modal(game) and game.seeds == seeds_before + 4, "confirmation creates profile and grants the farmer bonus exactly once")
	game.free()


## Сценарий: квестовый NPC показывает выбор, запоминает принятую миссию и принимает подходящий подарок.
## Исходное состояние: первое задание Мирона доступно, в активном слоте лежат ягоды.
## Ожидаемый результат: задание не стартует до подтверждения, после подтверждения активно, а подарок повышает отношения.
func test_branching_quest_dialogue_relationship_and_memory() -> void:
	var game := make_game(); game.mission_states.story_relic = game.QuestSystem.AVAILABLE
	expect(game.AdventurePolishSystem.open_quest_dialogue(game, "miron"), "quest NPC opens portrait dialogue")
	expect(game.mission_states.story_relic == game.QuestSystem.AVAILABLE and game.state.player.adventure_ui.dialogue.choices.size() == 2, "dialogue offers accept and decline without implicit acceptance")
	game.AdventurePolishSystem.handle_input(game, key_event(KEY_ENTER, KEY_ENTER, true))
	expect(game.mission_states.story_relic == game.QuestSystem.ACTIVE and game.state.player.quest_memory.has("miron"), "confirm accepts quest and records NPC memory")
	game.change_inventory_count("berries", 2); game.hotbar_slots[0] = "berries"; game.selected_hotbar = 0
	game.AdventurePolishSystem.open_quest_dialogue(game, "miron")
	game.AdventurePolishSystem.handle_input(game, key_event(KEY_G, KEY_G, true))
	expect(game.inventory_item_count("berries") == 1 and game.state.player.relationships.miron == 8, "edible hotbar gift is consumed and raises friendship")
	game.free()


## Сценарий: фиксация цели, предупреждение удара и атласный отклик используют живое состояние боя.
## Исходное состояние: один враг перенесён рядом с героем, затем проигран звук добычи киркой.
## Ожидаемый результат: Q фиксирует врага, таймер задаёт телеграф, а событие SFX запускает эффект и отдачу.
func test_target_lock_telegraph_and_action_feedback() -> void:
	var game := make_game(); game.current_location = "forest"; game.player = Vector2(500, 500)
	game.enemy_nodes[0].location = "forest"; game.enemy_nodes[0].position = Vector2(570, 500); game.enemy_nodes[0].alive = true; game.enemy_nodes[0].attack_timer = 0.25
	expect(game.AdventurePolishSystem.cycle_target(game) == 0, "target lock selects a nearby living enemy")
	expect(float(game.enemy_nodes[0].attack_timer) < 0.38 and game.player.distance_to(game.enemy_nodes[0].position) <= game.CombatSystem.TYPES.plant.range, "enemy runtime exposes the telegraph window before attack")
	game.audio_last_sfx = "mine"; game.audio_sfx_count += 1; game.AdventurePolishSystem.update(game, 0.01)
	expect(game.state.player.feedback.action == "mine" and game.state.player.feedback.timer > 0.0 and game.state.player.feedback.camera_shake > 0.0, "action sound starts matching atlas effect and light camera feedback")
	game.free()


## Сценарий: близкая угроза временно включает боевую музыку без потери темы локации.
## Исходное состояние: герой и один враг находятся рядом в лесу, затем враг удаляется за радиус выхода.
## Ожидаемый результат: звучит тревожная тема, а после безопасного расстояния восстанавливается лесная.
func test_adaptive_combat_music_returns_to_location_theme() -> void:
	var game := make_game(); game.current_location = "forest"; game.player = Vector2(500, 500)
	for enemy in game.enemy_nodes: enemy.alive = false
	game.enemy_nodes[0].location = "forest"; game.enemy_nodes[0].position = Vector2(700, 500); game.enemy_nodes[0].alive = true
	game.AudioSystem.update_adaptive_music(game)
	expect(game.audio_current_music == "danger" and game.state.player.feedback.combat_music, "nearby living enemy starts adaptive combat theme")
	game.enemy_nodes[0].position = Vector2(1200, 500); game.AudioSystem.update_adaptive_music(game)
	expect(game.audio_current_music == "forest" and not game.state.player.feedback.combat_music, "safe distance restores the current location theme")
	game.free()


## Сценарий: инструмент ломается, кузница чинит его, а магазин расширяет мягкую вместимость рюкзака.
## Исходное состояние: кирка имеет единицу прочности, затем герой получает монеты.
## Ожидаемый результат: расход доводит прочность до нуля и блокирует использование, ремонт восстанавливает её, улучшение даёт двенадцать ячеек.
func test_durability_repair_and_backpack_upgrade() -> void:
	var game := make_game(); game.state.inventory.durability.pickaxe = 1
	game.AdventurePolishSystem.consume_durability(game, "pickaxe")
	expect(not game.AdventurePolishSystem.can_use(game, "pickaxe"), "broken tool is rejected until repair")
	game.coins = 20
	expect(game.AdventurePolishSystem.repair(game, "pickaxe") and game.state.inventory.durability.pickaxe == 100 and game.coins == 10, "forge repair restores full durability for missing-condition price")
	var capacity_before: int = game.state.inventory.capacity(); game.coins = 500
	expect(game.AdventurePolishSystem.upgrade_backpack(game) and game.state.inventory.capacity() == capacity_before + 12, "backpack upgrade raises soft capacity by twelve slots")
	game.free()


## Сценарий: лавка имеет ограниченный дневной остаток и обновляет его на следующий день.
## Исходное состояние: достаточно монет, выбран товар с четырьмя единицами дневного запаса.
## Ожидаемый результат: пятая покупка запрещена, смена дня снова делает товар доступным.
func test_limited_daily_shop_stock() -> void:
	var game := make_game(); game.coins = 1000
	var product_index: int = game.shop_products.find_custom(func(product): return product.kind == "tomato")
	for ignored in 4: expect(game.ShopSystem.buy(game, product_index), "daily stock unit can be bought")
	expect(not game.ShopSystem.buy(game, product_index), "fifth regular purchase is blocked by daily stock")
	game.day += 1
	expect(game.ShopSystem.buy(game, product_index), "daily stock refreshes on the next day")
	game.free()


## Сценарий: профиль, отношения, память, прочность и расширение рюкзака входят в общий снимок.
## Исходное состояние: все новые постоянные поля заполнены нестандартными значениями.
## Ожидаемый результат: после порчи памяти применение снимка точно восстанавливает каждое поле.
func test_adventure_progress_survives_save_cycle() -> void:
	var game := make_game(); game.state.player.profile.name = "Василиса"; game.state.player.profile.created = true
	game.state.player.relationships.miron = 42; game.state.player.quest_memory.miron = {"mission":"story_relic","day":3,"state":"active"}
	game.state.inventory.backpack_level = 2; game.state.inventory.durability.axe = 37
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.state.player.profile.name = "X"; game.state.player.relationships.clear(); game.state.player.quest_memory.clear(); game.state.inventory.backpack_level = 0; game.state.inventory.durability.axe = 100
	expect(game.SaveSystem.apply(game, snapshot), "save accepts the adventure-polish snapshot")
	expect(game.state.player.profile.name == "Василиса" and game.state.player.relationships.miron == 42 and game.state.player.quest_memory.has("miron"), "save restores profile relationships and quest memory")
	expect(game.state.inventory.backpack_level == 2 and game.state.inventory.durability.axe == 37, "save restores backpack upgrade and durability")
	game.free()
