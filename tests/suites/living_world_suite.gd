extends "res://tests/suites/suite_base.gd"


## Запускает контрактные тесты живой деревни, животных и изолированного полигона отладки.
func run() -> void:
	test_village_has_distinct_connected_districts()
	test_village_palette_covers_every_season()
	test_wildlife_atlases_follow_shared_contract()
	test_wildlife_runtime_has_reactions_and_death()
	test_debug_playground_controls_world_state()
	test_debug_collision_and_enemy_factory()
	test_villagers_follow_building_schedule_and_relationships()
	test_personal_requests_and_daily_gifts()
	test_distinct_interiors_have_solid_reachable_furniture()
	test_village_events_have_gameplay_and_rewards()
	test_debug_inspector_supports_pause_step_pointer_and_graph()
	test_runtime_debug_overlay_classifies_navigation_grid()
	test_runtime_debug_object_inspector_identifies_visual_objects()
	test_runtime_debug_overlay_controls_pause_layers_and_noclip()
	test_debug_tools_share_storybook_chrome_and_technical_colors()
	test_grandmother_side_gate_stays_walkable()
	test_world_polish_atlas_has_complete_transparent_grid()
	test_expansion_features_have_tutorial_steps()


## Сценарий: первая карта делится на районы, а ключевые двери остаются связаны дорогами.
## Исходное состояние: загружена статическая схема деревни с шестью кварталами.
## Ожидаемый результат: районы различимы, а дом, магазин и гильдия достигаются дорожной сетью.
func test_village_has_distinct_connected_districts() -> void:
	var game := make_game(); var layout = game.VillageLayoutSystem
	expect(game.SpatialGridSystem.BASE_CELL == 24 and layout.OVERWORLD_TILE_SIZE == game.SpatialGridSystem.BASE_CELL, "world renderer and layout share one 24-pixel base grid")
	expect(game.SpatialGridSystem.BLOCK_CELL == game.SpatialGridSystem.BASE_CELL * 2 and game.SpatialGridSystem.proportion("door_passage") == Vector2i(2,1), "one major block contains four base cells and doors reserve a two-cell passage")
	expect(layout.DISTRICTS.size() == 6 and layout.district_at(Vector2(1300,430)) == "market" and layout.district_at(Vector2(2110,250)) == "guild", "village exposes six readable functional districts")
	for building_id in ["cottage","shop_house","guild_hall"]:
		var point: Vector2 = game.BuildingSystem.BUILDINGS[building_id].door
		expect(layout.path_reaches(point), "village road reaches service landmark: %s" % point)
	expect(layout.is_water(Vector2(1200,layout.river_center_y(1200)),18.0) and not layout.is_water(layout.BRIDGES[0].get_center(),18.0), "river blocks movement while bridge preserves navigation")
	expect(layout.blocks_scenic_prop(Vector2(850,220),18.0), "visible decorative forge from the master owns a matching collision shape")
	expect(not layout.blocks_scenic_prop(Vector2(1170,537),18.0), "removed procedural props no longer leave invisible collision walls")
	game.free()


## Сценарий: календарь меняет не только HUD, но и цветовой строй первой локации.
## Исходное состояние: запрашиваются четыре поддерживаемых сезона.
## Ожидаемый результат: каждый сезон имеет полную палитру и визуально отличный цвет травы.
func test_village_palette_covers_every_season() -> void:
	var game := make_game(); var colors: Array[Color] = []
	for season in game.WorldEventSystem.SEASONS:
		var palette: Dictionary = game.VillageLayoutSystem.seasonal_palette(season); expect(palette.has("grass") and palette.has("path") and palette.has("leaf"), "village season has complete palette: %s" % season); colors.append(palette.grass)
	expect(colors[0] != colors[1] and colors[1] != colors[2] and colors[2] != colors[3], "village seasons use visibly distinct ground palettes")
	game.free()


## Сценарий: пять животных используют одинаковые прозрачные атласы восемь на шесть.
## Исходное состояние: движок импортировал нормализованные изображения из directional.
## Ожидаемый результат: все атласы имеют 768×1024, заполненные ячейки и отдельные строки востока и запада.
func test_wildlife_atlases_follow_shared_contract() -> void:
	var game := make_game()
	for kind in game.WildlifeSystem.TYPES:
		var texture: Texture2D = game.WILDLIFE_ACTION_SHEETS[kind]; var image := texture.get_image(); var filled := true; var chroma_spill := false
		for row in 8:
			for column in 6:
				if not image.get_region(Rect2i(column*128,row*128,128,128)).get_used_rect().has_area(): filled = false
		for y in range(0,image.get_height(),2):
			for x in range(0,image.get_width(),2):
				var pixel := image.get_pixel(x,y)
				if pixel.a > 0.1 and pixel.r > 0.90 and pixel.b > 0.90 and pixel.g < 0.12 and absf(pixel.r - pixel.b) < 0.12: chroma_spill = true
		expect(texture.get_size() == Vector2(768,1024) and image.get_pixel(0,0).a < 0.05 and filled and not chroma_spill, "wildlife atlas is transparent complete chroma-free 6x8 grid: %s" % kind)
	expect(game.AnimationAssetRegistry.direction_index(Vector2.RIGHT) != game.AnimationAssetRegistry.direction_index(Vector2.LEFT), "wildlife east and west use separately drawn rows")
	game.free()


## Сценарий: животное рождается с явным состоянием, получает урон и остаётся видимо в смерти.
## Исходное состояние: олень расположен рядом с вооружённым героем.
## Ожидаемый результат: runtime содержит состояния, удар включает hurt, смертельный удар включает death.
func test_wildlife_runtime_has_reactions_and_death() -> void:
	var game := make_game(); game.current_location = "overworld"; game.player = Vector2(400,400); game.wildlife_nodes = game.WildlifeSystem.default_animals().slice(0,1)
	var animal: Dictionary = game.wildlife_nodes[0]; animal.position = game.player + Vector2(30,0); animal.location = "overworld"; game.wildlife_nodes[0] = animal
	expect(animal.visual_state == "idle" and animal.has("state_timer") and animal.has("attack_timer"), "wildlife starts with explicit animation runtime")
	expect(game.WildlifeSystem.attack(game,0) and game.wildlife_nodes[0].visual_state == "hurt", "wildlife hit selects hurt animation")
	game.wildlife_nodes[0].hp = 1; expect(game.WildlifeSystem.attack(game,0) and not game.wildlife_nodes[0].alive and game.wildlife_nodes[0].visual_state == "death", "wildlife defeat keeps visible death state")
	game.free()


## Сценарий: полигон независимо переключает время, погоду, сезон, анимации и телепорты.
## Исходное состояние: чистая игра открывает стенд через тот же системный вызов, что F10.
## Ожидаемый результат: команды меняют только контролируемые параметры и создают витрину животных.
func test_debug_playground_controls_world_state() -> void:
	var game := make_game(); var old_time: float = game.game_minutes; var old_day: int = game.day; var old_position: Vector2 = game.player; game.DebugPlaygroundSystem.configure(game)
	var showcase_kinds: Array = game.wildlife_nodes.map(func(animal): return animal.kind)
	expect(game.DebugPlaygroundSystem.active(game) and showcase_kinds.size() == 5 and showcase_kinds.duplicate().all(func(kind): return showcase_kinds.count(kind) == 1), "debug playground opens one specimen of every wildlife family")
	game.DebugPlaygroundSystem.cycle_weather(game); expect(game.state.world.weather == "rain", "debug playground cycles deterministic weather")
	game.DebugPlaygroundSystem.cycle_season(game); expect(game.day != old_day, "debug playground advances to next season")
	game.DebugPlaygroundSystem.teleport(game); expect(game.player != old_position, "debug playground teleports between test zones")
	game.DebugPlaygroundSystem.leave(game); expect(game.day == old_day and is_equal_approx(game.game_minutes, old_time) and game.player == old_position, "leaving debug playground restores calendar and exact return point")
	game.free()


## Сценарий: полигон позволяет проверять навигацию и фабрику уровневых врагов без сохранения.
## Исходное состояние: выбран второй уровень, коллизии включены, список врагов пуст для стенда.
## Ожидаемый результат: стена блокирует героя, переключатель снимает блок, созданный враг получает уровень два.
func test_debug_collision_and_enemy_factory() -> void:
	var game := make_game(); game.DebugPlaygroundSystem.configure(game); game.enemy_nodes.clear(); var wall: Rect2 = game.DebugPlaygroundSystem.OBSTACLES[0]
	expect(not game.DebugPlaygroundSystem.is_walkable(game,wall.get_center(),game.PLAYER_RADIUS), "debug obstacle participates in collision testing")
	game.DebugPlaygroundSystem.toggle_collisions(game); expect(game.DebugPlaygroundSystem.is_walkable(game,wall.get_center(),game.PLAYER_RADIUS), "debug collision switch immediately opens obstacle")
	game.DebugPlaygroundSystem.change_enemy_level(game,1); game.DebugPlaygroundSystem.spawn_enemy(game); expect(game.enemy_nodes.size() == 1 and game.enemy_nodes[0].level == 2 and game.enemy_nodes[0].location == game.DebugPlaygroundSystem.LOCATION, "debug factory spawns selected enemy level in isolation")
	game.free()


## Сценарий: деревенский житель уходит на работу внутрь здания и остаётся доступен для разговора там.
## Исходное состояние: ясный полдень, Мирон создан на своей стартовой позиции площади.
## Ожидаемый результат: расписание переносит Мирона в гильдию, а поиск NPC использует новое место и позицию.
func test_villagers_follow_building_schedule_and_relationships() -> void:
	var game := make_game(); game.game_minutes = 12 * 60; game.state.world.weather = "clear"; game.state.world.weather_day = game.day
	game.NpcMovementSystem.update(game,0.01); var state: Dictionary = game.npc_movement.miron
	expect(state.location == "guild_interior" and state.schedule == "работает", "village schedule moves working NPC into their actual building")
	game.current_location = "guild_interior"; game.player = state.position
	expect(game.QuestSystem.nearest_npc(game) == "miron", "quest interaction follows scheduled NPC across locations")
	expect(game.VillageLifeSystem.friendship_tier(55) == "добрый друг" and game.VillageLifeSystem.dialogue_text(game,"miron").contains("дружба"), "relationship tier and schedule enrich ordinary dialogue")
	game.free()


## Сценарий: подарок учитывает вкус и дневной лимит, а дружба открывает персональное поручение.
## Исходное состояние: у героя есть любимая еда Мирона и три моркови, отношения почти достигли порога.
## Ожидаемый результат: любимый подарок даёт двенадцать дружбы один раз, поручение забирает предметы и выдаёт награду один раз.
func test_personal_requests_and_daily_gifts() -> void:
	var game := make_game(); game.change_inventory_count("carrot",4); game.state.player.relationships.miron = 10
	expect(game.VillageLifeSystem.give_gift(game,"miron","carrot") and game.state.player.relationships.miron == 22, "favorite gift applies NPC-specific friendship value")
	expect(not game.VillageLifeSystem.give_gift(game,"miron","carrot") and game.inventory_item_count("carrot") == 3, "daily gift guard preserves item after first gift")
	var coins: int = game.coins; expect(game.VillageLifeSystem.claim_personal_request(game,"miron") and game.coins == coins + 28 and game.inventory_item_count("carrot") == 0, "personal friendship request consumes objective and grants reward")
	expect(not game.VillageLifeSystem.claim_personal_request(game,"miron"), "personal friendship request cannot be rewarded twice")
	game.free()


## Сценарий: четыре главных интерьера имеют разные атласные наборы и честные коллизии мебели.
## Исходное состояние: проверяются центральные точки мебели, рабочие точки перед ней и выходы помещений.
## Ожидаемый результат: мебель твёрдая, рабочая зона и выход достижимы, наборы не совпадают.
func test_distinct_interiors_have_solid_reachable_furniture() -> void:
	var game := make_game(); var first_cells: Array = []
	for location in ["cottage_interior","shop_interior","guild_interior","forge_interior"]:
		var props: Array = game.InteriorVisualSystem.props(location); first_cells.append(game.InteriorVisualSystem.profile(props[0].kind).cell)
		expect(not game.BuildingSystem.is_walkable_inside(location,props[0].position,game.PLAYER_RADIUS), "interior furniture owns collision: %s" % location)
		var data: Dictionary = game.BuildingSystem.INTERIORS[location]
		expect(game.BuildingSystem.is_walkable_inside(location,data.exit-Vector2(0,35),game.PLAYER_RADIUS) and game.BuildingSystem.is_walkable_inside(location,data.get("service_position",data.exit),game.PLAYER_RADIUS), "exit and front service remain reachable: %s" % location)
	expect(first_cells.duplicate().all(func(cell): return first_cells.count(cell) == 1), "main interiors use four distinct thematic prop cells")
	for kind in game.InteriorVisualSystem.PROFILES:
		var profile: Dictionary = game.InteriorVisualSystem.profile(kind)
		expect(posmod(int(profile.visual_size.x),24)==0 and posmod(int(profile.visual_size.y),24)==0 and posmod(int(profile.collision_size.x),24)==0 and posmod(int(profile.collision_size.y),24)==0, "interior profile follows 24-pixel art and collision grid: %s" % kind)
	game.free()


## Сценарий: календарные события создают торговлю, пир и защищаемое нападение с единственной наградой.
## Исходное состояние: события последовательно задаются вручную, здоровье снижено, враги очищены.
## Ожидаемый результат: рынок открывает торговлю, пир лечит, нападение создаёт отряд с капитаном и награждает после победы.
func test_village_events_have_gameplay_and_rewards() -> void:
	var game := make_game(); game.current_location = "overworld"; game.state.world.estate.event = "market"; game.player = game.VillageEventSystem.POSITIONS.market
	expect(game.VillageEventSystem.interact(game,"market") and game.shop_open, "market event exposes actual trading window")
	game.shop_open = false; game.state.world.estate.event = "festival"; game.state.world.estate.event_state = {}; game.player_hp = 20; game.energy = 1
	expect(game.VillageEventSystem.interact(game,"festival") and game.player_hp == game.player_max_hp and game.energy == game.SkillSystem.max_stamina(game), "festival feast restores hero resources")
	game.state.world.estate.event = "raid"; game.state.world.estate.event_state = {}; game.enemy_nodes.clear(); game.VillageEventSystem.update(game)
	expect(game.VillageEventSystem.raid_alive(game) == 4 and game.enemy_nodes.any(func(enemy): return enemy.get("event_raid_boss",false)) and game.VillageEventSystem.blocks_position(game,game.VillageEventSystem.POSITIONS.raid,game.PLAYER_RADIUS), "raid creates scaled squad, captain and solid barricade")
	for enemy in game.enemy_nodes: enemy.alive = false
	var coins: int = game.coins; game.VillageEventSystem.update(game); game.VillageEventSystem.update(game)
	expect(game.coins == coins + 120 and game.state.world.estate.event_state.rewarded and game.FarmLifeSystem.state(game).reputation == 10, "raid captain victory grants reward and reputation exactly once")
	game.free()


## Сценарий: стенд управляется мышью, ставит мир на паузу, делает один кадр и собирает график.
## Исходное состояние: открыт чистый полигон, выбрана кнопка паузы и затем кнопка шага.
## Ожидаемый результат: кнопки меняют состояние, дельта равна нулю на паузе и 1/12 на одном шаге, история FPS растёт.
func test_debug_inspector_supports_pause_step_pointer_and_graph() -> void:
	var game := make_game(); game.DebugPlaygroundSystem.configure(game); var pause_rect: Rect2 = game.DebugPlaygroundSystem.BUTTONS[4].rect; var step_rect: Rect2 = game.DebugPlaygroundSystem.BUTTONS[5].rect
	expect(game.DebugPlaygroundSystem.handle_pointer(game,pause_rect.get_center()) and is_zero_approx(game.DebugPlaygroundSystem.simulation_delta(game,0.2)), "mouse pause button freezes debug simulation")
	game.DebugPlaygroundSystem.handle_pointer(game,step_rect.get_center()); expect(is_equal_approx(game.DebugPlaygroundSystem.simulation_delta(game,0.2),1.0/12.0), "frame-step advances one fixed debug frame")
	game.DebugPlaygroundSystem.update(game,0.016); game.DebugPlaygroundSystem.update(game,0.016)
	expect(game.get_meta("debug_playground").frame_history.size() == 2 and game.get_meta("debug_playground").hitboxes and game.get_meta("debug_playground").routes, "debug graph and spatial overlays are enabled and stateful")
	game.free()


## Сценарий: внутриигровая панель использует те же правила, по которым реально движется герой.
## Исходное состояние: F10 открывает панель на обычной первой локации с видимой сеткой 50 пикселей.
## Ожидаемый результат: проход, вода, здание и враг получают разные причины и цвета категорий.
func test_runtime_debug_overlay_classifies_navigation_grid() -> void:
	var game := make_game(); game.current_location = "overworld"; game.player = Vector2(1160,650); game.update_camera()
	var location: String = game.current_location; var position: Vector2 = game.player
	game.DebugOverlaySystem.handle_input(game,key_event(KEY_F10,KEY_F10,true))
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	expect(game.DebugOverlaySystem.active(game) and state.grid and state.cache.size() > 200, "F10 opens cached navigation overlay in the current location")
	expect(state.grid_size == game.SpatialGridSystem.BASE_CELL and game.DebugOverlaySystem.GRID_SIZES == [12,24,48,96], "debug overlay opens on the exact art grid and exposes detail base block and overview scales")
	expect(game.current_location == location and game.player == position and not game.DebugPlaygroundSystem.active(game), "F10 keeps the tester on the exact live level instead of replacing it with a playground")
	expect(not game.DebugOverlaySystem.button_enabled("tile_edit") and not game.DebugOverlaySystem.button_enabled("save_patch") and game.DebugOverlaySystem.button_enabled("grid"), "unfinished editor tools stay visible but disabled while runtime diagnostics remain available")
	var water: Vector2 = Vector2(1200,game.VillageLayoutSystem.river_center_y(1200))
	var building: Vector2 = game.BuildingSystem.collision_rects("cottage")[0].get_center()
	var enemy_position := Vector2(1160,650)
	for y in range(150,1100,50):
		for x in range(100,2300,50):
			if game.NavigationSystem.walkability_reason(game,Vector2(x,y)) == "walkable": enemy_position = Vector2(x,y); break
		if enemy_position != Vector2(1160,650): break
	game.enemy_nodes = [{"alive":true,"location":"overworld","position":enemy_position}]
	expect(game.NavigationSystem.walkability_reason(game,water) == "water", "debug classifier identifies actual river collision")
	expect(game.NavigationSystem.walkability_reason(game,building) == "building", "debug classifier identifies actual building collision")
	expect(game.NavigationSystem.walkability_reason(game,enemy_position) == "enemy", "debug classifier identifies dynamic enemy collision")
	expect(game.DebugOverlayRenderer.reason_color("walkable") != game.DebugOverlayRenderer.reason_color("water") and game.DebugOverlayRenderer.reason_color("enemy") != game.DebugOverlayRenderer.reason_color("building"), "navigation categories own distinct overlay colors")
	game.free()


## Сценарий: курсор F10 выбирает объект по его видимой области, а не только по цвету навигационной клетки.
## Исходное состояние: герой, бабушка, дерево, сундук, ресурс, враг и здание находятся в активном мире с известными координатами.
## Ожидаемый результат: каждый тип возвращает имя, ID, X/Y, bounds, коллизию и технические строки; панели не выбирают мир насквозь.
func test_runtime_debug_object_inspector_identifies_visual_objects() -> void:
	var game := make_game(); game.current_location = "overworld"; game.DebugOverlaySystem.toggle(game); game.camera_offset = Vector2(100,200)
	var enemy := {"kind":"orc","location":"overworld","position":Vector2(800,600),"home":Vector2(760,600),"direction":Vector2.LEFT,"moving":true,"attack_timer":0.2,"visual_state":"attack","visual_time":0.1,"action_kind":"melee","action_target":Vector2(700,600),"level":3,"max_hp":15,"hp":9,"alive":true}
	game.enemy_nodes = [enemy]
	var enemy_target: Dictionary = game.DebugObjectInspectorSystem.hovered_object(game,enemy.position-game.camera_offset)
	expect(enemy_target.id == "enemy:0:orc" and enemy_target.name == game.LocaleSystem.entity("orc") and enemy_target.position == enemy.position, "debug hover resolves enemy id name and world coordinates")
	expect((enemy_target.bounds as Rect2).has_point(enemy.position) and String(enemy_target.collision).contains("r30") and enemy_target.details.any(func(line): return String(line).contains("HP 9/15")), "enemy info exposes visual bounds collision and combat state")
	var building_center: Vector2 = game.BuildingSystem.destination_rect("cottage").get_center(); var building_target: Dictionary = game.DebugObjectInspectorSystem.hovered_object(game,building_center-game.camera_offset)
	expect(building_target.id == "building:cottage" and building_target.category == "ЗДАНИЕ" and building_target.details.any(func(line): return String(line).contains("cottage_interior")), "debug hover resolves building sprite and interior metadata")
	var tree: Dictionary = game.state.world.tree_nodes[0]; var tree_target: Dictionary = game.DebugObjectInspectorSystem.hovered_object(game,tree.position-game.camera_offset+Vector2(70,-70))
	expect(String(tree_target.id).begins_with("tree_") and (tree_target.bounds as Rect2).size == Vector2(192,192), "tree crown uses complete visible sprite bounds")
	var player_target: Dictionary = game.DebugObjectInspectorSystem.hovered_object(game,game.player-game.camera_offset)
	expect(player_target.id == "player" and player_target.priority > enemy_target.priority and player_target.details.any(func(line): return String(line).contains("HP")), "player owns highest hover priority and complete RPG info")
	var container: Dictionary = game.world_loot_nodes.filter(func(node): return node.location == "overworld")[0]; game.camera_offset = container.position-Vector2(180,300)
	var container_target: Dictionary = game.DebugObjectInspectorSystem.hovered_object(game,Vector2(180,300))
	expect(String(container_target.id).begins_with("container:") and container_target.details.any(func(line): return String(line).contains("содержимое")), "loot container exposes persistent id open state and exact contents")
	var grandmother: Dictionary = game.npc_movement.grandmother; game.camera_offset = grandmother.position-Vector2(220,300)
	var npc_target: Dictionary = game.DebugObjectInspectorSystem.hovered_object(game,Vector2(220,300))
	expect(npc_target.id == "npc:grandmother" and npc_target.details.any(func(line): return String(line).contains("home")), "NPC inspector exposes runtime schedule direction and home anchor")
	expect(game.DebugObjectInspectorRenderer.bounds_text(enemy_target.bounds).contains("×"), "INFO renderer formats sprite position and dimensions")
	expect(game.DebugObjectInspectorSystem.hovered_object(game,game.DebugOverlaySystem.PANEL.get_center()).is_empty(), "debug panel prevents selecting hidden world objects")
	game.free()


## Сценарий: диагностические команды работают поверх мира и не меняют честную карту коллизий.
## Исходное состояние: панель открыта, симуляция запущена, хитбоксы скрыты и noclip выключен.
## Ожидаемый результат: кнопки включают слои, пауза делает шаг, а noclip двигает сквозь стену без перекраски стены.
func test_runtime_debug_overlay_controls_pause_layers_and_noclip() -> void:
	var game := make_game(); game.current_location = "overworld"; game.DebugOverlaySystem.toggle(game)
	game.DebugOverlaySystem.handle_pointer(game,game.DebugOverlaySystem.BUTTONS[1].rect.get_center())
	game.DebugOverlaySystem.handle_pointer(game,game.DebugOverlaySystem.BUTTONS[4].rect.get_center())
	expect(game.get_meta(game.DebugOverlaySystem.META_KEY).hitboxes and is_zero_approx(game.DebugOverlaySystem.simulation_delta(game,0.2)), "debug buttons enable hitboxes and pause the running world")
	game.DebugOverlaySystem.request_step(game)
	expect(is_equal_approx(game.DebugOverlaySystem.simulation_delta(game,0.2),1.0/12.0), "debug frame-step advances exactly one fixed frame")
	var wall: Vector2 = game.BuildingSystem.collision_rects("cottage")[0].get_center(); game.player = wall - Vector2(100,0)
	game.DebugOverlaySystem.toggle_option(game,"noclip"); game.NavigationSystem.move(game,Vector2(100,0))
	expect(game.player == wall and game.NavigationSystem.walkability_reason(game,wall) == "building", "noclip bypasses movement collision while inspector preserves its real reason")
	game.free()


## Сценарий: F10, полигон и конструктор используют общий художественный корпус без потери диагностической цветовой семантики.
## Исходное состояние: общий Debug UI Kit подключён к трём рендерам, недоступная команда остаётся в панели, а визуальный эталон создан на живом уровне.
## Ожидаемый результат: деревянные nine-patch компоненты окружают технические экраны, состояния различимы, а скриншот имеет базовое разрешение игры.
func test_debug_tools_share_storybook_chrome_and_technical_colors() -> void:
	var game := make_game(); var kit_source := FileAccess.get_file_as_string("res://scripts/systems/debug_ui_kit_system.gd")
	expect(kit_source.contains("UiKitSystem.draw_panel") and kit_source.contains("UiKitSystem.draw_button") and kit_source.contains("TECH_GREEN") and kit_source.contains("TECH_GOLD"), "debug kit combines the storybook nine-patch shell with explicit diagnostic accents")
	for renderer_path in ["res://scripts/systems/debug_overlay_renderer.gd","res://scripts/systems/debug_playground_renderer.gd","res://scripts/systems/level_editor_renderer.gd"]:
		expect(FileAccess.get_file_as_string(renderer_path).contains("DebugUiKitSystem"), "%s consumes the shared debug chrome instead of a disconnected flat panel" % renderer_path)
	expect(not game.DebugOverlaySystem.button_enabled("save_patch") and game.DebugOverlaySystem.BUTTONS.any(func(button: Dictionary): return button.action=="save_patch"), "unfinished debug action remains visible with a real disabled state")
	var preview := Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/ui/debug_overlay_ingame_preview.png"))
	expect(preview != null and preview.get_size()==Vector2i(1152,648), "live F10 visual reference covers the shared shell grid hitboxes labels and disabled action")
	game.free()


## Сценарий: справа от бабушки существует честная калитка, совпадающая с видимым маршрутом двора.
## Исходное состояние: герой стоит на высоте бабушки и движется горизонтально через правую сторону фермерского забора.
## Ожидаемый результат: весь коридор калитки проходим, но секции забора выше и ниже по-прежнему блокируют движение.
func test_grandmother_side_gate_stays_walkable() -> void:
	var game := make_game(); game.current_location = "overworld"; game.slime_alive = false; game.enemy_nodes.clear(); game.resource_nodes.clear(); game.food_nodes.clear(); game.world_loot_nodes.clear()
	for x in range(420, 501, 10):
		expect(game.NavigationSystem.walkability_reason(game, Vector2(x, 940)) == "walkable", "grandmother side gate remains walkable at x=%d" % x)
	expect(game.NavigationSystem.walkability_reason(game, Vector2(452, 845)) == "fence" and game.NavigationSystem.walkability_reason(game, Vector2(452, 1040)) == "fence", "solid fence sections remain blocked above and below grandmother gate")
	game.free()


## Сценарий: новый атлас интерьеров, событий, оружия и частиц соблюдает строгую сетку и прозрачность.
## Исходное состояние: движок импортировал PNG 640×512 как ресурс Texture2D.
## Ожидаемый результат: все двадцать ячеек непустые, углы прозрачны и пурпурный chroma-key отсутствует.
func test_world_polish_atlas_has_complete_transparent_grid() -> void:
	var game := make_game(); var image: Image = game.WorldPolishRenderer.ATLAS.get_image(); var filled := true; var chroma := false
	for row in 4:
		for column in 5:
			if not image.get_region(Rect2i(column*128,row*128,128,128)).get_used_rect().has_area(): filled = false
	for y in range(0,image.get_height(),4):
		for x in range(0,image.get_width(),4):
			var pixel: Color = image.get_pixel(x,y); if pixel.a > 0.1 and pixel.r > 0.9 and pixel.b > 0.9 and pixel.g < 0.15: chroma = true
	expect(image.get_size() == Vector2i(640,512) and image.get_pixel(0,0).a < 0.05 and filled and not chroma, "world polish atlas is transparent chroma-free complete 5x4 grid")
	expect(game.ActionEffectVisualSystem.profiles_are_valid(), "sixteen action effects use independent modular 72x72 sprites")
	var action_source:=FileAccess.get_file_as_string("res://scripts/systems/adventure_polish_renderer.gd")
	expect(not action_source.contains("action_effects_atlas.png") and action_source.contains("ActionEffectVisualSystem"), "action feedback no longer samples the fractional source atlas")
	expect(game.WorldPolishRenderer.held_weapon_destination(Vector2.ZERO,Vector2.RIGHT,false).size==Vector2(48,48), "held weapon keeps the documented 48 px animation slot")
	var effects_preview:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/action_effects_catalog.png"))
	expect(effects_preview!=null and effects_preview.get_size()==Vector2i(288,288), "action effect migration keeps a complete four-by-four visual catalog")
	game.free()


## Сценарий: тестер получает пошаговые подсказки для каждой добавленной механики большого этапа.
## Исходное состояние: загружен единый каталог обучающих событий и их русские тексты.
## Ожидаемый результат: личные просьбы, четыре события, мебель и инспектор зарегистрированы и описаны.
func test_expansion_features_have_tutorial_steps() -> void:
	var game := make_game()
	for event in ["personal_request","market_event","festival_event","night_trader","raid_event","interior_furniture","debug_inspector"]:
		expect(event in game.TutorialSystem.STEP_IDS and not game.LocaleSystem.tutorial(event).is_empty(), "expansion feature has tutorial coverage: %s" % event)
	game.free()
