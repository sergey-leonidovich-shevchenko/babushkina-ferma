extends "res://tests/suites/suite_base.gd"

func run() -> void:
	test_tutorial_reset_and_tester_kit()
	test_experience_from_farming_combat_and_quest()
	test_food_healing_and_temporary_effects()
	test_world_collisions_and_bridge_passage()
	test_hotbar_assignment_equipment_and_universal_input()
	test_crafting_window_and_save_snapshot()
	test_enemy_families_loot_tables_and_world_route()
	test_gameplay_systems_are_modular()
	test_colored_crystals_and_orc_equipment_loot()

func test_tutorial_reset_and_tester_kit() -> void:
	var game := make_game()
	game.tutorial_step = 7
	game.tutorial_visible = false
	game.reset_tutorial()
	expect(game.tutorial_step == 0 and game.tutorial_visible, "Y reset restarts and shows tutorial")
	game.coins = 0
	game.carrots = 0
	game.crystals = 0
	game.slime_alive = false
	game.grant_tester_kit()
	expect(game.coins >= 500 and game.carrots >= 10 and game.crystals >= 10, "F9 grants tester resources")
	expect(game.slime_alive and game.slime_hp == 3, "F9 restores combat target")
	game.free()

func test_experience_from_farming_combat_and_quest() -> void:
	var game := make_game()
	game.player = Vector2(390, 240)
	game.facing = Vector2.RIGHT
	game.plots[Vector2i.ZERO].tilled = true
	game.selected_tool = game.Tool.SEEDS
	game.use_selected_tool()
	expect(game.player_xp == 1, "planting a crop grants experience")
	game.player = game.slime_position
	game.attack_slime()
	game.attack_slime()
	game.attack_slime()
	expect(game.player_xp == 11, "defeating an enemy grants experience")
	game.quest_active = true
	game.carrots = 10
	game.talk_to_grandmother()
	expect(game.player_xp == 36, "completing a quest grants experience through the shared XP system")
	game.award_xp(14)
	expect(game.player_level == 2 and game.player_xp == 0 and game.player_max_hp == 110, "experience raises level and maximum health")
	game.free()

func test_food_healing_and_temporary_effects() -> void:
	var game := make_game()
	game.player_hp = 50
	game.apples = 1
	game.inventory_selected = 12
	expect(game.consume_selected_item(), "apple can be eaten from inventory")
	expect(game.player_hp == 80 and game.apples == 0, "apple restores health without exceeding the live health maximum")
	game.berries = 1
	game.inventory_selected = 13
	game.consume_selected_item()
	game.update_status_effects(2.1)
	expect(game.player_hp == 90 and game.regeneration_timer > 0.0, "berries regenerate health over time")
	game.nuts = 1
	game.inventory_selected = 14
	game.consume_selected_item()
	game.player = game.slime_position
	game.attack_slime()
	expect(game.slime_hp == 1, "nut strength effect increases combat damage")
	game.mushrooms = 1
	game.inventory_selected = 15
	game.consume_selected_item()
	game.slime_alive = false
	game.move_right_held = true
	var start_x: float = game.player.x
	game.update_player_movement(1.0)
	expect(game.player.x - start_x > game.speed, "mushroom effect increases movement speed")
	game.player = game.food_nodes[0].position
	game.food_nodes[0].active = true
	expect(game.perform_repeatable_action() and game.mushrooms == 2, "wild food sprite can be collected while action is held")
	game.oranges = 1
	game.player_hp = 60
	game.energy = 5
	expect(game.consume_item("orange") and game.player_hp == 80 and game.energy == 7, "orange restores health and energy")
	game.free()

func test_world_collisions_and_bridge_passage() -> void:
	var game := make_game()
	game.player = game.slime_position - Vector2(90, 0)
	game.move_player_with_collisions(Vector2(120, 0))
	expect(game.player.x <= game.slime_position.x - game.PLAYER_RADIUS - 27.0, "living enemy blocks player movement")
	var rock: Dictionary = game.resource_nodes[0]
	game.player = rock.position - Vector2(100, 0)
	game.move_player_with_collisions(Vector2(140, 0))
	expect(game.player.x < rock.position.x - game.PLAYER_RADIUS - 28.0, "active rock blocks player movement")
	game.resource_nodes[0].hits = 0
	game.move_player_with_collisions(Vector2(140, 0))
	expect(game.player.x > rock.position.x, "depleted resource no longer blocks movement")
	game.player = game.pond_position - Vector2(260, 0)
	game.move_player_with_collisions(Vector2(160, 0))
	expect(game.player.x < game.pond_position.x - 200.0, "pond shoreline blocks player movement")
	game.player = Vector2(1200, 830)
	game.move_player_with_collisions(Vector2(0, 80))
	expect(game.player.y <= 842.0, "river blocks movement away from bridge")
	game.player = Vector2(1500, 830)
	game.move_player_with_collisions(Vector2(0, 80))
	expect(game.player.y > 860.0, "bridge allows crossing the river")
	game.player = Vector2(1120, 510)
	game.move_player_with_collisions(Vector2(100, 100))
	expect(game.player.y > 510.0, "diagonal collision slides along an obstacle instead of sticking")
	game.free()

func test_hotbar_assignment_equipment_and_universal_input() -> void:
	var game := make_game()
	game.inventory_selected = 1
	expect(game.assign_selected_to_hotbar(0) and game.hotbar_slots[0] == "carrot", "inventory item can be assigned to any quick slot")
	game.carrots = 1
	game.player_hp = 50
	game.select_hotbar(0)
	expect(game.use_active_item() and game.player_hp == 65, "quick slot uses the item currently in hand")
	game.iron_helmet = 1
	game.inventory_selected = 16
	expect(game.equip_selected_item() and game.equipment.head == "iron_helmet", "helmet equips into head slot")
	expect(game.player_max_hp == 110, "helmet increases maximum health")
	game.crystal_ring = 1
	game.inventory_selected = 19
	game.equip_selected_item()
	game.player = game.slime_position
	game.attack_slime()
	expect(game.slime_hp == 1, "equipped ring increases combat damage")
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	var previous_slot: int = game.selected_hotbar
	expect(game.handle_gamepad_and_touch(right) and game.selected_hotbar == posmod(previous_slot + 1, 10), "gamepad cycles quick slots")
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(176 + 3 * 80 + 20, 580)
	touch.pressed = true
	expect(game.handle_gamepad_and_touch(touch) and game.selected_hotbar == 3, "touch selects a quick slot")
	game.free()

func test_crafting_window_and_save_snapshot() -> void:
	var game := make_game()
	game.player = game.workbench_position
	game.perform_context_action()
	expect(game.crafting_open, "workbench opens a dedicated recipe window")
	game.slime_gel = 3
	game.wood = 2
	expect(game.CraftingSystem.craft(game, 0) and game.sword_crafted, "selected recipe consumes ingredients and creates output")
	game.coins = 321
	game.hotbar_slots[0] = "orange"
	game.equipment.head = "iron_helmet"
	game.iron_helmet = 1
	game.plots[Vector2i.ZERO].tilled = true
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.coins = 0
	game.hotbar_slots[0] = "hoe"
	game.equipment.head = ""
	game.plots[Vector2i.ZERO].tilled = false
	expect(game.SaveSystem.apply(game, snapshot), "save snapshot can be loaded")
	expect(game.coins == 321 and game.hotbar_slots[0] == "orange", "save restores economy and quick slots")
	expect(game.equipment.head == "iron_helmet" and game.plots[Vector2i.ZERO].tilled, "save restores equipment and farm state")
	game.free()

func test_enemy_families_loot_tables_and_world_route() -> void:
	var game := make_game()
	expect(game.CombatSystem.TYPES.has("plant") and game.CombatSystem.TYPES.has("orc") and game.CombatSystem.TYPES.has("skeleton") and game.CombatSystem.TYPES.has("undead"), "combat system defines all enemy families")
	game.current_location = "forest"
	game.player = game.enemy_nodes[0].position
	for _hit in 5: game.attack_nearest_enemy()
	expect(not game.enemy_nodes[0].alive and game.dropped_items.size() == 2, "predatory plant uses its configured loot table")
	game.player = game.dropped_items[0].position
	game.collect_dropped_item(0)
	expect(game.materials.fiber > 0 or game.materials.rare_seeds > 0, "enemy material enters shared inventory")
	game.current_location = "overworld"
	game.WorldSystem.travel(game)
	expect(game.current_location == "forest", "world gate travels from village to forest")
	for _location in 6: game.WorldSystem.travel(game)
	expect(game.current_location == "overworld", "world route connects all seven locations in a loop")
	game.free()

func test_gameplay_systems_are_modular() -> void:
	var game := make_game()
	expect(game.PlayerSystem != null and game.NavigationSystem != null and game.InventorySystem != null and game.SkillSystem != null, "player progression navigation and inventory systems are separate modules")
	expect(game.FarmSystem != null and game.FishingSystem != null and game.QuestSystem != null, "farm fishing and quest systems are separate modules")
	expect(game.CombatSystem != null and game.CraftingSystem != null and game.SaveSystem != null, "combat crafting and save systems are separate modules")
	expect(game.WorldSystem != null and game.RenderSystem != null, "world and rendering coordinators are separate modules")
	expect(game.ResourceSystem != null and game.ShopSystem != null and game.TutorialSystem != null and game.DiscoverySystem != null and game.WildlifeSystem != null and game.LootContainerSystem != null and game.ForageSystem != null, "resources shop tutorial discoveries wildlife forage and world loot are separate modules")
	expect(game.AudioSystem != null, "music and sound effects are owned by a separate audio module")
	game.free()

func test_colored_crystals_and_orc_equipment_loot() -> void:
	var game := make_game()
	game.selected_tool = game.Tool.PICKAXE
	game.player = game.resource_nodes[1].position
	expect(game.mine_resource(1), "red crystal vein can be mined")
	expect(game.materials.red_crystal == 1, "red crystal enters shared inventory")
	game.current_location = "cave"
	game.player = game.resource_nodes[4].position
	expect(game.mine_resource(4), "green crystal vein can be mined")
	expect(game.materials.green_crystal == 1, "green crystal enters shared inventory")
	game.current_location = "ruins"
	game.player = game.enemy_nodes[1].position
	for _hit in 8:
		game.attack_nearest_enemy()
	expect(not game.enemy_nodes[1].alive, "orc can drop its configured equipment loot")
	var found_blade := false
	for item in game.dropped_items:
		if item.kind == "orc_blade":
			found_blade = true
	expect(found_blade, "orc loot table includes an equippable blade")
	game.free()
