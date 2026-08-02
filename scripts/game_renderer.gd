extends "res://scripts/game_context.gd"

func _draw() -> void:
	RenderSystem.draw(self)

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
		var start_rect := Rect2(382, 526, 388, 82)
		draw_rect(start_rect, Color(0.06, 0.13, 0.11, 0.80))
		draw_rect(start_rect.grow(-4), Color(0.18, 0.34, 0.25, 0.88))
		draw_rect(start_rect.grow(-8), Color(0.08, 0.18, 0.14, 0.93))
		draw_string(UI_FONT, Vector2(396, 563), LocaleSystem.ui("press_any"), HORIZONTAL_ALIGNMENT_CENTER, 360, 23, Color("ffe5a3"))
		draw_string(UI_FONT, Vector2(396, 591), LocaleSystem.ui("title_controls"), HORIZONTAL_ALIGNMENT_CENTER, 360, 14, Color(1, 1, 1, pulse))

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

func draw_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("7fad5c"))
	# Редкие крупные кластеры вместо ~5000 отдельных draw calls каждый кадр.
	for y in range(150, int(WORLD_SIZE.y), 190):
		for x in range(70 + (y % 140), int(WORLD_SIZE.x), 210):
			draw_circle(Vector2(x, y), 3.0, Color("99bd6a"))
			draw_line(Vector2(x - 6, y + 7), Vector2(x, y - 2), Color("668f4b"), 2)
			draw_line(Vector2(x + 6, y + 7), Vector2(x, y - 2), Color("668f4b"), 2)
	# river
	draw_rect(Rect2(0, 860, WORLD_SIZE.x, 340), Color("4f9fb0"))
	for x in range(0, int(WORLD_SIZE.x), 70): draw_line(Vector2(x, 900), Vector2(x + 34, 900), Color("83c9c5"), 3)
	# house and bed marker
	draw_rect(Rect2(54, 130, 190, 150), Color("e5c478"))
	draw_colored_polygon(PackedVector2Array([Vector2(38,145), Vector2(149,72), Vector2(260,145)]), Color("9c5338"))
	draw_rect(Rect2(128, 216, 43, 64), Color("6b4328"))
	draw_string(UI_FONT, Vector2(66, 308), LocaleSystem.ui("home"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# shop
	draw_rect(Rect2(910, 194, 128, 98), Color("f3d88e"))
	draw_rect(Rect2(895, 175, 158, 30), Color("d66b45"))
	draw_string(UI_FONT, Vector2(913, 238), LocaleSystem.ui("seeds_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("55382b"))
	draw_string(UI_FONT, Vector2(905, 320), LocaleSystem.ui("shop_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# Несколько стадий плодовых деревьев из бесплатного sprite sheet.
	draw_texture_rect_region(PLANT_SHEET, Rect2(270, 126, 290, 90), Rect2(94, 0, 290, 90))
	# selling crate
	draw_rect(Rect2(790, 392, 60, 54), Color("9c633b"))
	for i in 3: draw_line(Vector2(794, 402 + i * 15), Vector2(846, 402 + i * 15), Color("d09755"), 4)
	draw_string(UI_FONT, Vector2(753, 473), LocaleSystem.ui("sell_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))

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

func draw_player() -> void:
	AnimationRenderer.draw_player(self)

func draw_rpg_world() -> void:
	# Бабушка и верстак.
	draw_circle(npc_position - Vector2(0, 15), 13, Color("e7b68b"))
	draw_rect(Rect2(npc_position - Vector2(15, 2), Vector2(30, 35)), Color("854d6f"))
	draw_string(UI_FONT, npc_position + Vector2(-40, 55), LocaleSystem.entity("grandmother"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("293c2f"))
	draw_mission_npc(guild_master_position, LocaleSystem.quest("story_relic", "giver"), "story_relic", Color("496b8c"))
	draw_mission_npc(herbalist_position, LocaleSystem.quest("side_seed", "giver"), "side_seed", Color("568255"))
	draw_rect(Rect2(workbench_position - Vector2(32, 20), Vector2(64, 44)), Color("865334"))
	draw_line(workbench_position - Vector2(25, 8), workbench_position + Vector2(25, -8), Color("d09a59"), 5)
	draw_string(UI_FONT, workbench_position + Vector2(-45, 45), LocaleSystem.entity("workbench"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("293c2f"))
	if AnimationRenderer.draw_slime(self):
		if slime_alive:
			draw_rect(Rect2(slime_position + Vector2(-28, -50), Vector2(56, 7)), Color("402d32"))
			draw_rect(Rect2(slime_position + Vector2(-27, -49), Vector2(54.0 * slime_hp / 3.0, 5)), Color("dc554b"))
	elif loot_available:
		draw_circle(slime_position, 13, Color("78d6a5"))
		draw_circle(slime_position - Vector2(4, 4), 4, Color("baf1c8"))
	# Вход в отдельную пещерную локацию.
	draw_circle(cave_entrance_position, 52, Color("283a43"))
	draw_circle(cave_entrance_position, 38 + sin(Time.get_ticks_msec() / 170.0) * 4, Color("66d5cf"), false, 6)
	draw_string(UI_FONT, cave_entrance_position + Vector2(-58, 78), LocaleSystem.location("cave"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7fff4"))

func draw_mission_npc(position: Vector2, npc_name: String, mission_id: String, color: Color) -> void:
	draw_circle(position - Vector2(0, 16), 13, Color("e6b38a"))
	draw_rect(Rect2(position - Vector2(16, 2), Vector2(32, 38)), color)
	draw_string(UI_FONT, position + Vector2(-62, 58), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 124, 15, Color("293c2f"))
	var state: String = mission_states.get(mission_id, QuestSystem.AVAILABLE)
	var marker := "!" if state == QuestSystem.AVAILABLE else ("✓" if state == QuestSystem.COMPLETED else "?")
	draw_circle(position - Vector2(0, 62), 16, Color("f1ca5c") if state != QuestSystem.COMPLETED else Color("70bd78"))
	draw_string(UI_FONT, position + Vector2(-8, -56), marker, HORIZONTAL_ALIGNMENT_CENTER, 16, 20, Color("3b3225"))

func forage_sprite_layout(kind: String, position: Vector2) -> Dictionary:
	return PresentationSystem.forage_sprite_layout(FORAGE_SPRITES, kind, position)

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
		if food.active:
			draw_circle(position, 30 + sin(Time.get_ticks_msec() / 170.0) * 3, Color(1.0, 0.88, 0.32, 0.24), false, 3)
		else:
			draw_string(UI_FONT, position + Vector2(-55, 42), ForageSystem.remaining_text(self, food), HORIZONTAL_ALIGNMENT_CENTER, 110, 12, Color("e7d6a3"))

func fishing_animation_frame(frame_count: int, frame_ms: int = 140) -> int:
	return PresentationSystem.animation_frame(Time.get_ticks_msec(), frame_count, frame_ms)

func draw_fishing_animations() -> void:
	var water_frame := fishing_animation_frame(32, 180)
	draw_texture_rect_region(WATER_ANIMATION, Rect2(0, 860, WORLD_SIZE.x, 340), Rect2(water_frame * 16, 0, 16, 16), Color(1,1,1,0.32))
	var fish_frame := fishing_animation_frame(10, 130)
	draw_texture_rect_region(FISH_ANIMATION, Rect2(pond_position + Vector2(-24, -8), Vector2(48, 48)), Rect2(fish_frame * 16, 0, 16, 16))
	if fishing_state == "ready":
		var splash_frame := fishing_animation_frame(18, 80)
		draw_texture_rect_region(SPLASH_ANIMATION, Rect2(pond_position + Vector2(-32, -32), Vector2(64, 64)), Rect2(splash_frame * 16, 0, 16, 16))

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

func draw_dropped_items() -> void:
	for item in dropped_items:
		if item_texture(item.kind):
			draw_item_icon(item.kind, Rect2(item.position - Vector2(22, 22), Vector2(44, 44)))
		else:
			draw_circle(item.position, 15, inventory_item_color(item.kind))
		draw_circle(item.position, 23 + sin(Time.get_ticks_msec() / 150.0) * 3, Color("fff0a8"), false, 3)
		draw_string(UI_FONT, item.position + Vector2(-55, 42), inventory_item_name(item.kind), HORIZONTAL_ALIGNMENT_CENTER, 110, 13, Color("fff4cf"))

func draw_world_loot() -> void:
	for container in world_loot_nodes:
		if container.location != current_location:
			continue
		var position: Vector2 = container.position.round()
		var alpha := 0.38 if container.opened else 1.0
		match container.kind:
			"chest":
				draw_rect(Rect2(position - Vector2(27, 16), Vector2(54, 34)), Color(0.35, 0.20, 0.10, alpha))
				draw_rect(Rect2(position - Vector2(24, 13), Vector2(48, 12)), Color(0.62, 0.36, 0.16, alpha))
				draw_rect(Rect2(position - Vector2(4, 4), Vector2(8, 13)), Color(0.93, 0.72, 0.25, alpha))
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
		if not container.opened:
			var pulse := 34.0 + sin(Time.get_ticks_msec() / 180.0 + float(container.id)) * 3.0
			draw_circle(position, pulse, Color(1.0, 0.82, 0.30, 0.35), false, 3)
		else:
			draw_string(UI_FONT, position + Vector2(-35, 38), LocaleSystem.ui("empty"), HORIZONTAL_ALIGNMENT_CENTER, 70, 12, Color(0.8, 0.8, 0.75, 0.55))

func draw_enemy_nodes_and_gate() -> void:
	draw_circle(world_gate_position, 42 + sin(Time.get_ticks_msec() / 180.0) * 4, Color("e6b85e"), false, 6)
	draw_string(UI_FONT, world_gate_position + Vector2(-75, 68), WorldSystem.name(WorldSystem.next_location(current_location)), HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color("fff0bd"))
	for enemy in enemy_nodes:
		if not AnimationSystem.enemy_is_visible(enemy) or enemy.location != current_location: continue
		var data: Dictionary = CombatSystem.TYPES[enemy.kind]
		var position: Vector2 = enemy.position
		AnimationRenderer.draw_enemy(self, enemy)
		if not enemy.alive: continue
		draw_rect(Rect2(position - Vector2(31, 48), Vector2(62, 7)), Color("402d32"))
		draw_rect(Rect2(position - Vector2(30, 47), Vector2(60.0 * enemy.hp / float(data.hp), 5)), Color("dc554b"))
		draw_string(UI_FONT, position + Vector2(-65, 55), LocaleSystem.entity(enemy.kind), HORIZONTAL_ALIGNMENT_CENTER, 130, 14, Color("fff0bd"))

func enemy_sprite_texture(kind: String) -> Texture2D:
	match kind:
		"plant": return PREDATOR_PLANT_SHEET
		"orc": return ORC_IDLE_SHEET
		"cave_guardian": return CAVE_GUARDIAN_TEXTURE
		"skeleton": return SKELETON_WARRIOR_TEXTURE
		"undead": return CURSED_KNIGHT_TEXTURE
	return null

func enemy_direction_row(direction: Vector2) -> int:
	return PresentationSystem.enemy_direction_row(direction)

func draw_wildlife() -> void:
	for animal in wildlife_nodes:
		if not animal.alive or animal.location != current_location:
			continue
		var data: Dictionary = WildlifeSystem.TYPES[animal.kind]
		var position: Vector2 = animal.position.round()
		if animal.kind == "bat":
			var flap := 10.0 + sin(animal.animation * 14.0) * 8.0
			draw_colored_polygon(PackedVector2Array([position, position + Vector2(-28, -flap), position + Vector2(-18, 12)]), Color("6f6484"))
			draw_colored_polygon(PackedVector2Array([position, position + Vector2(28, -flap), position + Vector2(18, 12)]), Color("6f6484"))
			draw_circle(position, 10, Color("40374e"))
			draw_circle(position + Vector2(-4, -2), 2, Color("e78a70"))
			draw_circle(position + Vector2(4, -2), 2, Color("e78a70"))
		elif animal.kind == "lizard":
			var bob := sin(animal.animation * 7.0) * 2.0
			draw_texture_rect(MEADOW_LIZARD, Rect2(position - Vector2(48, 34 - bob), Vector2(96, 64)), false)
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

func inventory_item_color(kind: String) -> Color:
	return InventorySystem.data(kind).color

func item_texture(kind: String) -> Texture2D:
	match kind:
		"iron_helmet": return ITEM_HELMET
		"guardian_armor": return ITEM_ARMOR
		"travel_boots": return ITEM_BOOTS
		"crystal_ring": return ITEM_DIAMOND
		"orange": return ITEM_ORANGE
		"healing_potion": return ITEM_HEALING_POTION
		"oak_shield": return ITEM_OAK_SHIELD
		"watermelon": return ITEM_WATERMELON_SLICE
	return null

func draw_item_icon(kind: String, rect: Rect2) -> void:
	var texture := item_texture(kind)
	if texture:
		draw_texture_rect(texture, rect, false)
	else:
		draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.34, inventory_item_color(kind))

func interaction_position(interaction: String) -> Vector2:
	return PresentationSystem.interaction_position(self, interaction)

func draw_interaction_highlight() -> void:
	var interaction := nearest_interaction()
	if interaction.is_empty():
		return
	var center := interaction_position(interaction)
	var pulse := 34.0 + sin(Time.get_ticks_msec() / 130.0) * 4.0
	draw_circle(center, pulse, Color("ffe36e"), false, 4.0)
	draw_string(UI_FONT, center + Vector2(-45, -48), LocaleSystem.ui("action"), HORIZONTAL_ALIGNMENT_CENTER, 90, 16, Color("fff4bd"))

func draw_ui() -> void:
	draw_rect(Rect2(0, 0, 1152, 106), Color("182f2b"))
	var hours := floori(game_minutes / 60.0)
	var minutes := int(game_minutes) % 60
	draw_string(UI_FONT, Vector2(24, 34), LocaleSystem.ui("day", [day, hours, minutes]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe39d"))
	draw_string(UI_FONT, Vector2(24, 68), LocaleSystem.ui("resources", [energy, coins, seeds, carrots]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_rect(Rect2(830, 14, 145, 36), Color("4d6659"))
	var skill_button_text := LocaleSystem.ui("skills") if skill_points == 0 else "%s (%d)" % [LocaleSystem.ui("skills"), skill_points]
	draw_string(UI_FONT, Vector2(840, 38), skill_button_text, HORIZONTAL_ALIGNMENT_CENTER, 125, 14, Color("fff0bd"))
	draw_rect(Rect2(990, 14, 145, 36), Color("4d6659"))
	draw_string(UI_FONT, Vector2(1000, 38), LocaleSystem.ui("quests"), HORIZONTAL_ALIGNMENT_CENTER, 125, 14, Color("fff0bd"))
	draw_player_status_bars()
	draw_string(UI_FONT, Vector2(390, 68), "Слизь %d  Камень %d  Кристалл %d  Рыба %d  Оружие: %s" % [slime_gel, stone, crystals, fish, equipped_weapon], HORIZONTAL_ALIGNMENT_LEFT, 740, 13, Color("bde8d2"))
	if fishing_state == "casting":
		draw_string(UI_FONT, Vector2(576, 205), "Поплавок... %.1f" % maxf(fishing_timer, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 260, 20, Color("d7f6ff"))
	elif fishing_state == "ready":
		draw_circle(Vector2(576, 195), 22 + sin(Time.get_ticks_msec() / 100.0) * 3, Color("ffdc5c"))
		draw_string(UI_FONT, Vector2(576, 202), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 24, Color("5b4526"))
	draw_rect(Rect2(190, 510, 772, 34), Color("182f2b"))
	draw_string(UI_FONT, Vector2(211, 533), message, HORIZONTAL_ALIGNMENT_CENTER, 730, 17, Color("fff4cf"))
	draw_hotbar()
	draw_mission_tracker()
	if tutorial_visible and tutorial_step < tutorial_steps.size():
		draw_rect(Rect2(18, 108, 420, 68), Color("263c36"))
		draw_string(UI_FONT, Vector2(34, 132), LocaleSystem.ui("tutorial", [tutorial_step + 1, tutorial_steps.size()]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9ed6b3"))
		draw_string(UI_FONT, Vector2(34, 160), LocaleSystem.tutorial(tutorial_steps[tutorial_step].event), HORIZONTAL_ALIGNMENT_LEFT, 385, 17, Color.WHITE)
	draw_discovery_card()
	if shop_open:
		draw_shop()
	if inventory_open:
		draw_inventory()
	if crafting_open:
		draw_crafting_window()
	if quest_log_open:
		draw_quest_log()
	if skill_menu_open:
		draw_skill_menu()

func draw_discovery_card() -> void:
	if discovery_current.is_empty():
		return
	var card := discovery_card_rect()
	draw_rect(card, Color(0.08, 0.12, 0.11, 0.96))
	draw_rect(card.grow(-4), Color("355347"))
	draw_rect(Rect2(card.position + Vector2(4, 4), Vector2(card.size.x - 8, 28)), Color("d5ad55"))
	draw_string(UI_FONT, card.position + Vector2(12, 23), LocaleSystem.ui("new_nearby"), HORIZONTAL_ALIGNMENT_LEFT, 205, 11, Color("352c21"))
	draw_string(UI_FONT, card.position + Vector2(220, 23), LocaleSystem.ui("hide"), HORIZONTAL_ALIGNMENT_RIGHT, 76, 11, Color("352c21"))
	draw_string(UI_FONT, card.position + Vector2(12, 51), discovery_current.title, HORIZONTAL_ALIGNMENT_LEFT, 282, 17, Color("fff0bd"))
	draw_multiline_string(UI_FONT, card.position + Vector2(12, 72), discovery_current.text, HORIZONTAL_ALIGNMENT_LEFT, 282, 12, 2, Color.WHITE)
	var ratio := clampf(discovery_timer / DiscoverySystem.CARD_DURATION, 0.0, 1.0)
	draw_rect(Rect2(card.position + Vector2(8, card.size.y - 7), Vector2((card.size.x - 16) * ratio, 3)), Color("f1ca5c"))

func discovery_card_rect() -> Rect2:
	return PresentationSystem.discovery_card_rect()

func draw_mission_tracker() -> void:
	var lines: Array[String] = []
	if quest_active:
		lines.append("Бабушкина морковь: %d/10" % mini(carrots, 10))
	for mission_id in QuestSystem.MISSIONS:
		if mission_states.get(mission_id) == QuestSystem.ACTIVE:
			lines.append("%s — %s" % [QuestSystem.mission_data(mission_id).title, QuestSystem.objective_text(self, mission_id)])
	if lines.is_empty():
		return
	var height := 30.0 + lines.size() * 22.0
	draw_rect(Rect2(790, 108, 338, height), Color(0.10, 0.18, 0.16, 0.92))
	draw_string(UI_FONT, Vector2(804, 130), LocaleSystem.ui("quest_tracker"), HORIZONTAL_ALIGNMENT_LEFT, 310, 15, Color("f1ca5c"))
	for index in lines.size():
		draw_string(UI_FONT, Vector2(804, 153 + index * 22), lines[index], HORIZONTAL_ALIGNMENT_LEFT, 310, 14, Color("fff4cf"))

func draw_quest_log() -> void:
	draw_rect(Rect2(120, 62, 912, 524), Color("29251f"))
	draw_rect(Rect2(140, 82, 872, 484), Color("e6d3a4"))
	draw_rect(Rect2(140, 82, 872, 64), Color("5d4937"))
	draw_string(UI_FONT, Vector2(326, 125), LocaleSystem.ui("quest_log"), HORIZONTAL_ALIGNMENT_CENTER, 500, 28, Color("fff1c4"))
	var row_y := 172.0
	for mission_id in QuestSystem.MISSIONS:
		var mission: Dictionary = QuestSystem.mission_data(mission_id)
		var state: String = mission_states.get(mission_id, QuestSystem.AVAILABLE)
		var state_name: String = {QuestSystem.AVAILABLE:LocaleSystem.ui("available"), QuestSystem.ACTIVE:LocaleSystem.ui("active"), QuestSystem.COMPLETED:LocaleSystem.ui("completed")}[state]
		draw_rect(Rect2(170, row_y, 812, 142), Color("fff0bd") if state != QuestSystem.COMPLETED else Color("c9e2bd"))
		draw_string(UI_FONT, Vector2(190, row_y + 29), "%s • %s" % [mission.type, mission.title], HORIZONTAL_ALIGNMENT_LEFT, 520, 20, Color("493b2f"))
		draw_string(UI_FONT, Vector2(770, row_y + 29), state_name, HORIZONTAL_ALIGNMENT_RIGHT, 185, 15, Color("50704e"))
		draw_string(UI_FONT, Vector2(190, row_y + 62), mission.description, HORIZONTAL_ALIGNMENT_LEFT, 745, 15, Color("493b2f"))
		draw_string(UI_FONT, Vector2(190, row_y + 92), LocaleSystem.ui("objective", [QuestSystem.objective_text(self, mission_id)]), HORIZONTAL_ALIGNMENT_LEFT, 520, 16, Color("6b5038"))
		draw_string(UI_FONT, Vector2(190, row_y + 119), LocaleSystem.ui("reward", [mission.coins, mission.xp, inventory_item_name(mission.reward_item), mission.reward_count]), HORIZONTAL_ALIGNMENT_LEFT, 720, 14, Color("49704d"))
		row_y += 158.0
	draw_string(UI_FONT, Vector2(320, 548), LocaleSystem.ui("quest_close"), HORIZONTAL_ALIGNMENT_CENTER, 512, 16, Color("493b2f"))

func draw_player_status_bars() -> void:
	var hp_ratio := clampf(float(player_hp) / float(player_max_hp), 0.0, 1.0)
	var hp_bar := Rect2(24, 77, 160, 18)
	draw_rect(hp_bar, Color("3a2528"))
	draw_rect(hp_bar.grow(-2), Color("71333a"))
	draw_rect(Rect2(hp_bar.position + Vector2(2, 2), Vector2((hp_bar.size.x - 4) * hp_ratio, hp_bar.size.y - 4)), Color("e25555").lerp(Color("63cf72"), hp_ratio))
	draw_string(UI_FONT, Vector2(29, 91), "HP %d/%d" % [player_hp, player_max_hp], HORIZONTAL_ALIGNMENT_CENTER, 150, 13, Color.WHITE)
	var xp_needed := SkillSystem.xp_to_next_character_level(player_level)
	var xp_ratio := clampf(float(player_xp) / float(xp_needed), 0.0, 1.0)
	var xp_bar := Rect2(202, 77, 170, 18)
	draw_rect(xp_bar, Color("222e3c"))
	draw_rect(Rect2(xp_bar.position + Vector2(2, 2), Vector2((xp_bar.size.x - 4) * xp_ratio, xp_bar.size.y - 4)), Color("5b9de3"))
	draw_string(UI_FONT, Vector2(205, 91), "УР. %d • XP %d/%d" % [player_level, player_xp, xp_needed], HORIZONTAL_ALIGNMENT_CENTER, 164, 13, Color.WHITE)
	var mana_ratio := clampf(float(player_mana) / float(player_max_mana), 0.0, 1.0)
	var mana_bar := Rect2(380, 77, 150, 18)
	draw_rect(mana_bar, Color("252846"))
	draw_rect(Rect2(mana_bar.position + Vector2(2, 2), Vector2((mana_bar.size.x - 4) * mana_ratio, mana_bar.size.y - 4)), Color("596bd8"))
	draw_string(UI_FONT, Vector2(383, 91), LocaleSystem.ui("mana_label", [player_mana, player_max_mana]), HORIZONTAL_ALIGNMENT_CENTER, 144, 13, Color.WHITE)
	var stamina_max := SkillSystem.max_stamina(self)
	var stamina_ratio := clampf(float(energy) / float(stamina_max), 0.0, 1.0)
	var stamina_bar := Rect2(538, 77, 150, 18)
	draw_rect(stamina_bar, Color("3b3222"))
	draw_rect(Rect2(stamina_bar.position + Vector2(2, 2), Vector2((stamina_bar.size.x - 4) * stamina_ratio, stamina_bar.size.y - 4)), Color("e0a640"))
	draw_string(UI_FONT, Vector2(541, 91), LocaleSystem.ui("stamina_label", [energy, stamina_max]), HORIZONTAL_ALIGNMENT_CENTER, 144, 13, Color.WHITE)
	var effects: Array[String] = []
	if regeneration_timer > 0.0: effects.append("❤ реген %.0fс" % regeneration_timer)
	if strength_timer > 0.0: effects.append("⚔ сила %.0fс" % strength_timer)
	if speed_timer > 0.0: effects.append("➜ скорость %.0fс" % speed_timer)
	if not effects.is_empty():
		draw_rect(Rect2(450, 108, 680, 26), Color(0.08, 0.16, 0.14, 0.88))
		draw_string(UI_FONT, Vector2(465, 127), LocaleSystem.ui("effects") + " " + "   ".join(effects), HORIZONTAL_ALIGNMENT_LEFT, 650, 15, Color("ffeaa3"))

func draw_hotbar() -> void:
	var start_x := 176.0
	for index in 10:
		var slot := Rect2(start_x + index * 80.0, 558, 72, 72)
		var selected := index == selected_hotbar
		draw_rect(slot, Color("f2c96f") if selected else Color("263c36"))
		draw_rect(slot.grow(-4), Color("fff0bd") if selected else Color("49665c"))
		var kind: String = hotbar_slots[index]
		var item := InventorySystem.data(kind)
		draw_item_icon(kind, Rect2(slot.position + Vector2(17, 10), Vector2(38, 38)))
		draw_string(UI_FONT, slot.position + Vector2(5, 16), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("352e28") if selected else Color.WHITE)
		draw_string(UI_FONT, slot.position + Vector2(4, 61), item.short, HORIZONTAL_ALIGNMENT_CENTER, 64, 11, Color("352e28") if selected else Color.WHITE)

func draw_inventory() -> void:
	draw_rect(Rect2(38, 40, 1076, 552), Color("2d2925"))
	draw_rect(Rect2(54, 56, 1044, 520), Color("e8cf96"))
	draw_rect(Rect2(54, 56, 1044, 62), Color("594334"))
	draw_string(UI_FONT, Vector2(270, 98), LocaleSystem.ui("inventory"), HORIZONTAL_ALIGNMENT_CENTER, 440, 25, Color("fff0bd"))
	var first_visible := inventory_scroll_row * InventorySystem.COLUMNS
	var last_visible := mini(first_visible + InventorySystem.VISIBLE_SLOTS, inventory_slots.size())
	for index in range(first_visible, last_visible):
		var column := index % 6
		var row := index / 6 - inventory_scroll_row
		var slot := Rect2(72 + column * 112, 126 + row * 69, 102, 61)
		var selected := index == inventory_selected
		var moving := index == inventory_move_from
		draw_rect(slot, Color("f0c96f") if selected else Color("715744"))
		draw_rect(slot.grow(-4), Color("fff0bd") if not moving else Color("95d2a6"))
		var kind: String = inventory_slots[index]
		if not kind.is_empty() and inventory_item_count(kind) > 0:
			draw_item_icon(kind, Rect2(slot.position + Vector2(5, 6), Vector2(30, 30)))
			draw_string(UI_FONT, slot.position + Vector2(37, 23), inventory_item_name(kind), HORIZONTAL_ALIGNMENT_LEFT, 61, 10, Color("352e28"))
			draw_string(UI_FONT, slot.position + Vector2(73, 51), "×%d" % inventory_item_count(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("352e28"))
		else:
			draw_string(UI_FONT, slot.position + Vector2(45, 39), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("937d61"))
	var total_rows := ceili(float(inventory_slots.size()) / InventorySystem.COLUMNS)
	var scroll_track := Rect2(750, 126, 10, 337)
	draw_rect(scroll_track, Color("8c7559"))
	var thumb_height := maxf(34.0, scroll_track.size.y * InventorySystem.VISIBLE_ROWS / float(maxi(total_rows, InventorySystem.VISIBLE_ROWS)))
	var scroll_ratio := float(inventory_scroll_row) / float(maxi(InventorySystem.max_scroll_row(self), 1))
	draw_rect(Rect2(scroll_track.position + Vector2(1, (scroll_track.size.y - thumb_height) * scroll_ratio), Vector2(8, thumb_height)), Color("f0c96f"))
	draw_string(UI_FONT, Vector2(650, 106), LocaleSystem.ui("row", [inventory_scroll_row + 1, maxi(total_rows - InventorySystem.VISIBLE_ROWS + 1, 1)]), HORIZONTAL_ALIGNMENT_RIGHT, 100, 11, Color("d8c49a"))
	draw_equipment_panel()
	for index in 10:
		var assign_box := Rect2(72 + index * 68, 492, 62, 44)
		draw_rect(assign_box, Color("f0c96f") if index == selected_hotbar else Color("715744"))
		draw_string(UI_FONT, assign_box.position + Vector2(3, 14), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		draw_string(UI_FONT, assign_box.position + Vector2(4, 35), InventorySystem.data(hotbar_slots[index]).short, HORIZONTAL_ALIGNMENT_CENTER, 54, 9, Color.WHITE)
	draw_rect(Rect2(770, 500, 142, 38), Color("6e9b63"))
	draw_rect(Rect2(928, 500, 142, 38), Color("c08a55"))
	draw_string(UI_FONT, Vector2(778, 525), LocaleSystem.ui("eat"), HORIZONTAL_ALIGNMENT_CENTER, 126, 13, Color.WHITE)
	draw_string(UI_FONT, Vector2(936, 525), LocaleSystem.ui("equip"), HORIZONTAL_ALIGNMENT_CENTER, 126, 13, Color.WHITE)
	draw_string(UI_FONT, Vector2(72, 563), LocaleSystem.ui("inventory_help"), HORIZONTAL_ALIGNMENT_LEFT, 990, 13, Color("493b2f"))

func draw_equipment_panel() -> void:
	draw_rect(Rect2(770, 136, 300, 350), Color("6f5542"))
	draw_string(UI_FONT, Vector2(790, 168), LocaleSystem.ui("equipment"), HORIZONTAL_ALIGNMENT_CENTER, 260, 22, Color("fff0bd"))
	draw_circle(Vector2(920, 265), 48, Color("e5b68d"))
	draw_rect(Rect2(882, 310, 76, 105), Color("638d72"))
	var slots := ["head", "body", "legs", "hands", "offhand", "ring"]
	var labels := {"head":LocaleSystem.ui("head"), "body":LocaleSystem.ui("body"), "legs":LocaleSystem.ui("legs"), "hands":LocaleSystem.ui("hands"), "offhand":LocaleSystem.ui("offhand"), "ring":LocaleSystem.ui("ring")}
	for index in slots.size():
		var slot_name: String = slots[index]
		var left := index % 2 == 0
		var box := Rect2(790 if left else 972, 195 + (index / 2) * 82, 82, 64)
		draw_rect(box, Color("fff0bd"))
		var kind: String = equipment[slot_name]
		draw_string(UI_FONT, box.position + Vector2(4, 16), labels[slot_name], HORIZONTAL_ALIGNMENT_CENTER, 74, 11, Color("493b2f"))
		if not kind.is_empty():
			draw_item_icon(kind, Rect2(box.position + Vector2(23, 23), Vector2(36, 36)))
			draw_string(UI_FONT, box.position + Vector2(4, 59), InventorySystem.data(kind).short, HORIZONTAL_ALIGNMENT_CENTER, 74, 10, Color("493b2f"))

func draw_skill_menu() -> void:
	draw_rect(Rect2(92, 48, 968, 552), Color("25232c"))
	draw_rect(Rect2(112, 68, 928, 512), Color("e4d4a9"))
	draw_rect(Rect2(112, 68, 928, 70), Color("493e61"))
	draw_string(UI_FONT, Vector2(180, 108), LocaleSystem.ui("character"), HORIZONTAL_ALIGNMENT_LEFT, 510, 28, Color("fff2c7"))
	draw_string(UI_FONT, Vector2(735, 106), LocaleSystem.ui("level_points", [player_level, skill_points]), HORIZONTAL_ALIGNMENT_RIGHT, 270, 18, Color("f5cf6a"))
	for index in SkillSystem.SKILLS.size():
		var skill: Dictionary = SkillSystem.SKILLS[index]
		var column := index % 2
		var row := index / 2
		var box := Rect2(142 + column * 444, 158 + row * 92, 414, 78)
		var selected := index == skill_menu_selected
		draw_rect(box, Color("efc75f") if selected else Color("6c5c48"))
		draw_rect(box.grow(-4), Color("fff0bd") if selected else Color("f0dfb5"))
		draw_string(UI_FONT, box.position + Vector2(14, 29), "%s  %s" % [skill.icon, LocaleSystem.skill(skill.id)], HORIZONTAL_ALIGNMENT_LEFT, 245, 19, Color("43382f"))
		draw_string(UI_FONT, box.position + Vector2(310, 29), LocaleSystem.ui("rank", [SkillSystem.skill(self, skill.id)]), HORIZONTAL_ALIGNMENT_RIGHT, 88, 15, Color("4c674c"))
		draw_string(UI_FONT, box.position + Vector2(14, 55), LocaleSystem.skill(skill.id, true), HORIZONTAL_ALIGNMENT_LEFT, 380, 12, Color("665746"))
		if skill.get("profession", false):
			var needed := SkillSystem.xp_to_next_skill_rank(SkillSystem.skill(self, skill.id))
			var ratio := clampf(float(skill_xp.get(skill.id, 0)) / float(needed), 0.0, 1.0)
			var bar := Rect2(box.position + Vector2(14, 64), Vector2(380, 6))
			draw_rect(bar, Color("766751"))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("6da86d"))
	draw_string(UI_FONT, Vector2(220, 556), LocaleSystem.ui("skill_help"), HORIZONTAL_ALIGNMENT_CENTER, 712, 15, Color("493b2f"))

func draw_crafting_window() -> void:
	draw_rect(Rect2(170, 70, 812, 510), Color("33271f"))
	draw_rect(Rect2(190, 90, 772, 470), Color("e8cf96"))
	draw_rect(Rect2(190, 90, 772, 64), Color("744b32"))
	draw_string(UI_FONT, Vector2(326, 132), LocaleSystem.ui("workbench"), HORIZONTAL_ALIGNMENT_CENTER, 500, 28, Color("fff1c4"))
	for index in CraftingSystem.RECIPES.size():
		var recipe: Dictionary = CraftingSystem.RECIPES[index]
		var row := Rect2(220, 174 + index * 68, 712, 58)
		draw_rect(row, Color("f2c96f") if index == crafting_selected else Color("fff0bd"))
		draw_string(UI_FONT, row.position + Vector2(18, 35), inventory_item_name(recipe.output), HORIZONTAL_ALIGNMENT_LEFT, 230, 17, Color("493b2f"))
		draw_string(UI_FONT, row.position + Vector2(250, 35), CraftingSystem.ingredients_text(self, recipe), HORIZONTAL_ALIGNMENT_LEFT, 440, 14, Color("49704d") if CraftingSystem.can_craft(self, recipe) else Color("a64d45"))
	draw_string(UI_FONT, Vector2(220, 535), LocaleSystem.ui("craft_help"), HORIZONTAL_ALIGNMENT_CENTER, 712, 16, Color("493b2f"))

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
	var table := Rect2(405, 174, 570, 324)
	draw_rect(table, Color("fff4cf"))
	draw_rect(Rect2(table.position, Vector2(table.size.x, 42)), Color("53704b"))
	draw_string(UI_FONT, table.position + Vector2(62, 28), LocaleSystem.ui("product"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(UI_FONT, table.position + Vector2(350, 28), LocaleSystem.ui("buy"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(UI_FONT, table.position + Vector2(455, 28), LocaleSystem.ui("sell"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	for i in shop_products.size():
		var product: Dictionary = shop_products[i]
		var row := Rect2(table.position + Vector2(0, 42 + i * 47), Vector2(table.size.x, 47))
		draw_rect(row, Color("f2c96f") if i == shop_selected else Color("f8e8b5"))
		draw_rect(row, Color("76543c"), false, 2)
		if product.has("icon"):
			draw_texture_rect_region(SUPPLY_SHEET, Rect2(row.position + Vector2(12, 5), Vector2(34, 38)), product.icon)
		else:
			draw_item_icon(product.kind, Rect2(row.position + Vector2(13, 7), Vector2(32, 32)))
		draw_string(UI_FONT, row.position + Vector2(56, 30), inventory_item_name(product.kind), HORIZONTAL_ALIGNMENT_LEFT, 286, 14, Color("3d3428"))
		draw_string(UI_FONT, row.position + Vector2(370, 30), ("%d 🪙" % product.buy) if product.buy > 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("3d3428"))
		draw_string(UI_FONT, row.position + Vector2(478, 30), ("%d 🪙" % product.sell) if product.sell > 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("3d3428"))
	draw_string(UI_FONT, Vector2(690, 535), LocaleSystem.ui("shop_help"), HORIZONTAL_ALIGNMENT_CENTER, 560, 16, Color("493b2f"))
