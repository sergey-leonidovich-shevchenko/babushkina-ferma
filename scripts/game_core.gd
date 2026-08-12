extends "res://scripts/game_renderer.gd"

## Подготавливает узел к работе: создаёт зависимые данные и синхронизирует начальное состояние.
func _ready() -> void:
	InputSystem.ensure_default_actions()
	for content_error in ContentRegistry.validate():
		push_error("Invalid game content: " + content_error)
	LocaleSystem.load_locale()
	if is_inside_tree(): SettingsSystem.load(self)
	AudioSystem.initialize(self); message = LocaleSystem.text("welcome"); language_selected = maxi(LocaleSystem.LOCALES.find(LocaleSystem.current), 0)
	for y in FARM_SIZE.y:
		for x in FARM_SIZE.x:
			plots[Vector2i(x, y)] = {"tilled": false, "planted": false, "watered": false, "growth": 0.0, "stage": 0, "stage_flash": 0.0}
	if world_loot_nodes.is_empty():
		world_loot_seed = LootContainerSystem.random_seed() if world_loot_seed == 0 else world_loot_seed
		world_loot_nodes = LootContainerSystem.generate(world_loot_seed)
	benchmark_autoplay = "--autoplay" in OS.get_cmdline_user_args()
	if "--title-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = true
	if benchmark_autoplay:
		language_screen = false
		title_screen = false
		move_right_held = true
	if "--inventory-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = false
		grant_tester_kit()
		open_inventory()
	if "--creation-preview" in OS.get_cmdline_user_args(): language_screen = false; title_screen = false; AdventurePolishSystem.begin_new_game(self)
	if "--dialogue-preview" in OS.get_cmdline_user_args(): language_screen = false; title_screen = false; current_location = "overworld"; AdventurePolishSystem.open_quest_dialogue(self, "miron")
	if "--buildings-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = false
		current_location = "overworld"
		player = Vector2(590, 360); tutorial_visible = false
	if "--companions-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = false
		current_location = "prison_interior"
		player = Vector2(576, 470)
		coins = 500
		skill_levels.leadership = 2
	if "--animation-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = false
		current_location = "overworld"
		player = Vector2(700, 560)
		npc_position = Vector2(520, 540)
		guild_master_position = Vector2(700, 500)
		herbalist_position = Vector2(880, 540)
		recruited_companions.assign(["mila", "borislav"])
		active_companions.assign(["mila", "borislav"])
		companion_positions = {"mila":Vector2(620, 650), "borislav":Vector2(780, 650)}
	if "--enemy-levels-preview" in OS.get_cmdline_user_args():
		configure_enemy_levels_preview()
	if "--enemy-animations-preview" in OS.get_cmdline_user_args():
		EnemyAnimationLibrary.configure_preview(self)
	if "--debug-playground" in OS.get_cmdline_user_args(): DebugPlaygroundSystem.configure(self)
	if "--debug-navigation" in OS.get_cmdline_user_args(): DebugOverlaySystem.toggle(self)
	if "--farm-life-preview" in OS.get_cmdline_user_args(): language_screen=false; title_screen=false; current_location="overworld"; state.world.estate.level=3; player=Vector2(445,710); day=4; tutorial_visible=false
	if "--first-level-preview" in OS.get_cmdline_user_args() or "--capture-first-level" in OS.get_cmdline_user_args(): language_screen=false; title_screen=false; current_location="overworld"; player=Vector2(1160,650); tutorial_visible=false
	if "--capture-first-level" in OS.get_cmdline_user_args(): set_meta("capture_first_level_frames", 6); set_meta("capture_first_level_clean", true)
	if "--moon-glade-preview" in OS.get_cmdline_user_args():
		configure_moon_glade_preview()
	if "--storage-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = false
		current_location = "cottage_interior"
		home_chest_owned = true
		grant_tester_kit()
		StorageSystem.open(self)
	if "--forge-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = false
		current_location = "forge_interior"
		grant_tester_kit()
		open_forge()
	if "--contracts-preview" in OS.get_cmdline_user_args():
		ContractSystem.configure_preview(self)
	if "--story-preview" in OS.get_cmdline_user_args(): language_screen = false; title_screen = false; quest_log_open = true; quest_log_page = 0; if "--map-preview" in OS.get_cmdline_user_args(): quest_log_open = false; world_map_open = true; state.world.estate.discovered = WorldMapSystem.LOCATIONS.keys()
	if "--fishing-preview" in OS.get_cmdline_user_args(): FishingSystem.configure_preview(self)
	if MenuSystem.consume_new_game_request():
		language_screen = false
		title_screen = false
		AdventurePolishSystem.begin_new_game(self)
	MenuSystem.prepare_title(self)
	if "--pause-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = false
		MenuSystem.open_pause(self)
	if "--settings-preview" in OS.get_cmdline_user_args():
		language_screen = false
		title_screen = false
		MenuSystem.open_pause(self)
		MenuSystem.open_settings(self, false)
	NpcMovementSystem.initialize(self); FarmLifeSystem.initialize(self); sync_background_location(); AudioSystem.update_context_music(self)
	if has_meta("capture_first_level_clean"):
		var preview_life := FarmLifeSystem.state(self)
		preview_life.first_day = 6; preview_life.cutscene = ""; preview_life.cutscene_timer = 0.0
		message = ""; DiscoverySystem.dismiss(self)
	# На старте постоянная подпись локации достаточна; крупная карточка остаётся для новых мест.
	if current_location != "overworld": DiscoverySystem.show_location(self, current_location)
	queue_redraw()


## Сохраняет автоматический игровой скриншот после нескольких отрисованных кадров в режиме проверки уровня.
func _process(_delta: float) -> void:
	if not has_meta("capture_first_level_frames"): return
	var frames_left := int(get_meta("capture_first_level_frames")) - 1
	set_meta("capture_first_level_frames", frames_left)
	if frames_left > 0: return
	remove_meta("capture_first_level_frames")
	var image := get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://assets/generated/level_drafts/first_level_ingame_preview.png")
	var error := image.save_png(output)
	if error != OK: push_error("Не удалось сохранить предпросмотр первой локации: %s" % error)
	get_tree().quit()

## Готовит безопасную витрину пяти рангов врагов, трёх угроз и максимального облика героя.
func configure_enemy_levels_preview() -> void:
	language_screen = false
	title_screen = false
	current_location = "overworld"
	player = Vector2(1150, 650)
	player_level = SkillSystem.MAX_CHARACTER_LEVEL; player_hp = player_max_hp
	tutorial_visible = false
	for index in mini(5, enemy_nodes.size()):
		var enemy: Dictionary = enemy_nodes[index]
		enemy.location = "overworld"
		enemy.level = index + 1
		enemy.max_hp = CombatSystem.max_hp(enemy.kind, enemy.level)
		enemy.hp = enemy.max_hp
		enemy.position = Vector2(700 + index * 225, 520)
		enemy.home = enemy.position
		enemy.attack_timer = 999.0
		enemy_nodes[index] = enemy
	for index in mini(3, hazard_nodes.size()):
		var hazard: Dictionary = hazard_nodes[index]
		hazard.location = "overworld"
		hazard.kind = EnvironmentHazardSystem.FAMILY_ORDER[index]
		hazard.level = 1 + index * 2
		hazard.position = Vector2(820 + index * 330, 820)
		hazard.cooldown = 999.0
		hazard_nodes[index] = hazard


## Готовит витрину финального этапа Лунной поляны со Стражем, алтарём и наградой.
func configure_moon_glade_preview() -> void:
	language_screen = false; title_screen = false; current_location = "moon_glade"
	day = 5; game_minutes = 21.0 * 60.0; player = Vector2(1710, 610); tutorial_visible = false
	MoonGladeSystem.prepare(self)
	var moon_state: Dictionary = state.world.moon_glade
	moon_state.flower_collected = true; moon_state.crystal_charged = true; moon_state.echoes = [true, true, true]
	moon_state.altar_activated = true; moon_state.guardian_alive = true; moon_state.guardian_hp = MoonGladeSystem.GUARDIAN_MAX_HP

## Выполняет один физический кадр и обновляет активные игровые системы в заданном порядке.
func _physics_process(delta: float) -> void:
	AudioSystem.update(self, delta); update_hud_feedback(delta)
	DebugOverlaySystem.update(self, delta); delta = DebugOverlaySystem.simulation_delta(self, delta); if delta <= 0.0: queue_redraw(); return
	AdventurePolishSystem.update(self, delta); delta = FarmLifeSystem.simulation_delta(self,delta); if delta <= 0.0: queue_redraw(); return
	if DebugPlaygroundSystem.active(self): DebugPlaygroundSystem.update(self, delta); delta = DebugPlaygroundSystem.simulation_delta(self, delta); if delta <= 0.0: queue_redraw(); return
	if title_screen or menu_state.pause_open or menu_state.settings_open or AdventurePolishSystem.has_modal(self) or FarmLifeSystem.modal_active(self):
		queue_redraw()
		return
	update_game_clock(delta); WorldEventSystem.update(self); sync_background_environment(); EstateSystem.update_daily_event(self); VillageEventSystem.update(self); FarmLifeSystem.update(self,delta); update_crops(delta); TreeSystem.update(self, delta); MoonGladeSystem.update(self, delta); CastleCampaignSystem.update(self, delta)
	update_combat(delta); update_fishing(delta)
	update_status_effects(delta)
	CompanionSystem.update(self, delta)
	NpcMovementSystem.update(self, delta)
	PlayerSystem.update_animation(self, delta)
	AnimationSystem.update(self, delta)
	SkillSystem.update_resources(self, delta)
	ForageSystem.update(self)
	if not DebugPlaygroundSystem.active(self): DiscoverySystem.update(self, delta)
	if not DebugPlaygroundSystem.active(self): WildlifeSystem.update(self, delta)
	if benchmark_autoplay:
		update_benchmark_route(delta)
	if shop_open or inventory_open or crafting_open or storage_open or forge_open or contract_open or quest_log_open or skill_menu_open or world_map_open:
		queue_redraw()
		return
	update_player_movement(delta)
	LocationTransitionSystem.update(self, delta)
	update_held_action(delta)
	update_held_attack(delta)
	update_camera()
	queue_redraw()


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
	var current_speed := speed * (1.3 if speed_timer > 0.0 else 1.0) * InventorySystem.speed_multiplier(self)
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
	if title_screen or menu_state.pause_open or menu_state.settings_open:
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
			KEY_F10: DebugPlaygroundSystem.configure(self)
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
	var cell := targeted_plot()
	if not valid_plot(cell):
		message = LocaleSystem.text("face_plot")
		return
	var plot: Dictionary = plots[cell]
	var action_sfx := ""
	if selected_tool != Tool.HAND and energy <= 0:
		message = LocaleSystem.text("no_energy")
		return
	match selected_tool:
		Tool.HOE:
			if not plot.tilled:
				plot.tilled = true
				energy -= 1
				SkillSystem.award_profession_xp(self, "farming", 1)
				message = LocaleSystem.text("soil_ready")
				action_sfx = "hoe"
			else: message = LocaleSystem.text("already_tilled")
		Tool.SEEDS:
			if plot.tilled and not plot.planted and seeds > 0:
				plot.planted = true
				plot.growth = 0.0
				plot.stage = 0
				plot.stage_flash = 0.0
				seeds -= 1
				energy -= 1
				award_xp(1, "Посадка моркови")
				SkillSystem.award_profession_xp(self, "farming", 2)
				notify_tutorial("plant")
				action_sfx = "plant"
			elif seeds <= 0: message = LocaleSystem.text("no_seeds")
			else: message = LocaleSystem.text("till_first")
		Tool.WATER:
			if plot.planted and not plot.watered:
				var is_second_watering: bool = plot.growth >= STAGE_DURATION * 2.0
				plot.watered = true
				energy -= 1
				SkillSystem.award_profession_xp(self, "farming", 1)
				message = LocaleSystem.text("watered")
				notify_tutorial("rewater" if is_second_watering else "water")
				action_sfx = "water"
			else: message = LocaleSystem.text("nothing_water")
		Tool.HAND:
			if plot.planted and plot.growth >= GROWTH_DURATION:
				plot.planted = false
				plot.tilled = true
				plot.watered = false
				plot.growth = 0.0
				plot.stage = 0
				plot.stage_flash = 0.0
				var harvested: int = SkillSystem.harvest_count(self)
				carrots += harvested; var quality: String = EstateSystem.record_quality(self, "carrot", harvested)
				award_xp(3)
				SkillSystem.award_profession_xp(self, "farming", 4)
				message = "%s • %s" % [LocaleSystem.text("harvested", [inventory_item_name("carrot"), harvested]), LocaleSystem.ui("quality_%s" % quality)]
				notify_tutorial("harvest")
				action_sfx = "harvest"
			else: message = LocaleSystem.text("not_ripe")
	plots[cell] = plot
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
	var interactions := {}
	if current_location == "overworld":
		interactions = {
			"npc": NpcMovementSystem.actor(self, "grandmother", npc_position).position,
			"shop": BuildingSystem.SHOP_STALL_POSITION,
			"crate": BuildingSystem.SELL_CRATE_POSITION,
			"workbench": workbench_position,
			"cave_entrance": cave_entrance_position
		}
		if loot_available:
			interactions["loot"] = slime_position
	elif current_location == "cave":
		interactions = {"cave_exit": cave_exit_position}
	if not BuildingSystem.is_interior(current_location):
		interactions["world_gate"] = world_gate_position
	var nearest := ""
	var nearest_distance := 92.0
	for key in interactions:
		var distance := player.distance_to(interactions[key])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = key
	var building_interaction := BuildingSystem.nearest_interaction(self, nearest_distance)
	if not building_interaction.is_empty():
		nearest = building_interaction
		nearest_distance = player.distance_to(BuildingSystem.interaction_position(self, building_interaction))
	var quest_npc := QuestSystem.nearest_npc(self, nearest_distance)
	if not quest_npc.is_empty():
		nearest = "quest_npc:%s" % quest_npc
		nearest_distance = player.distance_to(QuestSystem.npc_position(self, quest_npc))
	var event_interaction := WorldEventSystem.nearest_interaction(self, nearest_distance); if not event_interaction.is_empty(): nearest = event_interaction
	var village_event := VillageEventSystem.nearest_interaction(self,nearest_distance); if not village_event.is_empty(): nearest = village_event
	var life_interaction := FarmLifeSystem.nearest_interaction(self,nearest_distance); if not life_interaction.is_empty(): nearest = life_interaction
	var campaign_interaction := CastleCampaignSystem.nearest_interaction(self, nearest_distance)
	if not campaign_interaction.is_empty():
		nearest = campaign_interaction
		nearest_distance = player.distance_to(CastleCampaignSystem.interaction_position(campaign_interaction))
	var estate_interaction := EstateSystem.nearest_interaction(self, nearest_distance); if not estate_interaction.is_empty(): nearest = estate_interaction
	if home_chest_owned and current_location == "cottage_interior":
		var chest_distance := player.distance_to(StorageSystem.CHEST_POSITION)
		if chest_distance < nearest_distance:
			nearest = "home_chest"
			nearest_distance = chest_distance
	var prisoner_interaction := CompanionSystem.nearest_prisoner(self, nearest_distance)
	if not prisoner_interaction.is_empty():
		nearest = prisoner_interaction
		nearest_distance = player.distance_to(CompanionSystem.interaction_position(prisoner_interaction))
	for index in dropped_items.size():
		var distance: float = player.distance_to(dropped_items[index].position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = "drop:%d" % index
	for index in world_loot_nodes.size():
		var container: Dictionary = world_loot_nodes[index]
		if container.opened or container.location != current_location:
			continue
		var distance: float = player.distance_to(container.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = "container:%d" % index
	for index in resource_nodes.size():
		var node: Dictionary = resource_nodes[index]
		if node.hits <= 0 or node.location != current_location:
			continue
		var distance: float = player.distance_to(node.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = "resource:%d" % index
	for index in food_nodes.size():
		var food: Dictionary = food_nodes[index]
		if not food.active or food.get("location", "overworld") != current_location:
			continue
		var distance: float = player.distance_to(food.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = "food:%d" % index
	return nearest

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func perform_context_action() -> bool:
	var interaction := nearest_interaction()
	if interaction.begins_with("building:"):
		return BuildingSystem.enter(self, interaction.get_slice(":", 1))
	if interaction == "interior_exit":
		return BuildingSystem.leave(self)
	if interaction.begins_with("interior_link:"):
		return BuildingSystem.travel_inside(self, interaction.get_slice(":", 1))
	if interaction.begins_with("interior_service:"):
		return BuildingSystem.use_service(self, interaction.get_slice(":", 1))
	if interaction.begins_with("prisoner:"):
		return CompanionSystem.interact(self, interaction.get_slice(":", 1))
	if interaction.begins_with("quest_npc:"):
		return AdventurePolishSystem.open_quest_dialogue(self, interaction.get_slice(":", 1))
	if interaction == "home_chest":
		return StorageSystem.open(self)
	if interaction == "moon_portal":
		return WorldEventSystem.use_portal(self)
	if interaction.begins_with("moon_"):
		return MoonGladeSystem.interact(self, interaction)
	if interaction.begins_with("village_event:"): return VillageEventSystem.interact(self,interaction.get_slice(":",1))
	if interaction.begins_with("life:"): return FarmLifeSystem.interact(self,interaction)
	if interaction.begins_with("castle_"):
		return CastleCampaignSystem.interact(self, interaction)
	if interaction == "estate_board": return EstateSystem.purchase_next(self)
	if interaction.begins_with("drop:"):
		return collect_dropped_item(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("container:"):
		return LootContainerSystem.open(self, int(interaction.get_slice(":", 1)))
	if interaction.begins_with("resource:"):
		return mine_resource(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("food:"):
		return collect_food(int(interaction.get_slice(":", 1)))
	match interaction:
		"npc":
			talk_to_grandmother()
			return true
		"shop":
			open_shop()
			return true
		"crate":
			sell_carrots()
			return true
		"workbench":
			open_crafting()
			return true
		"loot":
			collect_loot()
			return true
		"cave_entrance":
			enter_cave()
			return true
		"cave_exit":
			exit_cave()
			return true
		"world_gate":
			WorldSystem.travel(self)
			return true
	return false

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
		skill_menu_selected = clampi(skill_menu_selected, 0, SkillSystem.SKILLS.size() - 1)
		clear_movement_keys()
		message = "Выбери развитие. Свободных очков: %d" % skill_points

## Обрабатывает относящееся к методу событие и синхронизирует зависимое состояние.
func handle_skill_menu_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: skill_menu_selected = posmod(skill_menu_selected - 1, SkillSystem.SKILLS.size())
			JOY_BUTTON_DPAD_RIGHT: skill_menu_selected = posmod(skill_menu_selected + 1, SkillSystem.SKILLS.size())
			JOY_BUTTON_DPAD_UP: skill_menu_selected = posmod(skill_menu_selected - 3, SkillSystem.SKILLS.size())
			JOY_BUTTON_DPAD_DOWN: skill_menu_selected = posmod(skill_menu_selected + 3, SkillSystem.SKILLS.size())
			JOY_BUTTON_A: SkillSystem.allocate(self, SkillSystem.SKILLS[skill_menu_selected].id)
			JOY_BUTTON_Y, JOY_BUTTON_B, JOY_BUTTON_START: skill_menu_open = false
		queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE, KEY_K: skill_menu_open = false
		KEY_LEFT: skill_menu_selected = posmod(skill_menu_selected - 1, SkillSystem.SKILLS.size())
		KEY_RIGHT: skill_menu_selected = posmod(skill_menu_selected + 1, SkillSystem.SKILLS.size())
		KEY_UP: skill_menu_selected = posmod(skill_menu_selected - 3, SkillSystem.SKILLS.size())
		KEY_DOWN: skill_menu_selected = posmod(skill_menu_selected + 3, SkillSystem.SKILLS.size())
		KEY_ENTER, KEY_E: SkillSystem.allocate(self, SkillSystem.SKILLS[skill_menu_selected].id)
	queue_redraw()

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
	TutorialSystem.notify(self, event_name)

## Выполняет операцию «сброса обучения» и возвращает результат согласно контракту метода.
func reset_tutorial() -> void:
	TutorialSystem.reset(self)

## Выполняет заявленный переход режима и обновляет связанный интерфейс.
func open_crafting() -> void:
	crafting_open = true
	crafting_selected = 0
	clear_movement_keys()
	message = LocaleSystem.text("recipe_select")

## Обрабатывает крафта ввода и синхронизирует связанное состояние.
func handle_crafting_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_ESCAPE, KEY_C: crafting_open = false
		KEY_UP: crafting_selected = posmod(crafting_selected - 1, CraftingSystem.RECIPES.size())
		KEY_DOWN: crafting_selected = posmod(crafting_selected + 1, CraftingSystem.RECIPES.size())
		KEY_ENTER, KEY_E: CraftingSystem.craft(self, crafting_selected)
	queue_redraw()

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
	update_input_device(event)
	if not language_screen and (title_screen or menu_state.pause_open or menu_state.settings_open):
		if MenuSystem.handle_input(self, event):
			get_viewport().set_input_as_handled()
		return
	if AdventurePolishSystem.has_modal(self) and AdventurePolishSystem.handle_input(self, event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		var world_controls_visible := not (shop_open or inventory_open or crafting_open or storage_open or forge_open or contract_open or quest_log_open or skill_menu_open or world_map_open)
		if world_controls_visible:
			var movement_changed := set_movement_motion_state(event)
			if movement_changed:
				var direction := get_movement_direction()
				if direction != Vector2.ZERO:
					facing = direction
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey:
		if event.keycode == KEY_G: CombatSystem.set_blocking(self, event.pressed)
		if event.pressed and not event.echo and event.keycode == KEY_SHIFT: CombatSystem.start_dodge(self)
		var is_action_key := set_action_key_state(event)
		var is_attack_key := set_attack_key_state(event)
		var is_movement_key := update_movement_key_state(event)
		if not title_screen and not menu_state.pause_open and event.pressed and is_movement_key:
			apply_immediate_key_response(event)
		if is_action_key and not title_screen and not menu_state.pause_open and not shop_open and not inventory_open and not crafting_open and not storage_open and not forge_open and not contract_open and not quest_log_open and not skill_menu_open and not world_map_open:
			if event.pressed and not event.echo:
				if not perform_context_action() and current_location == "overworld":
					use_active_item()
			get_viewport().set_input_as_handled()
		if is_attack_key and not title_screen and not menu_state.pause_open and not shop_open and not inventory_open and not crafting_open and not storage_open and not forge_open and not contract_open and not quest_log_open and not skill_menu_open and not world_map_open:
			if event.pressed and not event.echo:
				attack_nearest_enemy()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var world_controls_visible := not (shop_open or inventory_open or crafting_open or storage_open or forge_open or contract_open or quest_log_open or skill_menu_open or world_map_open)
		if world_controls_visible and event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			var movement_button := set_movement_button_state(event)
			if movement_button and event.pressed:
				apply_immediate_gamepad_facing()
			if movement_button and not title_screen and not menu_state.pause_open:
				get_viewport().set_input_as_handled()
				return
			return
		if handle_gamepad_and_touch(event):
			get_viewport().set_input_as_handled()
			return


## Запоминает последнее устройство ввода и включает мобильный слой только после настоящего касания.
func update_input_device(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_controls_visible = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		touch_controls_visible = false

## Обрабатывает относящееся к методу событие и синхронизирует зависимое состояние.
func handle_gamepad_and_touch(event: InputEvent) -> bool:
	var world_controls_visible := not (shop_open or inventory_open or crafting_open or storage_open or forge_open or contract_open or quest_log_open or skill_menu_open or world_map_open); if world_controls_visible and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_STICK: CombatSystem.set_blocking(self, event.pressed); return true
	if world_controls_visible and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_STICK: AdventurePolishSystem.cycle_target(self); return true
	if world_controls_visible and event is InputEventScreenTouch and InterfaceRenderer.BLOCK_BUTTON.has_point(event.position): CombatSystem.set_blocking(self, event.pressed); return true
	if world_controls_visible and event is InputEventScreenTouch and event.pressed and InterfaceRenderer.DODGE_BUTTON.has_point(event.position): CombatSystem.start_dodge(self); return true
	if InputSystem.set_pointer_action_state(self, event, world_controls_visible): return true
	if world_controls_visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and InterfaceRenderer.PAUSE_BUTTON.has_point(event.position):
		return MenuSystem.open_pause(self)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if inventory_open: InventoryInputSystem.handle_mouse(self, event); return true
		if event.pressed:
			if world_controls_visible and AdventurePolishSystem.target_at_screen(self, event.position): return true
			if world_controls_visible and InterfaceRenderer.DODGE_BUTTON.has_point(event.position): CombatSystem.start_dodge(self); return true
			if world_map_open: WorldMapSystem.toggle(self); return true
			if quest_log_open and InputSystem.handle_quest_pointer(self, event.position): return true
			if InterfaceRenderer.LOCATION_BADGE.has_point(event.position): WorldMapSystem.toggle(self); return true
			if InterfaceRenderer.QUEST_BUTTON.has_point(event.position): toggle_quest_log(); return true
			if InterfaceRenderer.SKILL_BUTTON.has_point(event.position): open_skill_menu(); return true
			var mouse_hotbar := InterfaceRenderer.hotbar_at(event.position)
			if mouse_hotbar >= 0: select_hotbar(mouse_hotbar); return true
	if event is InputEventJoypadButton and event.pressed:
		if world_map_open: InputSystem.handle_modal_input(self, event); return true
		var modal_handler: Callable = InputSystem.handle_storage_input if storage_open else (InputSystem.handle_forge_input if forge_open else (InputSystem.handle_contract_input if contract_open else Callable()))
		if modal_handler.is_valid():
			modal_handler.call(self, event); return true
		if skill_menu_open: handle_skill_menu_input(event); return true
		if quest_log_open: InputSystem.handle_modal_input(self, event); return true
		if inventory_open: handle_inventory_input(event); return true
		match event.button_index:
			JOY_BUTTON_B: CombatSystem.start_dodge(self); return true
			JOY_BUTTON_RIGHT_SHOULDER: WorldMapSystem.toggle(self); return true
			JOY_BUTTON_LEFT_SHOULDER: CompanionSystem.cycle_command(self); return true
			JOY_BUTTON_DPAD_LEFT:
				select_hotbar(posmod(selected_hotbar - 1, 10))
				return true
			JOY_BUTTON_DPAD_RIGHT:
				select_hotbar(posmod(selected_hotbar + 1, 10))
				return true
			JOY_BUTTON_A:
				if not perform_context_action(): use_active_item()
				return true
			JOY_BUTTON_X:
				attack_nearest_enemy()
				return true
			JOY_BUTTON_Y:
				open_inventory()
				return true
			JOY_BUTTON_BACK:
				toggle_quest_log()
				return true
			JOY_BUTTON_START:
				MenuSystem.open_pause(self)
				return true
	if event is InputEventScreenDrag and inventory_open:
		inventory_touch_drag_y += event.relative.y
		if absf(inventory_touch_drag_y) >= 36.0:
			InventorySystem.scroll(self, -1 if inventory_touch_drag_y > 0.0 else 1)
			inventory_touch_drag_y = 0.0
		queue_redraw()
		return true
	if event is InputEventScreenTouch and event.pressed:
		if world_controls_visible and InterfaceRenderer.PAUSE_BUTTON.has_point(event.position):
			return MenuSystem.open_pause(self)
		if discovery_card_rect().has_point(event.position) and not discovery_current.is_empty():
			DiscoverySystem.dismiss(self)
			return true
		if storage_open:
			return InputSystem.handle_storage_touch(self, event.position)
		if forge_open:
			return InputSystem.handle_forge_touch(self, event.position)
		if contract_open:
			return InputSystem.handle_contract_touch(self, event.position)
		if InterfaceRenderer.QUEST_BUTTON.has_point(event.position):
			toggle_quest_log()
			return true
		if skill_menu_open:
			if event.position.y >= 158.0 and event.position.y < 526.0 and event.position.x >= 142.0 and event.position.x < 1000.0:
				var column := clampi(int((event.position.x - 142.0) / 444.0), 0, 1)
				var row := clampi(int((event.position.y - 158.0) / 92.0), 0, 3)
				skill_menu_selected = row * 2 + column
				SkillSystem.allocate(self, SkillSystem.SKILLS[skill_menu_selected].id)
			return true
		if InterfaceRenderer.SKILL_BUTTON.has_point(event.position):
			open_skill_menu()
			return true
		if inventory_open:
			return InventoryInputSystem.handle_touch(self, event.position)
		if world_controls_visible and AdventurePolishSystem.target_at_screen(self, event.position): return true
		var index := InterfaceRenderer.hotbar_at(event.position)
		if index >= 0:
			select_hotbar(index)
		else:
			if not perform_context_action(): use_active_item()
		return true
	return false
