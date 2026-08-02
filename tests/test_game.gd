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
	expect(game.inventory_slots[13] == "seeds" and game.inventory_slots[0] == "", "inventory item moves between slots")
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
