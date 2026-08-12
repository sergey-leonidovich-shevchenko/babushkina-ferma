extends "res://tests/suites/suite_base.gd"

const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")
const FirstLevelArtSystem := preload("res://scripts/systems/first_level_art_system.gd")
const VillageAmbientRenderer := preload("res://scripts/systems/village_ambient_renderer.gd")

## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_first_level_master_is_sliced_into_a_seamless_world_grid()
	test_first_location_has_clear_functional_zones()
	test_village_hybrid_layout_layers_and_navigation()
	test_bridge_render_data_and_discovery_covers_both_crossings()
	test_village_ambient_layer_respects_grid_and_seasons()
	test_story_and_side_mission_chains()
	test_mission_progress_and_drops_are_saved()
	test_contextual_discoveries_and_new_item_hints()
	test_discoveries_and_tutorial_checklist_are_saved()
	test_wildlife_flees_and_does_not_talk()
	test_wildlife_combat_loot_animation_and_save()
	test_seeded_world_loot_generation_and_opening()
	test_world_loot_discovery_and_save_persistence()


## Сценарий: цельный мастер первой локации нарезается на игровую сетку без деформации и щелей.
## Исходное состояние: исходное изображение 1536×1024 и игровой мир 2400×1200.
## Ожидаемый результат: центральные 48×24 исходных тайла образуют 48×24 игровых тайла и точно закрывают мир.
func test_first_level_master_is_sliced_into_a_seamless_world_grid() -> void:
	var master: Texture2D = load("res://assets/generated/level_drafts/first_level_fairytale_master_v1.png")
	expect(master != null and master.get_size() == Vector2(1536, 1024), "fairytale first-level master is imported at its authored resolution")
	expect(FirstLevelArtSystem.layout_is_valid(), "fairytale master crop maps to the complete 2400x1200 world")
	expect(FirstLevelArtSystem.source_rect(Vector2i.ZERO) == Rect2(0, 128, 32, 32), "first playable sprite starts on the tile-aligned crop row")
	expect(FirstLevelArtSystem.world_rect(Vector2i(47, 23)) == Rect2(2350, 1150, 50, 50), "last playable sprite closes the lower-right world corner")
	var mapped_center := FirstLevelArtSystem.source_to_world(Vector2(768, 512))
	expect(mapped_center == Vector2(1200, 600), "master center maps to the center of the playable world")

## Сценарий: первая локация разделена на двор, площадь и дикую окраину без перекрытий ключевых объектов.
## Исходное состояние: новая игра с исходными координатами зданий, персонажей, растений и ресурсов.
## Ожидаемый результат: старт находится на дороге, сервисы собраны на площади, опасности вынесены за её пределы, а обучение отмечает прибытие.
func test_first_location_has_clear_functional_zones() -> void:
	var game := make_game()
	var square: Rect2 = game.BuildingSystem.VILLAGE_SQUARE
	expect(game.BuildingSystem.VILLAGE_MAIN_PATH.has_point(game.player), "new character starts on the readable village road")
	expect(square.has_point(game.BuildingSystem.SHOP_STALL_POSITION) and square.has_point(game.BuildingSystem.SELL_CRATE_POSITION), "shop stall and sale crate form one market zone")
	expect(square.has_point(game.guild_master_position) and square.has_point(game.herbalist_position), "quest NPCs form a readable village square")
	expect(not square.has_point(game.slime_position), "starter combat is kept outside the safe village square")
	for tree in game.TREE_POSITIONS:
		expect(not square.has_point(tree), "trees do not block the village square")
	var farm_rect := Rect2(Vector2(game.FARM_ORIGIN), Vector2(game.FARM_SIZE * game.TILE))
	expect(game.BuildingSystem.FARM_YARD_RECT.encloses(farm_rect), "all farm plots stay inside the fenced homestead yard")
	expect(not game.BuildingSystem.destination_rect("cottage").intersects(farm_rect), "cottage sprite does not overlap the farm plots")
	expect(not game.is_position_walkable(Vector2(38, 900)), "farm fence blocks shortcuts across the garden boundary")
	expect(game.is_position_walkable(Vector2(190, 830)), "farm gate remains wide enough for the character")
	var cottage_door: Vector2 = game.BuildingSystem.BUILDINGS.cottage.door
	game.player = cottage_door
	game.move_player_with_collisions(Vector2(150, 0))
	expect(game.player.x >= cottage_door.x + 149.0, "visible road beside the cottage is a continuous walkable corridor to the right")
	game.discovery_current.clear()
	game.discovery_scan_timer = 0.0
	game.DiscoverySystem.update(game, 0.1)
	expect(game.discovery_current.is_empty(), "context cards wait until the introductory village walk is complete")
	game.player = square.position + Vector2(12, 80)
	game.move_right_held = true
	game.update_player_movement(0.05)
	expect(game.tutorial_events_completed.has("village_paths"), "walking into the square completes the location layout tutorial")
	game.free()

## Сценарий: новая деревня собирается из независимых слоёв земли, воды, дорог, объектов и коллизий.
## Исходное состояние: новая игра на первой локации и общий атлас деревенского декора четыре на два.
## Ожидаемый результат: ключевые ориентиры связаны дорогами, вода блокирует движение, мост пропускает героя, а крупный декор имеет коллизии.
func test_village_hybrid_layout_layers_and_navigation() -> void:
	var game := make_game()
	for building_id in ["cottage", "shop_house", "guild_hall"]:
		var door: Vector2 = game.BuildingSystem.BUILDINGS[building_id].door
		expect(VillageLayoutSystem.path_reaches(door), "village road reaches building door: %s" % building_id)
	expect(VillageLayoutSystem.path_reaches(Vector2(game.FARM_ORIGIN) + Vector2(144, 144)), "village road reaches the farm yard")
	expect(VillageLayoutSystem.path_reaches(game.cave_entrance_position), "village road reaches the adventure exit")
	expect(VillageLayoutSystem.path_reaches(game.world_gate_position), "eastern road reaches the world frontier")
	expect(VillageLayoutSystem.PROP_CELLS.size() == 8, "village atlas registers all eight prop cells")
	expect(VillageLayoutSystem.SCENIC_PLACEMENTS.size() >= 10, "first location gains a dense secondary layer of sliced village props")
	expect(VillageLayoutSystem.FLOWER_PATCHES.size() >= 20, "meadow decoration is dense enough to break up empty green fields")
	for prop in VillageLayoutSystem.SCENIC_PLACEMENTS:
		expect(VillageLayoutSystem.PROP_CELLS.has(prop.kind), "every scenic placement references a valid atlas cell: %s" % prop.kind)
	var prop_atlas: Texture2D = load("res://assets/game/environment/village_prop_atlas.png")
	expect(prop_atlas != null and prop_atlas.get_width() > 1200 and prop_atlas.get_height() > 700, "high-resolution village prop atlas is imported")
	var river_point := Vector2(300, VillageLayoutSystem.river_center_y(300))
	expect(VillageLayoutSystem.is_water(river_point, game.PLAYER_RADIUS), "river water is part of the navigation contract")
	expect(not game.is_position_walkable(river_point), "player cannot walk through the river away from a bridge")
	expect(game.is_position_walkable(VillageLayoutSystem.BRIDGES[0].get_center()), "bridge remains a usable river crossing")
	expect(not game.is_position_walkable(VillageLayoutSystem.WELL_POSITION), "well sprite owns a matching solid footprint")
	expect(not game.is_position_walkable(Vector2(850, 220)), "decorative forge from the master art owns a matching solid footprint")
	var cottage_door: Vector2 = game.BuildingSystem.BUILDINGS.cottage.door
	var square_center: Vector2 = game.BuildingSystem.VILLAGE_SQUARE.get_center()
	expect(cottage_door.y > VillageLayoutSystem.river_center_y(cottage_door.x) + VillageLayoutSystem.RIVER_HALF_WIDTH, "homestead is placed south of the river like the selected concept")
	expect(square_center.y < VillageLayoutSystem.river_center_y(square_center.x) - VillageLayoutSystem.RIVER_HALF_WIDTH, "village center is placed north of the river")
	expect(game.FARM_ORIGIN.y > VillageLayoutSystem.river_center_y(game.FARM_ORIGIN.x), "farm field belongs to the southern homestead zone")
	expect(VillageLayoutSystem.BRIDGES.size() == 2, "homestead and eastern frontier have separate river bridges")
	expect(not VillageLayoutSystem.is_water(Vector2(300, 1000), game.PLAYER_RADIUS), "river is narrow and no longer replaces the entire southern half of the map")
	expect(game.cave_entrance_position.x > 1600.0 and game.cave_entrance_position.y < 260.0, "mine entrance matches the northern ruined gate in the selected master")
	game.free()


## Сценарий: для обоих мостов используются корректные кадры спрайтов и единая контекстная подсказка.
## Исходное состояние: новая игра на территории деревни.
## Ожидаемый результат: обе переправы рендерятся без сдвига, и подсказка «bridge» показывается рядом с нужным мостом.
func test_bridge_render_data_and_discovery_covers_both_crossings() -> void:
	var game := make_game()
	game.current_location = "overworld"
	var east_bridge_center: Vector2 = VillageLayoutSystem.BRIDGES[1].get_center()
	expect(VillageLayoutSystem.bridge_render_rect(0).size == Vector2(100, 190), "first bridge uses the intended render size")
	expect(VillageLayoutSystem.bridge_render_rect(1).size == Vector2(100, 190), "second bridge uses the intended render size")
	expect(VillageLayoutSystem.BRIDGE_RENDER_SIZES[0] == Vector2(100, 190), "first bridge render source frame has full bridge resolution")
	expect(VillageLayoutSystem.BRIDGE_RENDER_SIZES[1] == Vector2(100, 190), "second bridge render source frame has full bridge resolution")
	expect(VillageLayoutSystem.bridge_navigation_rect(0).size == Vector2(156, 238), "small bridge owns a forgiving navigation lane matching its visible width")
	expect(VillageLayoutSystem.bridge_navigation_rect(1).size == Vector2(156, 238), "main bridge owns a forgiving navigation lane matching its visible width")
	expect(VillageLayoutSystem.nearest_bridge_center(east_bridge_center) == east_bridge_center, "nearest-bridge helper picks eastern crossing")
	for bridge_index in VillageLayoutSystem.BRIDGES.size():
		var bridge_center: Vector2 = VillageLayoutSystem.BRIDGES[bridge_index].get_center()
		game.player = bridge_center - Vector2(0, 115)
		game.move_player_with_collisions(Vector2(0, 230))
		expect(game.player.y > bridge_center.y + 80.0, "player crosses the complete visible bridge without catching on water: %d" % bridge_index)
	game.player = east_bridge_center
	game.discovery_current.clear()
	game.discovery_scan_timer = 0.0
	expect(game.DiscoverySystem.scan_nearby(game), "bridge around player is found as a contextual discovery")
	expect(game.discovery_current.id == "bridge", "bridge discovery uses a single stable hint id")
	var foreground_source := FileAccess.get_file_as_string("res://scripts/systems/village_foreground_renderer.gd")
	expect(not foreground_source.contains("BUILDING_ATLAS") and not foreground_source.contains("bridge.has_point"), "approaching houses and bridges no longer swaps in legacy foreground sprites")
	game.free()


## Сценарий: живой слой первой локации использует валидные ячейки, позиции и сезонные ограничения.
## Исходное состояние: производственный атлас содержит двенадцать ячеек, а карта — детерминированные размещения.
## Ожидаемый результат: декор остаётся внутри мира, осенние листья появляются только осенью, а зимняя вода не цветёт.
func test_village_ambient_layer_respects_grid_and_seasons() -> void:
	expect(VillageAmbientRenderer.CELLS.size() == 12, "village ambient catalog exposes all twelve authored sprites")
	expect(VillageAmbientRenderer.PLACEMENTS.size() >= 20, "first location owns a dense but bounded living decoration layer")
	for placement in VillageAmbientRenderer.PLACEMENTS:
		expect(VillageAmbientRenderer.CELLS.has(placement.kind), "ambient placement references a valid atlas cell: %s" % placement.kind)
		expect(FirstLevelArtSystem.WORLD_RECT.has_point(placement.position), "ambient placement stays inside first-level world: %s" % placement.kind)
	expect(VillageAmbientRenderer.source_rect("stump") == Rect2(362,362,362,362), "stump resolves to its isolated production cell")
	expect(VillageAmbientRenderer.is_visible_in_season("leaves","autumn") and not VillageAmbientRenderer.is_visible_in_season("leaves","summer"), "leaf swirl belongs only to autumn")
	expect(not VillageAmbientRenderer.is_visible_in_season("water_lilies","winter"), "winter hides flowering water plants")

## Сценарий: сюжетная и побочная миссии проходят от диалога до цели, сдачи и награды.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_story_and_side_mission_chains() -> void:
	var game := make_game()
	game.player = game.guild_master_position
	expect(game.nearest_interaction() == "quest_npc:miron", "story mission giver is interactive")
	game.perform_context_action()
	game.AdventurePolishSystem.handle_dialogue_key(game, KEY_ENTER)
	expect(game.mission_states.story_relic == game.QuestSystem.ACTIVE, "guild master starts story mission")
	game.current_location = "cave"
	game.player = game.enemy_nodes[4].position
	for _hit in 12:
		game.attack_nearest_enemy()
	expect(not game.enemy_nodes[4].alive, "cave guardian can be defeated for story mission")
	var relic_drop := -1
	for index in game.dropped_items.size():
		if game.dropped_items[index].kind == "moon_relic":
			relic_drop = index
	expect(relic_drop >= 0, "cave guardian drops the moon relic")
	game.collect_dropped_item(relic_drop)
	expect(game.materials.moon_relic == 1, "quest relic can be collected")
	game.current_location = "overworld"
	game.player = game.guild_master_position
	game.perform_context_action()
	game.AdventurePolishSystem.handle_dialogue_key(game, KEY_ENTER)
	expect(game.mission_states.story_relic == game.QuestSystem.COMPLETED, "relic can be returned to complete story mission")
	expect(game.coins == 140 and game.guardian_armor == 1, "story mission grants coins and equipment")
	game.player = game.herbalist_position
	game.perform_context_action()
	game.AdventurePolishSystem.handle_dialogue_key(game, KEY_ENTER)
	expect(game.mission_states.side_seed == game.QuestSystem.ACTIVE, "herbalist starts side mission")
	game.materials.rare_seeds = 1
	game.perform_context_action()
	game.AdventurePolishSystem.handle_dialogue_key(game, KEY_ENTER)
	expect(game.mission_states.side_seed == game.QuestSystem.COMPLETED, "side mission accepts its requested loot")
	expect(game.berries == 3 and game.coins == 175, "side mission grants food and coins")
	game.toggle_quest_log()
	expect(game.quest_log_open, "J journal state can be opened")
	game.toggle_quest_log()
	var journal_button := InputEventJoypadButton.new()
	journal_button.button_index = JOY_BUTTON_BACK
	journal_button.pressed = true
	expect(game.handle_gamepad_and_touch(journal_button) and game.quest_log_open, "gamepad can open mission journal")
	var journal_touch := InputEventScreenTouch.new()
	journal_touch.position = game.InterfaceRenderer.QUEST_BUTTON.get_center()
	journal_touch.pressed = true
	expect(game.handle_gamepad_and_touch(journal_touch) and not game.quest_log_open, "touch HUD button closes mission journal")
	game.free()

## Сценарий: сохранение восстанавливает этапы миссий и ещё не подобранную сюжетную добычу.
## Исходное состояние: новая игра, изменённое сценарием состояние и отдельный тестовый путь сохранения.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_mission_progress_and_drops_are_saved() -> void:
	var game := make_game()
	game.mission_states.story_relic = game.QuestSystem.ACTIVE
	game.dropped_items.append({"kind":"moon_relic","count":1,"position":Vector2(700, 500)})
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.mission_states.story_relic = game.QuestSystem.AVAILABLE
	game.dropped_items.clear()
	expect(game.SaveSystem.apply(game, snapshot), "mission snapshot can be restored")
	expect(game.mission_states.story_relic == game.QuestSystem.ACTIVE, "save restores mission state")
	expect(game.dropped_items.size() == 1 and game.dropped_items[0].kind == "moon_relic", "save restores uncollected quest loot")
	expect(game.dropped_items[0].position == Vector2(700, 500), "save restores quest loot position")
	game.free()

## Сценарий: новые объекты и выпавшие предметы показывают правильные одноразовые подсказки.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_contextual_discoveries_and_new_item_hints() -> void:
	var game := make_game()
	game.discovery_current.clear()
	game.seen_discoveries.clear()
	game.player = game.BuildingSystem.SHOP_STALL_POSITION
	expect(game.DiscoverySystem.scan_nearby(game), "approaching an unknown feature opens a contextual hint")
	expect(game.discovery_current.id == "shop" and game.seen_discoveries.has("shop"), "shop hint explains and remembers the discovered feature")
	var card: Rect2 = game.discovery_card_rect()
	expect(card.position.x >= 800.0 and card.size.x <= 320.0 and not card.has_point(game.player), "context hint stays compact in the screen corner and does not cover the player")
	game.DiscoverySystem.dismiss(game)
	game.DiscoverySystem.scan_nearby(game)
	expect(game.discovery_current.get("id", "") != "shop", "seen feature does not repeat its hint while another nearby discovery may appear")
	game.current_location = "cave"
	game.player = Vector2(700, 500)
	game.dropped_items.append({"kind":"moon_relic","count":1,"position":game.player})
	expect(game.DiscoverySystem.scan_nearby(game), "new dropped item opens a discovery hint")
	expect(game.discovery_current.id == "item:moon_relic" and "Мирону" in game.discovery_current.text, "quest item hint explains where to bring it")
	game.DiscoverySystem.dismiss(game)
	expect(game.discovery_current.is_empty(), "context hint can be dismissed")
	game.free()

## Сценарий: изученные объекты и выполненные шаги обучения переживают сохранение и загрузку.
## Исходное состояние: новая игра, изменённое сценарием состояние и отдельный тестовый путь сохранения.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_discoveries_and_tutorial_checklist_are_saved() -> void:
	var game := make_game()
	game.seen_discoveries = {"shop":true,"enemy:orc":true}
	game.notify_tutorial("save")
	expect(game.tutorial_step == 0 and game.tutorial_events_completed.has("save"), "future tutorial actions are remembered without skipping current step")
	var save_step: int = game.tutorial_steps.find_custom(func(step): return step.event == "save")
	game.tutorial_step = save_step
	game.notify_tutorial("unrelated")
	expect(game.tutorial_step == save_step + 1, "remembered action completes its checklist step when prerequisites are reached")
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.seen_discoveries.clear()
	game.tutorial_events_completed.clear()
	game.tutorial_step = 0
	game.SaveSystem.apply(game, snapshot)
	expect(game.seen_discoveries.has("shop") and game.seen_discoveries.has("enemy:orc"), "save restores discovered feature history")
	expect(game.tutorial_step == save_step + 1 and game.tutorial_events_completed.has("save"), "save restores tutorial checklist progress")
	var required_events := ["move","village_paths","character_animation","forage_harvest","forage_regrow","forage_sale","plant","rewater","trade","fight","hotbar","equipment","fish_cast","fish_hook","fish_control","fish","tree_chop","tree_fall","tree_regrow","craft_window","story_chain","side_quests","mission_complete","journal","side_mission","colored_crystal","day","level_up","skill_point","profession","pause_menu","settings","save","wildlife","world_loot","watermelon","potion","shield","lizard","pirate_ship","pirate_quest","pirate_loot"]
	for event_name in required_events:
		expect(game.tutorial_steps.any(func(step): return step.event == event_name), "tutorial covers feature: %s" % event_name)
	game.free()

## Сценарий: пугливые животные убегают от героя, не предлагают диалог и показывают подсказку охоты.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_wildlife_flees_and_does_not_talk() -> void:
	var game := make_game()
	var deer: Dictionary = game.wildlife_nodes[0]
	game.player = deer.position - Vector2(60, 0)
	var before_distance: float = game.player.distance_to(deer.position)
	game.WildlifeSystem.update(game, 0.2)
	deer = game.wildlife_nodes[0]
	expect(game.player.distance_to(deer.position) > before_distance, "timid deer immediately flees from nearby player")
	game.player = deer.position
	expect(game.nearest_interaction().is_empty(), "decorative wildlife cannot be talked to")
	game.discovery_current.clear()
	game.seen_discoveries.clear()
	expect(game.DiscoverySystem.scan_nearby(game), "approaching wildlife opens its contextual hint")
	expect(game.discovery_current.id == "wildlife:deer" and "разговаривать нельзя" in game.discovery_current.text, "wildlife hint explains fleeing and hunting")
	game.free()

## Сценарий: охота на животных учитывает анимацию, видовую добычу и восстановление состояния.
## Исходное состояние: новая игра, изменённое сценарием состояние и отдельный тестовый путь сохранения.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_wildlife_combat_loot_animation_and_save() -> void:
	var game := make_game()
	expect(game.DEER_RUN_SHEET.get_width() == 192 and game.FOX_RUN_SHEET.get_width() == 192 and game.BOAR_RUN_SHEET.get_width() == 160, "wildlife animation sheets are loaded")
	expect(game.FANTASY_WILDLIFE_ATLAS.get_width() == 2172, "bat and lizard share the coherent fantasy wildlife atlas")
	expect(game.WildlifeSystem.TYPES.has("deer") and game.WildlifeSystem.TYPES.has("fox") and game.WildlifeSystem.TYPES.has("boar") and game.WildlifeSystem.TYPES.has("bat") and game.WildlifeSystem.TYPES.has("lizard"), "five wildlife species are configured")
	game.current_location = "cave"
	game.player = game.wildlife_nodes[6].position
	expect(game.nearest_interaction().is_empty(), "bat has no dialogue interaction")
	game.attack_nearest_enemy()
	game.attack_nearest_enemy()
	expect(not game.wildlife_nodes[6].alive, "cave bat can be hunted")
	var wing_index := -1
	for index in game.dropped_items.size():
		if game.dropped_items[index].kind == "bat_wing": wing_index = index
	expect(wing_index >= 0 and game.dropped_items[wing_index].count == 2, "bat drops two wings")
	game.player = game.dropped_items[wing_index].position
	game.collect_dropped_item(wing_index)
	expect(game.materials.bat_wing == 2, "bat wings enter shared inventory")
	expect(game.inventory_slots.has("bat_wing") and game.inventory_item_count("bat_wing") == 2, "wildlife loot is visible in expanded inventory")
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	snapshot.slots = snapshot.slots.slice(0, 24)
	game.wildlife_nodes[6].alive = true
	game.wildlife_nodes[6].position = Vector2.ZERO
	game.SaveSystem.apply(game, snapshot)
	expect(not game.wildlife_nodes[6].alive, "save restores hunted wildlife state")
	expect(game.wildlife_nodes[6].position != Vector2.ZERO, "save restores moving wildlife position")
	expect(game.inventory_slots.size() >= 30 and game.inventory_slots.has("bat_wing"), "older 24-slot saves migrate to expanded wildlife inventory")
	game.free()

## Сценарий: одинаковое зерно создаёт одинаковые тайники, которые открываются только один раз.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_seeded_world_loot_generation_and_opening() -> void:
	var game := make_game()
	var first: Array = game.LootContainerSystem.generate(123456)
	var repeated: Array = game.LootContainerSystem.generate(123456)
	var different: Array = game.LootContainerSystem.generate(654321)
	expect(first == repeated, "same world seed generates identical loot containers")
	expect(first != different, "different world seed changes positions types or contents")
	expect(first.size() == 22, "random loot is distributed across all eight locations")
	game.world_loot_seed = 123456
	game.world_loot_nodes = first
	var container: Dictionary = game.world_loot_nodes[0]
	game.current_location = container.location
	game.player = container.position
	expect(game.nearest_interaction() == "container:0", "unopened world loot receives interaction highlight")
	expect(not game.NavigationSystem.is_walkable(game, container.position), "world loot blocks player movement")
	var before_coins: int = game.coins
	var before_counts: Dictionary = game.export_inventory_counts()
	expect(game.LootContainerSystem.open(game, 0), "world loot can be searched with context action")
	for kind in container.contents:
		if kind == "coins":
			expect(game.coins == before_coins + container.contents[kind], "container grants rolled coins")
		else:
			expect(game.inventory_item_count(kind) == before_counts.get(kind, 0) + container.contents[kind], "container grants rolled item: %s" % kind)
	expect(game.world_loot_nodes[0].opened, "searched container becomes permanently empty")
	expect(not game.LootContainerSystem.open(game, 0), "opened container cannot be looted twice")
	game.free()

## Сценарий: тайники показывают подсказку, сохраняют содержимое и остаются пустыми после обыска.
## Исходное состояние: новая игра, изменённое сценарием состояние и отдельный тестовый путь сохранения.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_world_loot_discovery_and_save_persistence() -> void:
	var game := make_game()
	game.world_loot_seed = 777
	game.world_loot_nodes = game.LootContainerSystem.generate(game.world_loot_seed)
	var container: Dictionary = game.world_loot_nodes[0]
	game.current_location = container.location
	game.player = container.position
	game.discovery_current.clear()
	game.seen_discoveries.clear()
	expect(game.DiscoverySystem.scan_nearby(game), "first nearby container opens contextual discovery")
	expect(game.discovery_current.id.begins_with("container:") and "находка" in game.discovery_current.text, "container hint explains one-time random loot")
	game.LootContainerSystem.open(game, 0)
	var saved_contents: Dictionary = game.world_loot_nodes[0].contents.duplicate(true)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.world_loot_seed = 1
	game.world_loot_nodes = game.LootContainerSystem.generate(1)
	game.SaveSystem.apply(game, snapshot)
	expect(game.world_loot_seed == 777 and game.world_loot_nodes[0].contents == saved_contents, "save restores generated world and rolled contents")
	expect(game.world_loot_nodes[0].opened, "save restores already searched container")
	expect(game.WorldLootRenderer.ATLAS.get_width() == 1774, "shared world-loot atlas replaces the standalone bone-pile placeholder")
	game.free()
