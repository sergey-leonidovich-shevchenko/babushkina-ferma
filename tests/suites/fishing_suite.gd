extends "res://tests/suites/suite_base.gd"


## Запускает сценарии полного цикла, физики, наград, сохранения и устройств управления рыбалкой.
func run() -> void:
	test_cast_release_hook_and_miss()
	test_bar_inertia_and_fish_behaviors()
	test_season_weather_and_night_ecology()
	test_progress_tutorial_escape_and_success()
	test_quality_treasure_and_collection_save()
	test_gamepad_and_touch_hold_state()


## Сценарий: удержание заряжает заброс, отпускание бросает леску, а сигнал можно подсечь или пропустить.
## Исходное состояние: герой с удочкой стоит у пруда и удерживает кнопку действия.
## Ожидаемый результат: стадии проходят заряд, ожидание, поклёвку и мини-игру, а просрочка сбрасывает цикл.
func test_cast_release_hook_and_miss() -> void:
	var game := _fishing_game()
	game.action_held = true
	expect(game.use_fishing_rod(), "fishing starts cast charge near water")
	game.update_fishing(0.6)
	expect(game.state.fishing.cast_power > 0.45, "held action immediately builds cast power")
	game.action_held = false; game.update_fishing(0.01)
	expect(game.state.fishing.phase == game.FishingSystem.PHASE_WAITING, "release casts the line")
	game.state.fishing.timer = 0.0; game.update_fishing(0.01)
	expect(game.state.fishing.phase == game.FishingSystem.PHASE_BITE, "bite opens a bounded hook window")
	expect(game.use_fishing_rod() and game.state.fishing.phase == game.FishingSystem.PHASE_MINIGAME, "timely hook starts the minigame")
	game.state.fishing.phase = game.FishingSystem.PHASE_BITE; game.state.fishing.timer = 0.01; game.update_fishing(0.02)
	expect(game.state.fishing.phase == game.FishingSystem.PHASE_IDLE, "expired hook window resets fishing")
	game.free()


## Сценарий: дополнительные виды появляются только в своём сезоне, погоде или ночном событии.
## Исходное состояние: календарь и таланты управляемо переключаются между весной, летом, зимой, грозой и затмением.
## Ожидаемый результат: базовая рыба доступна всегда, а редкие виды честно фильтруются средой и снастью.
func test_season_weather_and_night_ecology() -> void:
	var game := _fishing_game(); var fishing: Variant = game.FishingSystem
	var spring: Dictionary = fishing.fish_data("spring_trout"); var catfish: Dictionary = fishing.fish_data("summer_catfish"); var winter: Dictionary = fishing.fish_data("winter_char"); var moon: Dictionary = fishing.fish_data("moon_koi")
	game.day = 1; game.game_minutes = 12.0*60.0
	expect(fishing.habitat_matches(game,spring) and not fishing.habitat_matches(game,catfish),"spring daytime exposes trout but hides summer catfish")
	game.day = 8; game.game_minutes = 21.0*60.0
	expect(fishing.habitat_matches(game,catfish) and not fishing.habitat_matches(game,winter),"summer night exposes catfish but hides winter char")
	game.day = 22; game.game_minutes = 12.0*60.0
	expect(fishing.habitat_matches(game,winter),"winter calendar exposes cold-water char")
	game.day = 5; game.game_minutes = 21.0*60.0
	expect(fishing.habitat_matches(game,moon),"fifth-night eclipse exposes moon koi")
	game.talent_levels.fish_fine_rod = 0; expect(fishing.available_fish(game).all(func(fish): return String(fish.id) != "summer_catfish"),"locked fine-rod fish cannot enter the actual catch pool")
	expect(fishing.FISH_CATALOG.size() == 11,"fishing ecology contains eleven distinct species")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale; expect(not game.LocaleSystem.text("fish_moon_koi").is_empty(),"new fish catalog is localized for %s" % locale)
	game.LocaleSystem.current="ru"; game.free()


## Сценарий: зелёная зона имеет инерцию и отскок, а каталог содержит пять характеров движения рыбы.
## Исходное состояние: зона покоится в середине трека, встроенный каталог полностью загружен.
## Ожидаемый результат: удержание и отпускание меняют скорость, граница отражает её, все характеры доступны.
func test_bar_inertia_and_fish_behaviors() -> void:
	var game := _fishing_game()
	var state = game.state.fishing
	state.bar_y = 0.5; state.bar_velocity = 0.0; state.bar_size = 0.24
	game.FishingSystem._update_catch_bar(state, true, 0.2)
	expect(state.bar_y < 0.5 and state.bar_velocity < 0.0, "holding accelerates catch bar upward")
	game.FishingSystem._update_catch_bar(state, false, 0.3)
	expect(state.bar_velocity > 0.0, "release reverses momentum with gravity")
	state.bar_y = 0.95; state.bar_velocity = 1.0; game.FishingSystem._update_catch_bar(state, false, 0.2)
	expect(state.bar_y <= 0.88 and state.bar_velocity < 0.0, "bottom collision produces softened bounce")
	var behaviors: Array = game.FishingSystem.FISH_CATALOG.map(func(fish): return fish.behavior)
	for behavior in ["mixed", "smooth", "sinker", "floater", "dart"]:
		expect(behavior in behaviors, "fishing catalog contains behavior: %s" % behavior)
	game.free()


## Сценарий: попадание наполняет улов, первый урок не убывает, обычная рыба срывается, полная шкала награждает.
## Исходное состояние: четыре контролируемых положения рыбы и зелёной зоны около границ прогресса.
## Ожидаемый результат: соблюдаются Perfect, защита первого улова, поражение и успешная выдача рыбы.
func test_progress_tutorial_escape_and_success() -> void:
	var tutorial := _active_minigame()
	var state = tutorial.state.fishing
	tutorial.game_minutes = 360.0; tutorial.move_right_held = true; tutorial.update_game_clock(1.0)
	expect(tutorial.game_minutes == 360.0 and tutorial.get_movement_direction() == Vector2.ZERO, "active minigame pauses clock and world movement")
	state.fish_y = state.bar_y; state.fish_target = state.fish_y; state.fish_target_timer = 99.0
	var before: float = state.catch_progress; tutorial.update_fishing(0.1)
	expect(state.catch_progress > before and state.perfect, "fish inside bar fills meter and keeps perfect")
	state.fish_y = 0.05; state.bar_y = 0.85; state.fish_target = 0.05; state.fish_target_timer = 99.0; before = state.catch_progress; tutorial.update_fishing(0.1)
	expect(not state.perfect and is_equal_approx(state.catch_progress, before), "first catch tutorial cannot lose progress")
	tutorial.free()
	var lost := _active_minigame()
	lost.state.fishing.total_caught = 1; lost.state.fishing.catch_progress = 0.001; lost.state.fishing.fish_y = 0.05; lost.state.fishing.bar_y = 0.85; lost.state.fishing.fish_target = 0.05; lost.state.fishing.fish_target_timer = 99.0
	lost.update_fishing(0.1)
	expect(lost.state.fishing.phase == lost.FishingSystem.PHASE_RESULT and lost.fish == 0, "empty meter lets normal fish escape")
	lost.free()
	var caught := _active_minigame()
	caught.state.fishing.catch_progress = 0.999; caught.state.fishing.fish_y = caught.state.fishing.bar_y; caught.state.fishing.fish_target_timer = 99.0; caught.update_fishing(0.1)
	expect(caught.state.fishing.phase == caught.FishingSystem.PHASE_RESULT and caught.fish >= 1, "full meter awards caught fish")
	expect(caught.state.fishing.total_caught >= 1 and not caught.state.fishing.result_text.is_empty(), "success records collection and result")
	caught.free()


## Сценарий: дальность и идеальность повышают качество, сундук имеет свою шкалу, коллекция сохраняется.
## Исходное состояние: чистые расчёты качества, сундук внутри зоны и снимок с рекордом посреди мини-игры.
## Ожидаемый результат: качества соответствуют правилам, сундук собран, статистика загружена в спокойную фазу.
func test_quality_treasure_and_collection_save() -> void:
	var game := _fishing_game()
	expect(game.FishingSystem._quality_for(0.2, true) == "normal", "perfect does not upgrade normal quality")
	expect(game.FishingSystem._quality_for(0.6, true) == "gold", "perfect upgrades silver quality")
	expect(game.FishingSystem._quality_for(0.9, true) == "iridium", "perfect upgrades gold quality")
	var state = game.state.fishing
	state.treasure_visible = true; state.treasure_appears_at = 1.0; state.elapsed = 1.0; state.treasure_y = 0.5; state.bar_y = 0.5; state.bar_size = 0.24
	game.FishingSystem._update_treasure(state, 2.0)
	expect(state.treasure_caught and state.treasure_progress == 1.0, "treasure has independent overlap meter")
	var wood_before: int = game.wood; state.cast_power = 0.5; state.perfect = false; game.FishingSystem._complete_catch(game)
	expect(game.wood == wood_before + 2 and state.treasure_loot == "wood", "caught treasure awards deterministic bonus loot with the fish")
	expect(game.RenderSystem.FishingRenderer.PANEL.end.x <= 1152.0 and game.RenderSystem.FishingRenderer.PANEL.end.y <= 648.0, "fishing panel fits native viewport")
	var renderer_source:=FileAccess.get_file_as_string("res://scripts/systems/fishing_renderer.gd")
	var interface_source:=FileAccess.get_file_as_string("res://scripts/systems/interface_renderer.gd")
	expect(renderer_source.contains("UiKitSystem.draw_modal_panel") and renderer_source.contains("draw_item_icon(\"fish\"") and not renderer_source.contains("draw_colored_polygon(tail") and interface_source.contains("fishing_focus"), "fishing minigame reuses storybook art and suppresses overlapping world cards")
	var preview:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/ui/fishing_ingame_preview.png"))
	expect(preview!=null and preview.get_size()==Vector2i(1152,648), "fishing minigame keeps an exact native storybook UI reference")
	state.total_caught = 7; state.best_sizes = {"river_perch":34}; state.phase = game.FishingSystem.PHASE_MINIGAME
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	var restored := _fishing_game()
	expect(game.SaveSystem.apply(restored, snapshot), "save applies fishing collection")
	expect(restored.state.fishing.total_caught == 7 and restored.state.fishing.best_sizes.river_perch == 34, "catch count and records survive loading")
	expect(restored.state.fishing.phase == restored.FishingSystem.PHASE_IDLE, "transient minigame resets after loading")
	game.free(); restored.free()


## Сценарий: кнопка A и касание передают мини-игре как нажатие, так и отпускание.
## Исходное состояние: открытый мир без модальных окон и два синтетических устройства ввода.
## Ожидаемый результат: состояние удержания синхронно меняется для геймпада и сенсорного экрана.
func test_gamepad_and_touch_hold_state() -> void:
	var game := _fishing_game()
	var pad := InputEventJoypadButton.new(); pad.button_index = JOY_BUTTON_A; pad.pressed = true
	expect(not game.InputSystem.set_pointer_action_state(game, pad, true) and game.action_held, "gamepad starts held fishing control")
	pad.pressed = false
	expect(game.InputSystem.set_pointer_action_state(game, pad, true) and not game.action_held, "gamepad release ends held control")
	var touch := InputEventScreenTouch.new(); touch.pressed = true; game.InputSystem.set_pointer_action_state(game, touch, true)
	expect(game.action_held, "touch starts held fishing control")
	touch.pressed = false; game.InputSystem.set_pointer_action_state(game, touch, true)
	expect(not game.action_held, "touch release ends held control")
	game.free()


## Создаёт героя у пруда с выбранной удочкой для независимых рыбацких сценариев.
func _fishing_game() -> Node:
	var game := make_game()
	game.selected_tool = game.Tool.ROD; game.player = game.pond_position + Vector2(120, 0)
	return game


## Создаёт экземпляр, уже дошедший до управляемой вертикальной мини-игры.
func _active_minigame() -> Node:
	var game := _fishing_game()
	game.state.fishing.phase = game.FishingSystem.PHASE_BITE; game.use_fishing_rod()
	return game
