extends RefCounted

## Единственная точка регистрации игровых действий. Интерфейс может переназначить
## InputMap без изменений в бою, ферме или инвентаре.
const ACTION_BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"use_item": [KEY_E, KEY_SPACE],
	"attack": [KEY_F],
	"inventory": [KEY_TAB, KEY_I],
	"quests": [KEY_J],
	"skills": [KEY_K],
	"save_game": [KEY_F5],
	"load_game": [KEY_F8],
}


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func ensure_default_actions() -> void:
	for action in ACTION_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if not InputMap.action_get_events(action).is_empty():
			continue
		for keycode in ACTION_BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
static func set_action_key_state(game: Node, event: InputEventKey) -> bool:
	if event.keycode != KEY_E and event.keycode != KEY_SPACE:
		return false
	game.action_held = event.pressed
	if event.pressed and not event.echo:
		game.action_repeat_timer = game.ACTION_REPEAT_INTERVAL
	return true


## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
static func set_attack_key_state(game: Node, event: InputEventKey) -> bool:
	if event.keycode != KEY_F:
		return false
	game.attack_held = event.pressed
	if event.pressed and not event.echo:
		game.attack_repeat_timer = game.ATTACK_REPEAT_INTERVAL
	return true


## Обновляет относящуюся к методу часть состояния на текущем кадре.
static func update_held_action(game: Node, delta: float) -> void:
	if not game.action_held or game.title_screen or game.shop_open or game.inventory_open or game.storage_open or game.forge_open:
		return
	game.action_repeat_timer -= delta
	if game.action_repeat_timer > 0.0:
		return
	game.action_repeat_timer = game.ACTION_REPEAT_INTERVAL
	perform_repeatable_action(game)


## Обновляет удерживаемого атаки на текущем кадре.
static func update_held_attack(game: Node, delta: float) -> void:
	if not game.attack_held or game.title_screen or game.shop_open or game.inventory_open or game.storage_open or game.forge_open:
		return
	game.attack_repeat_timer -= delta
	if game.attack_repeat_timer <= 0.0:
		game.attack_repeat_timer = game.ATTACK_REPEAT_INTERVAL
		game.attack_nearest_enemy()


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func perform_repeatable_action(game: Node) -> bool:
	var interaction: String = game.nearest_interaction()
	if interaction.begins_with("resource:"):
		return game.mine_resource(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("drop:"):
		return game.collect_dropped_item(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("food:"):
		return game.collect_food(int(interaction.get_slice(":", 1)))
	if game.current_location != "overworld":
		return false
	var held_kind: String = game.hotbar_slots[game.selected_hotbar]
	if not game.InventorySystem.data(held_kind).has("tool"):
		return false
	game.use_selected_tool()
	game.notify_tutorial("hold_action")
	return true


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func apply_immediate_key_response(game: Node, event: InputEventKey) -> void:
	if event.echo:
		return
	var direction := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: direction = Vector2.LEFT
		KEY_RIGHT: direction = Vector2.RIGHT
		KEY_UP: direction = Vector2.UP
		KEY_DOWN: direction = Vector2.DOWN
	match event.physical_keycode:
		KEY_A: direction = Vector2.LEFT
		KEY_D: direction = Vector2.RIGHT
		KEY_W: direction = Vector2.UP
		KEY_S: direction = Vector2.DOWN
	if direction != Vector2.ZERO:
		game.facing = direction


## Обрабатывает инвентаря мыши и синхронизирует связанное состояние.
static func handle_inventory_mouse(game: Node, event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		game.InventorySystem.scroll(game, -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		game.queue_redraw()
		return
	var slot_index: int = game.InterfaceRenderer.inventory_slot_at(event.position, game.inventory_scroll_row, game.inventory_slots.size())
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if slot_index >= 0:
				game.inventory_selected = slot_index
				game.inventory_move_from = slot_index if not String(game.inventory_slots[slot_index]).is_empty() else -1
			else:
				var hotbar_index: int = game.InterfaceRenderer.inventory_hotbar_at(event.position)
				if hotbar_index >= 0: game.assign_selected_to_hotbar(hotbar_index)
				elif game.InterfaceRenderer.USE_BUTTON.has_point(event.position): game.consume_selected_item()
				elif game.InterfaceRenderer.EQUIP_BUTTON.has_point(event.position): game.equip_selected_item()
				elif game.InterfaceRenderer.SORT_BUTTON.has_point(event.position): game.InventorySystem.sort_slots(game)
		elif game.inventory_move_from >= 0:
			if slot_index >= 0 and game.InventorySystem.swap_slots(game, game.inventory_move_from, slot_index):
				game.inventory_selected = slot_index
				game.message = game.LocaleSystem.text("moved")
			game.inventory_move_from = -1
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and slot_index >= 0:
		game.inventory_selected = slot_index
		var kind: String = game.inventory_slots[slot_index]
		if game.InventorySystem.can_use(kind): game.consume_selected_item()
		elif game.InventorySystem.can_equip(kind): game.equip_selected_item()
	game.InventorySystem.keep_selection_visible(game)
	game.queue_redraw()


## Обрабатывает клавиатуру и геймпад двухколоночного домашнего сундука.
static func handle_storage_input(game: Node, event: InputEvent) -> void:
	var command := -1
	if event is InputEventKey and event.pressed and not event.echo:
		command = int(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		command = {JOY_BUTTON_DPAD_UP:KEY_UP, JOY_BUTTON_DPAD_DOWN:KEY_DOWN, JOY_BUTTON_DPAD_LEFT:KEY_LEFT, JOY_BUTTON_DPAD_RIGHT:KEY_RIGHT, JOY_BUTTON_A:KEY_ENTER, JOY_BUTTON_X:KEY_X, JOY_BUTTON_B:KEY_ESCAPE}.get(event.button_index, -1)
	if command < 0: return
	match command:
		KEY_ESCAPE, KEY_C: game.storage_open = false
		KEY_LEFT, KEY_RIGHT, KEY_TAB:
			game.storage_side = 1 - game.storage_side
			game.storage_selected = 0
		KEY_UP: game.storage_selected -= 1
		KEY_DOWN: game.storage_selected += 1
		KEY_ENTER, KEY_E, KEY_SPACE: game.StorageSystem.transfer_selected(game)
		KEY_X: game.StorageSystem.transfer_selected(game, true)
	game.StorageSystem.clamp_selection(game)
	game.queue_redraw()


## Обрабатывает касания колонок и кнопок переноса домашнего сундука.
static func handle_storage_touch(game: Node, position: Vector2) -> bool:
	if game.InterfaceRenderer.STORAGE_TRANSFER_ONE.has_point(position):
		game.StorageSystem.transfer_selected(game)
	elif game.InterfaceRenderer.STORAGE_TRANSFER_ALL.has_point(position):
		game.StorageSystem.transfer_selected(game, true)
	else:
		var side := 0 if game.InterfaceRenderer.STORAGE_LEFT_ROWS.has_point(position) else (1 if game.InterfaceRenderer.STORAGE_RIGHT_ROWS.has_point(position) else -1)
		if side >= 0:
			var previous_side: int = game.storage_side
			game.storage_side = side
			var items: Array[String] = game.StorageSystem.selected_items(game)
			var start: int = game.StorageSystem.visible_start(game.storage_selected if side == previous_side else 0, items.size())
			game.storage_selected = mini(start + int((position.y - 168.0) / 40.0), maxi(items.size() - 1, 0))
	game.queue_redraw()
	return true


## Обрабатывает клавиатуру и геймпад окна улучшений кузницы.
static func handle_forge_input(game: Node, event: InputEvent) -> void:
	var command := -1
	if event is InputEventKey and event.pressed and not event.echo:
		command = int(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		command = {JOY_BUTTON_DPAD_UP:KEY_UP, JOY_BUTTON_DPAD_DOWN:KEY_DOWN, JOY_BUTTON_A:KEY_ENTER, JOY_BUTTON_B:KEY_ESCAPE}.get(event.button_index, -1)
	if command < 0: return
	match command:
		KEY_ESCAPE, KEY_C: game.forge_open = false
		KEY_UP: game.forge_selected = posmod(game.forge_selected - 1, game.ForgeSystem.UPGRADES.size())
		KEY_DOWN: game.forge_selected = posmod(game.forge_selected + 1, game.ForgeSystem.UPGRADES.size())
		KEY_ENTER, KEY_E, KEY_SPACE: game.ForgeSystem.upgrade(game, game.forge_selected)
	game.queue_redraw()


## Обрабатывает касание строки кузницы как выбор и подтверждение улучшения.
static func handle_forge_touch(game: Node, position: Vector2) -> bool:
	if game.InterfaceRenderer.FORGE_ROWS.has_point(position):
		game.forge_selected = clampi(int((position.y - game.InterfaceRenderer.FORGE_ROWS.position.y) / 44.0), 0, game.ForgeSystem.UPGRADES.size() - 1)
		game.ForgeSystem.upgrade(game, game.forge_selected)
	game.queue_redraw()
	return true


## Обрабатывает клавиатуру и геймпад доски ежедневных контрактов гильдии.
static func handle_contract_input(game: Node, event: InputEvent) -> void:
	var command := -1
	if event is InputEventKey and event.pressed and not event.echo:
		command = int(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		command = {JOY_BUTTON_DPAD_UP:KEY_UP, JOY_BUTTON_DPAD_DOWN:KEY_DOWN, JOY_BUTTON_A:KEY_ENTER, JOY_BUTTON_B:KEY_ESCAPE}.get(event.button_index, -1)
	if command < 0: return
	match command:
		KEY_ESCAPE, KEY_C: game.contract_open = false
		KEY_UP: game.contract_selected = posmod(game.contract_selected - 1, game.ContractSystem.CONTRACT_IDS.size())
		KEY_DOWN: game.contract_selected = posmod(game.contract_selected + 1, game.ContractSystem.CONTRACT_IDS.size())
		KEY_ENTER, KEY_E, KEY_SPACE: game.ContractSystem.act_selected(game)
	game.queue_redraw()


## Выбирает касанием строку контракта и сразу выполняет доступное для неё действие.
static func handle_contract_touch(game: Node, position: Vector2) -> bool:
	if game.InterfaceRenderer.CONTRACT_ROWS.has_point(position):
		game.contract_selected = clampi(int((position.y - game.InterfaceRenderer.CONTRACT_ROWS.position.y) / 100.0), 0, game.ContractSystem.CONTRACT_IDS.size() - 1)
		game.ContractSystem.act_selected(game)
	game.queue_redraw()
	return true


## Листает страницы журнала по экранным стрелкам и сообщает, было ли касание обработано.
static func handle_quest_pointer(game: Node, position: Vector2) -> bool:
	if game.InterfaceRenderer.QUEST_PREV.has_point(position):
		game.quest_log_page = maxi(0, game.quest_log_page - 1)
	elif game.InterfaceRenderer.QUEST_NEXT.has_point(position):
		game.quest_log_page = mini(ceili(float(game.QuestSystem.MISSIONS.size()) / 3.0) - 1, game.quest_log_page + 1)
	else:
		return false
	game.queue_redraw()
	return true


## Маршрутизирует событие в единственное открытое модальное окно до мирового управления.
static func handle_modal_input(game: Node, event: InputEvent) -> bool:
	if game.shop_open:
		game.handle_shop_input(event)
	elif game.storage_open:
		handle_storage_input(game, event)
	elif game.forge_open:
		handle_forge_input(game, event)
	elif game.contract_open:
		handle_contract_input(game, event)
	elif game.quest_log_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_J, KEY_ESCAPE]: game.toggle_quest_log()
			elif event.keycode in [KEY_LEFT, KEY_PAGEUP]: game.quest_log_page = maxi(0, game.quest_log_page - 1)
			elif event.keycode in [KEY_RIGHT, KEY_PAGEDOWN]: game.quest_log_page = mini(ceili(float(game.QuestSystem.MISSIONS.size()) / 3.0) - 1, game.quest_log_page + 1)
			game.queue_redraw()
		elif event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B: game.toggle_quest_log()
			elif event.button_index == JOY_BUTTON_DPAD_LEFT: game.quest_log_page = maxi(0, game.quest_log_page - 1)
			elif event.button_index == JOY_BUTTON_DPAD_RIGHT: game.quest_log_page = mini(ceili(float(game.QuestSystem.MISSIONS.size()) / 3.0) - 1, game.quest_log_page + 1)
			game.queue_redraw()
	elif game.skill_menu_open:
		game.handle_skill_menu_input(event)
	elif game.crafting_open:
		game.handle_crafting_input(event)
	elif game.inventory_open:
		game.handle_inventory_input(event)
	else:
		return false
	return true
