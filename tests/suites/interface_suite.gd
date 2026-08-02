extends "res://tests/suites/suite_base.gd"


func run() -> void:
	test_inventory_layout_and_touch_mapping()
	test_item_context_and_actions()
	test_hud_layout_is_compact_and_safe()
	test_inventory_touch_actions()
	test_mouse_drag_context_and_hotbar()
	test_inventory_sorting()


func test_inventory_layout_and_touch_mapping() -> void:
	var game := make_game()
	for visible_index in game.InventorySystem.VISIBLE_SLOTS:
		var rect: Rect2 = game.InterfaceRenderer.inventory_slot_rect(visible_index)
		expect(game.InterfaceRenderer.INVENTORY_WINDOW.encloses(rect), "inventory grid slot %d stays inside its window" % visible_index)
		expect(game.InterfaceRenderer.inventory_slot_at(rect.get_center(), 0, game.inventory_slots.size()) == visible_index, "inventory touch maps exactly to slot %d" % visible_index)
	for index in 10:
		var rect: Rect2 = game.InterfaceRenderer.inventory_hotbar_rect(index)
		expect(game.InterfaceRenderer.inventory_hotbar_at(rect.get_center()) == index, "inventory quick slot touch maps to %d" % index)
		expect(not rect.intersects(game.InterfaceRenderer.USE_BUTTON) and not rect.intersects(game.InterfaceRenderer.EQUIP_BUTTON), "quick slot %d does not overlap contextual actions" % index)
	game.free()


func test_item_context_and_actions() -> void:
	var game := make_game()
	expect(game.InventorySystem.category("hoe") == "tool", "inventory identifies tools")
	expect(game.InventorySystem.category("carrot") == "food" and game.InventorySystem.can_use("carrot"), "inventory identifies usable food")
	expect(game.InventorySystem.category("iron_helmet") == "equipment" and game.InventorySystem.can_equip("iron_helmet"), "inventory identifies wearable equipment")
	expect(game.InventorySystem.category("moon_relic") == "quest", "inventory protects quest items with a distinct category")
	expect(game.InventorySystem.category("stone") == "resource", "inventory identifies crafting resources")
	expect(not game.InventorySystem.can_use("stone") and not game.InventorySystem.can_equip("stone"), "context buttons stay disabled for incompatible items")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale)
		expect(not game.LocaleSystem.ui("detail_" + game.InventorySystem.category("carrot")).is_empty(), "food detail is localized for %s" % locale)
	game.LocaleSystem.set_locale("ru")
	game.free()


func test_hud_layout_is_compact_and_safe() -> void:
	var game := make_game()
	expect(game.InterfaceRenderer.HUD_RECT.size.y <= 74.0, "gameplay HUD uses less than one eighth of the screen height")
	expect(not game.InterfaceRenderer.SKILL_BUTTON.intersects(game.InterfaceRenderer.QUEST_BUTTON), "HUD menu buttons do not overlap")
	for index in 10:
		var rect: Rect2 = game.InterfaceRenderer.hotbar_rect(index)
		expect(game.InterfaceRenderer.VIEWPORT.encloses(rect), "world quick slot %d stays inside the viewport" % index)
		expect(game.InterfaceRenderer.hotbar_at(rect.get_center()) == index, "world quick slot touch maps to %d" % index)
	game.free()


func test_inventory_touch_actions() -> void:
	var game := make_game()
	game.open_inventory()
	var select_touch := InputEventScreenTouch.new()
	select_touch.position = game.InterfaceRenderer.inventory_slot_rect(1).get_center()
	select_touch.pressed = true
	expect(game.handle_gamepad_and_touch(select_touch) and game.inventory_selected == 1, "touch selects the redesigned inventory slot")
	var assign_touch := InputEventScreenTouch.new()
	assign_touch.position = game.InterfaceRenderer.inventory_hotbar_rect(7).get_center()
	assign_touch.pressed = true
	expect(game.handle_gamepad_and_touch(assign_touch) and game.hotbar_slots[7] == "carrot", "touch assigns selected item in redesigned quick access")
	game.player_hp = 40
	game.carrots = 1
	var use_touch := InputEventScreenTouch.new()
	use_touch.position = game.InterfaceRenderer.USE_BUTTON.get_center()
	use_touch.pressed = true
	expect(game.handle_gamepad_and_touch(use_touch) and game.player_hp == 55, "touch context button consumes selected food")
	game.free()


func test_mouse_drag_context_and_hotbar() -> void:
	var game := make_game()
	game.open_inventory()
	var first_kind: String = game.inventory_slots[0]
	var target_kind: String = game.inventory_slots[5]
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = game.InterfaceRenderer.inventory_slot_rect(0).get_center()
	press.pressed = true
	expect(game.handle_gamepad_and_touch(press) and game.inventory_move_from == 0, "left mouse press starts inventory drag")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = game.InterfaceRenderer.inventory_slot_rect(5).get_center()
	release.pressed = false
	expect(game.handle_gamepad_and_touch(release) and game.inventory_slots[5] == first_kind and game.inventory_slots[0] == target_kind, "mouse drag swaps two inventory slots")
	game.carrots = 1
	game.inventory_selected = game.inventory_slots.find("carrot")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.position = game.InterfaceRenderer.inventory_slot_rect(game.inventory_selected).get_center()
	right_click.pressed = true
	game.player_hp = 40
	game.handle_inventory_input(right_click)
	expect(game.player_hp == 55 and game.carrots == 0, "right click uses edible inventory item contextually")
	game.inventory_open = false
	var hotbar_click := InputEventMouseButton.new()
	hotbar_click.button_index = MOUSE_BUTTON_LEFT
	hotbar_click.position = game.InterfaceRenderer.hotbar_rect(4).get_center()
	hotbar_click.pressed = true
	expect(game.handle_gamepad_and_touch(hotbar_click) and game.selected_hotbar == 4, "mouse selects a world quick slot")
	game.free()


func test_inventory_sorting() -> void:
	var game := make_game()
	for kind in game.state.inventory.counts: game.state.inventory.counts[kind] = 0
	game.has_pickaxe = true
	game.change_inventory_count("carrot", 1)
	game.change_inventory_count("iron_helmet", 1)
	game.change_inventory_count("moon_relic", 1)
	game.change_inventory_count("stone", 1)
	for index in game.inventory_slots.size(): game.inventory_slots[index] = ""
	game.inventory_slots[0] = "stone"
	game.inventory_slots[1] = "iron_helmet"
	game.inventory_slots[2] = "carrot"
	game.inventory_slots[3] = "pickaxe"
	game.inventory_slots[4] = "moon_relic"
	game.inventory_selected = 2
	game.InventorySystem.sort_slots(game)
	expect(game.inventory_slots.slice(0, 5) == ["pickaxe", "carrot", "iron_helmet", "moon_relic", "stone"], "sorting groups tools food equipment quests and resources")
	expect(game.inventory_slots[game.inventory_selected] == "carrot" and game.inventory_scroll_row == 0, "sorting preserves selected item and returns to the first row")
	expect(game.message == game.LocaleSystem.text("inventory_sorted"), "sorting provides localized feedback")
	game.free()
