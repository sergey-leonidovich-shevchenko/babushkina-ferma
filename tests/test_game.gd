extends SceneTree

const GameScript = preload("res://scripts/game.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	test_keyboard_press_and_release()
	test_immediate_keyboard_response()
	test_four_direction_character_animation()
	test_clock_rolls_to_next_day()
	test_crop_pauses_for_second_watering()
	test_shop_buy_and_sell()
	test_quest_can_be_completed_with_bought_or_grown_carrots()
	test_combat_loot_craft_and_equip_cycle()
	test_nearest_interaction_and_tutorial()
	test_inventory_move_drop_delete_and_pickup()
	test_location_transition_to_cave_and_back()
	test_pickaxe_mines_surface_and_cave_resources()
	test_fishing_cast_wait_and_catch_cycle()
	test_bow_reward_and_crystal_sword_upgrade()
	test_held_action_repeats_tools_without_reopening_ui()
	test_tutorial_reset_and_tester_kit()
	test_experience_from_farming_combat_and_quest()
	test_food_healing_and_temporary_effects()
	test_world_collisions_and_bridge_passage()
	test_hotbar_assignment_equipment_and_universal_input()
	test_crafting_window_and_save_snapshot()
	test_enemy_families_loot_tables_and_world_route()
	test_colored_crystals_and_orc_equipment_loot()
	test_story_and_side_mission_chains()
	test_mission_progress_and_drops_are_saved()
	test_contextual_discoveries_and_new_item_hints()
	test_discoveries_and_tutorial_checklist_are_saved()
	test_wildlife_flees_and_does_not_talk()
	test_wildlife_combat_loot_animation_and_save()
	test_seeded_world_loot_generation_and_opening()
	test_world_loot_discovery_and_save_persistence()
	test_character_level_skill_points_and_resource_attributes()
	test_profession_progress_and_gameplay_bonuses()
	test_progression_save_and_universal_skill_menu_input()
	test_regrowing_forage_harvest_value_and_sale()
	test_forage_atlas_cells_are_isolated_and_bottom_anchored()
	test_new_pixel_items_watermelon_shield_potion_and_lizard()
	test_unbounded_scrolling_inventory_and_forage_save()
	test_gameplay_systems_are_modular()
	print("TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func make_game() -> Node:
	var game := GameScript.new()
	game._ready()
	game.title_screen = false
	return game

func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	return event

func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)

func test_keyboard_press_and_release() -> void:
	var game := make_game()
	var press := key_event(KEY_D, KEY_D, true)
	var release := key_event(KEY_D, KEY_D, false)
	expect(game.update_movement_key_state(press), "D is recognized as movement")
	expect(game.get_movement_direction() == Vector2.RIGHT, "movement begins on key-down")
	game.update_movement_key_state(release)
	expect(game.get_movement_direction() == Vector2.ZERO, "movement stops on key-up")
	game.free()

func test_immediate_keyboard_response() -> void:
	var game := make_game()
	var start: Vector2 = game.player
	game.update_movement_key_state(key_event(KEY_RIGHT, KEY_RIGHT, true))
	game.update_player_movement(1.0 / 60.0)
	expect(game.player.x > start.x, "first physics frame moves player without key-repeat delay")
	expect(game.player.x - start.x < 5.0, "first frame has no artificial position jump")
	game.free()

func test_four_direction_character_animation() -> void:
	var game := make_game()
	expect(game.FARMER_SHEET.get_width() == 384 and game.FARMER_SHEET.get_height() == 256, "hero sheet contains six frames in four directions")
	expect(game.PlayerSystem.direction_row(Vector2.DOWN) == 0, "down movement uses front-facing animation row")
	expect(game.PlayerSystem.direction_row(Vector2.LEFT) == 1, "left movement uses left-facing animation row")
	expect(game.PlayerSystem.direction_row(Vector2.RIGHT) == 2, "right movement uses right-facing animation row")
	expect(game.PlayerSystem.direction_row(Vector2.UP) == 3, "up movement uses back-facing animation row")
	expect(game.PlayerSystem.animation_frame(0.45, false) == 0, "idle hero holds a stable pose")
	expect(game.PlayerSystem.animation_frame(0.11, true) == 1, "walking advances to the next sprite frame immediately")
	var before: float = game.walk_animation_time
	game.PlayerSystem.update_animation(game, 0.2)
	expect(game.walk_animation_time > before, "character animation clock advances independently of key repeat")
	for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		game.move_left_held = direction == Vector2.LEFT
		game.move_right_held = direction == Vector2.RIGHT
		game.move_up_held = direction == Vector2.UP
		game.move_down_held = direction == Vector2.DOWN
		game.update_player_movement(1.0 / 60.0)
	expect(game.tutorial_events_completed.has("character_animation"), "walking in all four directions completes the animation tutorial check")
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.character_animation_directions.clear()
	game.SaveSystem.apply(game, snapshot)
	expect(game.character_animation_directions.size() == 4, "save restores tested animation directions")
	game.free()

func test_clock_rolls_to_next_day() -> void:
	var game := make_game()
	game.day = 1
	game.game_minutes = 1439.5
	game.update_game_clock(1.0)
	expect(game.day == 2, "clock starts at day 1 and rolls to day 2")
	expect(game.game_minutes < 1.0, "midnight wraps game time")
	game.free()

func test_crop_pauses_for_second_watering() -> void:
	var game := make_game()
	var cell := Vector2i.ZERO
	var plot: Dictionary = game.plots[cell]
	plot.tilled = true
	plot.planted = true
	plot.watered = true
	game.plots[cell] = plot
	game.update_crops(10.1)
	plot = game.plots[cell]
	expect(plot.stage == 2, "crop reaches second stage after ten seconds")
	expect(not plot.watered, "crop requests a second watering")
	var paused_growth: float = plot.growth
	game.update_crops(5.0)
	expect(is_equal_approx(game.plots[cell].growth, paused_growth), "growth pauses while dry")
	plot = game.plots[cell]
	plot.watered = true
	game.plots[cell] = plot
	game.update_crops(10.0)
	expect(game.plots[cell].growth == game.GROWTH_DURATION, "crop becomes ready after second watering")
	game.free()

func test_shop_buy_and_sell() -> void:
	var game := make_game()
	game.coins = 20
	game.seeds = 0
	game.shop_selected = 0
	expect(game.buy_selected_product(), "shop buys selected seed product")
	expect(game.coins == 15 and game.seeds == 4, "buy transaction updates coins and inventory")
	game.shop_selected = 1
	game.carrots = 1
	expect(game.sell_selected_product(), "shop sells selected carrot")
	expect(game.coins == 23 and game.carrots == 0, "sell transaction updates coins and inventory")
	game.free()

func test_quest_can_be_completed_with_bought_or_grown_carrots() -> void:
	var game := make_game()
	game.talk_to_grandmother()
	expect(game.quest_active, "grandmother starts carrot quest")
	game.carrots = 10
	game.talk_to_grandmother()
	expect(game.quest_complete and game.carrots == 0, "ten carrots complete quest")
	expect(game.coins == 70 and game.player_xp == 25, "quest grants coins and experience")
	game.free()

func test_combat_loot_craft_and_equip_cycle() -> void:
	var game := make_game()
	game.player = game.slime_position
	expect(game.attack_slime(), "player can attack nearby slime")
	game.attack_slime()
	game.attack_slime()
	expect(not game.slime_alive and game.loot_available, "defeated slime drops loot")
	expect(game.collect_loot() and game.slime_gel == 3, "loot can be collected")
	game.player = game.workbench_position
	expect(game.craft_sword(), "slime gel and wood craft a sword")
	expect(game.toggle_sword() and game.sword_equipped, "crafted sword can be equipped")
	game.free()

func test_nearest_interaction_and_tutorial() -> void:
	var game := make_game()
	game.player = game.npc_position
	expect(game.nearest_interaction() == "npc", "nearby NPC receives interaction highlight")
	game.player = Vector2(1200, 800)
	expect(game.nearest_interaction().is_empty(), "distant objects are not interactive")
	game.tutorial_step = 0
	game.notify_tutorial("wrong")
	expect(game.tutorial_step == 0, "wrong action does not advance tutorial")
	game.notify_tutorial("move")
	expect(game.tutorial_step == 1, "expected action advances tutorial")
	game.free()

func test_inventory_move_drop_delete_and_pickup() -> void:
	var game := make_game()
	game.inventory_selected = 0
	game.inventory_move_from = 0
	game.inventory_selected = 13
	game.move_inventory_slot()
	expect(game.inventory_slots[13] == "seeds" and game.inventory_slots[0] == "berries", "inventory items swap between slots")
	game.seeds = 2
	game.inventory_selected = 13
	expect(game.drop_selected_item(), "inventory item can be dropped")
	expect(game.seeds == 1 and game.dropped_items.size() == 1, "dropping removes one item and creates world loot")
	game.player = game.dropped_items[0].position
	expect(game.collect_dropped_item(0) and game.seeds == 2, "dropped item can be picked up again")
	expect(game.delete_selected_item() and game.seeds == 1, "inventory item can be deleted")
	game.free()

func test_location_transition_to_cave_and_back() -> void:
	var game := make_game()
	game.player = game.cave_entrance_position
	expect(game.nearest_interaction() == "cave_entrance", "cave entrance is highlighted nearby")
	game.enter_cave()
	expect(game.current_location == "cave", "entrance changes active location")
	game.player = game.cave_exit_position
	expect(game.nearest_interaction() == "cave_exit", "cave exit is interactive")
	game.exit_cave()
	expect(game.current_location == "overworld", "exit returns to overworld")
	game.free()

func test_pickaxe_mines_surface_and_cave_resources() -> void:
	var game := make_game()
	game.selected_tool = game.Tool.PICKAXE
	game.player = game.resource_nodes[0].position
	expect(game.mine_resource(0), "pickaxe mines a surface rock")
	expect(game.stone == 1, "surface mining adds stone to inventory")
	game.current_location = "cave"
	game.player = game.resource_nodes[2].position
	expect(game.mine_resource(2), "pickaxe mines a cave crystal")
	expect(game.crystals == 1, "cave mining adds crystal to inventory")
	game.free()

func test_fishing_cast_wait_and_catch_cycle() -> void:
	var game := make_game()
	expect(game.WATER_ANIMATION.get_width() == 512 and game.FISH_ANIMATION.get_width() == 160, "CC0 fishing animation sheets are loaded")
	game.selected_tool = game.Tool.ROD
	game.player = game.pond_position + Vector2(120, 0)
	expect(game.use_fishing_rod(), "rod casts near pond")
	expect(game.fishing_state == "casting", "fishing enters waiting state")
	game.update_fishing(2.6)
	expect(game.fishing_state == "ready", "bite becomes ready after timer")
	expect(game.use_fishing_rod() and game.fish == 1, "second action catches fish")
	game.free()

func test_bow_reward_and_crystal_sword_upgrade() -> void:
	var game := make_game()
	game.quest_active = true
	game.carrots = 10
	game.talk_to_grandmother()
	expect(game.has_bow, "carrot quest rewards hunting bow")
	game.slime_gel = 3
	game.wood = 2
	expect(game.craft_sword(), "basic forest sword can be crafted")
	game.crystals = 5
	expect(game.craft_sword(), "five crystals upgrade forest sword")
	expect(game.has_crystal_sword and game.crystals == 0, "crystal sword is stored in inventory")
	game.free()

func test_held_action_repeats_tools_without_reopening_ui() -> void:
	var game := make_game()
	var press := key_event(KEY_E, KEY_E, true)
	var release := key_event(KEY_E, KEY_E, false)
	expect(game.set_action_key_state(press) and game.action_held, "action starts on key-down")
	game.selected_tool = game.Tool.HOE
	game.player = Vector2(390, 240)
	game.facing = Vector2.RIGHT
	game.action_repeat_timer = 0.0
	game.update_held_action(0.2)
	expect(game.plots[Vector2i.ZERO].tilled, "held action tills targeted plot")
	game.player = Vector2(972, 278)
	game.perform_repeatable_action()
	expect(not game.shop_open, "held action does not repeatedly open shop")
	game.set_action_key_state(release)
	expect(not game.action_held, "action stops immediately on key-up")
	var attack_press := key_event(KEY_F, KEY_F, true)
	var attack_release := key_event(KEY_F, KEY_F, false)
	game.set_attack_key_state(attack_press)
	expect(game.attack_held, "attack starts on F key-down")
	game.set_attack_key_state(attack_release)
	expect(not game.attack_held, "attack stops on F key-up")
	game.free()

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

func test_story_and_side_mission_chains() -> void:
	var game := make_game()
	game.player = game.guild_master_position
	expect(game.nearest_interaction() == "guild_master", "story mission giver is interactive")
	game.perform_context_action()
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
	expect(game.mission_states.story_relic == game.QuestSystem.COMPLETED, "relic can be returned to complete story mission")
	expect(game.coins == 140 and game.guardian_armor == 1, "story mission grants coins and equipment")
	game.player = game.herbalist_position
	game.perform_context_action()
	expect(game.mission_states.side_seed == game.QuestSystem.ACTIVE, "herbalist starts side mission")
	game.materials.rare_seeds = 1
	game.perform_context_action()
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
	journal_touch.position = Vector2(1060, 30)
	journal_touch.pressed = true
	expect(game.handle_gamepad_and_touch(journal_touch) and not game.quest_log_open, "touch HUD button closes mission journal")
	game.free()

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

func test_contextual_discoveries_and_new_item_hints() -> void:
	var game := make_game()
	game.discovery_current.clear()
	game.seen_discoveries.clear()
	game.player = Vector2(972, 278)
	expect(game.DiscoverySystem.scan_nearby(game), "approaching an unknown feature opens a contextual hint")
	expect(game.discovery_current.id == "shop" and game.seen_discoveries.has("shop"), "shop hint explains and remembers the discovered feature")
	game.DiscoverySystem.dismiss(game)
	expect(not game.DiscoverySystem.scan_nearby(game), "seen feature does not repeat its hint")
	game.current_location = "cave"
	game.player = Vector2(700, 500)
	game.dropped_items.append({"kind":"moon_relic","count":1,"position":game.player})
	expect(game.DiscoverySystem.scan_nearby(game), "new dropped item opens a discovery hint")
	expect(game.discovery_current.id == "item:moon_relic" and "Мирону" in game.discovery_current.text, "quest item hint explains where to bring it")
	game.DiscoverySystem.dismiss(game)
	expect(game.discovery_current.is_empty(), "context hint can be dismissed")
	game.free()

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
	var required_events := ["move","character_animation","forage_harvest","forage_regrow","forage_sale","plant","rewater","trade","fight","hotbar","equipment","fish","craft_window","mission_complete","journal","side_mission","colored_crystal","day","level_up","skill_point","profession","save","wildlife","world_loot","watermelon","potion","shield","lizard"]
	for event_name in required_events:
		expect(game.tutorial_steps.any(func(step): return step.event == event_name), "tutorial covers feature: %s" % event_name)
	game.free()

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

func test_wildlife_combat_loot_animation_and_save() -> void:
	var game := make_game()
	expect(game.DEER_RUN_SHEET.get_width() == 192 and game.FOX_RUN_SHEET.get_width() == 192 and game.BOAR_RUN_SHEET.get_width() == 160, "wildlife animation sheets are loaded")
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

func test_seeded_world_loot_generation_and_opening() -> void:
	var game := make_game()
	var first: Array = game.LootContainerSystem.generate(123456)
	var repeated: Array = game.LootContainerSystem.generate(123456)
	var different: Array = game.LootContainerSystem.generate(654321)
	expect(first == repeated, "same world seed generates identical loot containers")
	expect(first != different, "different world seed changes positions types or contents")
	expect(first.size() == 19, "random loot is distributed across all seven locations")
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
	expect(game.BONE_PILE_TEXTURE.get_width() == 128, "bone pile sprite is loaded")
	game.free()

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
	touch.position = Vector2(860, 30)
	touch.pressed = true
	expect(game.handle_gamepad_and_touch(touch) and game.skill_menu_open, "touch HUD button opens character development")
	var legacy_snapshot: Dictionary = snapshot.duplicate(true)
	legacy_snapshot.erase("progression")
	game.SaveSystem.apply(game, legacy_snapshot)
	expect(game.skill_points == 0 and game.skill_levels.vitality == 0, "older saves migrate to default RPG skills")
	game.free()

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
