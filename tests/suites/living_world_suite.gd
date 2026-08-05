extends "res://tests/suites/suite_base.gd"


## Запускает контрактные тесты живой деревни, животных и изолированного полигона отладки.
func run() -> void:
	test_village_has_distinct_connected_districts()
	test_village_palette_covers_every_season()
	test_wildlife_atlases_follow_shared_contract()
	test_wildlife_runtime_has_reactions_and_death()
	test_debug_playground_controls_world_state()
	test_debug_collision_and_enemy_factory()


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
