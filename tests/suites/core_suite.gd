extends "res://tests/suites/suite_base.gd"

func run() -> void:
	test_localization_language_selector_and_catalogs()
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

func test_localization_language_selector_and_catalogs() -> void:
	var locale = GameScript.LocaleSystem
	expect(locale.LOCALES == ["ru", "en", "es", "de", "fr", "zh"], "six primary game locales are configured")
	for table in [locale.UI, locale.TEXT, locale.ITEMS, locale.LOCATIONS, locale.TUTORIAL, locale.SKILLS, locale.QUESTS, locale.ENTITIES]:
		for key in table:
			expect(table[key].size() == 6 and table[key].all(func(value): return not String(value).is_empty()), "localization key has six non-empty translations: %s" % key)
	var game := GameScript.new()
	game._ready()
	game.persist_locale_selection = false
	game.language_selected = 0
	expect(game.language_screen and game.language_button_rect(0).size == Vector2(312, 62), "new launch opens a keyboard gamepad and touch language selector")
	var right := key_event(KEY_RIGHT, KEY_RIGHT, true)
	game.handle_language_input(right)
	expect(game.language_selected == 1, "language selector moves immediately with keyboard")
	game.handle_language_input(key_event(KEY_ENTER, KEY_ENTER, true))
	expect(not game.language_screen and locale.current == "en" and locale.ui("title") == "GRANDMA'S FARM", "Enter applies English before the title screen")
	expect(locale.ui("title_subtitle") == "MYSTERY OF MOON VALLEY", "new RPG subtitle is localized with the title")
	expect(game.TITLE_ART.get_width() == 1152 and game.TITLE_ART.get_height() == 648, "title art matches the native viewport without runtime scaling")
	game.language_screen = true
	game.language_selected = 0
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad.pressed = true
	game.handle_language_input(dpad)
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	game.handle_language_input(accept)
	expect(not game.language_screen and locale.current == "en", "D-pad and A select a language")
	game.language_screen = true
	var touch := InputEventScreenTouch.new()
	touch.position = game.language_button_rect(4).get_center()
	touch.pressed = true
	game.handle_language_input(touch)
	expect(not game.language_screen and locale.current == "fr", "touch selects the tapped language button")
	locale.set_locale("zh", false)
	expect(locale.item("watermelon") == "多汁西瓜" and locale.tutorial("shield") == "制作并装备盾牌", "Chinese item and tutorial translations are available")
	locale.set_locale("de", false)
	expect(game.InventorySystem.data("oak_shield").name == "Eichenschild" and game.WorldSystem.name("cave") == "Kristallhöhlen", "systems resolve German names dynamically")
	var settings_path := "user://localization-test.cfg"
	expect(locale.set_locale("es", true, settings_path), "selected locale can be persisted")
	locale.set_locale("ru", false)
	expect(locale.load_locale(settings_path) == "es", "persisted locale is restored on the next launch")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	locale.set_locale("ru", false)
	game.free()

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
