extends RefCounted


## Обрабатывает мышь, клавиатуру и геймпад открытого инвентаря в одном изолированном модуле.
static func handle(game: Node, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		handle_mouse(game, event)
		return
	if event is InputEventJoypadButton and event.pressed:
		var previous_selected: int = game.inventory_selected
		var previous_filter: String = game.inventory_filter
		var was_open: bool = game.inventory_open
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: game.InventorySystem.move_filtered_selection(game, -1)
			JOY_BUTTON_DPAD_RIGHT: game.InventorySystem.move_filtered_selection(game, 1)
			JOY_BUTTON_DPAD_UP: game.InventorySystem.move_filtered_selection(game, -6)
			JOY_BUTTON_DPAD_DOWN: game.InventorySystem.move_filtered_selection(game, 6)
			JOY_BUTTON_LEFT_SHOULDER: game.InventorySystem.cycle_filter(game, -1)
			JOY_BUTTON_RIGHT_SHOULDER: game.InventorySystem.cycle_filter(game, 1)
			JOY_BUTTON_A: game.consume_selected_item()
			JOY_BUTTON_X: game.equip_selected_item()
			JOY_BUTTON_Y: game.inventory_open = false
		game.InventorySystem.keep_selection_visible(game)
		sync_feedback(game, previous_selected, previous_filter, was_open)
		game.queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	var previous_selected: int = game.inventory_selected
	var previous_filter: String = game.inventory_filter
	var was_open: bool = game.inventory_open
	match event.keycode:
		KEY_ESCAPE, KEY_I, KEY_TAB: game.inventory_open = false; game.inventory_move_from = -1
		KEY_LEFT: game.InventorySystem.move_filtered_selection(game, -1)
		KEY_RIGHT: game.InventorySystem.move_filtered_selection(game, 1)
		KEY_UP: game.InventorySystem.move_filtered_selection(game, -6)
		KEY_DOWN: game.InventorySystem.move_filtered_selection(game, 6)
		KEY_BRACKETLEFT: game.InventorySystem.cycle_filter(game, -1)
		KEY_BRACKETRIGHT: game.InventorySystem.cycle_filter(game, 1)
		KEY_PAGEUP: game.InventorySystem.move_filtered_selection(game, -game.InventorySystem.VISIBLE_SLOTS)
		KEY_PAGEDOWN: game.InventorySystem.move_filtered_selection(game, game.InventorySystem.VISIBLE_SLOTS)
		KEY_M: game.move_inventory_slot()
		KEY_S: game.InventorySystem.sort_slots(game)
		KEY_X: game.drop_selected_item()
		KEY_ENTER, KEY_E: game.consume_selected_item()
		KEY_Q: game.equip_selected_item()
		KEY_1: game.assign_selected_to_hotbar(0)
		KEY_2: game.assign_selected_to_hotbar(1)
		KEY_3: game.assign_selected_to_hotbar(2)
		KEY_4: game.assign_selected_to_hotbar(3)
		KEY_5: game.assign_selected_to_hotbar(4)
		KEY_6: game.assign_selected_to_hotbar(5)
		KEY_7: game.assign_selected_to_hotbar(6)
		KEY_8: game.assign_selected_to_hotbar(7)
		KEY_9: game.assign_selected_to_hotbar(8)
		KEY_0: game.assign_selected_to_hotbar(9)
		KEY_DELETE, KEY_BACKSPACE: game.delete_selected_item()
	game.InventorySystem.keep_selection_visible(game)
	sync_feedback(game, previous_selected, previous_filter, was_open)
	game.queue_redraw()


## Обрабатывает прокрутку, вкладки, перетаскивание и контекстные действия мыши.
static func handle_mouse(game: Node, event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		game.InventorySystem.scroll(game, -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1); game.queue_redraw(); return
	var category: String = game.InterfaceRenderer.inventory_category_at(event.position)
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not category.is_empty():
		press_at(game, event.position)
		game.InventorySystem.set_filter(game, category); game.queue_redraw(); return
	var slot_index: int = game.InterfaceRenderer.inventory_slot_at_game(game, event.position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_at(game, event.position)
			if slot_index >= 0:
				game.inventory_selected = slot_index
				game.inventory_move_from = slot_index if not String(game.inventory_slots[slot_index]).is_empty() else -1
			else:
				var hotbar_index: int = game.InterfaceRenderer.inventory_hotbar_at(event.position)
				if hotbar_index >= 0: game.assign_selected_to_hotbar(hotbar_index)
				elif game.InterfaceRenderer.USE_BUTTON.has_point(event.position): game.consume_selected_item()
				elif game.InterfaceRenderer.EQUIP_BUTTON.has_point(event.position): game.equip_selected_item()
				elif game.InterfaceRenderer.DROP_BUTTON.has_point(event.position): game.drop_selected_item()
				elif game.InterfaceRenderer.SORT_BUTTON.has_point(event.position): game.InventorySystem.sort_slots(game)
		elif game.inventory_move_from >= 0:
			if slot_index >= 0 and game.InventorySystem.swap_slots(game, game.inventory_move_from, slot_index): game.inventory_selected = slot_index; game.message = game.LocaleSystem.text("moved")
			game.inventory_move_from = -1
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and slot_index >= 0:
		game.inventory_selected = slot_index
		var kind: String = game.inventory_slots[slot_index]
		if game.InventorySystem.can_use(kind): game.consume_selected_item()
		elif game.InventorySystem.can_equip(kind): game.equip_selected_item()
	game.InventorySystem.keep_selection_visible(game)
	game.queue_redraw()


## Обрабатывает касание вкладки, предмета, хотбара или крупной кнопки действия.
static func handle_touch(game: Node, position: Vector2) -> bool:
	press_at(game, position)
	var category: String = game.InterfaceRenderer.inventory_category_at(position)
	if not category.is_empty(): return game.InventorySystem.set_filter(game, category)
	var inventory_index: int = game.InterfaceRenderer.inventory_slot_at_game(game, position)
	var hotbar_index: int = game.InterfaceRenderer.inventory_hotbar_at(position)
	if inventory_index >= 0: game.inventory_selected = inventory_index
	elif hotbar_index >= 0: game.assign_selected_to_hotbar(hotbar_index)
	elif game.InterfaceRenderer.USE_BUTTON.has_point(position): game.consume_selected_item()
	elif game.InterfaceRenderer.EQUIP_BUTTON.has_point(position): game.equip_selected_item()
	elif game.InterfaceRenderer.DROP_BUTTON.has_point(position): game.drop_selected_item()
	game.InventorySystem.keep_selection_visible(game)
	game.queue_redraw()
	return true


## Синхронизирует звуковой фокус рюкзака после клавиатурной или геймпадной команды.
static func sync_feedback(game: Node, previous_selected: int, previous_filter: String, was_open: bool) -> void:
	if was_open and not game.inventory_open:
		game.UiFeedbackSystem.back(game)
		return
	if previous_filter != game.inventory_filter:
		game.UiFeedbackSystem.focus(game, "inventory_filter:%s" % game.inventory_filter)
	elif previous_selected != game.inventory_selected:
		game.UiFeedbackSystem.focus(game, "inventory_slot:%d" % game.inventory_selected)


## Находит нарисованный элемент рюкзака под указателем и запускает общий отклик нажатия.
static func press_at(game: Node, position: Vector2) -> void:
	var category: String = game.InterfaceRenderer.inventory_category_at(position)
	if not category.is_empty():
		game.UiFeedbackSystem.press(game, game.InterfaceRenderer.inventory_category_rect(game.InventorySystem.FILTERS.find(category)))
		return
	var actual_index: int = game.InterfaceRenderer.inventory_slot_at_game(game, position)
	if actual_index >= 0:
		var visible_index: int = game.InventorySystem.filtered_indices(game).find(actual_index)
		if visible_index >= 0: game.UiFeedbackSystem.press(game, game.InterfaceRenderer.inventory_slot_rect(visible_index - game.inventory_scroll_row * 6))
		return
	for rect in [game.InterfaceRenderer.USE_BUTTON, game.InterfaceRenderer.EQUIP_BUTTON, game.InterfaceRenderer.DROP_BUTTON, game.InterfaceRenderer.SORT_BUTTON]:
		if rect.has_point(position): game.UiFeedbackSystem.press(game, rect); return
	var hotbar_index: int = game.InterfaceRenderer.inventory_hotbar_at(position)
	if hotbar_index >= 0: game.UiFeedbackSystem.press(game, game.InterfaceRenderer.inventory_hotbar_rect(hotbar_index))
