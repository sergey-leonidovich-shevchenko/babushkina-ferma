extends "res://scripts/game_context.gd"

const FarmRenderer := preload("res://scripts/presentation/farm_renderer.gd")

## Рисует строку с пользовательским масштабом текста и безопасным уменьшением при нехватке ширины.
func draw_ui_string(font: Font, position: Vector2, text: String, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, font_size: int = 16, color: Color = Color.WHITE) -> void:
	var effective_size := UiScaleSystem.fitted_font_size(self, font, text, width, font_size)
	draw_string(font, position, text, alignment, width, effective_size, color)

## Отрисовывает текущее визуальное состояние узла.
func _draw() -> void:
	RenderSystem.draw(self)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_title_screen() -> void:
	if title_screen:
		draw_texture_rect(TITLE_ART, Rect2(0, 0, 1152, 648), false)
		var pulse := 0.78 + sin(Time.get_ticks_msec() / 520.0) * 0.10
		for firefly in 5:
			var phase := Time.get_ticks_msec() / 900.0 + firefly * 1.73
			var point := Vector2(112 + firefly * 139 + sin(phase) * 22, 390 + cos(phase * 0.73) * 68)
			draw_circle(point, 3.0, Color(1.0, 0.83, 0.35, 0.20 + pulse * 0.22))
		MenuRenderer.draw_title_wordmark(self)
		draw_string(MENU_FONT, Vector2(1020, 630), "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0"), HORIZONTAL_ALIGNMENT_RIGHT, 110, 13, Color(1.0, 0.92, 0.72, 0.78))
		if menu_state.settings_open:
			MenuRenderer.draw_settings(self)
		else:
			MenuRenderer.draw_title_menu(self)
		if not menu_state.confirmation.is_empty(): MenuRenderer.draw_confirmation(self)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_language_screen() -> void:
	MenuRenderer.draw_language_screen(self)

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
	FarmRenderer.draw(self)

## Отрисовывает землю и состояние одной грядки независимо от её локации.
func draw_plot(rect: Rect2, plot: Dictionary) -> void:
	FarmRenderer.draw_plot(self, rect, plot)

## Отрисовывает культуры по текущему состоянию игры.
func draw_crop(rect: Rect2, plot: Dictionary) -> void:
	FarmRenderer.draw_crop(self, rect, plot)

## Отрисовывает культуры прогресса по текущему состоянию игры.
func draw_crop_progress(rect: Rect2, plot: Dictionary) -> void:
	FarmRenderer.draw_crop_progress(self, rect, plot)

## Рисует маленькие сезонные часы над уснувшей культурой вместо ошибочного требования полива.
func draw_season_pause_icon(center: Vector2) -> void:
	FarmRenderer.draw_season_pause_icon(self, center)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_water_needed_icon(center: Vector2) -> void:
	FarmRenderer.draw_water_needed_icon(self, center)

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
	_draw_cave_entrance()
	if player.distance_to(cave_entrance_position) < 180.0:
		draw_string(UI_FONT, cave_entrance_position + Vector2(-58, 78), LocaleSystem.location("cave"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7fff4"))


## Отрисовывает внешние спрайты зданий, подписи и состояние закрытых дверей.
func draw_buildings() -> void:
	# В первой локации здания уже являются отдельными областями мастер-атласа;
	# отдельные фасады используются в остальных внешних биомах и конструкторе.
	if current_location == "overworld": return
	for building_id in BuildingSystem.buildings_at(current_location):
		var data: Dictionary = BuildingSystem.BUILDINGS[building_id]
		BuildingVisualSystem.draw_building(self,building_id,Vector2(data.door))
		var unlocked := BuildingSystem.can_enter(self, building_id)
		var door: Vector2 = data.door
		if not unlocked and player.distance_to(door) < 180.0:
			draw_string(UI_FONT, door + Vector2(-12, -28), "🔒", HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color("ffb36a"))


## Отрисовывает сезонный декор и доступные порталы мировых событий.
func draw_world_events() -> void:
	if current_location == "overworld": EnvironmentVisualSystem.draw_seasonal_village(self, WorldEventSystem.SEASONS.find(WorldEventSystem.season(day)))
	var portal_position := WorldEventSystem.RETURN_PORTAL_POSITION if current_location == "moon_glade" else WorldEventSystem.PORTAL_POSITION
	var portal_visible := current_location == "moon_glade" or (current_location == "overworld" and WorldEventSystem.eclipse_active(day, game_minutes))
	EnvironmentVisualSystem.draw_eclipse_world(self, current_location, portal_position, portal_visible)
	MoonGladeRenderer.draw(self)
	if portal_visible and player.distance_to(portal_position) < 160.0:
		draw_string(UI_FONT, portal_position + Vector2(-90, 55), "E • Лунный портал", HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color("e4dbff"))


## Отрисовывает мебель, выходы и переходы между этажами текущего интерьера.
func draw_interior_objects() -> void:
	var data: Dictionary = BuildingSystem.interior(current_location)
	if data.is_empty():
		return
	InteriorRenderer.draw(self)
	if data.has("service"):
		var service_position: Vector2 = data.service_position
		draw_string(UI_FONT, service_position + Vector2(-72, 18), LocaleSystem.entity(String(data.service)).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 144, 13, Color("fff0bd"))
	if current_location == "cottage_interior" and home_chest_owned:
		var chest_position: Vector2 = StorageSystem.CHEST_POSITION
		InteriorRenderer.draw_prop(self,"home_chest",chest_position)
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
	draw_quest_marker(position, marker)

## Отрисовывает жителей с заданиями только в их родной локации и показывает доступность диалога.
func draw_quest_npcs() -> void:
	for npc_id in QuestSystem.NPCS:
		var data: Dictionary = QuestSystem.NPCS[npc_id]
		var position := QuestSystem.npc_position(self, npc_id)
		var movement: Dictionary = NpcMovementSystem.actor(self, npc_id, position)
		if String(movement.get("location", data.location)) != current_location: continue
		draw_npc_sprite(int(data.sprite), position, movement.direction, movement.moving, data.tint)
		if player.distance_to(position) < 155.0:
			draw_string(UI_FONT, position + Vector2(-76, 58), QuestSystem.npc_name(npc_id), HORIZONTAL_ALIGNMENT_CENTER, 152, 15, Color("293c2f") if current_location == "overworld" else Color("fff0bd"))
		var marker := QuestSystem.npc_marker(self, npc_id)
		if marker.is_empty(): continue
		draw_quest_marker(position, marker)


## Рисует компактный пиксельный маркер задания, не перекрывающий голову персонажа и окружение.
func draw_quest_marker(position: Vector2, marker: String) -> void:
	var bob := sin(Time.get_ticks_msec() / 240.0 + position.x * 0.01) * 2.0
	var center := position + Vector2(0, -67 + bob)
	var color := Color("75bf79") if marker == "✓" else Color("efc85c")
	var shadow := PackedVector2Array([center+Vector2(-9,-8),center+Vector2(9,-8),center+Vector2(9,7),center+Vector2(0,13),center+Vector2(-9,7)])
	draw_colored_polygon(shadow, Color(0.12,0.14,0.12,0.42))
	var badge := PackedVector2Array([center+Vector2(-7,-9),center+Vector2(7,-9),center+Vector2(7,5),center+Vector2(0,10),center+Vector2(-7,5)])
	draw_colored_polygon(badge, color)
	draw_polyline(PackedVector2Array([badge[0],badge[1],badge[2],badge[3],badge[4],badge[0]]), Color("5a4524"), 1.5)
	draw_string(UI_FONT, center + Vector2(-6, 3), marker, HORIZONTAL_ALIGNMENT_CENTER, 12, 12, Color("30281d"))

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
		if OrchardSystem.handles(food.kind):
			OrchardSystem.draw_tree(self, food)
			if not food.active:
				draw_string(UI_FONT, position + Vector2(-55, 42), ForageSystem.remaining_text(self, food), HORIZONTAL_ALIGNMENT_CENTER, 110, 12, Color("e7d6a3"))
			continue
		match food.kind:
			"mushroom":
				draw_texture_rect(RED_MUSHROOMS, ForageSystem.destination_rect(food), false, Color(1, 1, 1, alpha))
			"watermelon":
				draw_texture_rect(ITEM_WATERMELON, ForageSystem.destination_rect(food), false, Color(1, 1, 1, alpha))
			"berries", "nut":
				var layout := forage_sprite_layout(food.kind, position)
				draw_texture_rect_region(PLANT_SHEET, layout.destination, layout.source, Color(1, 1, 1, alpha))
		if not food.active:
			draw_string(UI_FONT, position + Vector2(-55, 42), ForageSystem.remaining_text(self, food), HORIZONTAL_ALIGNMENT_CENTER, 110, 12, Color("e7d6a3"))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_fishing_animations() -> void:
	WaterVisualSystem.draw_first_location_animations(self)

## Отрисовывает взрослые деревья, пни, саженцы, повреждения и прогресс повторного роста.
func draw_tree_nodes() -> void:
	if current_location != "overworld": return
	for tree in state.world.tree_nodes:
		var stage: int = tree.stage
		var flash: float = tree.hit_flash
		var destination:=TreeSystem.destination_rect(tree)
		var tint := Color(1.0, 0.72, 0.62) if flash > 0.0 else Color.WHITE
		draw_texture_rect_region(FOREST_TREE_GROWTH_ATLAS,destination,TreeSystem.source_rect(stage),tint)
		if stage < 3:
			var progress: float = TreeSystem.regrow_progress(tree)
			var bar := Rect2(Vector2(destination.get_center().x-36,destination.end.y+6), Vector2(72, 8))
			draw_rect(bar, Color("243b35")); draw_rect(Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2) * progress, bar.size.y - 2)), Color("70c66a"))
		if stage == 3 and int(tree.health) < TreeSystem.MAX_HEALTH:
			for heart in TreeSystem.MAX_HEALTH: draw_circle(Vector2(destination.get_center().x-14+heart*14,destination.position.y-8),4,Color("df6657") if heart<int(tree.health) else Color("5b493e"))

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
		draw_texture_rect(texture, ResourceSystem.destination_rect(node), false, tint)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_dropped_items() -> void:
	for item in dropped_items:
		if item_texture(item.kind):
			draw_item_icon(item.kind, Rect2(item.position - Vector2(22, 22), Vector2(44, 44)))
		else:
			draw_circle(item.position, 15, inventory_item_color(item.kind))

## Отрисовывает мира добычи по текущему состоянию игры.
func draw_world_loot() -> void:
	WorldLootRenderer.draw(self)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_enemy_nodes_and_gate() -> void:
	if not BuildingSystem.is_interior(current_location):
		WorldPolishRenderer.draw_cell(self,4,1,Rect2(world_gate_position-Vector2(60,60),Vector2(120,120)),Color(1,1,1,0.88))
		if player.distance_to(world_gate_position) < 185.0:
			draw_circle(world_gate_position, 42 + sin(Time.get_ticks_msec() / 180.0) * 4, Color("e6b85e"), false, 6)
			draw_string(UI_FONT, world_gate_position + Vector2(-75, 68), WorldSystem.name(WorldSystem.next_location(current_location)), HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color("fff0bd"))
	for enemy in enemy_nodes:
		if not AnimationSystem.enemy_is_visible(enemy) or enemy.location != current_location: continue
		var position: Vector2 = enemy.position
		AnimationRenderer.draw_enemy(self, enemy)
		if not enemy.alive: continue
		var sprite_size:Vector2=CreatureVisualProfileSystem.enemy_size(int(enemy.level)); var bar_y:=position.y-sprite_size.y*CreatureVisualProfileSystem.GROUND_RATIO
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
		var size:Vector2=CreatureVisualProfileSystem.hazard_size(hazard.kind)
		draw_living_atlas_sprite(HAZARD_RANK_ATLAS, source, hazard.position, size, hazard.pulse, false, float(column) * 1.2)
		var top_y: float = hazard.position.y - size.y * 0.72
		draw_string(UI_FONT, Vector2(hazard.position.x - 58, top_y), LocaleSystem.ui("enemy_level", [hazard.level]), HORIZONTAL_ALIGNMENT_CENTER, 116, 13, Color("ffd46a"))
		draw_string(UI_FONT, hazard.position + Vector2(-70, 56), LocaleSystem.entity(hazard.kind), HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color("e9f0c6"))
		if hazard.kind == "thorn_bloom" and hazard.cooldown > EnvironmentHazardSystem.TYPES.thorn_bloom.interval - 0.22:
			draw_line(hazard.position - Vector2(0, 24), player, Color(0.78, 0.95, 0.35, 0.72), 3.0)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func enemy_direction_row(direction: Vector2) -> int:
	return PresentationSystem.enemy_direction_row(direction)

## Отрисовывает животных по текущему состоянию игры.
func draw_wildlife() -> void:
	for animal in wildlife_nodes:
		if animal.location != current_location:
			continue
		var data: Dictionary = WildlifeSystem.TYPES[animal.kind]
		var position: Vector2 = animal.position.round()
		var state_name: String = animal.get("visual_state", "idle")
		var column := 0
		if state_name in ["run", "flee"]: column = 1 + int(animal.animation * (11.0 if state_name == "flee" else 8.0)) % 3
		elif state_name == "attack": column = 3
		elif state_name == "hurt": column = 4
		elif state_name == "death": column = 5
		var row := AnimationAssetRegistry.direction_index(animal.direction)
		var draw_size:Vector2=CreatureVisualProfileSystem.wildlife_size()
		draw_circle(position + Vector2(0, 12), 18.0, Color(0.08, 0.12, 0.08, 0.25))
		draw_texture_rect_region(WILDLIFE_ACTION_SHEETS[animal.kind], Rect2(position - draw_size * Vector2(0.5, 0.72), draw_size), Rect2(column * 128, row * 128, 128, 128))
		if animal.alive and animal.hp < data.hp:
			draw_rect(Rect2(position - Vector2(25, 44), Vector2(50, 5)), Color("402d32"))
			draw_rect(Rect2(position - Vector2(24, 43), Vector2(48.0 * animal.hp / float(data.hp), 3)), Color("dc554b"))

## Отрисовывает пещеры мира по текущему состоянию игры.
func draw_cave_world() -> void:
	_draw_cave_exit_gate()
	draw_string(UI_FONT, Vector2(90, 100), LocaleSystem.location("cave").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("9ce9dd"))


## Отрисовывает оформленный вход в пещеру в стиле каменного портала.
func _draw_cave_entrance() -> void:
	var frame := PackedVector2Array([
		cave_entrance_position + Vector2(-56, 48), cave_entrance_position + Vector2(-44, 4),
		cave_entrance_position + Vector2(-34, -31), cave_entrance_position + Vector2(-2, -55),
		cave_entrance_position + Vector2(33, -31), cave_entrance_position + Vector2(43, 4),
		cave_entrance_position + Vector2(55, 48)
	])
	draw_colored_polygon(frame, Color("1f2f3d", 0.75))
	draw_polyline(frame, Color("0b1218"), 2.5)
	for offset in [Vector2(-44, 26), Vector2(-34,-20), Vector2(-10,-45), Vector2(12,-51), Vector2(36,-20), Vector2(47,25)]:
		draw_texture_rect(RESOURCE_ROCK,CaveVisualSystem.entrance_rock_rect(cave_entrance_position,offset),false,Color("a7ad9e"))
	for offset in [Vector2(-36, 48), Vector2(34, 48), Vector2(0, -20)]:
		draw_circle(cave_entrance_position + offset, 5.0, Color("e2f6ff", 0.4))
	draw_rect(Rect2(cave_entrance_position + Vector2(-44, -50), Vector2(88, 34)), Color("0b171f", 0.52))
	for light in [Vector2(-48, -34), Vector2(0, -56), Vector2(48, -34)]:
		draw_arc(cave_entrance_position + light, 12, 0.4, 1.8, 8, Color("7dd4ff", 0.28), 2.2)


## Рисует вход из мира подземья назад с акцентом на направление и читаемую локацию.
func _draw_cave_exit_gate() -> void:
	draw_circle(cave_exit_position, 52, Color("11202b"))
	draw_circle(cave_exit_position, 42, Color("a8f0d6"), false, 4)
	for drift in [Vector2(-24, -6), Vector2(-8, 10), Vector2(8, 10), Vector2(24, -6)]:
		draw_circle(cave_exit_position + drift, 5.8, Color("d6f8de", 0.4 + sin(Time.get_ticks_msec() / 220.0 + drift.x) * 0.2))
	var glow := 0.18 + sin(Time.get_ticks_msec() / 250.0) * 0.09
	draw_circle(cave_exit_position, 34.0, Color(0.55, 0.95, 0.86, glow))


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
	var destination := VisualAssetSystem.fitted_icon_rect(rect)
	if texture:
		draw_texture_rect(texture, destination, false)
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
	StoryUiRenderer.draw_quest_log(self)

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_skill_menu() -> void:
	TalentRenderer.draw(self)

## Отрисовывает крафта окна по текущему состоянию игры.
func draw_crafting_window() -> void:
	ItemWindowRenderer.draw_crafting(self)

## Отрисовывает магазина по текущему состоянию игры.
func draw_shop() -> void:
	ItemWindowRenderer.draw_shop(self)

## Отрисовывает две колонки домашнего сундука и команды переноса предметов.
func draw_storage_window() -> void:
	ItemWindowRenderer.draw_storage(self)

## Отрисовывает список постоянных улучшений кузницы с уровнями и стоимостью.
func draw_forge_window() -> void:
	ItemWindowRenderer.draw_forge(self)
