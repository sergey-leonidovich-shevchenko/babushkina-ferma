extends "res://tests/suites/suite_base.gd"

## Запускает сценарии зданий, интерьеров, условий доступа и группы напарников.
func run() -> void:
	test_building_catalog_entry_exit_and_collision()
	test_progress_gated_buildings()
	test_castle_has_multiple_connected_locations()
	test_prison_recruitment_switching_and_capacity()
	test_companion_follow_combat_defense_and_healing()
	test_buildings_and_companions_are_saved_and_taught()


## Сценарий: восемь зданий отображаются, блокируют стены и имеют отдельные входы и выходы.
## Исходное состояние: новая игра в деревне, герой последовательно помещается у дома и его стен.
## Ожидаемый результат: каталог и атлас полны, дверь ведёт в малый интерьер, стены непроходимы, а выход возвращает наружу.
func test_building_catalog_entry_exit_and_collision() -> void:
	var game := make_game()
	expect(game.BuildingSystem.BUILDINGS.size() == 8, "eight distinct exterior buildings are configured")
	expect(game.BuildingSystem.INTERIORS.size() == 10, "buildings expose ten separate interior locations")
	expect(game.BUILDING_ATLAS.get_width() > 1700 and game.BUILDING_ATLAS.get_height() > 800, "eight-building pixel atlas is loaded")
	expect(game.COMPANION_ATLAS.get_width() > 2100 and game.COMPANION_ATLAS.get_height() > 700, "three-companion pixel atlas is loaded")
	var cottage: Dictionary = game.BuildingSystem.BUILDINGS.cottage
	game.player = cottage.door
	expect(game.nearest_interaction() == "building:cottage", "cottage door receives the contextual interaction")
	expect(game.perform_context_action(), "unlocked cottage can be entered immediately")
	expect(game.current_location == "cottage_interior", "cottage uses a separate interior location")
	game.player = game.BuildingSystem.INTERIORS.cottage_interior.service_position
	expect(game.nearest_interaction() == "interior_service:bed", "cottage contains an interactive bed")
	var day_before_sleep: int = game.day
	expect(game.perform_context_action() and game.day == day_before_sleep + 1, "cottage bed completes the day")
	var room: Rect2 = game.BuildingSystem.INTERIORS.cottage_interior.room
	expect(game.NavigationSystem.is_walkable(game, room.get_center()), "cottage floor is walkable")
	expect(not game.NavigationSystem.is_walkable(game, room.position), "cottage walls block movement")
	game.player = game.BuildingSystem.INTERIORS.cottage_interior.exit
	expect(game.nearest_interaction() == "interior_exit" and game.perform_context_action(), "interior exit returns through the same building")
	expect(game.current_location == "overworld" and game.player.y > cottage.door.y, "hero appears outside below the cottage door")
	expect(not game.NavigationSystem.is_walkable(game, game.BuildingSystem.collision_rect("cottage").get_center()), "exterior building body blocks movement")
	game.player = game.BuildingSystem.BUILDINGS.shop_house.door
	expect(game.BuildingSystem.enter(game, "shop_house"), "village shop has its own accessible interior")
	game.player = game.BuildingSystem.INTERIORS.shop_interior.service_position
	expect(game.perform_context_action() and game.shop_open, "shop counter opens the existing trade table")
	game.free()


## Сценарий: кузница, часовня, башня и замок открываются разными видами прогресса.
## Исходное состояние: новая игра без ремесленных рангов, ключа, завершённого сюжета и требуемого уровня.
## Ожидаемый результат: каждая дверь сначала отказывает, а затем открывается только после собственного условия.
func test_progress_gated_buildings() -> void:
	var game := make_game()
	game.current_location = "rocky"
	expect(not game.BuildingSystem.can_enter(game, "forge"), "forge starts locked without mining training")
	game.skill_levels.mining = 1
	expect(game.BuildingSystem.can_enter(game, "forge"), "mining rank one unlocks the forge")
	game.current_location = "cursed"
	expect(not game.BuildingSystem.can_enter(game, "chapel"), "moon chapel starts locked without an ancient key")
	game.change_inventory_count("ancient_key", 1)
	expect(game.BuildingSystem.can_enter(game, "chapel"), "ancient key unlocks the moon chapel")
	game.current_location = "forest"
	expect(not game.BuildingSystem.can_enter(game, "wizard_tower"), "wizard tower starts locked without mana mastery")
	game.skill_levels.mana = 2
	expect(game.BuildingSystem.can_enter(game, "wizard_tower"), "mana rank two unlocks the wizard tower")
	game.current_location = "ruins"
	game.player_level = 3
	expect(not game.BuildingSystem.can_enter(game, "moon_castle"), "level alone does not unlock the castle")
	game.mission_states.story_relic = game.QuestSystem.COMPLETED
	expect(game.BuildingSystem.can_enter(game, "moon_castle"), "completed relic story and level three unlock the castle")
	game.free()


## Сценарий: замок состоит из большого зала, верхнего этажа и отдельного подземелья.
## Исходное состояние: сюжет завершён, герой третьего уровня стоит у открытой двери замка.
## Ожидаемый результат: вход и оба перехода меняют локации, а обратные выходы возвращают в большой зал.
func test_castle_has_multiple_connected_locations() -> void:
	var game := make_game()
	game.current_location = "ruins"
	game.player_level = 3
	game.mission_states.story_relic = game.QuestSystem.COMPLETED
	game.player = game.BuildingSystem.BUILDINGS.moon_castle.door
	expect(game.BuildingSystem.enter(game, "moon_castle") and game.current_location == "castle_hall", "castle opens into a large great hall")
	expect(game.BuildingSystem.INTERIORS.castle_hall.room.size.x > 1500, "castle hall is larger than house interiors")
	expect(game.BuildingSystem.travel_inside(game, "castle_upper"), "great hall connects to the upper floor")
	expect(game.BuildingSystem.leave(game) and game.current_location == "castle_hall", "upper floor exit returns to the hall")
	expect(game.BuildingSystem.travel_inside(game, "castle_dungeon"), "great hall connects to the dungeon")
	expect(game.BuildingSystem.leave(game) and game.current_location == "castle_hall", "dungeon exit returns to the hall")
	game.player = game.BuildingSystem.INTERIORS.castle_hall.exit
	expect(game.BuildingSystem.leave(game) and game.current_location == "ruins", "castle front exit returns to the ruins")
	game.free()


## Сценарий: в тюрьме можно выкупать разных спутников, менять активного и расширить группу лидерством.
## Исходное состояние: герой в тюрьме с 500 монетами и нулевым рангом лидерства.
## Ожидаемый результат: Мила доступна сразу, сильные кандидаты требуют ранг, замена работает, а второй слот открывается на ранге 2.
func test_prison_recruitment_switching_and_capacity() -> void:
	var game := make_game()
	game.current_location = "prison_interior"
	game.coins = 500
	game.player = game.CompanionSystem.COMPANIONS.mila.position
	expect(game.nearest_interaction() == "prisoner:mila", "nearest prison cell highlights Mila")
	expect(game.perform_context_action(), "Mila can be released without leadership training")
	expect(game.recruited_companions == ["mila"] and game.active_companions == ["mila"], "first released companion joins the active party")
	var coins_after_mila: int = game.coins
	expect(coins_after_mila == 420, "releasing Mila charges her configured price")
	expect(not game.CompanionSystem.interact(game, "borislav"), "Borislav refuses a leader without rank one")
	game.skill_levels.leadership = 1
	expect(game.CompanionSystem.interact(game, "borislav"), "leadership rank one allows Borislav to be released")
	expect(game.active_companions == ["borislav"], "new companion replaces the active one while capacity is one")
	game.skill_levels.leadership = 2
	expect(game.CompanionSystem.capacity(game) == 2, "leadership rank two expands party capacity to two")
	expect(game.CompanionSystem.interact(game, "luna"), "leadership rank two allows healer Luna to be released")
	expect(game.active_companions == ["borislav", "luna"], "two different companions can be active together")
	expect(game.CompanionSystem.interact(game, "mila"), "an already recruited companion can be selected again")
	expect(game.active_companions == ["luna", "mila"], "selecting at full capacity replaces the oldest active companion")
	game.free()


## Сценарий: активные напарники следуют, атакуют, защищают и лечат согласно разным характеристикам.
## Исходное состояние: Мила и Луна активны в лесу рядом с раненым героем и хищным растением.
## Ожидаемый результат: позиции приближаются к герою, защита складывается, Луна лечит, а ближайший враг получает урон.
func test_companion_follow_combat_defense_and_healing() -> void:
	var game := make_game()
	game.skill_levels.leadership = 2
	game.recruited_companions.assign(["mila", "luna"])
	game.active_companions.assign(["mila", "luna"])
	game.current_location = "forest"
	game.player = game.enemy_nodes[0].position - Vector2(70, 0)
	game.player_hp = 50
	game.companion_positions = {"mila":game.player - Vector2(300, 0),"luna":game.player - Vector2(280, 0)}
	game.companion_heal_timer = 10.0
	var before_distance: float = game.companion_positions.mila.distance_to(game.player)
	game.CompanionSystem.update(game, 0.5)
	expect(game.companion_positions.mila.distance_to(game.player) < before_distance, "active companion follows the moving hero")
	expect(game.CompanionSystem.defense_bonus(game) == 4, "Mila and Luna combine their defense values")
	game.companion_heal_timer = 0.0
	game.CompanionSystem.update(game, 0.01)
	expect(game.player_hp == 54, "Luna periodically restores her configured four health")
	game.companion_positions.mila = game.enemy_nodes[0].position
	var enemy_hp: int = game.enemy_nodes[0].hp
	game.companion_attack_timer = 0.0
	game.CompanionSystem.update(game, 0.01)
	expect(game.enemy_nodes[0].hp == enemy_hp - 2, "Mila automatically deals her configured damage to a nearby enemy")
	game.free()


## Сценарий: состав группы, интерьер и новые этапы обучения переживают сохранение.
## Исходное состояние: герой находится на верхнем этаже замка с двумя нанятыми напарниками и лидерством 2.
## Ожидаемый результат: snapshot восстанавливает локацию и группу, а туториал содержит все новые пользовательские сценарии.
func test_buildings_and_companions_are_saved_and_taught() -> void:
	var game := make_game()
	game.skill_levels.leadership = 2
	game.recruited_companions.assign(["mila", "borislav", "luna"])
	game.active_companions.assign(["borislav", "luna"])
	game.current_location = "castle_upper"
	game.player = Vector2(620, 410)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.recruited_companions.clear()
	game.active_companions.clear()
	game.current_location = "overworld"
	expect(game.SaveSystem.apply(game, snapshot), "save applies building and companion state")
	expect(game.current_location == "castle_upper" and game.player == Vector2(620, 410), "save restores exact interior and position")
	expect(game.recruited_companions.size() == 3 and game.active_companions == ["borislav", "luna"], "save restores recruited and active companions")
	for event_name in ["building_enter", "locked_building", "castle_floor", "companion_recruit", "companion_change"]:
		expect(game.tutorial_steps.any(func(step): return step.event == event_name), "tutorial covers building feature: %s" % event_name)
	game.free()
