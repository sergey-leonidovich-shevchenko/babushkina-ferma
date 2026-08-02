extends SceneTree

const GameScript = preload("res://scripts/game.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	test_keyboard_press_and_release()
	test_immediate_keyboard_response()
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
	expect(game.perform_repeatable_action() and game.mushrooms == 1, "wild food sprite can be collected while action is held")
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
