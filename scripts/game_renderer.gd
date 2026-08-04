extends "res://scripts/game_context.gd"

## Отрисовывает текущее визуальное состояние узла.
func _draw() -> void:
	RenderSystem.draw(self)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_title_screen() -> void:
	if title_screen:
		draw_texture_rect(TITLE_ART, Rect2(0, 0, 1152, 648), false)
		draw_rect(Rect2(0, 0, 1152, 202), Color(0.03, 0.055, 0.075, 0.38))
		draw_rect(Rect2(0, 500, 1152, 148), Color(0.025, 0.045, 0.04, 0.32))
		var pulse := 0.78 + sin(Time.get_ticks_msec() / 520.0) * 0.10
		for firefly in 7:
			var phase := Time.get_ticks_msec() / 900.0 + firefly * 1.73
			var point := Vector2(95 + firefly * 163 + sin(phase) * 22, 390 + cos(phase * 0.73) * 68)
			draw_circle(point, 3.0, Color(1.0, 0.83, 0.35, 0.20 + pulse * 0.22))
		var title_rect := Rect2(196, 54, 760, 62)
		draw_string(UI_FONT, title_rect.position + Vector2(3, 52), LocaleSystem.ui("title"), HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x, 50, Color(0.08, 0.09, 0.08, 0.78))
		draw_string(UI_FONT, title_rect.position + Vector2(0, 48), LocaleSystem.ui("title"), HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x, 50, Color("fff0bd"))
		draw_rect(Rect2(355, 128, 442, 38), Color(0.12, 0.20, 0.18, 0.80))
		draw_rect(Rect2(360, 133, 432, 28), Color(0.32, 0.24, 0.16, 0.72))
		draw_string(UI_FONT, Vector2(370, 155), LocaleSystem.ui("title_subtitle"), HORIZONTAL_ALIGNMENT_CENTER, 412, 20, Color("ffe19a"))
		draw_string(UI_FONT, Vector2(326, 194), LocaleSystem.ui("title_features"), HORIZONTAL_ALIGNMENT_CENTER, 500, 15, Color(1.0, 0.96, 0.82, 0.88))
		if menu_state.settings_open:
			MenuRenderer.draw_settings(self)
		else:
			MenuRenderer.draw_title_menu(self)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_language_screen() -> void:
	draw_texture_rect(TITLE_ART, Rect2(0, 0, 1152, 648), false)
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.025, 0.055, 0.055, 0.74))
	draw_string(UI_FONT, Vector2(196, 112), LocaleSystem.ui("choose_language"), HORIZONTAL_ALIGNMENT_CENTER, 760, 38, Color("fff4cf"))
	for index in LocaleSystem.LOCALES.size():
		var rect := language_button_rect(index)
		var selected := index == language_selected
		draw_rect(rect, Color("e8bd62") if selected else Color("365548"))
		draw_rect(rect.grow(-4), Color("fff0bd") if selected else Color("4d7161"))
		draw_string(UI_FONT, rect.position + Vector2(10, 40), "%d  %s" % [index + 1, LocaleSystem.language_name(index)], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20, 24, Color("352e28") if selected else Color.WHITE)
	draw_string(UI_FONT, Vector2(236, 540), LocaleSystem.ui("confirm"), HORIZONTAL_ALIGNMENT_CENTER, 680, 18, Color.WHITE)

## Отрисовывает мира по текущему состоянию игры.
func draw_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("7fad5c"))
	# Редкие крупные кластеры заменяют около 5000 отдельных команд отрисовки каждый кадр.
	for y in range(150, int(WORLD_SIZE.y), 190):
		for x in range(70 + (y % 140), int(WORLD_SIZE.x), 210):
			draw_circle(Vector2(x, y), 3.0, Color("99bd6a"))
			draw_line(Vector2(x - 6, y + 7), Vector2(x, y - 2), Color("668f4b"), 2)
			draw_line(Vector2(x + 6, y + 7), Vector2(x, y - 2), Color("668f4b"), 2)
	# Река.
	draw_rect(Rect2(0, 860, WORLD_SIZE.x, 340), Color("4f9fb0"))
	for x in range(0, int(WORLD_SIZE.x), 70): draw_line(Vector2(x, 900), Vector2(x + 34, 900), Color("83c9c5"), 3)
	# Дом и указатель кровати.
	draw_rect(Rect2(54, 130, 190, 150), Color("e5c478"))
	draw_colored_polygon(PackedVector2Array([Vector2(38,145), Vector2(149,72), Vector2(260,145)]), Color("9c5338"))
	draw_rect(Rect2(128, 216, 43, 64), Color("6b4328"))
	draw_string(UI_FONT, Vector2(66, 308), LocaleSystem.ui("home"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# Магазин.
	draw_rect(Rect2(910, 194, 128, 98), Color("f3d88e"))
	draw_rect(Rect2(895, 175, 158, 30), Color("d66b45"))
	draw_string(UI_FONT, Vector2(913, 238), LocaleSystem.ui("seeds_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("55382b"))
	draw_string(UI_FONT, Vector2(905, 320), LocaleSystem.ui("shop_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# Несколько стадий плодовых деревьев из бесплатного листа спрайтов.
	draw_texture_rect_region(PLANT_SHEET, Rect2(270, 126, 290, 90), Rect2(94, 0, 290, 90))
	# Ящик для продажи урожая.
	draw_rect(Rect2(790, 392, 60, 54), Color("9c633b"))
	for i in 3: draw_line(Vector2(794, 402 + i * 15), Vector2(846, 402 + i * 15), Color("d09755"), 4)
	draw_string(UI_FONT, Vector2(753, 473), LocaleSystem.ui("sell_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_farm() -> void:
	for cell in plots:
		var plot: Dictionary = plots[cell]
		var rect := Rect2(FARM_ORIGIN + cell * TILE, Vector2(TILE - 3, TILE - 3))
		if plot.tilled:
			draw_rect(rect, Color("835238") if not plot.watered else Color("4e4539"))
			for line_y in 3: draw_line(rect.position + Vector2(5, 13 + line_y * 12), rect.position + Vector2(40, 13 + line_y * 12), Color("a86c47"), 2)
		else:
			draw_rect(rect, Color("73994f"))
		if plot.planted:
			draw_crop(rect.get_center(), plot)
			draw_crop_progress(rect, plot)
			if not plot.watered and plot.growth < GROWTH_DURATION:
				draw_water_needed_icon(rect.position + Vector2(8, 4))
	var target := targeted_plot()
	if valid_plot(target):
		draw_rect(Rect2(FARM_ORIGIN + target * TILE, Vector2(TILE - 3, TILE - 3)), Color("fff3a6"), false, 3)

## Отрисовывает культуры по текущему состоянию игры.
func draw_crop(center: Vector2, plot: Dictionary) -> void:
	var stage: int = plot.stage
	var flash: float = plot.stage_flash
	var bounce := 1.0 + sin(flash * 18.0) * flash * 0.16
	if flash > 0.0:
		draw_circle(center - Vector2(0, 8), 20.0 * flash, Color(1.0, 0.91, 0.38, flash * 0.35), false, 3.0)
	if stage == 0:
		draw_circle(center + Vector2(0, 5), 4, Color("d6b66a"))
		draw_line(center + Vector2(0, 3), center - Vector2(0, 3), Color("5e8a42"), 3)
	elif stage == 1:
		draw_line(center + Vector2(0, 7), center - Vector2(0, 8 * bounce), Color("315a36"), 4)
		draw_colored_polygon(PackedVector2Array([center - Vector2(1, 6), center - Vector2(12, 12), center - Vector2(5, 2)]), Color("63a34e"))
		draw_colored_polygon(PackedVector2Array([center - Vector2(-1, 5), center - Vector2(-11, 11), center - Vector2(-5, 1)]), Color("4f843f"))
	elif stage == 2:
		draw_circle(center + Vector2(0, 8), 5, Color("e98a3d"))
		draw_line(center + Vector2(0, 5), center - Vector2(0, 14 * bounce), Color("315a36"), 5)
		draw_circle(center - Vector2(8, 10), 8 * bounce, Color("5d9849"))
		draw_circle(center + Vector2(8, -11), 8 * bounce, Color("4a813e"))
	elif stage == 3:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 3), center + Vector2(7, 3), center + Vector2(3, 18), center + Vector2(-2, 20)]), Color("ee7a32"))
		draw_line(center + Vector2(0, 5), center - Vector2(0, 18 * bounce), Color("315a36"), 5)
		draw_circle(center - Vector2(9, 13), 10 * bounce, Color("66a24d"))
		draw_circle(center + Vector2(9, -13), 10 * bounce, Color("4b833e"))
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 1), center + Vector2(8, 1), center + Vector2(4, 20), center + Vector2(0, 24), center + Vector2(-5, 19)]), Color("f4772d"))
		draw_line(center + Vector2(0, 3), center - Vector2(0, 19), Color("315a36"), 5)
		draw_circle(center - Vector2(10, 14), 11, Color("68a54d"))
		draw_circle(center + Vector2(10, -14), 11, Color("4b873e"))

## Отрисовывает культуры прогресса по текущему состоянию игры.
func draw_crop_progress(rect: Rect2, plot: Dictionary) -> void:
	var progress: float = clampf(plot.growth / GROWTH_DURATION, 0.0, 1.0)
	var bar := Rect2(rect.position + Vector2(3, -10), Vector2(rect.size.x - 6, 7))
	if progress >= 1.0:
		# Иконка готовности: золотой ромб с зелёной галочкой.
		var icon_center := rect.position + Vector2(rect.size.x - 5, -7)
		draw_colored_polygon(PackedVector2Array([icon_center + Vector2(0, -10), icon_center + Vector2(10, 0), icon_center + Vector2(0, 10), icon_center + Vector2(-10, 0)]), Color("ffd45c"))
		draw_polyline(PackedVector2Array([icon_center + Vector2(-5, 0), icon_center + Vector2(-1, 4), icon_center + Vector2(6, -5)]), Color("28583b"), 3.0)
		return
	draw_rect(bar, Color("243b35"))
	var fill_color := Color("e58b3e").lerp(Color("6fcb62"), progress)
	draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * progress, bar.size.y - 2)), fill_color)
	# Четыре крупных деления — по одному на каждую стадию.
	for marker in range(1, 4):
		var marker_x := bar.position.x + bar.size.x * marker / 4.0
		draw_line(Vector2(marker_x, bar.position.y), Vector2(marker_x, bar.end.y), Color("f7e4b0"), 1.5)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_water_needed_icon(center: Vector2) -> void:
	# Красная капля: заметный сигнал, что рост поставлен на паузу.
	var pulse := 1.0 + sin(Time.get_ticks_msec() / 130.0) * 0.08
	var points := PackedVector2Array([
		center + Vector2(0, -9) * pulse,
		center + Vector2(7, 1) * pulse,
		center + Vector2(5, 7) * pulse,
		center + Vector2(0, 10) * pulse,
		center + Vector2(-5, 7) * pulse,
		center + Vector2(-7, 1) * pulse
	])
	draw_colored_polygon(points, Color("e4473f"))
	draw_circle(center + Vector2(-2, 2), 2.0, Color("ffaaa0"))

## Отрисовывает героя по текущему состоянию игры.
func draw_player() -> void:
	AnimationRenderer.draw_player(self)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_rpg_world() -> void:
	# Бабушка и верстак.
	var grandmother: Dictionary = NpcMovementSystem.actor(self, "grandmother", npc_position)
	draw_npc_sprite(0, grandmother.position, grandmother.direction, grandmother.moving)
	if player.distance_to(grandmother.position) < 150.0:
		draw_string(UI_FONT, grandmother.position + Vector2(-50, 55), LocaleSystem.entity("grandmother"), HORIZONTAL_ALIGNMENT_CENTER, 100, 16, Color("293c2f"))
	draw_rect(Rect2(workbench_position - Vector2(32, 20), Vector2(64, 44)), Color("865334"))
	draw_line(workbench_position - Vector2(25, 8), workbench_position + Vector2(25, -8), Color("d09a59"), 5)
	if player.distance_to(workbench_position) < 150.0:
		draw_string(UI_FONT, workbench_position + Vector2(-55, 45), LocaleSystem.entity("workbench"), HORIZONTAL_ALIGNMENT_CENTER, 110, 16, Color("293c2f"))
	if AnimationRenderer.draw_slime(self):
		if slime_alive:
			draw_rect(Rect2(slime_position + Vector2(-28, -50), Vector2(56, 7)), Color("402d32"))
			draw_rect(Rect2(slime_position + Vector2(-27, -49), Vector2(54.0 * slime_hp / 3.0, 5)), Color("dc554b"))
	elif loot_available:
		draw_circle(slime_position, 13, Color("78d6a5"))
		draw_circle(slime_position - Vector2(4, 4), 4, Color("baf1c8"))
	# Каменная арка заменяет технический тёмный круг и сразу читается как вход в отдельную пещеру.
	var mouth := PackedVector2Array([
		cave_entrance_position + Vector2(-46, 38), cave_entrance_position + Vector2(-46, -8),
		cave_entrance_position + Vector2(-34, -36), cave_entrance_position + Vector2(0, -52),
		cave_entrance_position + Vector2(34, -36), cave_entrance_position + Vector2(46, -8),
		cave_entrance_position + Vector2(46, 38),
	])
	draw_colored_polygon(mouth, Color("1c2930"))
	for offset in [Vector2(-43,14), Vector2(-35,-22), Vector2(-10,-45), Vector2(20,-42), Vector2(40,-14), Vector2(42,24)]:
		draw_texture_rect(RESOURCE_ROCK, Rect2(cave_entrance_position + offset - Vector2(18, 18), Vector2(36, 36)), false, Color("a9ad9e"))
	draw_line(cave_entrance_position + Vector2(-35, 37), cave_entrance_position + Vector2(35, 37), Color("0f171b"), 6.0)
	if player.distance_to(cave_entrance_position) < 180.0:
		draw_string(UI_FONT, cave_entrance_position + Vector2(-58, 78), LocaleSystem.location("cave"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7fff4"))


## Отрисовывает внешние спрайты зданий, подписи и состояние закрытых дверей.
func draw_buildings() -> void:
	var source_size := Vector2(BUILDING_ATLAS.get_width() / 4.0, BUILDING_ATLAS.get_height() / 2.0)
	for building_id in BuildingSystem.buildings_at(current_location):
		var data: Dictionary = BuildingSystem.BUILDINGS[building_id]
		var sprite_index: int = data.sprite
		var source := Rect2(Vector2(sprite_index % 4, sprite_index / 4) * source_size, source_size)
		var destination := BuildingSystem.destination_rect(building_id)
		draw_texture_rect_region(BUILDING_ATLAS, destination, source)
		var unlocked := BuildingSystem.can_enter(self, building_id)
		var door: Vector2 = data.door
		if not unlocked and player.distance_to(door) < 180.0:
			draw_string(UI_FONT, door + Vector2(-12, -28), "🔒", HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color("ffb36a"))


## Отрисовывает сезонный декор и доступные порталы мировых событий.
func draw_world_events() -> void:
	if current_location == "overworld": VisualAssetSystem.draw_seasonal_village(self, WorldEventSystem.SEASONS.find(WorldEventSystem.season(day)))
	var portal_position := WorldEventSystem.RETURN_PORTAL_POSITION if current_location == "moon_glade" else WorldEventSystem.PORTAL_POSITION
	var portal_visible := current_location == "moon_glade" or (current_location == "overworld" and WorldEventSystem.eclipse_active(day, game_minutes))
	VisualAssetSystem.draw_eclipse_world(self, current_location, portal_position, portal_visible)
	MoonGladeRenderer.draw(self)
	if portal_visible and player.distance_to(portal_position) < 160.0:
		draw_string(UI_FONT, portal_position + Vector2(-90, 55), "E • Лунный портал", HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color("e4dbff"))


## Отрисовывает мебель, выходы и переходы между этажами текущего интерьера.
func draw_interior_objects() -> void:
	var data: Dictionary = BuildingSystem.interior(current_location)
	if data.is_empty():
		return
	var room: Rect2 = data.room
	draw_rect(Rect2(room.position + Vector2(34, 48), Vector2(110, 48)), Color("5b3d2c"))
	draw_rect(Rect2(room.end - Vector2(174, room.size.y - 48), Vector2(120, 54)), Color("735238"))
	draw_rect(Rect2(data.exit - Vector2(34, 18), Vector2(68, 36)), Color("382d29"))
	draw_string(UI_FONT, data.exit + Vector2(-44, 38), "E • выход", HORIZONTAL_ALIGNMENT_CENTER, 88, 13, Color("fff0bd"))
	for link in data.get("links", []):
		draw_circle(link.position, 34, Color("d6ad52"), false, 5)
		draw_string(UI_FONT, link.position + Vector2(-58, 6), "ЛЕСТНИЦА", HORIZONTAL_ALIGNMENT_CENTER, 116, 13, Color("fff0bd"))
	if data.has("service"):
		var service_position: Vector2 = data.service_position
		draw_rect(Rect2(service_position - Vector2(52, 24), Vector2(104, 48)), Color("d0a45b"))
		draw_string(UI_FONT, service_position + Vector2(-48, 5), LocaleSystem.entity(String(data.service)).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 96, 13, Color("352d26"))
	if current_location == "cottage_interior" and home_chest_owned:
		var chest_position: Vector2 = StorageSystem.CHEST_POSITION
		draw_rect(Rect2(chest_position - Vector2(46, 24), Vector2(92, 52)), Color("58351f"))
		draw_rect(Rect2(chest_position - Vector2(42, 20), Vector2(84, 44)), Color("a66d35"))
		draw_arc(chest_position - Vector2(0, 18), 42, PI, TAU, 16, Color("d19a4b"), 7)
		draw_rect(Rect2(chest_position - Vector2(7, 4), Vector2(14, 18)), Color("e2bd62"))
		draw_string(UI_FONT, chest_position + Vector2(-62, 49), LocaleSystem.entity("home_chest"), HORIZONTAL_ALIGNMENT_CENTER, 124, 13, Color("fff0bd"))
	if current_location == "prison_interior":
		for companion_id in CompanionSystem.COMPANIONS:
			var position: Vector2 = CompanionSystem.COMPANIONS[companion_id].position
			draw_rect(Rect2(position - Vector2(72, 78), Vector2(144, 150)), Color("2e3338"), false, 5)
			for bar_x in range(-54, 55, 27):
				draw_line(position + Vector2(bar_x, -72), position + Vector2(bar_x, 66), Color("85878a"), 4)


## Отрисовывает кандидатов тюрьмы и активных напарников с их текущими характеристиками.
func draw_companions() -> void:
	if current_location == "prison_interior":
		for companion_id in CompanionSystem.COMPANIONS:
			var data: Dictionary = CompanionSystem.COMPANIONS[companion_id]
			var position: Vector2 = data.position
			draw_companion_sprite(companion_id, position)
			var state_text := "В ГРУППЕ" if companion_id in active_companions else ("НАНЯТ" if companion_id in recruited_companions else "%d монет" % int(data.price))
			draw_string(UI_FONT, position + Vector2(-100, 92), CompanionSystem.name(self, companion_id), HORIZONTAL_ALIGNMENT_CENTER, 200, 15, Color("fff0bd"))
			draw_string(UI_FONT, position + Vector2(-100, 112), "⚔%d  🛡%d  ✚%d • %s" % [data.damage, data.defense, data.heal, state_text], HORIZONTAL_ALIGNMENT_CENTER, 200, 13, Color("d8e9d2"))
		return
	for companion_id in active_companions:
		var position: Vector2 = companion_positions.get(companion_id, player + Vector2(-50, 35))
		draw_companion_sprite(companion_id, position)


## Отрисовывает одного напарника из его атласа восьми направлений.
func draw_companion_sprite(companion_id: String, position: Vector2) -> void:
	var data: Dictionary = CompanionSystem.COMPANIONS.get(companion_id, {})
	if data.is_empty():
		return
	var moving: bool = companion_moving.get(companion_id, false) and current_location != "prison_interior"
	var direction: Vector2 = companion_directions.get(companion_id, Vector2.DOWN)
	DirectionalCharacterSystem.draw_companion(self, companion_id, position, direction, moving)

## Отрисовывает NPC из атласа восьми направлений по фактическому состоянию движения.
func draw_npc_sprite(sprite_index: int, position: Vector2, direction: Vector2 = Vector2.DOWN, moving: bool = false, tint: Color = Color.WHITE) -> void:
	DirectionalCharacterSystem.draw_npc(self, sprite_index, position, direction, moving, tint)

## Применяет общий цикл дыхания или шага к одному прозрачному атласному спрайту.
func draw_living_atlas_sprite(texture: Texture2D, source: Rect2, position: Vector2, size: Vector2, time: float, moving: bool, phase: float, flip_x: bool = false, modulate: Color = Color.WHITE) -> void:
	var motion: Dictionary = PresentationSystem.living_motion(time, moving, phase)
	var sprite_scale: Vector2 = motion.scale
	if flip_x:
		sprite_scale.x *= -1.0
	var world_transform := -camera_offset
	draw_set_transform(world_transform + position + Vector2(motion.offset), float(motion.rotation), sprite_scale)
	draw_texture_rect_region(texture, Rect2(Vector2(-size.x * 0.5, -size.y * 0.66), size), source, modulate)
	draw_set_transform(world_transform, 0.0, Vector2.ONE)

## Отрисовывает сюжетного NPC, его имя и маркер состояния миссии.
func draw_mission_npc(position: Vector2, npc_name: String, mission_id: String, sprite_index: int) -> void:
	draw_npc_sprite(sprite_index, position)
	if player.distance_to(position) < 155.0:
		draw_string(UI_FONT, position + Vector2(-62, 58), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 124, 15, Color("293c2f"))
	var state: String = mission_states.get(mission_id, QuestSystem.AVAILABLE)
	var marker := "!" if state == QuestSystem.AVAILABLE else ("✓" if state == QuestSystem.COMPLETED else "?")
	draw_circle(position - Vector2(0, 62), 16, Color("f1ca5c") if state != QuestSystem.COMPLETED else Color("70bd78"))
	draw_string(UI_FONT, position + Vector2(-8, -56), marker, HORIZONTAL_ALIGNMENT_CENTER, 16, 20, Color("3b3225"))

## Отрисовывает жителей с заданиями только в их родной локации и показывает доступность диалога.
func draw_quest_npcs() -> void:
	for npc_id in QuestSystem.NPCS:
		var data: Dictionary = QuestSystem.NPCS[npc_id]
		if data.location != current_location: continue
		var position := QuestSystem.npc_position(self, npc_id)
		var movement: Dictionary = NpcMovementSystem.actor(self, npc_id, position)
		draw_npc_sprite(int(data.sprite), position, movement.direction, movement.moving, data.tint)
		if player.distance_to(position) < 155.0:
			draw_string(UI_FONT, position + Vector2(-76, 58), QuestSystem.npc_name(npc_id), HORIZONTAL_ALIGNMENT_CENTER, 152, 15, Color("293c2f") if current_location == "overworld" else Color("fff0bd"))
		var marker := QuestSystem.npc_marker(self, npc_id)
		if marker.is_empty(): continue
		draw_circle(position - Vector2(0, 62), 16, Color("f1ca5c") if marker != "✓" else Color("70bd78"))
		draw_string(UI_FONT, position + Vector2(-8, -56), marker, HORIZONTAL_ALIGNMENT_CENTER, 16, 20, Color("3b3225"))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func forage_sprite_layout(kind: String, position: Vector2) -> Dictionary:
	return PresentationSystem.forage_sprite_layout(FORAGE_SPRITES, kind, position)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_food_nodes() -> void:
	for food in food_nodes:
		if food.get("location", "overworld") != current_location:
			continue
		var position: Vector2 = food.position
		var alpha := 1.0 if food.active else 0.36
		match food.kind:
			"mushroom":
				draw_texture_rect(RED_MUSHROOMS, Rect2(position - Vector2(28, 28), Vector2(56, 56)), false, Color(1, 1, 1, alpha))
			"watermelon":
				draw_texture_rect(ITEM_WATERMELON, Rect2(position - Vector2(32, 38), Vector2(64, 64)), false, Color(1, 1, 1, alpha))
			"berries", "apple", "nut":
				var layout := forage_sprite_layout(food.kind, position)
				draw_texture_rect_region(PLANT_SHEET, layout.destination, layout.source, Color(1, 1, 1, alpha))
		if not food.active:
			draw_string(UI_FONT, position + Vector2(-55, 42), ForageSystem.remaining_text(self, food), HORIZONTAL_ALIGNMENT_CENTER, 110, 12, Color("e7d6a3"))

## Выполняет операцию «рыбалки анимации кадра» и возвращает результат согласно контракту метода.
func fishing_animation_frame(frame_count: int, frame_ms: int = 140) -> int:
	return PresentationSystem.animation_frame(Time.get_ticks_msec(), frame_count, frame_ms)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_fishing_animations() -> void:
	var fish_frame := fishing_animation_frame(10, 130)
	draw_texture_rect_region(FISH_ANIMATION, Rect2(pond_position + Vector2(-24, -8), Vector2(48, 48)), Rect2(fish_frame * 16, 0, 16, 16))
	if state.fishing.phase == FishingSystem.PHASE_BITE:
		var splash_frame := fishing_animation_frame(18, 80)
		draw_texture_rect_region(SPLASH_ANIMATION, Rect2(pond_position + Vector2(-32, -32), Vector2(64, 64)), Rect2(splash_frame * 16, 0, 16, 16))

## Отрисовывает взрослые деревья, пни, саженцы, повреждения и прогресс повторного роста.
func draw_tree_nodes() -> void:
	if current_location != "overworld": return
	for tree in state.world.tree_nodes:
		var position: Vector2 = tree.position
		var stage: int = tree.stage
		var flash: float = tree.hit_flash
		if stage == 0:
			draw_rect(Rect2(position + Vector2(-18, 20), Vector2(36, 18)), Color("75492f"), true)
			draw_ellipse_stump(position + Vector2(0, 20))
		else:
			var size := Vector2(64, 64) if stage == 1 else (Vector2(128, 128) if stage == 2 else Vector2(192, 192))
			var anchor := Vector2(size.x * 0.5, size.y * 0.67)
			var tint := Color(1.0, 0.72, 0.62) if flash > 0.0 else Color.WHITE
			draw_texture_rect(FOREST_TREE, Rect2(position - anchor, size), false, tint)
		if stage < 3:
			var progress: float = TreeSystem.regrow_progress(tree)
			var bar := Rect2(position + Vector2(-34, 49), Vector2(68, 8))
			draw_rect(bar, Color("243b35")); draw_rect(Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2) * progress, bar.size.y - 2)), Color("70c66a"))
		if stage == 3 and int(tree.health) < TreeSystem.MAX_HEALTH:
			for heart in TreeSystem.MAX_HEALTH: draw_circle(position + Vector2(-14 + heart * 14, -68), 4, Color("df6657") if heart < int(tree.health) else Color("5b493e"))

## Рисует овальный срез пня как самостоятельный пиксельный элемент окружения.
func draw_ellipse_stump(center: Vector2) -> void:
	var points := PackedVector2Array()
	for step in 16: points.append(center + Vector2(cos(TAU * step / 16.0) * 20.0, sin(TAU * step / 16.0) * 8.0))
	draw_colored_polygon(points, Color("c48b52")); draw_polyline(points, Color("8d5b38"), 2.0)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_resource_nodes() -> void:
	for node in resource_nodes:
		if node.hits <= 0 or node.location != current_location:
			continue
		var is_crystal: bool = node.kind in ["crystal", "red_crystal", "green_crystal"]
		var texture: Texture2D = RESOURCE_CRYSTAL if is_crystal else RESOURCE_ROCK
		var tint := Color.WHITE
		if node.kind == "red_crystal": tint = Color("ef6872")
		elif node.kind == "green_crystal": tint = Color("6bdc83")
		draw_texture_rect(texture, Rect2(node.position - Vector2(28, 28), Vector2(56, 56)), false, tint)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_dropped_items() -> void:
	for item in dropped_items:
		if item_texture(item.kind):
			draw_item_icon(item.kind, Rect2(item.position - Vector2(22, 22), Vector2(44, 44)))
		else:
			draw_circle(item.position, 15, inventory_item_color(item.kind))

## Отрисовывает мира добычи по текущему состоянию игры.
func draw_world_loot() -> void:
	for container in world_loot_nodes:
		if container.location != current_location:
			continue
		var position: Vector2 = container.position.round()
		var alpha := 0.38 if container.opened else 1.0
		match container.kind:
			"chest", "pirate_chest":
				draw_rect(Rect2(position - Vector2(27, 16), Vector2(54, 34)), Color(0.35, 0.20, 0.10, alpha))
				draw_rect(Rect2(position - Vector2(24, 13), Vector2(48, 12)), Color(0.62, 0.36, 0.16, alpha))
				draw_rect(Rect2(position - Vector2(4, 4), Vector2(8, 13)), Color(0.93, 0.72, 0.25, alpha))
				if container.kind == "pirate_chest": draw_circle(position + Vector2(0,-2), 7, Color("d8d4c1", alpha))
				if container.opened:
					draw_line(position - Vector2(24, 16), position + Vector2(20, -32), Color(0.48, 0.27, 0.12, alpha), 8)
			"bone_pile":
				draw_texture_rect(BONE_PILE_TEXTURE, Rect2(position - Vector2(38, 38), Vector2(76, 76)), false, Color(1, 1, 1, alpha))
			"sack":
				draw_circle(position + Vector2(0, 5), 22, Color(0.62, 0.47, 0.27, alpha))
				draw_colored_polygon(PackedVector2Array([position + Vector2(-11,-10),position + Vector2(11,-10),position + Vector2(5,-25),position + Vector2(-5,-25)]), Color(0.76, 0.61, 0.37, alpha))
			"trash":
				draw_circle(position, 25, Color(0.26, 0.31, 0.27, alpha))
				draw_line(position - Vector2(18, 14), position + Vector2(17, 13), Color(0.58, 0.46, 0.31, alpha), 7)
				draw_circle(position + Vector2(10, -8), 8, Color(0.43, 0.49, 0.45, alpha))
		if container.opened:
			draw_string(UI_FONT, position + Vector2(-35, 38), LocaleSystem.ui("empty"), HORIZONTAL_ALIGNMENT_CENTER, 70, 12, Color(0.8, 0.8, 0.75, 0.55))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_enemy_nodes_and_gate() -> void:
	if not BuildingSystem.is_interior(current_location):
		draw_circle(world_gate_position, 38, Color(0.90, 0.72, 0.37, 0.28), false, 3)
		if player.distance_to(world_gate_position) < 185.0:
			draw_circle(world_gate_position, 42 + sin(Time.get_ticks_msec() / 180.0) * 4, Color("e6b85e"), false, 6)
			draw_string(UI_FONT, world_gate_position + Vector2(-75, 68), WorldSystem.name(WorldSystem.next_location(current_location)), HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color("fff0bd"))
	for enemy in enemy_nodes:
		if not AnimationSystem.enemy_is_visible(enemy) or enemy.location != current_location: continue
		var position: Vector2 = enemy.position
		AnimationRenderer.draw_enemy(self, enemy)
		if not enemy.alive: continue
		var sprite_height := 126.0 if enemy.kind in ["cave_guardian","drowned_captain"] else (104.0 if enemy.kind in ["undead","sea_ghost"] else 96.0)
		var bar_y := position.y - sprite_height * 0.72
		draw_string(UI_FONT, Vector2(position.x - 65, bar_y - 9), LocaleSystem.ui("enemy_level", [enemy.level]), HORIZONTAL_ALIGNMENT_CENTER, 130, 13, Color("ffd46a"))
		draw_rect(Rect2(Vector2(position.x - 31, bar_y), Vector2(62, 7)), Color("402d32"))
		draw_rect(Rect2(Vector2(position.x - 30, bar_y + 1), Vector2(60.0 * enemy.hp / float(enemy.max_hp), 5)), Color("dc554b"))
		draw_string(UI_FONT, position + Vector2(-65, 55), LocaleSystem.entity(enemy.kind), HORIZONTAL_ALIGNMENT_CENTER, 130, 14, Color("fff0bd"))


## Отрисовывает укоренённые растения-угрозы, их уровни и момент дистанционной атаки.
func draw_hazards() -> void:
	for hazard in hazard_nodes:
		if hazard.location != current_location:
			continue
		var column: int = EnvironmentHazardSystem.FAMILY_ORDER.find(hazard.kind)
		var rank: int = EnvironmentHazardSystem.visual_rank(hazard.level)
		var cell_size := Vector2(HAZARD_RANK_ATLAS.get_width() / 3.0, HAZARD_RANK_ATLAS.get_height() / 3.0)
		var source := Rect2(Vector2(column, rank) * cell_size, cell_size)
		var size := Vector2(108, 92) if hazard.kind == "poison_ivy" else (Vector2(104, 112) if hazard.kind == "thorn_bloom" else Vector2(100, 104))
		draw_living_atlas_sprite(HAZARD_RANK_ATLAS, source, hazard.position, size, hazard.pulse, false, float(column) * 1.2)
		var top_y: float = hazard.position.y - size.y * 0.72
		draw_string(UI_FONT, Vector2(hazard.position.x - 58, top_y), LocaleSystem.ui("enemy_level", [hazard.level]), HORIZONTAL_ALIGNMENT_CENTER, 116, 13, Color("ffd46a"))
		draw_string(UI_FONT, hazard.position + Vector2(-70, 56), LocaleSystem.entity(hazard.kind), HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color("e9f0c6"))
		if hazard.kind == "thorn_bloom" and hazard.cooldown > EnvironmentHazardSystem.TYPES.thorn_bloom.interval - 0.22:
			draw_line(hazard.position - Vector2(0, 24), player, Color(0.78, 0.95, 0.35, 0.72), 3.0)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func enemy_sprite_texture(kind: String) -> Texture2D:
	match kind:
		"plant": return PREDATOR_PLANT_SHEET
		"orc": return ORC_IDLE_SHEET
		"cave_guardian": return CAVE_GUARDIAN_TEXTURE
		"skeleton": return SKELETON_WARRIOR_TEXTURE
		"undead": return CURSED_KNIGHT_TEXTURE
	return null

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func enemy_direction_row(direction: Vector2) -> int:
	return PresentationSystem.enemy_direction_row(direction)

## Отрисовывает животных по текущему состоянию игры.
func draw_wildlife() -> void:
	for animal in wildlife_nodes:
		if not animal.alive or animal.location != current_location:
			continue
		var data: Dictionary = WildlifeSystem.TYPES[animal.kind]
		var position: Vector2 = animal.position.round()
		if animal.kind in ["bat", "lizard"]:
			var sprite_index := 0 if animal.kind == "bat" else 1
			var source_width := FANTASY_WILDLIFE_ATLAS.get_width() / 2.0
			var source := Rect2(float(sprite_index) * source_width, 0, source_width, FANTASY_WILDLIFE_ATLAS.get_height())
			var size := Vector2(88, 72) if animal.kind == "bat" else Vector2(92, 68)
			draw_living_atlas_sprite(FANTASY_WILDLIFE_ATLAS, source, position, size, animal.animation, true, float(sprite_index) * 1.3, animal.direction.x < -0.1)
		else:
			var texture: Texture2D = DEER_RUN_SHEET
			if animal.kind == "fox": texture = FOX_RUN_SHEET
			elif animal.kind == "boar": texture = BOAR_RUN_SHEET
			var row := 0
			if absf(animal.direction.x) > absf(animal.direction.y): row = 2 if animal.direction.x < 0.0 else 3
			elif animal.direction.y < 0.0: row = 1
			var frame: int = int(animal.animation * 9.0) % int(data.frames)
			draw_texture_rect_region(texture, Rect2(position - Vector2(32, 40), Vector2(64, 64)), Rect2(frame * 32, row * 32, 32, 32))
		if animal.hp < data.hp:
			draw_rect(Rect2(position - Vector2(25, 44), Vector2(50, 5)), Color("402d32"))
			draw_rect(Rect2(position - Vector2(24, 43), Vector2(48.0 * animal.hp / float(data.hp), 3)), Color("dc554b"))

## Отрисовывает пещеры мира по текущему состоянию игры.
func draw_cave_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("18232c"))
	for y in range(100, int(WORLD_SIZE.y), 230):
		for x in range(80, int(WORLD_SIZE.x), 260):
			draw_circle(Vector2(x + (y % 160), y), 4, Color("34434b"))
	draw_circle(cave_exit_position, 54, Color("0e151a"))
	draw_circle(cave_exit_position, 40, Color("b1e4d5"), false, 5)
	var crystal_positions := [Vector2(480, 250), Vector2(720, 600), Vector2(1040, 300), Vector2(1380, 720), Vector2(1720, 280), Vector2(2050, 620)]
	for crystal_position in crystal_positions:
		draw_texture_rect(CAVE_CRYSTAL, Rect2(crystal_position - Vector2(32, 32), Vector2(64, 64)), false)
		draw_circle(crystal_position, 42, Color(0.35, 0.95, 0.85, 0.12))
	draw_string(UI_FONT, Vector2(90, 100), LocaleSystem.location("cave").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("9ce9dd"))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func inventory_item_color(kind: String) -> Color:
	return InventorySystem.data(kind).color

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func item_texture(kind: String) -> Texture2D:
	return VisualAssetSystem.item_texture(kind)

## Возвращает короткий различимый знак для предмета, пока для него не создана собственная текстура.
func fallback_item_glyph(kind: String) -> String:
	var short_name: String = String(InventorySystem.data(kind).short).strip_edges()
	return short_name.left(2).to_upper() if not short_name.is_empty() else "?"

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_item_icon(kind: String, rect: Rect2) -> void:
	var texture := item_texture(kind)
	if VisualAssetSystem.draw_potion(self, kind, rect):
		pass
	elif texture:
		draw_texture_rect(texture, rect, false)
	elif VisualAssetSystem.draw_pirate_item(self, kind, rect):
		pass
	elif VisualAssetSystem.draw_eclipse_item(self, kind, rect):
		pass
	elif VisualAssetSystem.draw_inventory_item(self, kind, rect):
		pass
	else:
		var center := rect.get_center(); var radius := minf(rect.size.x, rect.size.y) * 0.38
		draw_circle(center, radius, inventory_item_color(kind)); draw_circle(center, radius, Color(0.95, 0.9, 0.72, 0.88), false, 2.0)
		draw_string(UI_FONT, center + Vector2(-rect.size.x * 0.32, 4), fallback_item_glyph(kind), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * 0.64, maxi(8, int(rect.size.y * 0.24)), Color("172b26"))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func interaction_position(interaction: String) -> Vector2:
	return PresentationSystem.interaction_position(self, interaction)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_interaction_highlight() -> void:
	var interaction := nearest_interaction()
	if interaction.is_empty():
		return
	var center := interaction_position(interaction)
	var radius := 24.0 + sin(Time.get_ticks_msec() / 180.0) * 1.5
	var color := Color(1.0, 0.85, 0.36, 0.82)
	var corner := 8.0
	# Четыре коротких угла читаются как выбор, но не закрывают сам предмет и окружение.
	for signs: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
		var point: Vector2 = center + signs * radius
		draw_line(point, point - Vector2(signs.x * corner, 0), color, 2.0)
		draw_line(point, point - Vector2(0, signs.y * corner), color, 2.0)

## Отрисовывает интерфейса по текущему состоянию игры.
func draw_ui() -> void:
	InterfaceRenderer.draw(self)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_discovery_card() -> void:
	if discovery_current.is_empty():
		return
	var card := discovery_card_rect()
	draw_texture_rect_region(InterfaceRenderer.CARD_ATLAS, card, InterfaceRenderer.CARD_DISCOVERY_SOURCE)
	draw_string(UI_FONT, card.position + Vector2(18, 25), LocaleSystem.ui("new_nearby"), HORIZONTAL_ALIGNMENT_LEFT, 190, 10, Color("f6dda1"))
	draw_string(UI_FONT, card.position + Vector2(218, 25), LocaleSystem.ui("hide"), HORIZONTAL_ALIGNMENT_RIGHT, 76, 9, Color("f6dda1"))
	draw_string(UI_FONT, card.position + Vector2(18, 53), discovery_current.title, HORIZONTAL_ALIGNMENT_LEFT, 274, 15, Color("4c3425"))
	draw_multiline_string(UI_FONT, card.position + Vector2(18, 73), discovery_current.text, HORIZONTAL_ALIGNMENT_LEFT, 274, 11, 2, Color("654930"))
	var ratio := clampf(discovery_timer / DiscoverySystem.CARD_DURATION, 0.0, 1.0)
	draw_rect(Rect2(card.position + Vector2(8, card.size.y - 7), Vector2((card.size.x - 16) * ratio, 3)), Color("f1ca5c"))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func discovery_card_rect() -> Rect2:
	return PresentationSystem.discovery_card_rect()

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_mission_tracker() -> void:
	var lines: Array[String] = PresentationSystem.quest_tracker_lines(self)
	if lines.is_empty():
		return
	var height := 30.0 + lines.size() * 22.0
	var tracker := Rect2(790, 108, 338, height)
	draw_texture_rect_region(InterfaceRenderer.CARD_ATLAS, tracker, InterfaceRenderer.CARD_QUEST_SOURCE)
	draw_string(UI_FONT, Vector2(820, 132), LocaleSystem.ui("quest_tracker"), HORIZONTAL_ALIGNMENT_LEFT, 276, 13, Color("5a3823"))
	for index in lines.size():
		draw_string(UI_FONT, Vector2(822, 156 + index * 22), "◆  " + lines[index], HORIZONTAL_ALIGNMENT_LEFT, 274, 11, Color("654930"))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_quest_log() -> void:
	draw_rect(Rect2(120, 62, 912, 524), Color("29251f"))
	draw_rect(Rect2(140, 82, 872, 484), Color("e6d3a4"))
	draw_rect(Rect2(140, 82, 872, 64), Color("5d4937"))
	draw_string(UI_FONT, Vector2(326, 125), LocaleSystem.ui("quest_log"), HORIZONTAL_ALIGNMENT_CENTER, 500, 28, Color("fff1c4"))
	var mission_ids: Array = QuestSystem.MISSIONS.keys()
	var page_count := maxi(1, ceili(float(mission_ids.size()) / 3.0))
	quest_log_page = clampi(quest_log_page, 0, page_count - 1)
	var row_y := 158.0
	for index in range(quest_log_page * 3, mini((quest_log_page + 1) * 3, mission_ids.size())):
		var mission_id: String = mission_ids[index]
		var mission: Dictionary = QuestSystem.mission_data(mission_id)
		var state := QuestSystem.mission_state(self, mission_id)
		var state_name: String = {QuestSystem.LOCKED:LocaleSystem.ui("locked"), QuestSystem.AVAILABLE:LocaleSystem.ui("available"), QuestSystem.ACTIVE:LocaleSystem.ui("active"), QuestSystem.COMPLETED:LocaleSystem.ui("completed")}[state]
		var fill := Color("d4c7a5") if state == QuestSystem.LOCKED else (Color("c9e2bd") if state == QuestSystem.COMPLETED else Color("fff0bd"))
		draw_rect(Rect2(170, row_y, 812, 116), fill)
		draw_string(UI_FONT, Vector2(190, row_y + 25), "%s • %s" % [mission.type, mission.title], HORIZONTAL_ALIGNMENT_LEFT, 520, 18, Color("493b2f"))
		draw_string(UI_FONT, Vector2(730, row_y + 25), state_name, HORIZONTAL_ALIGNMENT_RIGHT, 225, 13, Color("50704e"))
		draw_string(UI_FONT, Vector2(190, row_y + 50), mission.description, HORIZONTAL_ALIGNMENT_LEFT, 745, 13, Color("493b2f"))
		draw_string(UI_FONT, Vector2(190, row_y + 76), LocaleSystem.ui("objective", [QuestSystem.objective_text(self, mission_id)]), HORIZONTAL_ALIGNMENT_LEFT, 520, 13, Color("6b5038"))
		var reward_text: String = LocaleSystem.ui("reward", [mission.coins, mission.xp, inventory_item_name(mission.reward_item), mission.reward_count])
		if int(mission.get("skill_points", 0)) > 0: reward_text += " • %s" % LocaleSystem.ui("reward_skill_points", [mission.skill_points])
		draw_string(UI_FONT, Vector2(190, row_y + 99), reward_text, HORIZONTAL_ALIGNMENT_LEFT, 720, 12, Color("49704d"))
		row_y += 126.0
	draw_rect(InterfaceRenderer.QUEST_PREV, Color("795d3e")); draw_rect(InterfaceRenderer.QUEST_NEXT, Color("795d3e"))
	draw_string(UI_FONT, Vector2(180, 550), "←", HORIZONTAL_ALIGNMENT_CENTER, 34, 20, Color("fff0bd")); draw_string(UI_FONT, Vector2(632, 550), "→", HORIZONTAL_ALIGNMENT_CENTER, 34, 20, Color("fff0bd"))
	draw_string(UI_FONT, Vector2(228, 550), LocaleSystem.ui("quest_page", [quest_log_page + 1, page_count]), HORIZONTAL_ALIGNMENT_LEFT, 390, 13, Color("493b2f"))
	draw_string(UI_FONT, Vector2(690, 550), LocaleSystem.ui("quest_close"), HORIZONTAL_ALIGNMENT_RIGHT, 290, 13, Color("493b2f"))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_skill_menu() -> void:
	draw_rect(Rect2(92, 48, 968, 552), Color("25232c"))
	draw_rect(Rect2(112, 68, 928, 512), Color("e4d4a9"))
	draw_rect(Rect2(112, 68, 928, 70), Color("493e61"))
	draw_string(UI_FONT, Vector2(180, 108), LocaleSystem.ui("character"), HORIZONTAL_ALIGNMENT_LEFT, 510, 28, Color("fff2c7"))
	draw_string(UI_FONT, Vector2(735, 106), LocaleSystem.ui("level_points", [player_level, skill_points]), HORIZONTAL_ALIGNMENT_RIGHT, 270, 18, Color("f5cf6a"))
	for index in SkillSystem.SKILLS.size():
		var skill: Dictionary = SkillSystem.SKILLS[index]
		var column := index % 3
		var row := index / 3
		var box := Rect2(134 + column * 304, 154 + row * 128, 286, 112)
		var selected := index == skill_menu_selected
		draw_rect(box, Color("efc75f") if selected else Color("6c5c48"))
		draw_rect(box.grow(-4), Color("fff0bd") if selected else Color("f0dfb5"))
		draw_string(UI_FONT, box.position + Vector2(12, 28), "%s  %s" % [skill.icon, LocaleSystem.skill(skill.id)], HORIZONTAL_ALIGNMENT_LEFT, 184, 16, Color("43382f"))
		draw_string(UI_FONT, box.position + Vector2(196, 28), LocaleSystem.ui("rank", [SkillSystem.skill(self, skill.id)]), HORIZONTAL_ALIGNMENT_RIGHT, 76, 12, Color("4c674c"))
		draw_multiline_string(UI_FONT, box.position + Vector2(12, 52), LocaleSystem.skill(skill.id, true), HORIZONTAL_ALIGNMENT_LEFT, 260, 11, 2, Color("665746"))
		if skill.get("profession", false):
			var needed := SkillSystem.xp_to_next_skill_rank(SkillSystem.skill(self, skill.id))
			var ratio := clampf(float(skill_xp.get(skill.id, 0)) / float(needed), 0.0, 1.0)
			var bar := Rect2(box.position + Vector2(12, 96), Vector2(260, 6))
			draw_rect(bar, Color("766751"))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("6da86d"))
	draw_string(UI_FONT, Vector2(220, 556), LocaleSystem.ui("skill_help"), HORIZONTAL_ALIGNMENT_CENTER, 712, 15, Color("493b2f"))

## Отрисовывает крафта окна по текущему состоянию игры.
func draw_crafting_window() -> void:
	draw_rect(Rect2(170, 70, 812, 510), Color("33271f"))
	draw_rect(Rect2(190, 90, 772, 470), Color("e8cf96"))
	draw_rect(Rect2(190, 90, 772, 64), Color("744b32"))
	draw_string(UI_FONT, Vector2(326, 132), LocaleSystem.ui("workbench"), HORIZONTAL_ALIGNMENT_CENTER, 500, 28, Color("fff1c4"))
	var first_recipe := clampi(crafting_selected - 4, 0, maxi(0, CraftingSystem.RECIPES.size() - 9))
	for index in range(first_recipe, mini(first_recipe + 9, CraftingSystem.RECIPES.size())):
		var recipe: Dictionary = CraftingSystem.RECIPES[index]
		var row := Rect2(220, 164 + (index - first_recipe) * 43, 712, 38)
		draw_rect(row, Color("f2c96f") if index == crafting_selected else Color("fff0bd"))
		draw_string(UI_FONT, row.position + Vector2(18, 25), inventory_item_name(recipe.output), HORIZONTAL_ALIGNMENT_LEFT, 230, 15, Color("493b2f"))
		draw_string(UI_FONT, row.position + Vector2(250, 25), CraftingSystem.ingredients_text(self, recipe), HORIZONTAL_ALIGNMENT_LEFT, 440, 12, Color("49704d") if CraftingSystem.can_craft(self, recipe) else Color("a64d45"))
	draw_string(UI_FONT, Vector2(220, 535), LocaleSystem.ui("craft_help"), HORIZONTAL_ALIGNMENT_CENTER, 712, 16, Color("493b2f"))

## Отрисовывает магазина по текущему состоянию игры.
func draw_shop() -> void:
	# Отдельная сцена-интерьер поверх игрового мира.
	draw_rect(Rect2(112, 70, 928, 520), Color("33271f"))
	draw_rect(Rect2(132, 90, 888, 480), Color("f0d49a"))
	for plank_y in range(108, 560, 32):
		draw_line(Vector2(132, plank_y), Vector2(1020, plank_y), Color("d8b878"), 2)
	draw_rect(Rect2(132, 90, 888, 72), Color("744b32"))
	draw_string(UI_FONT, Vector2(576, 138), LocaleSystem.ui("shop"), HORIZONTAL_ALIGNMENT_CENTER, 500, 30, Color("fff1c4"))
	# Прилавок и декоративные припасы из набора.
	draw_rect(Rect2(158, 190, 210, 302), Color("9b663d"))
	draw_texture_rect_region(SUPPLY_SHEET, Rect2(175, 208, 176, 136), Rect2(0, 0, 176, 136))
	draw_string(UI_FONT, Vector2(174, 470), LocaleSystem.ui("grandma_stock"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff1c4"))
	# Таблица товаров.
	var table := Rect2(405, 174, 570, 340)
	draw_rect(table, Color("fff4cf"))
	draw_rect(Rect2(table.position, Vector2(table.size.x, 42)), Color("53704b"))
	draw_string(UI_FONT, table.position + Vector2(62, 28), LocaleSystem.ui("product"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(UI_FONT, table.position + Vector2(350, 28), LocaleSystem.ui("buy"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(UI_FONT, table.position + Vector2(455, 28), LocaleSystem.ui("sell"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var first_product := clampi(shop_selected - 4, 0, maxi(0, shop_products.size() - 9))
	for i in range(first_product, mini(first_product + 9, shop_products.size())):
		var product: Dictionary = shop_products[i]
		var row := Rect2(table.position + Vector2(0, 42 + (i - first_product) * 32), Vector2(table.size.x, 32))
		draw_rect(row, Color("f2c96f") if i == shop_selected else Color("f8e8b5"))
		draw_rect(row, Color("76543c"), false, 2)
		if product.has("icon"):
			draw_texture_rect_region(SUPPLY_SHEET, Rect2(row.position + Vector2(15, 3), Vector2(24, 26)), product.icon)
		else:
			draw_item_icon(product.kind, Rect2(row.position + Vector2(13, 3), Vector2(26, 26)))
		draw_string(UI_FONT, row.position + Vector2(48, 22), inventory_item_name(product.kind), HORIZONTAL_ALIGNMENT_LEFT, 295, 13, Color("3d3428"))
		draw_string(UI_FONT, row.position + Vector2(370, 22), ("%d 🪙" % product.buy) if product.buy > 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("3d3428"))
		draw_string(UI_FONT, row.position + Vector2(478, 22), ("%d 🪙" % product.sell) if product.sell > 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("3d3428"))
	draw_string(UI_FONT, Vector2(690, 535), LocaleSystem.ui("shop_help"), HORIZONTAL_ALIGNMENT_CENTER, 560, 16, Color("493b2f"))

## Отрисовывает две колонки домашнего сундука и команды переноса предметов.
func draw_storage_window() -> void:
	draw_rect(Rect2(54, 64, 1044, 510), Color("17251f"))
	draw_rect(Rect2(72, 82, 1008, 474), Color("d7bd82"))
	draw_rect(Rect2(72, 82, 1008, 58), Color("70472d"))
	draw_string(UI_FONT, Vector2(326, 121), LocaleSystem.ui("home_storage"), HORIZONTAL_ALIGNMENT_CENTER, 500, 26, Color("fff1c4"))
	draw_string(UI_FONT, Vector2(96, 158), LocaleSystem.ui("backpack_column"), HORIZONTAL_ALIGNMENT_LEFT, 430, 16, Color("493b2f"))
	draw_string(UI_FONT, Vector2(626, 158), LocaleSystem.ui("chest_column"), HORIZONTAL_ALIGNMENT_LEFT, 430, 16, Color("493b2f"))
	draw_storage_column(StorageSystem.inventory_items(self), 0, Rect2(96, 168, 430, 320))
	draw_storage_column(StorageSystem.stored_items(self), 1, Rect2(626, 168, 430, 320))
	draw_rect(InterfaceRenderer.STORAGE_TRANSFER_ONE, Color("6b8f60"))
	draw_rect(InterfaceRenderer.STORAGE_TRANSFER_ALL, Color("8f7045"))
	draw_string(UI_FONT, InterfaceRenderer.STORAGE_TRANSFER_ONE.position + Vector2(4, 24), LocaleSystem.ui("transfer_one"), HORIZONTAL_ALIGNMENT_CENTER, 108, 12, Color.WHITE)
	draw_string(UI_FONT, InterfaceRenderer.STORAGE_TRANSFER_ALL.position + Vector2(4, 24), LocaleSystem.ui("transfer_all"), HORIZONTAL_ALIGNMENT_CENTER, 108, 12, Color.WHITE)
	draw_string(UI_FONT, Vector2(96, 548), LocaleSystem.ui("storage_help"), HORIZONTAL_ALIGNMENT_CENTER, 960, 13, Color("493b2f"))

## Отрисовывает одну прокручиваемую колонку предметов домашнего сундука.
func draw_storage_column(items: Array[String], side: int, rect: Rect2) -> void:
	draw_rect(rect, Color("fff0bd"))
	var selected := storage_selected if storage_side == side else 0
	var start := StorageSystem.visible_start(selected, items.size())
	for visible_index in StorageSystem.MAX_VISIBLE_ROWS:
		var index := start + visible_index
		var row := Rect2(rect.position + Vector2(0, visible_index * 40), Vector2(rect.size.x, 40))
		var active := storage_side == side and index == storage_selected
		draw_rect(row, Color("efc766") if active else (Color("f3dfaa") if visible_index % 2 == 0 else Color("ead39a")))
		if index >= items.size(): continue
		var kind: String = items[index]
		draw_item_icon(kind, Rect2(row.position + Vector2(8, 5), Vector2(30, 30)))
		draw_string(UI_FONT, row.position + Vector2(48, 25), inventory_item_name(kind), HORIZONTAL_ALIGNMENT_LEFT, 290, 13, Color("3d3428"))
		var amount := inventory_item_count(kind) if side == 0 else state.storage.count(kind)
		draw_string(UI_FONT, row.position + Vector2(350, 25), "×%d" % amount, HORIZONTAL_ALIGNMENT_RIGHT, 60, 13, Color("3d3428"))

## Отрисовывает список постоянных улучшений кузницы с уровнями и стоимостью.
func draw_forge_window() -> void:
	draw_rect(Rect2(120, 64, 912, 520), Color("241d1a"))
	draw_rect(Rect2(142, 84, 868, 478), Color("c7a46d"))
	draw_rect(Rect2(142, 84, 868, 58), Color("563b32"))
	draw_string(UI_FONT, Vector2(326, 123), LocaleSystem.ui("forge_title"), HORIZONTAL_ALIGNMENT_CENTER, 500, 26, Color("fff1c4"))
	for index in ForgeSystem.UPGRADES.size():
		var upgrade: Dictionary = ForgeSystem.UPGRADES[index]
		var row := Rect2(164, 154 + index * 44, 824, 40)
		var current_level := ForgeSystem.level(self, upgrade.kind)
		draw_rect(row, Color("e9c36f") if index == forge_selected else Color("ecd8a6"))
		draw_item_icon(upgrade.kind, Rect2(row.position + Vector2(7, 5), Vector2(30, 30)))
		draw_string(UI_FONT, row.position + Vector2(48, 26), inventory_item_name(upgrade.kind), HORIZONTAL_ALIGNMENT_LEFT, 230, 14, Color("3d3428"))
		draw_string(UI_FONT, row.position + Vector2(280, 26), LocaleSystem.ui("upgrade_level", [current_level, ForgeSystem.MAX_UPGRADE_LEVEL]), HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color("5b4934"))
		var cost := LocaleSystem.ui("upgrade_max") if current_level >= ForgeSystem.MAX_UPGRADE_LEVEL else ForgeSystem.cost_text(self, upgrade)
		draw_string(UI_FONT, row.position + Vector2(408, 26), cost, HORIZONTAL_ALIGNMENT_LEFT, 400, 11, Color("49704d") if ForgeSystem.can_upgrade(self, index) else Color("a64d45"))
		var durability: int = int(state.inventory.durability.get(upgrade.kind, state.inventory.durability.get("sword", 100) if upgrade.kind == "sword" else -1))
		if durability >= 0: draw_string(UI_FONT, row.position + Vector2(690, 26), "◆ %d%%" % durability, HORIZONTAL_ALIGNMENT_RIGHT, 110, 11, Color("49704d") if durability > 20 else Color("a64d45"))
	draw_string(UI_FONT, Vector2(164, 552), "%s • R / X — ремонт" % LocaleSystem.ui("forge_help"), HORIZONTAL_ALIGNMENT_CENTER, 824, 13, Color("493b2f"))
