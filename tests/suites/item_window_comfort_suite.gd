extends "res://tests/suites/suite_base.gd"


## Запускает регрессии удобства предметных окон через реальный маршрутизатор ввода.
func run() -> void:
	test_inventory_drag_assigns_hotbar_without_moving_stack()
	test_item_tooltip_content_stays_above_actions()
	test_routed_crafting_requires_explicit_create_action()
	test_routed_shop_buttons_preserve_deliberate_transactions()
	test_routed_forge_buttons_separate_selection_upgrade_and_repair()
	test_inventory_right_click_and_scroll_reach_the_active_window()


## Сценарий: игрок перетаскивает предмет на быстрый слот и затем использует подсказки клавиатуры и геймпада.
## Исходное состояние: рюкзак открыт, первый предмет имеет известный запас, а нужный быстрый слот содержит другой предмет.
## Ожидаемый результат: отпускание мыши назначает быстрый доступ без расхода или перемещения стопки, а подписи совпадают с действующими клавишами.
func test_inventory_drag_assigns_hotbar_without_moving_stack() -> void:
	var game := make_game()
	game.open_inventory()
	var indices: Array[int] = game.InventorySystem.filtered_indices(game)
	var original_index := indices[0]
	var kind: String = game.inventory_slots[original_index]
	var amount: int = game.inventory_item_count(kind)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	press.position = game.InterfaceRenderer.inventory_slot_rect(0).get_center()
	game._input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false
	release.position = game.InterfaceRenderer.inventory_hotbar_rect(7).get_center()
	game._input(release)
	expect(game.hotbar_slots[7] == kind and game.inventory_slots[original_index] == kind and game.inventory_item_count(kind) == amount, "dropping inventory item on quick slot assigns it without consuming or moving the stack")
	expect(game.inventory_move_from == -1, "hotbar drop completes the drag state")
	expect(game.InventoryInputSystem.action_label(game, "eat").ends_with("• E") and game.InventoryInputSystem.action_label(game, "equip").ends_with("• Q"), "keyboard hints never advertise the destructive X binding as equip")
	game.handle_inventory_input(joypad_button_event(JOY_BUTTON_DPAD_RIGHT, true))
	expect(game.InventoryInputSystem.action_label(game, "eat").ends_with("• A") and game.InventoryInputSystem.action_label(game, "equip").ends_with("• X"), "controller hints use the actual A and X actions")
	game.inventory_move_from = original_index
	game.handle_inventory_input(joypad_button_event(JOY_BUTTON_B, true))
	expect(not game.inventory_open and game.inventory_move_from == -1, "standard controller cancel closes the backpack and clears its drag state")
	game.free()


## Сценарий: описание предмета строится для еды, изношенного оружия и экипировки при открытом рюкзаке.
## Исходное состояние: карточка ограничена областью над кнопками действий, у предметов присутствуют различные эффекты и прочность.
## Ожидаемый результат: текстовые области, прогресс прочности и сравнение находятся в карточке и не перекрывают кнопки или иконку.
func test_item_tooltip_content_stays_above_actions() -> void:
	var game := make_game()
	var tooltip: Rect2 = game.InterfaceRenderer.INVENTORY_TOOLTIP_RECT
	for has_effect in [false, true]:
		for has_durability in [false, true]:
			var layout: Dictionary = game.InterfaceRenderer.ItemTooltipRenderer.content_layout(tooltip, has_effect, has_durability)
			for id in layout:
				var rect: Rect2 = layout[id]
				expect(tooltip.encloses(rect) and not rect.intersects(game.InterfaceRenderer.USE_BUTTON) and not rect.intersects(game.InterfaceRenderer.EQUIP_BUTTON), "item content %s remains above all backpack actions" % id)
			expect(not (layout.icon as Rect2).intersects(layout.title), "wrapped item title has independent space beside the icon")
	var last_slot: Rect2 = game.InterfaceRenderer.inventory_slot_rect(35)
	expect(last_slot.end.y <= game.InterfaceRenderer.INVENTORY_GRID_PANEL.end.y-7 and game.InterfaceRenderer.INVENTORY_GRID_PANEL.encloses(last_slot), "sixth inventory row stays inside the fullscreen grid with bottom padding")
	game.free()


## Сценарий: настоящее платформенное событие выбирает рецепт, создаёт предмет явной кнопкой и закрывает рюкзак крестиком.
## Исходное состояние: узел игры находится в дереве сцены, у игрока два бревна, на верстаке ещё не выбран распил.
## Ожидаемый результат: выбор не расходует сырьё, кнопка создаёт ровно одну партию, а видимые крестики действительно закрывают окна через общий маршрутизатор.
func test_routed_crafting_requires_explicit_create_action() -> void:
	var game := GameScript.new()
	context.root.add_child(game)
	game.language_screen = false; game.title_screen = false
	game.LocaleSystem.set_locale("ru")
	game.change_inventory_count("log", 2)
	game.open_crafting()
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT; pointer.pressed = true
	pointer.position = game.ItemWindowRenderer.craft_row_rect(1).get_center()
	game._input(pointer)
	expect(game.CraftingSystem.RECIPES[game.crafting_selected].output == "plank" and game.inventory_item_count("log") == 2 and game.inventory_item_count("plank") == 0, "routed recipe click selects its preview without spending materials")
	pointer.position = game.ItemWindowRenderer.CRAFT_ACTION.get_center()
	game._input(pointer)
	expect(game.inventory_item_count("log") == 1 and game.inventory_item_count("plank") == 4, "routed explicit create button spends one log for exactly four planks")
	pointer.position = game.ItemWindowRenderer.CLOSE_BUTTON.get_center()
	game._input(pointer)
	expect(not game.crafting_open, "routed click closes the crafting window from its visible cross")
	game.open_inventory()
	pointer.position = game.InterfaceRenderer.INVENTORY_CLOSE_BUTTON.get_center()
	game._input(pointer)
	expect(not game.inventory_open, "routed click closes the backpack from its separately positioned cross")
	game.free()


## Сценарий: игрок выбирает товар мышью, покупает явной кнопкой и продаёт касанием.
## Исходное состояние: лавка открыта, у игрока сорок монет и одна морковь, первоначально выбраны семена.
## Ожидаемый результат: выбор не проводит сделку, покупка и продажа сохраняют точные суммы, а недоступные кнопки не меняют предметы и монеты.
func test_routed_shop_buttons_preserve_deliberate_transactions() -> void:
	var game := make_game()
	game.shop_open = true; game.coins = 40; game.carrots = 1
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT; pointer.pressed = true
	pointer.position = game.ItemWindowRenderer.shop_row_rect(1).get_center()
	game._input(pointer)
	expect(game.shop_selected == 1 and game.coins == 40 and game.carrots == 1, "routed shop row selects carrot without buying or selling it")
	pointer.position = game.ItemWindowRenderer.SHOP_BUY_ACTION.get_center()
	game._input(pointer)
	expect(game.coins == 30 and game.carrots == 2, "deliberate buy button uses the exact shop price and quantity")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true; touch.position = game.ItemWindowRenderer.SHOP_SELL_ACTION.get_center()
	game._input(touch)
	expect(game.coins == 38 and game.carrots == 1, "touch sell button exchanges exactly one carrot for eight coins")
	game.coins = 0
	game._input(pointer)
	expect(not game.ShopSystem.can_buy(game, 1) and game.carrots == 1 and game.coins == 0, "disabled buy cannot spend unavailable money")
	game.carrots = 0
	game._input(touch)
	expect(not game.ShopSystem.can_sell(game, 1) and game.coins == 0, "disabled sell cannot create money from an absent item")
	game.coins = 40; game.state.world.estate.event = "traveler"
	expect(game.ShopSystem.purchase_price(game, game.shop_products[1]) == 8, "visible purchase price includes the same day discount as the transaction")
	game.shop_products[1].stock_day = game.day; game.shop_products[1].stock = 0
	expect(not game.ShopSystem.can_buy(game, 1), "sold out daily stock disables the purchase action")
	pointer.button_index = MOUSE_BUTTON_WHEEL_DOWN
	game._input(pointer)
	expect(game.shop_selected == 2, "shop wheel navigation reaches goods beyond the current selection")
	game._input(joypad_button_event(JOY_BUTTON_B, true))
	expect(not game.shop_open, "controller cancel closes the shop")
	game.free()


## Сценарий: кузница принимает мышью отдельные команды выбора, улучшения и ремонта, затем сундук переносит предмет.
## Исходное состояние: выбранный меч имеет сорок процентов прочности, для улучшения хватает металла и камня, у героя двадцать монет.
## Ожидаемый результат: выбор не расходует ресурсы, улучшение списывает точную стоимость, ремонт списывает шесть монет, а сундук сохраняет суммарное количество предметов.
func test_routed_forge_buttons_separate_selection_upgrade_and_repair() -> void:
	var game := make_game()
	game.change_inventory_count("sword", 1)
	game.materials.metal = 5; game.materials.stone = 5
	game.state.inventory.durability.sword = 40; game.coins = 20; game.forge_open = true
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT; pointer.pressed = true
	pointer.position = game.ItemWindowRenderer.forge_row_rect(0).get_center()
	game._input(pointer)
	expect(game.ForgeSystem.level(game, "sword") == 0 and game.materials.metal == 5, "routed forge row selection never spends upgrade resources")
	pointer.position = game.ItemWindowRenderer.FORGE_UPGRADE_ACTION.get_center()
	game._input(pointer)
	expect(game.ForgeSystem.level(game, "sword") == 1 and game.materials.metal == 3 and game.materials.stone == 4, "explicit forge upgrade spends the exact material recipe")
	pointer.position = game.ItemWindowRenderer.FORGE_REPAIR_ACTION.get_center()
	game._input(pointer)
	expect(game.state.inventory.durability.sword == 100 and game.coins == 14, "explicit repair restores durability and charges its displayed price")
	game._input(pointer)
	expect(game.coins == 14, "repairing a fully repaired item is disabled without further charges")
	game.forge_open = false; game.home_chest_owned = true; game.current_location = "cottage_interior"; game.carrots = 3
	game.StorageSystem.open(game)
	game.storage_selected = game.StorageSystem.inventory_items(game).find("carrot")
	pointer.position = game.InterfaceRenderer.STORAGE_TRANSFER_ONE.get_center()
	game._input(pointer)
	expect(game.carrots == 2 and game.state.storage.count("carrot") == 1, "routed storage mouse button transfers one item without loss or duplication")
	game.free()


## Сценарий: игрок использует правую кнопку мыши и колесо в открытом рюкзаке.
## Исходное состояние: здоровье снижено, в видимой ячейке есть морковь, а после добавления коллекции инвентарь требует прокрутки.
## Ожидаемый результат: события проходят через основной маршрутизатор, еда восстанавливает здоровье, колесо меняет видимую строку.
func test_inventory_right_click_and_scroll_reach_the_active_window() -> void:
	var game := make_game()
	game.carrots = 2; game.player_hp = 40; game.open_inventory()
	var carrot_slot: int = game.InventorySystem.filtered_indices(game).find(game.inventory_slots.find("carrot"))
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_RIGHT; pointer.pressed = true
	pointer.position = game.InterfaceRenderer.inventory_slot_rect(carrot_slot).get_center()
	game._input(pointer)
	expect(game.carrots == 1 and game.player_hp == 55, "routed right-click consumes food instead of being discarded by left-button filtering")
	for kind in game.InventorySystem.ITEM_DATA: game.change_inventory_count(String(kind), 1)
	pointer.button_index = MOUSE_BUTTON_WHEEL_DOWN
	game._input(pointer)
	expect(game.inventory_scroll_row == 1, "routed mouse wheel scrolls the actual backpack contents")
	game.free()
