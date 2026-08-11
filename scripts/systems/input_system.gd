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
	"dodge": [KEY_SHIFT],
	"block": [KEY_G],
	"inventory": [KEY_TAB, KEY_I],
	"quests": [KEY_J],
	"skills": [KEY_K],
	"world_map": [KEY_M],
	"save_game": [KEY_F5],
	"load_game": [KEY_F8],
}
const JOY_AXIS_DEAD_ZONE := 0.2


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


## Синхронизирует удержание основного действия для геймпада и сенсорного экрана, включая отпускание.
static func set_pointer_action_state(game: Node, event: InputEvent, world_controls_visible: bool) -> bool:
	if not world_controls_visible: return false
	var is_action: bool = (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A) or event is InputEventScreenTouch
	if not is_action: return false
	game.action_held = event.pressed
	return not event.pressed


## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
static func set_attack_key_state(game: Node, event: InputEventKey) -> bool:
	if event.keycode != KEY_F:
		return false
	game.attack_held = event.pressed
	if event.pressed and not event.echo:
		game.attack_repeat_timer = game.ATTACK_REPEAT_INTERVAL
	return true


## Обновляет направление движения по кнопкам D-Pad.
static func set_movement_button_state(game: Node, event: InputEventJoypadButton) -> bool:
	if not event.pressed and event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			game.move_left_held = false
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			game.move_right_held = false
		elif event.button_index == JOY_BUTTON_DPAD_UP:
			game.move_up_held = false
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			game.move_down_held = false
		return true
	if not event.pressed:
		return false
	match event.button_index:
		JOY_BUTTON_DPAD_LEFT:
			game.move_left_held = true
			game.move_right_held = false
		JOY_BUTTON_DPAD_RIGHT:
			game.move_right_held = true
			game.move_left_held = false
		JOY_BUTTON_DPAD_UP:
			game.move_up_held = true
			game.move_down_held = false
		JOY_BUTTON_DPAD_DOWN:
			game.move_down_held = true
			game.move_up_held = false
		_:
			return false
	return true


## Обновляет направление движения для левого стикa геймпада с dead-zone.
static func set_movement_motion_state(game: Node, event: InputEventJoypadMotion) -> bool:
	match event.axis:
		JOY_AXIS_LEFT_X:
			var x_axis := clampf(event.axis_value, -1.0, 1.0)
			if absf(x_axis) < JOY_AXIS_DEAD_ZONE:
				game.move_left_held = false
				game.move_right_held = false
			else:
				game.move_left_held = x_axis < 0.0
				game.move_right_held = x_axis > 0.0
			return true
		JOY_AXIS_LEFT_Y:
			var y_axis := clampf(event.axis_value, -1.0, 1.0)
			if absf(y_axis) < JOY_AXIS_DEAD_ZONE:
				game.move_up_held = false
				game.move_down_held = false
			else:
				# В Godot по умолчанию ось Y на стикe растет вниз.
				game.move_up_held = y_axis < 0.0
				game.move_down_held = y_axis > 0.0
			return true
	return false


## Обновляет относящуюся к методу часть состояния на текущем кадре.
static func update_held_action(game: Node, delta: float) -> void:
	if game.state.fishing.phase != game.FishingSystem.PHASE_IDLE: return
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
		command = {JOY_BUTTON_DPAD_UP:KEY_UP, JOY_BUTTON_DPAD_DOWN:KEY_DOWN, JOY_BUTTON_A:KEY_ENTER, JOY_BUTTON_X:KEY_R, JOY_BUTTON_B:KEY_ESCAPE}.get(event.button_index, -1)
	if command < 0: return
	match command:
		KEY_ESCAPE, KEY_C: game.forge_open = false
		KEY_UP: game.forge_selected = posmod(game.forge_selected - 1, game.ForgeSystem.UPGRADES.size())
		KEY_DOWN: game.forge_selected = posmod(game.forge_selected + 1, game.ForgeSystem.UPGRADES.size())
		KEY_ENTER, KEY_E, KEY_SPACE: game.ForgeSystem.upgrade(game, game.forge_selected)
		KEY_R:
			var kind: String = game.ForgeSystem.UPGRADES[game.forge_selected].kind
			if kind == "sword": kind = "sword"
			game.AdventurePolishSystem.repair(game, kind)
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
	if game.world_map_open:
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_M, KEY_ESCAPE]) or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER]): game.WorldMapSystem.toggle(game)
	elif game.shop_open:
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
