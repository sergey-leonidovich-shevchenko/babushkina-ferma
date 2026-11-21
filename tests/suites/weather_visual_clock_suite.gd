# Сценарии работают с настоящим динамическим игровым фасадом.
@warning_ignore_start("untyped_declaration", "unsafe_method_access", "unsafe_property_access")
extends RefCounted

const Clock := preload("res://scripts/presentation/weather_visual_clock.gd")
const Frame := preload("res://scripts/presentation/post_motion_frame.gd")
const Fixture := preload("res://tests/suites/post_motion_frame_suite.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Editor := preload("res://scripts/systems/level_editor_system.gd")
const Producer := preload("res://tools/qa/world/weather/scenarios.gd")


## Проверяет реальные такты, границы визита и неизменность игрового сохранения.
static func run(context: SceneTree) -> void:
	_ticks_and_pause(context)
	_transitions_and_load(context)
	_ownership_and_invalid_data(context)
	_long_repeat(context)
	_producer_seed(context)


## Сценарий: настоящая смена скрипта QA-сцены не теряет её закреплённый seed.
## Иначе полный snapshot старой/новой версии содержал бы случайную добычу.
static func _producer_seed(c: SceneTree) -> void:
	var game := Producer.create(c.root, "rain")
	c.expect(
		game.world_loot_seed == 20261015, "actual producer restores seed after script replacement"
	)
	var saved: Dictionary = game.SaveSystem.snapshot(game)
	c.expect(saved.world_loot_seed == 20261015, "actual producer snapshot has the fixed world seed")
	game.free()


## Сценарий: после разрешённого такта все чтения возвращают одну фазу.
## Пауза, окна и ограничение движения не создают долг при возвращении.
static func _ticks_and_pause(c: SceneTree) -> void:
	var g := Fixture.fixture()
	c.expect(Clock.seconds(g) == 0.0 and not g.has_meta(Clock.META), "cold weather read is pure")
	g._physics_process(0.02)
	c.expect(
		is_equal_approx(Clock.seconds(g), 0.02), "actual post-motion tick advances weather once"
	)
	c.expect(
		Clock.seconds(g) == Frame.read(g).seconds, "first-map clocks agree after ordinary tick"
	)
	var snapshot: Dictionary = g.SaveSystem.snapshot(g)
	var value: Dictionary = g.get_meta(Clock.META)
	for index in 120:
		Clock.seconds(g)
	c.expect(g.get_meta(Clock.META) == value, "repeated render reads never advance weather")
	c.expect(
		g.SaveSystem.snapshot(g) == snapshot, "render reads preserve the full gameplay snapshot"
	)
	for mode: String in ["manual", "inventory", "focus", "editor", "reduced", "reference"]:
		match mode:
			"manual":
				g.menu_state.pause_open = true
			"inventory":
				g.inventory_open = true
			"focus":
				g.settings_state.pause_on_focus_loss = true
				g._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"editor":
				g.set_meta(Editor.META_KEY, {"active": true})
			"reduced":
				g.settings_state.reduced_motion = true
			"reference":
				Reference.enable(g)
		var before := Clock.seconds(g)
		for index in 3:
			g._physics_process(0.02)
		c.expect(Clock.seconds(g) == before, mode + " freezes precipitation phase")
		g.MenuSystem.resume(g)
		g.inventory_open = false
		g._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		g.settings_state.pause_on_focus_loss = false
		g.remove_meta(Editor.META_KEY)
		g.settings_state.reduced_motion = false
		Reference.disable(g)
		g._physics_process(0.02)
		c.expect(
			is_equal_approx(Clock.seconds(g), before + 0.02), mode + " resumes without catch-up"
		)
	g.free()


## Сценарий: настоящий вход/выход дома сбрасывает старый визит ещё до следующего такта.
## Загрузка той же карты тоже не восстанавливает декоративное время из save.
static func _transitions_and_load(c: SceneTree) -> void:
	var g := Fixture.fixture()
	g._physics_process(0.02)
	c.expect(g.BuildingSystem.enter(g, "cottage"), "actual cottage entry succeeds")
	c.expect(
		Clock.seconds(g) == 0.0 and not g.has_meta(Clock.META),
		"door discards previous weather visit"
	)
	g._physics_process(0.02)
	c.expect(is_equal_approx(Clock.seconds(g), 0.02), "destination owns a fresh local phase")
	c.expect(g.BuildingSystem.leave(g), "actual cottage return succeeds")
	c.expect(Clock.seconds(g) == 0.0, "return cannot revive the older overworld phase")
	g._physics_process(0.02)
	var saved: Dictionary = g.SaveSystem.snapshot(g)
	Clock.advance(g, 12.0)
	c.expect(g.SaveSystem.snapshot(g) == saved, "visual time is absent from full save")
	c.expect(g.SaveSystem.apply(g, saved), "actual save reload succeeds")
	c.expect(
		Clock.seconds(g) == 0.0 and not g.has_meta(Clock.META),
		"same-map load clears transient phase"
	)
	g.free()


## Сценарий: второй мир не принимает чужие часы, повреждения или недопустимые delta.
## Временные данные остаются числовыми и не владеют ресурсами/узлами.
static func _ownership_and_invalid_data(c: SceneTree) -> void:
	var a := Fixture.fixture()
	var b := Fixture.fixture()
	a._physics_process(0.02)
	b._physics_process(0.04)
	var valid: Dictionary = a.get_meta(Clock.META)
	c.expect(valid.is_read_only() and valid.size() == 5, "clock owns one bounded immutable value")
	b.set_meta(Clock.META, valid)
	c.expect(Clock.seconds(b) == 0.0, "another game cannot reuse the first clock")
	for field: String in ["game", "viewport", "background", "world", "seconds"]:
		var bad := valid.duplicate()
		bad[field] = "foreign" if field == "world" else -1
		bad.make_read_only()
		a.set_meta(Clock.META, bad)
		c.expect(Clock.seconds(a) == 0.0, "invalid clock field rejected: " + field)
	for bad: Variant in [{}, [], null, 4.0, valid.duplicate()]:
		a.set_meta(Clock.META, bad)
		c.expect(Clock.seconds(a) == 0.0, "invalid or mutable metadata cannot supply time")
	for seconds: float in [NAN, INF, -1.0]:
		var bad := valid.duplicate()
		bad.seconds = seconds
		bad.make_read_only()
		a.set_meta(Clock.META, bad)
		c.expect(Clock.seconds(a) == 0.0, "non-finite or negative phase cannot reach draw")
	a.set_meta(Clock.META, valid)
	for delta: float in [0.0, -1.0, NAN, INF]:
		Clock.advance(a, delta)
		c.expect(a.get_meta(Clock.META) == valid, "invalid delta cannot move or replace clock")
	c.expect(is_equal_approx(Clock.seconds(a), 0.02), "negative controls preserve the valid phase")
	a.free()
	b.free()


## Сценарий: много разрешённых шагов не создают коллекцию частиц или настенный таймер.
## Это проверка логики часов, а не измерение FPS или длительная игровая сессия.
static func _long_repeat(c: SceneTree) -> void:
	var g := Fixture.fixture()
	var saved: Dictionary = g.SaveSystem.snapshot(g)
	for index in 36000:
		Clock.advance(g, 1.0)
	c.expect(Clock.seconds(g) == 36000.0, "ten simulated hours retain an exact finite phase")
	c.expect(g.get_meta(Clock.META).size() == 5, "long repeat retains only one bounded clock")
	c.expect(g.SaveSystem.snapshot(g) == saved, "long clock repeat preserves gameplay and RNG")
	g.free()
