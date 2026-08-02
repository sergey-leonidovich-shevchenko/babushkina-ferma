extends "res://tests/suites/suite_base.gd"


func run() -> void:
	test_inventory_layout_and_touch_mapping()
	test_item_context_and_actions()
	test_hud_layout_is_compact_and_safe()
	test_inventory_touch_actions()


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
