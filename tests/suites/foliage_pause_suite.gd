extends RefCounted

const Scenario := preload("res://tests/helpers/foliage_pause_scenario.gd")
const Wind := Scenario.Wind


## Проверяет все реальные причины паузы, независимость от частоты и возврат без накопленного времени.
static func run(context: SceneTree) -> void:
	for mode in Scenario.MODES:
		for delta in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
			_test_mode(context, mode, delta)
	_test_focus_policy(context)


## Сценарий: каждое штатное окно останавливает визуальный и игровой state при трёх частотах шага.
## Исходное состояние: настоящая сцена с активным контактом травы, открытое существующим API окно.
## Ожидаемый результат: 36 шагов сохраняют все поля; возврат продвигает только один delta без нового target.
static func _test_mode(context: SceneTree, mode: String, delta: float) -> void:
	var game := Scenario.create(context)
	var opened := Scenario.enter(game, mode)
	context.expect(opened, "existing UI/API opens: " + mode)
	if not opened:
		Scenario.leave(game)
		game.free()
		return
	Scenario.step(game, delta)
	var frozen := Scenario.observe(game)
	var saved: Dictionary = game.SaveSystem.snapshot(game)
	for index in 36:
		Scenario.step(game, delta)
		var actual := Scenario.observe(game)
		context.expect(actual == frozen, "all visual state freezes: " + mode)
		context.expect(game.SaveSystem.snapshot(game) == saved, "all save fields freeze: " + mode)
	context.expect(frozen.statistics.owners <= 1 and frozen.statistics.groups <= 2, "bounded owners and groups: " + mode)
	Scenario.leave(game)
	if mode in ["cabinet", "storage"]:
		# Дом не продвигает часы первой карты; обычный возврат проверяется отдельно в VRELEASE-003.
		game.current_location = "overworld"
		game.player = Wind.placements()[6].anchor + Vector2(-12, 0)
		game.sync_background_location()
		game.update_camera()
		Scenario.Pose.reset(game)
	Scenario.step(game, delta)
	context.expect(
		is_equal_approx(Wind.Clock.seconds(game), float(frozen.seconds) + delta),
		"resume advances exactly one current delta, no pause debt: " + mode
	)
	var resumed := Scenario.observe(game)
	context.expect(resumed.statistics.owners == 1 and resumed.statistics.builds == 1, "resume reuses the bounded target: " + mode)
	game.free()


## Сценарий: разрешённая работа в фоне отличается от автопаузы, а ручной рюкзак сохраняется при возврате.
## Исходное состояние: настоящая сцена с выключенной автопаузой; затем открыт рюкзак с потерей фокуса.
## Ожидаемый результат: opt-out продвигает clock; focus-in не закрывает рюкзак и не отменяет его паузу.
static func _test_focus_policy(context: SceneTree) -> void:
	var game := Scenario.create(context)
	game.settings_state.pause_on_focus_loss = false
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var before := Wind.Clock.seconds(game)
	Scenario.step(game, 0.02)
	context.expect(is_equal_approx(Wind.Clock.seconds(game), before + 0.02), "explicit focus opt-out keeps simulation clock running")
	Scenario.enter(game, "focus_inventory")
	before = Wind.Clock.seconds(game)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	Scenario.step(game, 0.1)
	context.expect(game.inventory_open and Wind.Clock.seconds(game) == before, "focus return preserves manual inventory pause")
	Scenario.leave(game)
	game.free()
