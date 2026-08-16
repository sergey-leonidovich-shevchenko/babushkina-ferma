extends "res://tests/suites/suite_base.gd"


## Запускает календарные, погодные, фермерские, портальные и визуальные сценарии мировых событий.
func run() -> void:
	test_four_seasons_cycle_every_seven_days()
	test_weather_is_deterministic_and_season_safe()
	test_weather_by_location_does_not_mutate_state()
	test_rain_waters_tilled_plots_on_new_day()
	test_seasons_change_crop_growth_speed()
	test_carrots_are_dormant_in_winter()
	test_daylight_darkness_transitions_are_continuous()
	test_eclipse_crosses_midnight_every_five_days()
	test_moon_portal_requires_eclipse_and_returns_home()
	test_moon_glade_adventure_unlocks_in_order()
	test_eclipse_guardian_combat_and_treasure_reward()
	test_moon_glade_state_survives_save_and_resets_next_eclipse()
	test_event_atlases_expose_unique_grid_cells()
	test_large_event_props_have_collisions()
	test_event_tutorial_covers_each_new_feature()


## Сценарий: календарь проходит четыре сезона и начинает новый год.
## Исходное состояние: проверяются первые дни каждой семидневной границы.
## Ожидаемый результат: весна, лето, осень и зима идут в строгом порядке и повторяются с дня 29.
func test_four_seasons_cycle_every_seven_days() -> void:
	var game := make_game(); var system = game.WorldEventSystem
	expect(system.season(1) == "spring" and system.season(7) == "spring", "spring owns calendar days one through seven")
	expect(system.season(8) == "summer" and system.season(15) == "autumn", "summer and autumn start on seven-day boundaries")
	expect(system.season(22) == "winter" and system.season(29) == "spring", "winter completes a repeating twenty-eight-day year")
	game.free()


## Сценарий: редкое приключение последовательно открывает цветок, кристалл, три эха, алтарь и Стража.
## Исходное состояние: пятый день, 20:00, герой только что входит в свежий портал Лунной поляны.
## Ожидаемый результат: нельзя перескочить этап, а каждое верное взаимодействие открывает ровно следующую цель.
func test_moon_glade_adventure_unlocks_in_order() -> void:
	var game := make_game(); game.day = 5; game.game_minutes = 1200.0; game.current_location = "overworld"; game.player = game.WorldEventSystem.PORTAL_POSITION
	expect(game.WorldEventSystem.use_portal(game), "fresh eclipse opens the moon glade adventure")
	var system = game.MoonGladeSystem; var state: Dictionary = game.state.world.moon_glade
	expect(state.event_day == 5 and system.objective(game) == game.LocaleSystem.text("moon_objective_flower"), "new run starts with the moon flower objective")
	expect(not system.interact(game, "moon_altar"), "altar cannot bypass the exploration sequence")
	game.player = system.FLOWER_POSITION; expect(system.interact(game, "moon_flower"), "moon flower starts the ritual route")
	game.player = system.CRYSTAL_POSITION; expect(system.interact(game, "moon_crystal"), "charged crystal reveals lunar echoes")
	for index in system.ECHO_POSITIONS.size():
		game.player = system.ECHO_POSITIONS[index]
		expect(system.interact(game, "moon_echo:%d" % index), "lunar echo can be calmed: %d" % index)
	expect(system.echoes_complete(state), "all three echoes are tracked independently")
	game.player = system.ALTAR_POSITION; expect(system.interact(game, "moon_altar"), "completed echoes awaken the eclipse guardian")
	expect(state.guardian_alive and state.guardian_hp == system.GUARDIAN_MAX_HP, "guardian begins with full event health")
	game.free()


## Сценарий: Страж наносит урон, блокирует проход, погибает от обычной атаки и открывает уникальную награду.
## Исходное состояние: алтарь активирован, герой с кристальным мечом стоит рядом с полностью здоровым Стражем.
## Ожидаемый результат: общий боевой расчёт работает, сундук выдаётся один раз, а талисман повышает HP и урон.
func test_eclipse_guardian_combat_and_treasure_reward() -> void:
	var game := make_game(); var system = game.MoonGladeSystem
	game.current_location = "moon_glade"; game.state.world.moon_glade = system.default_state(); game.state.world.moon_glade.event_day = 5
	game.state.world.moon_glade.altar_activated = true; game.state.world.moon_glade.guardian_alive = true
	game.player = system.GUARDIAN_POSITION - Vector2(50, 0); game.equipped_weapon = "crystal_sword"
	var hp_before: int = game.player_hp; game.state.world.moon_glade.guardian_attack_timer = 0.0; system.update(game, 0.1)
	expect(game.player_hp == hp_before and game.state.world.moon_glade.guardian_windup > 0.0, "active eclipse guardian telegraphs ranged combat damage")
	system.update(game, 0.5)
	expect(game.player_hp < hp_before, "eclipse guardian deals damage on its visible contact frame")
	expect(not game.NavigationSystem.is_walkable(game, system.GUARDIAN_POSITION), "active guardian has solid collision")
	while game.state.world.moon_glade.guardian_alive:
		expect(system.attack_guardian(game), "normal held attack damages the eclipse guardian")
	expect(game.state.world.moon_glade.guardian_defeated, "zero guardian health unlocks the lunar chest")
	var coins_before: int = game.coins; game.player = system.CHEST_POSITION
	expect(system.interact(game, "moon_chest"), "unlocked lunar chest completes the expedition")
	expect(game.coins == coins_before + 120 and game.inventory_item_count("blue_gem") == 2 and game.inventory_item_count("healing_potion") == 1, "treasure grants guaranteed repeatable rewards")
	expect(game.inventory_item_count("eclipse_core") == 1 and not system.interact(game, "moon_chest"), "first clear grants one unique heart and chest cannot duplicate")
	var old_max_hp: int = game.player_max_hp; expect(game.InventorySystem.equip(game, "eclipse_core"), "eclipse heart equips into the ring slot")
	expect(game.player_max_hp == old_max_hp + 15 and game.InventorySystem.damage_bonus(game) >= 2, "eclipse heart grants documented health and damage")
	expect(game.tutorial_events_completed.has("moon_guardian") and game.tutorial_events_completed.has("moon_treasure"), "boss and treasure have tutorial coverage")
	game.free()


## Сценарий: незавершённая экспедиция сохраняется, а следующее затмение создаёт новый маршрут.
## Исходное состояние: на пятом дне собран цветок и успокоено одно эхо; снимок загружается в новую игру.
## Ожидаемый результат: прогресс восстанавливается точно, в день 10 сбрасывается, число прошлых побед не теряется.
func test_moon_glade_state_survives_save_and_resets_next_eclipse() -> void:
	var game := make_game(); var system = game.MoonGladeSystem
	game.day = 5; game.game_minutes = 1300.0; game.current_location = "moon_glade"; system.prepare(game)
	game.state.world.moon_glade.flower_collected = true; game.state.world.moon_glade.crystal_charged = true; game.state.world.moon_glade.echoes[0] = true; game.state.world.moon_glade.completed_runs = 2
	var snapshot: Dictionary = game.SaveSystem.snapshot(game); var loaded := make_game()
	expect(loaded.SaveSystem.apply(loaded, snapshot), "save containing moon glade progress loads")
	expect(loaded.state.world.moon_glade.event_day == 5 and loaded.state.world.moon_glade.echoes[0] and not loaded.state.world.moon_glade.echoes[1], "partial ritual state survives save roundtrip")
	loaded.day = 10; loaded.game_minutes = 1200.0; system.prepare(loaded)
	expect(not loaded.state.world.moon_glade.flower_collected and loaded.state.world.moon_glade.completed_runs == 2 and loaded.state.world.moon_glade.event_day == 10, "next eclipse resets route but preserves lifetime victories")
	game.free(); loaded.free()


## Сценарий: один и тот же день всегда получает одинаковую допустимую погоду.
## Исходное состояние: перебирается полный игровой год из двадцати восьми дней.
## Ожидаемый результат: результат повторяем, зимой не бывает дождя, а снег не выпадает вне зимы.
func test_weather_is_deterministic_and_season_safe() -> void:
	var game := make_game(); var system = game.WorldEventSystem
	for day in range(1, 29):
		var value: String = system.weather_for_day(day)
		expect(value == system.weather_for_day(day), "daily weather is deterministic on day %d" % day)
		expect(not (system.season(day) == "winter" and value in ["rain", "storm"]), "winter excludes rain on day %d" % day)
		expect(value != "snow" or system.season(day) == "winter", "snow remains a winter-only weather on day %d" % day)
	game.free()


## Сценарий: локальный прогноз по локации не изменяет глобальное состояние погоды.
## Исходное состояние: глобальная погода в явном режиме и локация игрока — overworld.
## Ожидаемый результат: запрос для леса не ломает сохранённое состояние, а локальный запрос стабилен.
func test_weather_by_location_does_not_mutate_state() -> void:
	var game := make_game(); var system = game.WorldEventSystem
	game.current_location = "overworld"
	game.day = 8
	game.state.world.weather_day = 4
	game.state.world.weather = "clear"
	var overworld_state: String = game.state.world.weather
	var before_day: int = game.state.world.weather_day
	var forest_local: String = system.weather(game, "forest")
	expect(system.WEATHER_NAMES.has(forest_local), "local location weather has a valid key")
	expect(game.state.world.weather == overworld_state and game.state.world.weather_day == before_day, "location query keeps world weather unchanged")
	var forest_local_two: String = system.weather(game, "forest")
	expect(forest_local == forest_local_two, "location query is deterministic and repeatable")
	var current_weather: String = system.weather(game)
	var expected_current: String = system.location_weather(game.day, "overworld")
	expect(current_weather == expected_current, "global query for current location resolves by deterministic overworld profile")
	game.free()


## Сценарий: начало дождливого дня заменяет ручной полив подготовленной грядки.
## Исходное состояние: первая грядка вспахана и суха, календарь принудительно переходит на дождливый день.
## Ожидаемый результат: погодное обновление помечает грядку политой только один раз на новом дне.
func test_rain_waters_tilled_plots_on_new_day() -> void:
	var game := make_game(); var rainy_day := 1
	while game.WorldEventSystem.weather_for_day(rainy_day) not in ["rain", "storm"]: rainy_day += 1
	var cell := Vector2i.ZERO; game.plots[cell].tilled = true; game.plots[cell].watered = false
	game.day = rainy_day; game.state.world.weather_day = rainy_day - 1
	game.WorldEventSystem.update(game)
	expect(game.plots[cell].watered, "rain automatically waters prepared farmland at day change")
	game.free()


## Сценарий: одинаковая политая культура растёт с сезонным коэффициентом.
## Исходное состояние: погода зафиксирована ясной, сравниваются весенний и зимний множители.
## Ожидаемый результат: весна ускоряет рост, а зимой множитель полностью останавливает культуру.
func test_seasons_change_crop_growth_speed() -> void:
	var game := make_game(); game.state.world.weather_day = 1; game.state.world.weather = "clear"; game.day = 1
	var spring_speed: float = game.WorldEventSystem.crop_growth_multiplier(game)
	game.day = 22; game.state.world.weather_day = 22; game.state.world.weather = "clear"
	var winter_speed: float = game.WorldEventSystem.crop_growth_multiplier(game)
	expect(spring_speed == 1.15 and winter_speed == 0.0 and spring_speed > winter_speed, "seasonal crop rates reward spring and stop outdoor crops in winter")
	game.free()


## Сценарий: политая морковь не растёт даже при большом реальном delta в зимний день.
## Исходное состояние: первая грядка посажена, полита и имеет незавершённую первую стадию; календарь установлен на день 22.
## Ожидаемый результат: рост, стадия и полив остаются неизменными, пока не наступит весна.
func test_carrots_are_dormant_in_winter() -> void:
	var game := make_game(); var cell := Vector2i.ZERO
	game.day = 22; game.state.world.weather_day = 22; game.state.world.weather = "snow"
	game.plots[cell].tilled = true; game.plots[cell].planted = true; game.plots[cell].watered = true
	game.plots[cell].growth = 4.0; game.plots[cell].stage = 0
	game.FarmSystem.update(game, 30.0)
	expect(game.plots[cell].growth == 4.0 and game.plots[cell].stage == 0, "winter update keeps planted carrot growth completely frozen")
	expect(game.plots[cell].watered, "winter dormancy does not consume the second-watering state")
	game.free()


## Сценарий: освещение соответствует утру, дню, сумеркам и ночи.
## Исходное состояние: используются фиксированные отметки игрового времени.
## Ожидаемый результат: день светлый, ночь затемнена, а переходы имеют промежуточную яркость.
func test_daylight_darkness_transitions_are_continuous() -> void:
	var game := make_game(); var system = game.WorldEventSystem
	expect(system.darkness(12.0 * 60.0) == 0.0, "midday has no artificial darkness")
	expect(system.darkness(21.0 * 60.0) > 0.6 and system.is_night(21.0 * 60.0), "late evening uses the night atmosphere")
	var dusk: float = system.darkness(19.0 * 60.0)
	expect(dusk > 0.0 and dusk < system.darkness(21.0 * 60.0), "dusk smoothly bridges day and night")
	game.free()


## Сценарий: редкое затмение начинается вечером пятого дня и заканчивается после полуночи.
## Исходное состояние: проверяются соседние минуты четвёртого, пятого и шестого дней.
## Ожидаемый результат: событие активно с 20:00 до 02:00 и отсутствует за границами окна.
func test_eclipse_crosses_midnight_every_five_days() -> void:
	var game := make_game(); var system = game.WorldEventSystem
	expect(not system.eclipse_active(5, 1199.0) and system.eclipse_active(5, 1200.0), "eclipse starts exactly at 20:00 on event day")
	expect(system.eclipse_active(6, 119.0) and not system.eclipse_active(6, 120.0), "eclipse continues after midnight and ends at 02:00")
	expect(not system.eclipse_active(4, 1300.0), "ordinary nights do not expose the rare event")
	game.free()


## Сценарий: портал скрыт обычной ночью, но переносит героя туда и обратно во время затмения.
## Исходное состояние: герой стоит у восточной точки портала на пятом дне после 20:00.
## Ожидаемый результат: вход ведёт на Лунную поляну, повторное взаимодействие возвращает в деревню.
func test_moon_portal_requires_eclipse_and_returns_home() -> void:
	var game := make_game(); game.player = game.WorldEventSystem.PORTAL_POSITION; game.day = 4; game.game_minutes = 21.0 * 60.0
	expect(game.WorldEventSystem.nearest_interaction(game, 92.0).is_empty(), "moon portal stays unavailable outside an eclipse")
	game.day = 5
	expect(game.WorldEventSystem.nearest_interaction(game, 92.0) == "moon_portal", "eclipse exposes portal interaction in the village")
	expect(game.WorldEventSystem.use_portal(game) and game.current_location == "moon_glade", "portal enters the moonlit event location")
	game.player = game.WorldEventSystem.RETURN_PORTAL_POSITION
	expect(game.WorldEventSystem.use_portal(game) and game.current_location == "overworld", "return portal safely restores the village")
	game.free()


## Сценарий: сезонные и лунные объекты используют самостоятельные модульные изображения.
## Исходное состояние: дробные исходные листы воспроизводимо разделены на шестнадцать runtime-спрайтов.
## Ожидаемый результат: все текстуры имеют уникальный путь, прозрачные углы и размер своего профиля.
func test_event_atlases_expose_unique_grid_cells() -> void:
	var game := make_game(); var paths:={}
	for kind in game.EnvironmentVisualSystem.TEXTURES:
		if not (kind.begins_with("tree_") or kind.begins_with("ground_") or kind.begins_with("moon_")): continue
		var texture:Texture2D=game.EnvironmentVisualSystem.texture(kind); var image:Image=texture.get_image()
		paths[texture.resource_path]=true
		expect(game.EnvironmentVisualSystem.profile_is_valid(kind), "%s owns a modular profile matching its independent texture"%kind)
		expect(image.get_pixel(0,0).a<0.05 and image.get_pixel(image.get_width()-1,image.get_height()-1).a<0.05, "%s keeps crop-safe transparent corners"%kind)
	expect(paths.size()==16, "seasonal and moon runtime objects use sixteen independent sprites")
	game.free()


## Сценарий: крупные сезонные и лунные объекты нельзя проходить насквозь.
## Исходное состояние: герой проверяет основание сезонного дерева в деревне и кристалла на Лунной поляне.
## Ожидаемый результат: оба основания блокируются, а точка возвратного портала остаётся проходимой.
func test_large_event_props_have_collisions() -> void:
	var game := make_game()
	expect(not game.NavigationSystem.is_walkable(game, game.EnvironmentVisualSystem.SEASONAL_TREE_BASE), "seasonal landmark tree owns a matching solid base")
	game.current_location = "moon_glade"
	expect(not game.NavigationSystem.is_walkable(game, game.EnvironmentVisualSystem.MOON_SOLID_BASES[0]), "moon crystal and altar props participate in navigation")
	expect(game.NavigationSystem.is_walkable(game, game.WorldEventSystem.RETURN_PORTAL_POSITION), "moon glade return portal remains reachable")
	game.free()


## Сценарий: тестер может пройти последовательные подсказки каждой новой механики.
## Исходное состояние: каталог обучения загружен вместе с переводами.
## Ожидаемый результат: календарь, портал и шесть этапов экспедиции имеют шаг и непустой русский текст.
func test_event_tutorial_covers_each_new_feature() -> void:
	var game := make_game()
	for event_name in ["season", "weather", "night", "eclipse", "moon_portal", "moon_flower", "moon_crystal", "moon_echoes", "moon_altar", "moon_guardian", "moon_treasure"]:
		expect(game.TutorialSystem.STEP_IDS.has(event_name), "tutorial includes world event step: %s" % event_name)
		expect(game.LocaleSystem.tutorial(event_name) != event_name, "tutorial explains world event in Russian: %s" % event_name)
	game.free()
