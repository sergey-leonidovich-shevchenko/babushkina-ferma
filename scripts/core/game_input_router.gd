extends RefCounted

## Маршрутизирует платформенное событие в активный экран или управление игровым миром.
static func route(game: Node, event: InputEvent) -> void:
	update_input_device(game, event)
	if _handle_high_priority_layer(game, event):
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion and _handle_joypad_motion(game, event):
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		_handle_keyboard(game, event)
	elif event is InputEventJoypadButton:
		var movement_result := _handle_movement_button(game, event)
		if movement_result > 0:
			if movement_result == 2:
				game.get_viewport().set_input_as_handled()
			return
		if handle_gamepad_and_touch(game, event):
			game.get_viewport().set_input_as_handled()

## Запоминает последнее устройство ввода и включает мобильный слой только после настоящего касания.
static func update_input_device(game: Node, event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		game.touch_controls_visible = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		game.touch_controls_visible = false

## Передаёт событие редактору, меню, сюжетному модальному окну или строительству оград.
static func _handle_high_priority_layer(game: Node, event: InputEvent) -> bool:
	if game.PublishedLevelSystem.handle_input(game,event):
		return true
	if not game.language_screen and not game.title_screen and not game.menu_state.pause_open:
		if game.LevelEditorSystem.handle_input(game, event):
			return true
	if not game.language_screen and (game.title_screen or game.menu_state.pause_open or game.menu_state.settings_open or game.menu_state.defeat_open):
		if game.MenuSystem.handle_input(game, event):
			return true
	if game.FirstChapterSystem.handle_input(game, event):
		game.queue_redraw()
		return true
	if game.AdventurePolishSystem.has_modal(game) and game.AdventurePolishSystem.handle_input(game, event):
		return true
	if not game.language_screen and not game.title_screen and not game.menu_state.pause_open and world_controls_visible(game):
		if game.FenceSystem.handle_input(game, event):
			return true
	return false

## Обрабатывает аналоговое движение и сразу обновляет направление взгляда героя.
static func _handle_joypad_motion(game: Node, event: InputEventJoypadMotion) -> bool:
	if not world_controls_visible(game):
		return false
	if not game.set_movement_motion_state(event):
		return false
	var direction: Vector2 = game.get_movement_direction()
	if direction != Vector2.ZERO:
		game.facing = direction
	return true

## Обрабатывает клавиатурные действия мира, магию, блок, уклонение и удержание кнопок.
static func _handle_keyboard(game: Node, event: InputEventKey) -> void:
	var world_magic: bool = not (game.title_screen or game.menu_state.pause_open) and world_controls_visible(game)
	if world_magic and event.pressed and not event.echo and game.InputSystem.matches(event, "cast_spell"):
		game.SpellSystem.cast(game)
		game.get_viewport().set_input_as_handled()
		return
	if world_magic and event.pressed and not event.echo and game.InputSystem.matches(event, "cycle_spell"):
		game.SpellSystem.cycle(game)
		game.get_viewport().set_input_as_handled()
		return
	if game.InputSystem.matches(event, "block"):
		game.CombatSystem.set_blocking(game, event.pressed)
	if event.pressed and not event.echo and game.InputSystem.matches(event, "dodge"):
		game.CombatSystem.start_dodge(game)
	var is_action_key: bool = game.set_action_key_state(event)
	var is_attack_key: bool = game.set_attack_key_state(event)
	var is_movement_key: bool = game.update_movement_key_state(event)
	if not game.title_screen and not game.menu_state.pause_open and event.pressed and is_movement_key:
		game.apply_immediate_key_response(event)
	if is_action_key and not game.title_screen and not game.menu_state.pause_open and world_controls_visible(game):
		if event.pressed and not event.echo:
			if not game.perform_context_action() and game.current_location == "overworld":
				game.use_active_item()
		game.get_viewport().set_input_as_handled()
	if is_attack_key and not game.title_screen and not game.menu_state.pause_open and world_controls_visible(game):
		if event.pressed and not event.echo:
			game.attack_nearest_enemy()
		game.get_viewport().set_input_as_handled()

## Обновляет цифровое движение геймпада и сообщает, что событие было обработано.
static func _handle_movement_button(game: Node, event: InputEventJoypadButton) -> int:
	if not world_controls_visible(game):
		return 0
	if event.button_index not in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		return 0
	var movement_button: bool = game.set_movement_button_state(event)
	if movement_button and event.pressed:
		game.apply_immediate_gamepad_facing()
	return 2 if movement_button and not game.title_screen and not game.menu_state.pause_open else 1

## Проверяет, доступны ли непосредственные действия персонажа без открытого игрового окна.
static func world_controls_visible(game: Node) -> bool:
	return not (game.shop_open \
		or game.inventory_open \
		or game.crafting_open \
		or game.storage_open \
		or game.forge_open \
		or game.contract_open \
		or game.quest_log_open \
		or game.skill_menu_open \
		or game.world_map_open)

## Обрабатывает общий слой мыши, тача и немаршрутных кнопок геймпада.
static func handle_gamepad_and_touch(game: Node, event: InputEvent) -> bool:
	var world_visible := world_controls_visible(game)
	if _handle_world_shortcut(game, event, world_visible):
		return true
	var close_pointer: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if game.ItemWindowRenderer.is_open(game) and close_pointer and game.ItemWindowRenderer.CLOSE_BUTTON.has_point(event.position):
		return game.ItemWindowRenderer.close_active(game)
	if game.InputSystem.set_pointer_action_state(game, event, world_visible):
		return true
	if event is InputEventMouseButton:
		return _handle_mouse(game, event, world_visible)
	if event is InputEventJoypadButton and event.pressed:
		return _handle_joypad_button(game, event)
	if event is InputEventScreenDrag and game.inventory_open:
		game.inventory_touch_drag_y += event.relative.y
		if absf(game.inventory_touch_drag_y) >= 36.0:
			game.InventorySystem.scroll(game, -1 if game.inventory_touch_drag_y > 0.0 else 1)
			game.inventory_touch_drag_y = 0.0
		game.queue_redraw()
		return true
	if event is InputEventScreenTouch and event.pressed:
		return _handle_touch(game, event, world_visible)
	return false

## Обрабатывает боевые, магические и системные быстрые действия поверх игрового мира.
static func _handle_world_shortcut(game: Node, event: InputEvent, world_visible: bool) -> bool:
	if not world_visible:
		return false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_STICK:
		game.CombatSystem.set_blocking(game, event.pressed)
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_MISC1:
		return game.SpellSystem.cast(game)
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_PADDLE1:
		game.SpellSystem.cycle(game)
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_STICK:
		game.AdventurePolishSystem.cycle_target(game)
		return true
	if event is InputEventScreenTouch and game.InterfaceRenderer.block_button_rect(game).has_point(event.position):
		game.CombatSystem.set_blocking(game, event.pressed)
		return true
	if event is InputEventScreenTouch and event.pressed:
		if game.SpellRenderer.cast_button_rect(game).has_point(event.position):
			return game.SpellSystem.cast(game)
		if game.SpellRenderer.cycle_button_rect(game).has_point(event.position):
			game.SpellSystem.cycle(game)
			return true
		if game.InterfaceRenderer.dodge_button_rect(game).has_point(event.position):
			game.CombatSystem.start_dodge(game)
			return true
	return false

## Обрабатывает клики мыши по паузе, инвентарю, талантам, карте и быстрому доступу.
static func _handle_mouse(game: Node, event: InputEventMouseButton, world_visible: bool) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if world_visible and event.pressed and game.InterfaceRenderer.pause_button_rect(game).has_point(event.position):
		return game.MenuSystem.open_pause(game)
	if game.inventory_open:
		game.InventoryInputSystem.handle_mouse(game, event)
		return true
	if not event.pressed:
		return false
	if game.crafting_open:
		var mouse_recipe: int = game.crafting_recipe_at(event.position)
		if mouse_recipe >= 0:
			game.crafting_selected = mouse_recipe
			game.CraftingSystem.craft(game, mouse_recipe)
			game.queue_redraw()
		return true
	if game.skill_menu_open:
		return _handle_talent_pointer(game, event.position)
	if world_visible and game.AdventurePolishSystem.target_at_screen(game, event.position): return true
	if world_visible and game.InterfaceRenderer.dodge_button_rect(game).has_point(event.position):
		game.CombatSystem.start_dodge(game)
		return true
	if game.world_map_open: return game.WorldMapSystem.handle_pointer(game, event.position)
	if game.quest_log_open and game.InputSystem.handle_quest_pointer(game, event.position): return true
	if world_visible and game.InterfaceRenderer.OBJECTIVE_CARD.has_point(event.position) and not game.HudLayoutSystem.primary_objective(game).is_empty(): game.toggle_quest_log(); return true
	if game.InterfaceRenderer.LOCATION_BADGE.has_point(event.position): game.WorldMapSystem.toggle(game); return true
	if game.InterfaceRenderer.QUEST_BUTTON.has_point(event.position): game.toggle_quest_log(); return true
	if game.InterfaceRenderer.SKILL_BUTTON.has_point(event.position): game.open_skill_menu(); return true
	var mouse_hotbar: int = game.InterfaceRenderer.hotbar_at(event.position)
	if mouse_hotbar >= 0:
		game.select_hotbar(mouse_hotbar)
		return true
	return false

## Обрабатывает кнопки геймпада в модальных окнах и стандартную раскладку игрового мира.
static func _handle_joypad_button(game: Node, event: InputEventJoypadButton) -> bool:
	if game.world_map_open: game.InputSystem.handle_modal_input(game, event); return true
	if game.storage_open: game.InputSystem.handle_storage_input(game, event); return true
	if game.forge_open: game.InputSystem.handle_forge_input(game, event); return true
	if game.contract_open: game.InputSystem.handle_contract_input(game, event); return true
	if game.crafting_open: game.handle_crafting_input(event); return true
	if game.skill_menu_open: game.handle_skill_menu_input(event); return true
	if game.quest_log_open: game.InputSystem.handle_modal_input(game, event); return true
	if game.inventory_open: game.handle_inventory_input(event); return true
	match event.button_index:
		JOY_BUTTON_B: game.CombatSystem.start_dodge(game)
		JOY_BUTTON_RIGHT_SHOULDER: game.WorldMapSystem.toggle(game)
		JOY_BUTTON_LEFT_SHOULDER: game.CompanionSystem.cycle_command(game)
		JOY_BUTTON_DPAD_LEFT: game.select_hotbar(posmod(game.selected_hotbar - 1, 10))
		JOY_BUTTON_DPAD_RIGHT: game.select_hotbar(posmod(game.selected_hotbar + 1, 10))
		JOY_BUTTON_A:
			if not game.perform_context_action(): game.use_active_item()
		JOY_BUTTON_X: game.attack_nearest_enemy()
		JOY_BUTTON_Y: game.open_inventory()
		JOY_BUTTON_BACK: game.toggle_quest_log()
		JOY_BUTTON_START: game.MenuSystem.open_pause(game)
		_: return false
	return true

## Обрабатывает касание модальных окон, HUD, талантов и панели быстрого доступа.
static func _handle_touch(game: Node, event: InputEventScreenTouch, world_visible: bool) -> bool:
	if game.world_map_open: return game.WorldMapSystem.handle_pointer(game, event.position)
	if world_visible and game.InterfaceRenderer.pause_button_rect(game).has_point(event.position):
		return game.MenuSystem.open_pause(game)
	if game.discovery_card_rect().has_point(event.position) and not game.discovery_current.is_empty():
		game.DiscoverySystem.dismiss(game)
		return true
	if game.storage_open: return game.InputSystem.handle_storage_touch(game, event.position)
	if game.forge_open: return game.InputSystem.handle_forge_touch(game, event.position)
	if game.contract_open: return game.InputSystem.handle_contract_touch(game, event.position)
	if game.crafting_open:
		var touch_recipe: int = game.crafting_recipe_at(event.position)
		if touch_recipe >= 0:
			game.crafting_selected = touch_recipe
			game.CraftingSystem.craft(game, touch_recipe)
			game.queue_redraw()
		return true
	if game.skill_menu_open: return _handle_talent_pointer(game, event.position)
	if world_visible and game.InterfaceRenderer.OBJECTIVE_CARD.has_point(event.position) and not game.HudLayoutSystem.primary_objective(game).is_empty(): game.toggle_quest_log(); return true
	if game.InterfaceRenderer.QUEST_BUTTON.has_point(event.position): game.toggle_quest_log(); return true
	if game.InterfaceRenderer.SKILL_BUTTON.has_point(event.position): game.open_skill_menu(); return true
	if game.inventory_open: return game.InventoryInputSystem.handle_touch(game, event.position)
	if world_visible and game.AdventurePolishSystem.target_at_screen(game, event.position): return true
	var index: int = game.InterfaceRenderer.hotbar_at(event.position)
	if index >= 0:
		game.select_hotbar(index)
	else:
		if not game.perform_context_action(): game.use_active_item()
	return true

## Обрабатывает общие кнопки и узлы дерева талантов для мыши и сенсорного экрана.
static func _handle_talent_pointer(game: Node, position: Vector2) -> bool:
	if game.TalentRenderer.CLOSE_BUTTON.has_point(position):
		game.skill_menu_open = false
		game.queue_redraw()
		return true
	if game.CharacterUiRenderer.COMMAND_BUTTON.has_point(position):
		game.CompanionSystem.cycle_command(game)
		game.queue_redraw()
		return true
	if game.TalentRenderer.RESPEC_BUTTON.has_point(position):
		game.TalentSystem.respec(game)
		game.queue_redraw()
		return true
	var talent_index: int = game.TalentRenderer.node_at(position)
	if talent_index >= 0:
		game.skill_menu_selected = talent_index
		game.TalentSystem.unlock(game, game.TalentSystem.at(talent_index).id)
		game.queue_redraw()
	return true
