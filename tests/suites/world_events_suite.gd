extends "res://tests/suites/suite_base.gd"


## Запускает календарные, погодные, фермерские, портальные и визуальные сценарии мировых событий.
func run() -> void:
	test_four_seasons_cycle_every_seven_days()
	test_weather_is_deterministic_and_season_safe()
	test_rain_waters_tilled_plots_on_new_day()
	test_seasons_change_crop_growth_speed()
	test_daylight_darkness_transitions_are_continuous()
	test_eclipse_crosses_midnight_every_five_days()
	test_moon_portal_requires_eclipse_and_returns_home()
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
## Ожидаемый результат: весна ускоряет рост, а зимний холод заметно замедляет его.
func test_seasons_change_crop_growth_speed() -> void:
	var game := make_game(); game.state.world.weather_day = 1; game.state.world.weather = "clear"; game.day = 1
	var spring_speed: float = game.WorldEventSystem.crop_growth_multiplier(game)
	game.day = 22; game.state.world.weather_day = 22; game.state.world.weather = "clear"
	var winter_speed: float = game.WorldEventSystem.crop_growth_multiplier(game)
	expect(spring_speed == 1.15 and winter_speed == 0.55 and spring_speed > winter_speed, "seasonal crop rates reward spring and challenge winter")
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


## Сценарий: оба новых атласа отдают отдельные непересекающиеся ячейки.
## Исходное состояние: сезонный и событийный листы импортированы как сетки четыре на два.
## Ожидаемый результат: восемь ячеек каждого листа имеют одинаковый размер и уникальное начало.
func test_event_atlases_expose_unique_grid_cells() -> void:
	var game := make_game(); var seasonal := {}; var eclipse := {}
	for row in 2:
		for column in 4:
			var seasonal_rect: Rect2 = game.VisualAssetSystem.seasonal_source(column, row == 1)
			var eclipse_rect: Rect2 = game.VisualAssetSystem.eclipse_source(column, row == 1)
			seasonal[str(seasonal_rect.position)] = true; eclipse[str(eclipse_rect.position)] = true
			expect(seasonal_rect.size == Vector2(313.5, 627.0), "seasonal atlas exposes validated cell %d:%d" % [column, row])
			expect(eclipse_rect.size == Vector2(313.5, 627.0), "eclipse atlas exposes validated cell %d:%d" % [column, row])
	expect(seasonal.size() == 8 and eclipse.size() == 8, "generated seasonal and eclipse sprites never share a source cell")
	game.free()


## Сценарий: крупные сезонные и лунные объекты нельзя проходить насквозь.
## Исходное состояние: герой проверяет основание сезонного дерева в деревне и кристалла на Лунной поляне.
## Ожидаемый результат: оба основания блокируются, а точка возвратного портала остаётся проходимой.
func test_large_event_props_have_collisions() -> void:
	var game := make_game()
	expect(not game.NavigationSystem.is_walkable(game, game.VisualAssetSystem.SEASONAL_TREE_BASE), "seasonal landmark tree owns a matching solid base")
	game.current_location = "moon_glade"
	expect(not game.NavigationSystem.is_walkable(game, game.VisualAssetSystem.MOON_SOLID_BASES[0]), "moon crystal and altar props participate in navigation")
	expect(game.NavigationSystem.is_walkable(game, game.WorldEventSystem.RETURN_PORTAL_POSITION), "moon glade return portal remains reachable")
	game.free()


## Сценарий: тестер может пройти последовательные подсказки каждой новой механики.
## Исходное состояние: каталог обучения загружен вместе с переводами.
## Ожидаемый результат: сезон, погода, ночь, затмение и портал имеют шаг и непустой русский текст.
func test_event_tutorial_covers_each_new_feature() -> void:
	var game := make_game()
	for event_name in ["season", "weather", "night", "eclipse", "moon_portal"]:
		expect(game.TutorialSystem.STEP_IDS.has(event_name), "tutorial includes world event step: %s" % event_name)
		expect(game.LocaleSystem.tutorial(event_name) != event_name, "tutorial explains world event in Russian: %s" % event_name)
	game.free()
