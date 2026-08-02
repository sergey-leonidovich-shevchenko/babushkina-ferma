extends "res://tests/suites/suite_base.gd"


## Запускает сценарии путешествия, палубы, пиратского боя, добычи, квеста, музыки и миграции.
func run() -> void:
	test_ship_is_an_eighth_bounded_location()
	test_four_pirate_enemy_types_have_unique_loot()
	test_drowned_captain_quest_rewards_cutlass()
	test_pirate_treasure_and_old_save_migration()
	test_ship_music_localization_and_tutorials()


## Сценарий: мировой маршрут приводит на корабль, где вода, борта, мачты и пушки непроходимы.
## Исходное состояние: герой находится в мастерской перед последним переходом общего маршрута.
## Ожидаемый результат: переход открывает корабль, палуба доступна, а пространство за корпусом заблокировано.
func test_ship_is_an_eighth_bounded_location() -> void:
	var game := make_game(); game.current_location = "glassworks"
	game.WorldSystem.travel(game)
	expect(game.current_location == "pirate_ship" and game.player == Vector2(220,430), "world gate reaches the pirate ship as location eight")
	expect(game.tutorial_events_completed.has("pirate_ship"), "first arrival completes the ship tutorial step")
	expect(game.NavigationSystem.is_walkable(game, Vector2(360,520)), "central wooden deck is walkable")
	expect(not game.NavigationSystem.is_walkable(game, Vector2(40,520)), "ocean outside the hull is blocked")
	expect(not game.PirateShipSystem.is_walkable(game.PirateShipSystem.MAST_POSITIONS[0], game.PLAYER_RADIUS), "mast has solid collision")
	expect(game.NavigationSystem.is_walkable(game, game.world_gate_position), "return gate remains reachable on the stern")
	game.WorldSystem.travel(game)
	expect(game.current_location == "overworld", "ship gate closes the eight-location loop")
	game.free()


## Сценарий: на палубе присутствуют корсары, зомби, призрак и капитан со своими таблицами добычи.
## Исходное состояние: стандартный каталог боя и пять пиратских точек появления на одном корабле.
## Ожидаемый результат: четыре семейства зарегистрированы, локализованы и используют только известные предметы.
func test_four_pirate_enemy_types_have_unique_loot() -> void:
	var game := make_game()
	var ship_enemies: Array = game.enemy_nodes.filter(func(enemy): return enemy.location == "pirate_ship")
	expect(ship_enemies.size() == 5, "pirate deck contains five combat encounters")
	for kind in game.CombatSystem.PIRATE_FAMILIES:
		expect(game.CombatSystem.TYPES.has(kind) and ship_enemies.any(func(enemy): return enemy.kind == kind), "ship contains pirate enemy type: %s" % kind)
		expect(game.LocaleSystem.ENTITIES.has(kind), "pirate enemy has six-language name: %s" % kind)
	expect(game.CombatSystem.TYPES.pirate.loot.has("pirate_doubloon") and game.CombatSystem.TYPES.sea_ghost.loot.has("ectoplasm"), "corsairs and ghosts use distinct loot tables")
	expect(FileAccess.get_file_as_string("res://scripts/systems/animation_renderer.gd").contains("func draw_pirate_enemy"), "pirate ranks have a dedicated animated renderer")
	var item_renderer := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	expect(item_renderer.contains("cursed_compass") and item_renderer.contains("pirate_cutlass"), "pirate quest items have dedicated inventory icons")
	game.free()


## Сценарий: Елена выдаёт приказ победить босса, компас подбирается и обменивается на саблю.
## Исходное состояние: новое задание доступно, герой стоит у штурмана, затем рядом с Утопшим капитаном.
## Ожидаемый результат: босс оставляет компас, сдача даёт награды, а экипированная сабля повышает урон.
func test_drowned_captain_quest_rewards_cutlass() -> void:
	var game := make_game(); game.current_location = "pirate_ship"; game.player = game.QuestSystem.npc_position(game, "elena")
	expect(game.perform_context_action() and game.mission_states.side_pirate_compass == game.QuestSystem.ACTIVE, "navigator starts the drowned captain quest")
	expect(game.tutorial_events_completed.has("pirate_quest"), "accepting ship quest opens its tutorial")
	var captain_index: int = game.enemy_nodes.find_custom(func(enemy): return enemy.kind == "drowned_captain")
	game.player = game.enemy_nodes[captain_index].position
	expect(game.CombatSystem.apply_damage(game, captain_index, 999), "drowned captain can be defeated through combat pipeline")
	var compass_index: int = game.dropped_items.find_custom(func(item): return item.kind == "cursed_compass")
	expect(compass_index >= 0 and game.tutorial_events_completed.has("pirate_loot"), "captain drops quest compass and explains pirate loot")
	game.player = game.dropped_items[compass_index].position; game.collect_dropped_item(compass_index)
	game.player = game.QuestSystem.npc_position(game, "elena")
	expect(game.perform_context_action() and game.mission_states.side_pirate_compass == game.QuestSystem.COMPLETED, "navigator accepts the cursed compass")
	expect(game.inventory_item_count("pirate_cutlass") == 1 and game.coins == 200, "quest rewards boarding cutlass coins and experience")
	var before_bonus: int = game.InventorySystem.damage_bonus(game); game.InventorySystem.equip(game, "pirate_cutlass")
	expect(game.InventorySystem.damage_bonus(game) == before_bonus + 3, "equipped boarding cutlass grants three damage")
	game.free()


## Сценарий: пиратские сундуки содержат тематические предметы и добавляются в старое сохранение.
## Исходное состояние: генерируется новый мир, затем снимок искусственно лишается корабельных тайников и миссии.
## Ожидаемый результат: новые сундуки валидны, а загрузка дополняет старый прогресс без его сброса.
func test_pirate_treasure_and_old_save_migration() -> void:
	var game := make_game(); var generated: Array = game.LootContainerSystem.generate(4242)
	var caches: Array = generated.filter(func(container): return container.location == "pirate_ship")
	expect(caches.size() == 3 and caches.all(func(container): return container.kind == "pirate_chest"), "ship generates three pirate treasure chests")
	expect(caches.any(func(container): return container.contents.has("pirate_doubloon") or container.contents.has("ectoplasm")), "pirate caches roll thematic items")
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	snapshot.containers = snapshot.containers.filter(func(container): return container.location != "pirate_ship")
	snapshot.missions.erase("side_pirate_compass")
	var restored := make_game()
	expect(game.SaveSystem.apply(restored, snapshot), "legacy snapshot loads after pirate expansion")
	expect(restored.world_loot_nodes.any(func(container): return container.location == "pirate_ship"), "legacy world receives missing ship treasure")
	expect(restored.mission_states.has("side_pirate_compass") and restored.inventory_item_count("pirate_doubloon") == 0, "legacy progress receives safe quest and item defaults")
	game.free(); restored.free()


## Сценарий: корабль использует отдельную оригинальную музыку и полностью переведённое обучение.
## Исходное состояние: импортированные звуковые ресурсы и каталоги шести поддерживаемых языков.
## Ожидаемый результат: pirate.wav загружается, выбирается по локации, а три шага обучения локализованы.
func test_ship_music_localization_and_tutorials() -> void:
	var game := make_game()
	expect(load("res://assets/game/audio/music/pirate.wav") != null, "original pirate music is importable")
	expect(game.AudioSystem.switch_music(game, "pirate_ship") and game.audio_current_music == "pirate", "ship selects its own music track")
	expect(game.LocaleSystem.LOCATIONS.has("pirate_ship") and game.LocaleSystem.ITEMS.has("pirate_cutlass"), "ship and reward items support all locales")
	for event_name in ["pirate_ship","pirate_quest","pirate_loot"]:
		expect(game.tutorial_steps.any(func(step): return step.event == event_name), "tutorial covers pirate feature: %s" % event_name)
	game.free()
