extends "res://scripts/game_renderer.gd"

const GameLoop := preload("res://scripts/core/game_loop.gd")
const GamePreviewController := preload("res://scripts/core/game_preview_controller.gd")
const GameInputRouter := preload("res://scripts/core/game_input_router.gd")
const GameBootstrap := preload("res://scripts/core/game_bootstrap.gd")
const GameInteractionRouter := preload("res://scripts/core/game_interaction_router.gd")
## Подготавливает узел к работе: создаёт зависимые данные и синхронизирует начальное состояние.
func _ready() -> void:
	GameBootstrap.initialize(self)


## Сохраняет автоматические игровые скриншоты после нескольких отрисованных кадров в режимах визуальной проверки.
func _process(_delta: float) -> void:
	GamePreviewController.process(self)
## Готовит безопасную витрину пяти рангов врагов, трёх угроз и максимального облика героя.
func configure_enemy_levels_preview() -> void:
	GamePreviewController.configure_enemy_levels(self)


## Готовит витрину финального этапа Лунной поляны со Стражем, алтарём и наградой.
func configure_moon_glade_preview() -> void:
	GamePreviewController.configure_moon_glade(self)

## Выполняет один физический кадр и обновляет активные игровые системы в заданном порядке.
func _physics_process(delta: float) -> void:
	GameLoop.physics_process(self, delta)


## Обновляет короткие визуальные реакции HUD на урон, монеты, новую минуту и смену погоды.
func update_hud_feedback(delta: float) -> void:
	if hud_last_hp < 0: hud_last_hp = player_hp
	if hud_last_coins < 0: hud_last_coins = coins
	if hud_last_minute < 0: hud_last_minute = int(game_minutes)
	if hud_last_weather.is_empty(): hud_last_weather = WorldEventSystem.weather(self)
	if player_hp < hud_last_hp: hud_hp_flash = 0.42
	if coins != hud_last_coins: hud_coin_pop = 0.36
	if int(game_minutes) != hud_last_minute: hud_clock_tick = 0.32
	var weather := WorldEventSystem.weather(self)
	if weather != hud_last_weather: hud_weather_transition = 0.48
	hud_last_hp = player_hp; hud_last_coins = coins; hud_last_minute = int(game_minutes); hud_last_weather = weather
	hud_hp_flash = maxf(0.0, hud_hp_flash - delta)
	hud_coin_pop = maxf(0.0, hud_coin_pop - delta)
	hud_clock_tick = maxf(0.0, hud_clock_tick - delta)
	hud_weather_transition = maxf(0.0, hud_weather_transition - delta)

## Обновляет относящуюся к методу часть состояния на текущем кадре.
func update_benchmark_route(delta: float) -> void:
	benchmark_elapsed += delta
	if benchmark_elapsed < 4.0:
		move_right_held = true
		move_down_held = false
	elif benchmark_elapsed < 7.0:
		move_right_held = true
		move_down_held = true
	else:
		move_right_held = false
		move_down_held = false
		if current_location == "overworld":
			current_location = "cave"
			sync_background_location()
			player = Vector2(900, 480)

## Обновляет относящуюся к методу часть состояния на текущем кадре.
func update_player_movement(delta: float) -> void:
	var direction := get_movement_direction()
	if direction.length() == 0.0:
		return
	facing = direction
	var current_speed := speed * (1.3 if speed_timer > 0.0 else 1.0) * InventorySystem.speed_multiplier(self) * TalentSystem.movement_multiplier(self)
	move_player_with_collisions(direction * current_speed * delta)
	notify_tutorial("move")
	if current_location == "overworld" and BuildingSystem.VILLAGE_SQUARE.has_point(player): notify_tutorial("village_paths")
	character_animation_directions[PlayerSystem.direction_row(direction)] = true
	if character_animation_directions.size() >= 4:
		notify_tutorial("character_animation")
	clamp_player_position()

## Выполняет операцию «перемещения героя с коллизий» и возвращает результат согласно контракту метода.
func move_player_with_collisions(motion: Vector2) -> void:
	NavigationSystem.move(self, motion)

## Проверяет заявленное методом условие без изменения игрового состояния.
func is_position_walkable(position: Vector2) -> bool:
	return NavigationSystem.is_walkable(self, position)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	return NavigationSystem.circle_intersects_rect(center, radius, rect)

## Обновляет относящуюся к методу часть состояния на текущем кадре.
func update_game_clock(delta: float) -> void:
	# Одна реальная секунда равна одной игровой минуте.
	if state.fishing.phase == FishingSystem.PHASE_MINIGAME: return
	game_minutes += delta
	if game_minutes >= 24.0 * 60.0:
		game_minutes -= 24.0 * 60.0
		day += 1
		message = LocaleSystem.text("new_day", [day])

## Обновляет относящуюся к методу часть состояния на текущем кадре.
func update_crops(delta: float) -> void:
	FarmSystem.update(self, delta)

## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
func get_movement_direction() -> Vector2:
	return PlayerSystem.movement_direction(self)

## Обновляет относящуюся к методу часть состояния на текущем кадре.
func update_movement_key_state(event: InputEventKey) -> bool:
	return PlayerSystem.update_movement_key(self, event)

## Обновляет удержание движения по кнопкам D-Pad геймпада.
func set_movement_button_state(event: InputEventJoypadButton) -> bool:
	return InputSystem.set_movement_button_state(self, event)

## Обновляет удержание движения по левому стикy геймпада.
func set_movement_motion_state(event: InputEventJoypadMotion) -> bool:
	return InputSystem.set_movement_motion_state(self, event)

## Устанавливает направление взгляда сразу при изменении геймпадного направления.
func apply_immediate_gamepad_facing() -> void:
	var direction := get_movement_direction()
	if direction != Vector2.ZERO:
		facing = direction

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func clear_movement_keys() -> void:
	PlayerSystem.clear_keys(self)

## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
func set_action_key_state(event: InputEventKey) -> bool:
	return InputSystem.set_action_key_state(self, event)

## Обновляет относящуюся к методу часть состояния на текущем кадре.
func update_held_action(delta: float) -> void:
	InputSystem.update_held_action(self, delta)

## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
func set_attack_key_state(event: InputEventKey) -> bool:
	return InputSystem.set_attack_key_state(self, event)

## Обновляет удерживаемого атаки на текущем кадре.
func update_held_attack(delta: float) -> void:
	InputSystem.update_held_attack(self, delta)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func perform_repeatable_action() -> bool:
	return InputSystem.perform_repeatable_action(self)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_movement_keys()

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func clamp_player_position() -> void:
	player.x = clampf(player.x, 40.0, WORLD_SIZE.x - 40.0)
	player.y = clampf(player.y, 120.0, WORLD_SIZE.y - 80.0)

## Обновляет относящуюся к методу часть состояния на текущем кадре.
func update_camera() -> void:
	# Камера привязана к целым пикселям: пиксельная графика не дрожит на субпикселях.
	camera_offset.x = roundf(clampf(player.x - 576.0, 0.0, WORLD_SIZE.x - 1152.0))
	camera_offset.y = roundf(clampf(player.y - 324.0, 0.0, WORLD_SIZE.y - 648.0))
	var background := get_node_or_null("WorldBackground")
	if background:
		background.position = -camera_offset

## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
func sync_background_location() -> void:
	AudioSystem.switch_music(self, current_location)
	if not DebugPlaygroundSystem.active(self): EstateSystem.discover_location(self, current_location)
	var background := get_node_or_null("WorldBackground")
	if background:
		background.set_location(current_location)
		background.set_environment(WorldEventSystem.season(day), WorldEventSystem.location_weather(day, current_location))

## Обновляет только сезон и погоду фонового слоя при смене календарного состояния.
func sync_background_environment() -> void:
	var background := get_node_or_null("WorldBackground")
	if background: background.set_environment(WorldEventSystem.season(day), WorldEventSystem.location_weather(day, current_location))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func apply_immediate_key_response(event: InputEventKey) -> void:
	InputSystem.apply_immediate_key_response(self, event)

## Обрабатывает команды, которые не были перехвачены более приоритетными экранами.
func _unhandled_input(event: InputEvent) -> void:
	if language_screen:
		handle_language_input(event)
		return
	if title_screen or menu_state.pause_open or menu_state.settings_open or menu_state.defeat_open:
		MenuSystem.handle_input(self, event)
		return
	if DebugOverlaySystem.handle_input(self, event): queue_redraw(); return
	if DebugPlaygroundSystem.handle_input(self,event) or FarmLifeSystem.handle_input(self,event): queue_redraw(); return
	if AdventurePolishSystem.handle_input(self, event):
		return

	if InputSystem.handle_modal_input(self, event):
		return
	if event.is_action_pressed("ui_cancel"):
		MenuSystem.open_pause(self)
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		use_active_item()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: select_hotbar(0)
			KEY_2: select_hotbar(1)
			KEY_3: select_hotbar(2)
			KEY_4: select_hotbar(3)
			KEY_5: select_hotbar(4)
			KEY_6: select_hotbar(5)
			KEY_7: select_hotbar(6)
			KEY_8: select_hotbar(7)
			KEY_9: select_hotbar(8)
			KEY_0: select_hotbar(9)
			KEY_B: open_shop()
			KEY_C: CompanionSystem.cycle_command(self)
			KEY_N: sleep_until_morning()
			KEY_F: attack_nearest_enemy()
			KEY_R: toggle_sword()
			KEY_T: tutorial_visible = not tutorial_visible
			KEY_Y: reset_tutorial()
			KEY_F9: grant_tester_kit()
			KEY_F5: save_game()
			KEY_F6:
				AudioSystem.set_enabled(self, not audio_enabled)
				SettingsSystem.save(self)
				message = LocaleSystem.ui("sound_on" if audio_enabled else "sound_off")
			KEY_F8: load_game()
			KEY_I, KEY_TAB: open_inventory()
			KEY_J: toggle_quest_log()
			KEY_K: open_skill_menu()
			KEY_M: WorldMapSystem.toggle(self)
			KEY_H: DiscoverySystem.dismiss(self)
		queue_redraw()

## Обрабатывает языка ввода и синхронизирует связанное состояние.
func handle_language_input(event: InputEvent) -> bool:
	var choose := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_UP]: language_selected = posmod(language_selected - 1, LocaleSystem.LOCALES.size())
		elif event.keycode in [KEY_RIGHT, KEY_DOWN]: language_selected = posmod(language_selected + 1, LocaleSystem.LOCALES.size())
		elif event.keycode in [KEY_ENTER, KEY_SPACE]: choose = true
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			language_selected = int(event.keycode - KEY_1)
			choose = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP]: language_selected = posmod(language_selected - 1, LocaleSystem.LOCALES.size())
		elif event.button_index in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]: language_selected = posmod(language_selected + 1, LocaleSystem.LOCALES.size())
		elif event.button_index == JOY_BUTTON_A: choose = true
	elif event is InputEventScreenTouch and event.pressed:
		for index in LocaleSystem.LOCALES.size():
			if language_button_rect(index).has_point(event.position):
				language_selected = index
				choose = true
				break
	if choose:
		LocaleSystem.set_locale(LocaleSystem.LOCALES[language_selected], persist_locale_selection)
		language_screen = false
		message = LocaleSystem.ui("title")
	queue_redraw()
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func language_button_rect(index: int) -> Rect2:
	var column := index % 2
	var row := index / 2
	return Rect2(250 + column * 340, 230 + row * 82, 312, 62)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func targeted_plot() -> Vector2i:
	var target := player + facing * 42.0
	return Vector2i(floori((target.x - FARM_ORIGIN.x) / TILE), floori((target.y - FARM_ORIGIN.y) / TILE))

## Проверяет заявленное методом условие без изменения игрового состояния.
func valid_plot(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < FARM_SIZE.x and cell.y < FARM_SIZE.y

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func use_selected_tool() -> void:
	if selected_tool == Tool.AXE: TreeSystem.chop_nearby(self); return
	if selected_tool == Tool.PICKAXE:
		mine_nearby_resource()
		return
	if selected_tool == Tool.ROD:
		use_fishing_rod()
		return
	var durability_kind: String = {Tool.HOE:"hoe", Tool.WATER:"water"}.get(selected_tool, "")
	if not durability_kind.is_empty() and not AdventurePolishSystem.can_use(self, durability_kind): return
	var cultivation_target: Dictionary = WorldFarmingSystem.target(self)
	var plot: Dictionary = WorldFarmingSystem.read_target(self, cultivation_target)
	var action_sfx := ""
	if selected_tool != Tool.HAND and energy <= 0:
		message = LocaleSystem.text("no_energy")
		return
	match selected_tool:
		Tool.HOE:
			if WorldFarmingSystem.till_pattern(self, cultivation_target) > 0: action_sfx = "hoe"
		Tool.SEEDS:
			if not cultivation_target.valid: message = WorldFarmingSystem.blocked_message(self, cultivation_target.reason)
			elif FarmSystem.plant(self, plot): action_sfx = "plant"
		Tool.WATER:
			if not cultivation_target.valid: message = WorldFarmingSystem.blocked_message(self, cultivation_target.reason)
			elif plot.planted and not plot.watered:
				var is_second_watering: bool = plot.growth >= STAGE_DURATION * 2.0
				plot.watered = true
				energy -= 1
				SkillSystem.award_profession_xp(self, "farming", 1)
				message = LocaleSystem.text("watered")
				notify_tutorial("rewater" if is_second_watering else "water")
				action_sfx = "water"
			else: message = LocaleSystem.text("nothing_water")
		Tool.HAND:
			if not cultivation_target.valid: message = WorldFarmingSystem.blocked_message(self, cultivation_target.reason)
			elif FarmSystem.harvest(self, plot): action_sfx = "harvest"
	if selected_tool != Tool.HOE:
		WorldFarmingSystem.write_target(self, cultivation_target, plot)
	if not action_sfx.is_empty():
		play_sfx(action_sfx)
		if not durability_kind.is_empty(): AdventurePolishSystem.consume_durability(self, durability_kind)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func sleep_until_morning() -> void:
	if current_location != "cottage_interior" and player.distance_to(Vector2(126, 190)) > 105.0:
		message = LocaleSystem.text("sleep_near_home")
		return
	day += 1
	game_minutes = 6.0 * 60.0
	energy = SkillSystem.max_stamina(self)
	player_mana = player_max_mana
	message = LocaleSystem.text("morning", [day])
	notify_tutorial("day"); FarmLifeSystem.on_sleep(self)

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func open_shop() -> void:
	if current_location != "shop_interior" and player.distance_to(BuildingSystem.SHOP_STALL_POSITION) > 100.0:
		message = "Подойди к лавке справа"
		return
	shop_open = true
	shop_selected = 0
	clear_movement_keys()
	message = "Добро пожаловать в сельскую лавку"
	notify_tutorial("shop")

## Выполняет операцию «ближайшего взаимодействия» и возвращает результат согласно контракту метода.
func nearest_interaction() -> String:
	return GameInteractionRouter.nearest(self)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func perform_context_action() -> bool:
	return GameInteractionRouter.perform(self)

## Выполняет заявленное игровое действие после проверки условий, затрат и наград.
func mine_nearby_resource() -> bool:
	return ResourceSystem.mine_nearby(self)

## Выполняет заявленное игровое действие после проверки условий, затрат и наград.
func mine_resource(index: int) -> bool:
	return ResourceSystem.mine(self, index)

## Проверяет заявленное методом условие без изменения игрового состояния.
func is_near_fishing_water() -> bool:
	return FishingSystem.is_near_water(self)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func use_fishing_rod() -> bool:
	return FishingSystem.use_rod(self)

## Обновляет рыбалки на текущем кадре.
func update_fishing(delta: float) -> void:
	FishingSystem.update(self, delta)

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func enter_cave() -> void:
	current_location = "cave"
	sync_background_location()
	player = cave_exit_position + Vector2(90, 0)
	update_camera()
	message = "Кристальная пещера"
	DiscoverySystem.show_location(self, current_location)
	notify_tutorial("travel")
	play_sfx("travel")

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func exit_cave() -> void:
	current_location = "overworld"
	sync_background_location()
	player = cave_entrance_position - Vector2(100, 0)
	update_camera()
	message = "Ты вернулся в зачарованный лес"
	DiscoverySystem.show_location(self, current_location)
	play_sfx("travel")

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func open_inventory() -> void:
	inventory_open = true
	inventory_move_from = -1
	InventorySystem.ensure_counted_items(self)
	InventorySystem.keep_selection_visible(self)
	clear_movement_keys()
	notify_tutorial("inventory")
	message = LocaleSystem.text("inventory_open")
	play_sfx("ui_open")

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func inventory_item_count(kind: String) -> int:
	match kind:
		"sword": return 1 if sword_crafted else 0
		"pickaxe": return 1 if has_pickaxe else 0
		"fishing_rod": return 1 if has_fishing_rod else 0
		"bow": return 1 if has_bow else 0
		"crystal_sword": return 1 if has_crystal_sword else 0
	return state.inventory.count(kind)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func inventory_item_name(kind: String) -> String:
	if kind.is_empty():
		return "Пусто"
	return InventorySystem.data(kind).name

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func change_inventory_count(kind: String, amount: int) -> bool:
	if amount < 0 and inventory_item_count(kind) < -amount:
		return false
	match kind:
		"sword":
			if amount < 0:
				sword_crafted = false
				sword_equipped = false
			elif amount > 0:
				sword_crafted = true
		"pickaxe": has_pickaxe = amount > 0
		"fishing_rod": has_fishing_rod = amount > 0
		"bow": has_bow = amount > 0
		"crystal_sword": has_crystal_sword = amount > 0
		_:
			if not state.inventory.change(kind, amount):
				return false
	if amount > 0 and inventory_item_count(kind) > 0:
		InventorySystem.ensure_item_slot(self, kind)
	return true

## Обрабатывает инвентаря ввода и синхронизирует связанное состояние.
func handle_inventory_input(event: InputEvent) -> void:
	InventoryInputSystem.handle(self, event)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func move_inventory_slot() -> void:
	if inventory_move_from < 0:
		inventory_move_from = inventory_selected
		message = "Выбери новый слот и нажми M"
		return
	InventorySystem.swap_slots(self, inventory_move_from, inventory_selected)
	inventory_move_from = -1
	message = LocaleSystem.text("moved")

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func drop_selected_item() -> bool:
	var kind: String = inventory_slots[inventory_selected]
	if kind.is_empty() or not change_inventory_count(kind, -1):
		message = "В этом слоте нечего выбрасывать"
		return false
	dropped_items.append({"kind": kind, "count": 1, "position": player + facing * 50.0})
	message = LocaleSystem.text("dropped")
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func delete_selected_item() -> bool:
	var kind: String = inventory_slots[inventory_selected]
	if kind.is_empty() or not change_inventory_count(kind, -1):
		message = "В этом слоте нечего удалять"
		return false
	message = "Удалена 1 единица: %s" % inventory_item_name(kind)
	return true

## Выполняет заявленное игровое действие после проверки условий, затрат и наград.
func collect_dropped_item(index: int) -> bool:
	if index < 0 or index >= dropped_items.size():
		return false
	var item: Dictionary = dropped_items[index]
	if player.distance_to(item.position) > 92.0:
		return false
	change_inventory_count(item.kind, item.count)
	dropped_items.remove_at(index)
	message = LocaleSystem.text("picked", [inventory_item_name(item.kind)])
	play_sfx("pickup")
	return true

## Выполняет заявленное игровое действие после проверки условий, затрат и наград.
func collect_food(index: int) -> bool:
	return ForageSystem.collect(self, index)

## Выполняет заявленное игровое действие после проверки условий, затрат и наград.
func consume_selected_item() -> bool:
	var kind: String = inventory_slots[inventory_selected]
	return consume_item(kind)

## Выполняет заявленное игровое действие после проверки условий, затрат и наград.
func consume_item(kind: String) -> bool:
	return PotionSystem.consume(self, kind)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func select_hotbar(index: int) -> bool:
	return InventorySystem.select_hotbar(self, index)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func assign_selected_to_hotbar(index: int) -> bool:
	return InventorySystem.assign_hotbar(self, inventory_selected, index)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func equip_selected_item() -> bool:
	return InventorySystem.equip(self, inventory_slots[inventory_selected])

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func use_active_item() -> bool:
	var kind: String = hotbar_slots[selected_hotbar]
	var item := InventorySystem.data(kind)
	if kind == "crab_trap": return FishingSystem.use_crab_trap(self)
	if kind == "fruit_sapling": return OrchardSystem.plant_sapling(self)
	if kind == "cauldron":
		if not TalentSystem.has(self, "farm_cooking"): message = "Сначала изучи «Домашнюю кухню»"; return false
		open_crafting("cauldron")
		return true
	if item.get("edible", false):
		return consume_item(kind)
	if item.has("tool"):
		selected_tool = item.tool
		use_selected_tool()
		return true
	message = LocaleSystem.text("cannot_use")
	return false

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func heal_player(amount: int) -> int:
	return PlayerSystem.heal(self, amount)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func award_xp(amount: int, reason: String = "") -> void:
	PlayerSystem.award_xp(self, amount, reason)

## Обновляет относящуюся к методу часть состояния на текущем кадре.
func update_status_effects(delta: float) -> void:
	PlayerSystem.update_effects(self, delta)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func talk_to_grandmother() -> void:
	QuestSystem.talk_to_grandmother(self)

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func toggle_quest_log() -> void:
	quest_log_open = not quest_log_open
	if quest_log_open:
		clear_movement_keys()
		message = LocaleSystem.text("journal_open")
		notify_tutorial("journal")

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func open_skill_menu() -> void:
	skill_menu_open = not skill_menu_open
	if skill_menu_open:
		skill_menu_selected = clampi(skill_menu_selected, 0, TalentSystem.TALENTS.size() - 1)
		clear_movement_keys()
		message = TalentSystem.word(self, "choose", false, [skill_points])

## Обрабатывает относящееся к методу событие и синхронизирует зависимое состояние.
func handle_skill_menu_input(event: InputEvent) -> void:
	TalentInputSystem.handle(self, event)

## Выполняет операцию «атаки слизня» и возвращает результат согласно контракту метода.
func attack_slime() -> bool:
	var attack_range := 280.0 if equipped_weapon == "bow" else 105.0
	if not slime_alive or player.distance_to(slime_position) > attack_range:
		message = LocaleSystem.text("no_enemy")
		return false
	PotionSystem.break_invisibility(self)
	var damage := 1 + (1 if strength_timer > 0.0 else 0) + InventorySystem.damage_bonus(self)
	if equipped_weapon == "forest_sword": damage = 2
	elif equipped_weapon == "crystal_sword": damage = 3
	elif equipped_weapon == "bow": damage = 2
	slime_hp -= damage
	AnimationSystem.begin_player_attack(self)
	AnimationSystem.hit_slime(self, slime_hp <= 0)
	play_sfx("attack")
	play_sfx("defeat" if slime_hp <= 0 else "hit")
	message = "Удар по слизню: -%d HP" % damage
	notify_tutorial("fight")
	notify_tutorial("combat_animation")
	if slime_hp <= 0:
		slime_alive = false
		loot_available = true
		award_xp(10)
		SkillSystem.award_profession_xp(self, "combat", 5)
		message = "Слизень побеждён! +10 опыта. Подбери добычу [E]"
	return true

## Выполняет операцию «атаки ближайшего врага» и возвращает результат согласно контракту метода.
func attack_nearest_enemy() -> bool:
	if equipped_weapon != "none" and not AdventurePolishSystem.can_use(self, "sword" if equipped_weapon == "forest_sword" else equipped_weapon): return false
	var sfx_before := audio_sfx_count
	if MoonGladeSystem.attack_guardian(self):
		AdventurePolishSystem.consume_durability(self, "weapon")
		return true
	if CastleCampaignSystem.attack_boss(self):
		AdventurePolishSystem.consume_durability(self, "weapon")
		return true
	var enemy_index := CombatSystem.nearest(self)
	var wildlife_index := WildlifeSystem.nearest(self)
	var enemy_distance := INF
	var wildlife_distance := INF
	if enemy_index >= 0:
		enemy_distance = player.distance_to(enemy_nodes[enemy_index].position)
	if wildlife_index >= 0:
		wildlife_distance = player.distance_to(wildlife_nodes[wildlife_index].position)
	if wildlife_distance < enemy_distance:
		var wildlife_hit := WildlifeSystem.attack(self, wildlife_index); if wildlife_hit: AdventurePolishSystem.consume_durability(self, "weapon"); return wildlife_hit
	if enemy_index >= 0:
		var enemy_hit := CombatSystem.attack(self, enemy_index); if enemy_hit: AdventurePolishSystem.consume_durability(self, "weapon"); return enemy_hit
	if wildlife_index >= 0:
		var second_hit := WildlifeSystem.attack(self, wildlife_index); if second_hit: AdventurePolishSystem.consume_durability(self, "weapon"); return second_hit
	if current_location == "overworld":
		var slime_hit := attack_slime(); if slime_hit and audio_sfx_count > sfx_before: AdventurePolishSystem.consume_durability(self, "weapon"); return slime_hit
	message = LocaleSystem.text("no_enemy")
	return false

## Обновляет боя на текущем кадре.
func update_combat(delta: float) -> void:
	CombatSystem.update(self, delta)
	EnvironmentHazardSystem.update(self, delta)
	if not slime_alive or invisibility_timer > 0.0 or player.distance_to(slime_position) > 72.0:
		slime_attack_timer = 0.0
		return
	slime_attack_timer += delta
	if slime_attack_timer >= 1.5:
		slime_attack_timer = 0.0
		AnimationSystem.begin_slime_attack(self)
		CombatSystem.damage_player(self, 20, LocaleSystem.entity("slime"))

## Выполняет заявленное игровое действие после проверки условий, затрат и наград.
func collect_loot() -> bool:
	if not loot_available or player.distance_to(slime_position) > 92.0:
		return false
	loot_available = false
	slime_gel += 3
	message = "Получено: слизь ×3"
	notify_tutorial("loot")
	return true

## Выполняет игровое действие «крафта меча» с проверкой условий и наград.
func craft_sword() -> bool:
	if sword_crafted and not has_crystal_sword:
		if crystals < 5:
			message = "Для улучшения меча нужно 5 кристаллов"
			return false
		crystals -= 5
		has_crystal_sword = true
		message = "Создан кристальный меч: 3 урона"
		return true
	if sword_crafted and has_crystal_sword:
		message = "Все доступные мечи уже созданы"
		return false
	if slime_gel < 3 or wood < 2:
		message = "Для меча нужно: слизь 3, древесина 2"
		return false
	slime_gel -= 3
	wood -= 2
	sword_crafted = true
	message = "Создан липкий лесной меч! Надень его [R]"
	notify_tutorial("craft")
	return true

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func toggle_sword() -> bool:
	var weapons := ["none"]
	if sword_crafted: weapons.append("forest_sword")
	if has_bow: weapons.append("bow")
	if has_crystal_sword: weapons.append("crystal_sword")
	if weapons.size() == 1:
		message = "Оружия пока нет"
		return false
	var current_index := weapons.find(equipped_weapon)
	equipped_weapon = weapons[(current_index + 1) % weapons.size()]
	sword_equipped = equipped_weapon == "forest_sword" or equipped_weapon == "crystal_sword"
	var weapon_names := {"none": "кулаки", "forest_sword": "лесной меч", "bow": "охотничий лук", "crystal_sword": "кристальный меч"}
	message = "Оружие: %s" % weapon_names[equipped_weapon]
	notify_tutorial("equip")
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func notify_tutorial(event_name: String) -> void:
	TutorialSystem.notify(self, event_name); FirstChapterSystem.observe(self,event_name)

## Выполняет операцию «сброса обучения» и возвращает результат согласно контракту метода.
func reset_tutorial() -> void:
	TutorialSystem.reset(self)

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func open_crafting(station: String = "workbench") -> void:
	CraftingSystem.open(self, station)

## Обрабатывает крафта ввода и синхронизирует связанное состояние.
func handle_crafting_input(event: InputEvent) -> void:
	CraftingSystem.handle_input(self, event)

## Находит видимый рецепт под указателем в текущем окне верстака или котелка.
func crafting_recipe_at(position: Vector2) -> int:
	return CraftingSystem.recipe_at(self, position)

## Открывает интерфейс установленного домашнего сундука.
func open_storage() -> bool:
	return StorageSystem.open(self)

## Обрабатывает клавиатуру и геймпад окна домашнего сундука.
func handle_storage_input(event: InputEvent) -> void:
	InputSystem.handle_storage_input(self, event)

## Открывает отдельное меню улучшений только у наковальни кузницы.
func open_forge() -> bool:
	if current_location != "forge_interior":
		return false
	forge_open = true
	forge_selected = 0
	clear_movement_keys()
	message = LocaleSystem.text("forge_opened")
	notify_tutorial("forge_open")
	return true

## Обрабатывает выбор и подтверждение улучшения в кузнице с клавиатуры и геймпада.
func handle_forge_input(event: InputEvent) -> void:
	InputSystem.handle_forge_input(self, event)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func export_inventory_counts() -> Dictionary:
	return state.inventory.counts.duplicate(true)

## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
func import_inventory_counts(counts: Dictionary) -> void:
	state.inventory.import_counts(counts)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func save_game() -> bool:
	var saved := FarmLifeSystem.save_active(self)
	message = LocaleSystem.text("saved" if saved else "save_failed")
	if saved:
		notify_tutorial("save")
	return saved

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func load_game() -> bool:
	var loaded := FarmLifeSystem.load_active(self)
	message = LocaleSystem.text("loaded" if loaded else "load_failed")
	if loaded:
		sync_background_location()
	return loaded

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func play_sfx(sound_id: String) -> bool:
	var played := AudioSystem.play_sfx(self, sound_id)
	if played:
		notify_tutorial("audio_feedback")
	return played

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func grant_tester_kit() -> void:
	coins = maxi(coins, 500)
	carrots = maxi(carrots, 10)
	seeds = maxi(seeds, 20)
	slime_gel = maxi(slime_gel, 10)
	wood = maxi(wood, 10)
	crystals = maxi(crystals, 10)
	apples = maxi(apples, 3)
	berries = maxi(berries, 3)
	nuts = maxi(nuts, 3)
	mushrooms = maxi(mushrooms, 3)
	oranges = maxi(oranges, 3)
	materials.watermelon = maxi(materials.watermelon, 3)
	materials.healing_potion = maxi(materials.healing_potion, 2)
	for potion in PotionSystem.POTIONS: materials[potion] = maxi(materials[potion], 2)
	for kind in VisualAssetSystem.FARM_FOOD_CELLS: materials[kind] = maxi(materials[kind], 3)
	materials.oak_shield = maxi(materials.oak_shield, 1)
	materials.lizard_scale = maxi(materials.lizard_scale, 2)
	materials.arrows = maxi(materials.arrows, 30)
	materials.metal = maxi(materials.metal, 20)
	materials.stone = maxi(materials.stone, 20)
	materials.fiber = maxi(materials.fiber, 10)
	materials.hide = maxi(materials.hide, 6)
	iron_helmet = maxi(iron_helmet, 1)
	guardian_armor = maxi(guardian_armor, 1)
	travel_boots = maxi(travel_boots, 1)
	crystal_ring = maxi(crystal_ring, 1)
	skill_points = maxi(skill_points, 3)
	player_hp = player_max_hp
	slime_alive = true
	slime_hp = 3
	slime_visual_state = "idle"
	slime_visual_time = 0.0
	loot_available = false
	ForageSystem.reset_all(self)
	for index in enemy_nodes.size():
		enemy_nodes[index].alive = true
		enemy_nodes[index].hp = CombatSystem.max_hp(enemy_nodes[index].kind, enemy_nodes[index].level)
		enemy_nodes[index].max_hp = enemy_nodes[index].hp
		enemy_nodes[index].position = enemy_nodes[index].home
		enemy_nodes[index].direction = Vector2.DOWN
		enemy_nodes[index].moving = false
		enemy_nodes[index].attack_timer = 0.0
		enemy_nodes[index].visual_state = "idle"
		enemy_nodes[index].visual_time = 0.0
	for index in hazard_nodes.size():
		hazard_nodes[index].cooldown = 0.0
	for index in wildlife_nodes.size():
		wildlife_nodes[index].alive = true
		wildlife_nodes[index].hp = WildlifeSystem.TYPES[wildlife_nodes[index].kind].hp
		wildlife_nodes[index].position = wildlife_nodes[index].home
	message = "QA-набор выдан: ресурсы, морковь, монеты и 3 очка навыков"

## Обрабатывает магазина ввода и синхронизирует связанное состояние.
func handle_shop_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE, KEY_B:
			shop_open = false
			message = "Заходи ещё!"
		KEY_UP:
			shop_selected = posmod(shop_selected - 1, shop_products.size())
		KEY_DOWN:
			shop_selected = posmod(shop_selected + 1, shop_products.size())
		KEY_ENTER, KEY_SPACE:
			buy_selected_product()
		KEY_X:
			sell_selected_product()
	queue_redraw()

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func buy_selected_product() -> bool:
	return ShopSystem.buy(self, shop_selected)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func sell_selected_product() -> bool:
	return ShopSystem.sell(self, shop_selected)

## Выполняет операцию «продажи моркови» и возвращает результат согласно контракту метода.
func sell_carrots() -> void:
	if carrots > 0:
		var earned := carrots * 8
		coins += earned
		carrots = 0
		message = "Продано! +%d монет" % earned
	else: message = "В рюкзаке нет моркови"

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func _input(event: InputEvent) -> void:
	GameInputRouter.route(self, event)


## Запоминает последнее устройство ввода и включает мобильный слой только после настоящего касания.
func update_input_device(event: InputEvent) -> void:
	GameInputRouter.update_input_device(self, event)

## Обрабатывает относящееся к методу событие и синхронизирует зависимое состояние.
func handle_gamepad_and_touch(event: InputEvent) -> bool:
	return GameInputRouter.handle_gamepad_and_touch(self, event)
