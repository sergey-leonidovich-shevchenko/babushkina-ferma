extends "res://tests/suites/suite_base.gd"


## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_inventory_uses_grandmother_skin_and_six_rows()
	test_inventory_layout_and_touch_mapping()
	test_item_context_and_actions()
	test_hud_layout_is_compact_and_safe()
	test_inventory_touch_actions()
	test_mouse_drag_context_and_hotbar()
	test_inventory_sorting()
	test_every_owned_item_has_a_visible_slot_and_icon_fallback()
	test_inventory_category_filters_support_pointer_and_gamepad()


## Сценарий: рюкзак использует утверждённый резной скин и сетку эталона 6×6.
## Исходное состояние: графический ресурс загружен, а константы интерфейса доступны без запуска окна.
## Ожидаемый результат: скин имеет исходное соотношение 16:9, показаны 36 ячеек, а рабочие панели не выходят за деревянную раму.
func test_inventory_uses_grandmother_skin_and_six_rows() -> void:
	var game := make_game()
	expect(game.InterfaceRenderer.INVENTORY_SKIN.get_size() == Vector2(1672, 941), "inventory uses the approved full-resolution grandmother skin")
	expect(game.InventorySystem.VISIBLE_ROWS == 6 and game.InventorySystem.VISIBLE_SLOTS == 36, "reference 6 by 6 item grid is preserved")
	expect(game.InterfaceRenderer.INVENTORY_WINDOW.encloses(game.InterfaceRenderer.inventory_slot_rect(35)), "last cell of the reference grid stays inside the carved frame")
	expect(game.InterfaceRenderer.INVENTORY_WINDOW.encloses(game.InterfaceRenderer.inventory_hotbar_rect(9)), "tenth quick slot stays inside the carved frame")
	game.free()


## Сценарий: все ячейки рюкзака и быстрых слотов находятся внутри окна и точно распознают касания.
## Исходное состояние: новая игра со стандартным рюкзаком; нужные количества предметов и открытые окна задаются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
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
	for index in game.InventorySystem.FILTERS.size():
		var tab: Rect2 = game.InterfaceRenderer.inventory_category_rect(index)
		expect(game.InterfaceRenderer.INVENTORY_WINDOW.encloses(tab) and game.InterfaceRenderer.inventory_category_at(tab.get_center()) == game.InventorySystem.FILTERS[index], "wooden inventory category maps exactly: %s" % game.InventorySystem.FILTERS[index])
	game.free()


## Сценарий: категории скрывают неподходящие предметы и переключаются указателем и плечевыми кнопками.
## Исходное состояние: в рюкзаке есть еда, ресурс и экипировка, активна общая вкладка.
## Ожидаемый результат: каждая вкладка возвращает только свой тип, выбор остаётся видимым, цикл не выходит за каталог.
func test_inventory_category_filters_support_pointer_and_gamepad() -> void:
	var game := make_game(); game.change_inventory_count("carrot", 1); game.change_inventory_count("stone", 1); game.change_inventory_count("iron_helmet", 1); game.open_inventory()
	expect(game.InventorySystem.set_filter(game, "food") and game.InventorySystem.filtered_indices(game).all(func(index): return game.InventorySystem.category(game.inventory_slots[index]) == "food"), "food tab contains only owned edible items")
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = game.InterfaceRenderer.inventory_category_rect(4).get_center()
	game.InventoryInputSystem.handle_mouse(game, click)
	expect(game.inventory_filter == "resource" and game.InventorySystem.category(game.inventory_slots[game.inventory_selected]) == "resource", "mouse selects resource tab and its first owned item")
	game.InventorySystem.cycle_filter(game, 1)
	expect(game.inventory_filter == "quest", "gamepad-style category cycling advances in fixed order")
	game.free()


## Сценарий: категория предмета определяет описание и доступность употребления или экипировки.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
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


## Сценарий: частичное старое сохранение содержит предмет, но потеряло его позицию в сетке.
## Исходное состояние: у героя есть металл и редкие семена, их идентификаторы вручную удалены из слотов.
## Ожидаемый результат: открытие рюкзака возвращает оба слота, а каждый предмет каталога имеет видимый знак fallback.
func test_every_owned_item_has_a_visible_slot_and_icon_fallback() -> void:
	var game := make_game(); game.state.inventory.counts.metal = 3; game.state.inventory.counts.rare_seeds = 2
	game.inventory_slots.erase("metal"); game.inventory_slots.erase("rare_seeds"); game.open_inventory()
	expect(game.inventory_slots.has("metal") and game.inventory_slots.has("rare_seeds"), "inventory repairs missing slots for every owned legacy item")
	for kind in game.InventorySystem.ITEM_DATA:
		expect(not game.fallback_item_glyph(kind).is_empty(), "registered item always has visible icon fallback: %s" % kind)
	game.free()


## Сценарий: игровой интерфейс занимает ограниченную высоту, а его кнопки и быстрые слоты не перекрываются.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_hud_layout_is_compact_and_safe() -> void:
	var game := make_game()
	expect(game.InterfaceRenderer.HUD_RECT.size.y <= 90.0, "selected adventurer HUD keeps its height below one seventh of the screen")
	expect(not game.InterfaceRenderer.SKILL_BUTTON.intersects(game.InterfaceRenderer.QUEST_BUTTON), "HUD menu buttons do not overlap")
	expect(game.InterfaceRenderer.HUD_RECT.encloses(game.InterfaceRenderer.PLAYER_PORTRAIT_RECT) and game.InterfaceRenderer.HUD_RECT.encloses(game.InterfaceRenderer.CLOCK_BADGE), "portrait and calendar stay inside the carved top frame")
	expect(game.InterfaceRenderer.HUD_RECT.encloses(game.InterfaceRenderer.LOCATION_BADGE), "persistent location badge stays inside compact HUD")
	expect(not game.InterfaceRenderer.LOCATION_BADGE.intersects(game.InterfaceRenderer.PLAYER_BARS_RECT) and not game.InterfaceRenderer.LOCATION_BADGE.intersects(game.InterfaceRenderer.SKILL_BUTTON), "location badge does not overlap player bars or menu buttons")
	expect(not game.InterfaceRenderer.PLAYER_BARS_RECT.intersects(game.InterfaceRenderer.CLOCK_BADGE) and not game.InterfaceRenderer.CLOCK_BADGE.intersects(game.InterfaceRenderer.LOCATION_BADGE), "second concept keeps portrait bars clock and location in separate modules")
	for weather in game.WorldEventSystem.WEATHER_NAMES:
		expect(not game.InterfaceRenderer.weather_icon(weather).is_empty(), "every weather state has a readable HUD icon: %s" % weather)
	for location in game.WorldSystem.LOCATIONS:
		expect(not game.InterfaceRenderer.location_icon(location).is_empty(), "location badge has an icon for %s" % location)
	for location in game.BuildingSystem.INTERIORS:
		expect(not game.InterfaceRenderer.location_icon(location).is_empty(), "interior location badge has an icon for %s" % location)
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale)
		expect(not game.LocaleSystem.ui("location_label", [game.WorldSystem.name("cave")]).is_empty(), "persistent location name is localized for %s" % locale)
	game.LocaleSystem.set_locale("ru")
	expect(game.InterfaceRenderer.HOTBAR_SLOT_SIZE == game.InterfaceRenderer.INVENTORY_HOTBAR_SIZE, "world and inventory quick slots use the same approved dimensions")
	expect(is_equal_approx(game.InterfaceRenderer.HOTBAR_PITCH, game.InterfaceRenderer.INVENTORY_HOTBAR_PITCH), "world and inventory quick slots use the same spacing")
	for index in 10:
		var rect: Rect2 = game.InterfaceRenderer.hotbar_rect(index)
		expect(game.InterfaceRenderer.VIEWPORT.encloses(rect), "world quick slot %d stays inside the viewport" % index)
		expect(game.InterfaceRenderer.WORLD_HOTBAR_PANEL.encloses(rect), "world quick slot %d stays inside the inventory-style wooden panel" % index)
		expect(game.InterfaceRenderer.hotbar_at(rect.get_center()) == index, "world quick slot touch maps to %d" % index)
	game.free()


## Сценарий: касание выбирает предмет, назначает его в панель быстрого доступа и употребляет через контекстную кнопку.
## Исходное состояние: новая игра со стандартным рюкзаком; нужные количества предметов и открытые окна задаются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
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


## Сценарий: мышь перетаскивает предметы, выполняет действие правой кнопкой и выбирает панель быстрого доступа.
## Исходное состояние: новая игра со стандартным рюкзаком; нужные количества предметов и открытые окна задаются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
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


## Сценарий: сортировка группирует предметы по назначению и сохраняет текущий выбор.
## Исходное состояние: новая игра со стандартным рюкзаком; нужные количества предметов и открытые окна задаются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
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
