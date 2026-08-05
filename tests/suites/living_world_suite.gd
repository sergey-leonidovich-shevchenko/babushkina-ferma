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
	test_world_polish_atlas_has_complete_transparent_grid()
	test_expansion_features_have_tutorial_steps()


## Сценарий: первая карта делится на районы, а ключевые двери остаются связаны дорогами.
## Исходное состояние: загружена статическая схема деревни с шестью кварталами.
## Ожидаемый результат: районы различимы, а дом, магазин и гильдия достигаются дорожной сетью.
func test_village_has_distinct_connected_districts() -> void:
	var game := make_game(); var layout = game.VillageLayoutSystem
	expect(layout.DISTRICTS.size() == 6 and layout.district_at(Vector2(1050,430)) == "market" and layout.district_at(Vector2(1450,430)) == "guild", "village exposes six readable functional districts")
	for point in [Vector2(330,950),Vector2(1050,370),Vector2(1450,370)]: expect(layout.path_reaches(point), "village road reaches service landmark: %s" % point)
	expect(layout.is_water(Vector2(1200,layout.river_center_y(1200)),18.0) and not layout.is_water(layout.BRIDGES[0].get_center(),18.0), "river blocks movement while bridge preserves navigation")
	expect(layout.blocks_scenic_prop(layout.BORDER_TREES[0] + Vector2(0,28),18.0) and layout.blocks_scenic_prop(layout.BORDER_ROCKS[0],18.0), "visible village border trees and rocks own matching collision shapes")
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
		var props: Array = game.InteriorRenderer.PROPS[location]; first_cells.append(props[0].cell)
		expect(not game.BuildingSystem.is_walkable_inside(location,props[0].position,game.PLAYER_RADIUS), "interior furniture owns collision: %s" % location)
		var data: Dictionary = game.BuildingSystem.INTERIORS[location]
		expect(game.BuildingSystem.is_walkable_inside(location,data.exit-Vector2(0,35),game.PLAYER_RADIUS) and game.BuildingSystem.is_walkable_inside(location,data.get("service_position",data.exit),game.PLAYER_RADIUS), "exit and front service remain reachable: %s" % location)
	expect(first_cells.duplicate().all(func(cell): return first_cells.count(cell) == 1), "main interiors use four distinct thematic prop cells")
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
	game.free()


## Сценарий: тестер получает пошаговые подсказки для каждой добавленной механики большого этапа.
## Исходное состояние: загружен единый каталог обучающих событий и их русские тексты.
## Ожидаемый результат: личные просьбы, четыре события, мебель и инспектор зарегистрированы и описаны.
func test_expansion_features_have_tutorial_steps() -> void:
	var game := make_game()
	for event in ["personal_request","market_event","festival_event","night_trader","raid_event","interior_furniture","debug_inspector"]:
		expect(event in game.TutorialSystem.STEP_IDS and not game.LocaleSystem.tutorial(event).is_empty(), "expansion feature has tutorial coverage: %s" % event)
	game.free()
