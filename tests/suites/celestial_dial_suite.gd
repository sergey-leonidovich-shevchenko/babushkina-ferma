extends "res://tests/suites/suite_base.gd"

const Clock := preload("res://scripts/presentation/celestial_clock_renderer.gd")
const Hud := preload("res://scripts/presentation/moon_hud_renderer.gd")
const Assets := preload("res://scripts/systems/celestial_dial_assets_system.gd")
const Audit := preload("res://scripts/presentation/moon_ui_audit.gd")
const Hub := preload("res://scripts/systems/menu_hub_system.gd")

## Проверяет непрерывность суток, геометрию светил, паузу, повторное использование слоёв и календарный текст.
func run() -> void:
	test_orbit_and_midnight()
	test_assets_and_localized_calendar()
	test_clock_freezes_and_resumes()

## Сценарий: солнце проходит восход, полдень, закат и полночь, часы пересекают границу дня.
## Исходное состояние: непрерывный угол рассчитывается из номера дня и дробной игровой минуты.
## Ожидаемый результат: тела противоположны, восход слева, положение в полночь меняется лишь на долю градуса.
func test_orbit_and_midnight() -> void:
	var center := Clock.dial_rect(Hud.CLOCK).get_center()
	var positions := [Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN]
	for index in 4:
		var angle := Clock.rotation_angle(1,360+index*360)
		var sun := Clock.body_center(Hud.CLOCK,angle,true)
		var moon := Clock.body_center(Hud.CLOCK,angle,false)
		expect(sun.distance_to(center+positions[index]*Clock.ORBIT_RADIUS)<0.001,"sun rises left and sets right: "+str(index))
		expect((sun+moon).distance_to(center*2)<0.001,"sun and moon are opposite: "+str(index))
	var before := Clock.rotation_angle(999,1439.99)
	var after := Clock.rotation_angle(1000,0.01)
	expect(is_equal_approx(after-before,TAU*0.02/1440.0),"midnight continues the same rotation without a complete-turn jump")
	expect(Clock.body_center(Hud.CLOCK,before,true).distance_to(Clock.body_center(Hud.CLOCK,after,true))<0.003,"midnight visible position stays continuous")
	var earlier := Clock.rotation_angle(1,720)
	var later := Clock.rotation_angle(1,720.016)
	expect(later>earlier and later-earlier<0.001,"fractional game minutes drive movement between integer ticks")
	for index in 4: expect(Clock.moon_phase(1+index*7)==index/4.0,"all four lunar quarters are distinct")
	expect(Clock.moon_phase(29)==Clock.moon_phase(1),"lunar phases repeat after 28 days")

## Сценарий: календарь показывает длинный день и сезон при максимальном масштабе шрифта на всех языках.
## Исходное состояние: три модульных слоя импортированы отдельно, глобальная фильтрация мира остаётся прежней.
## Ожидаемый результат: подпись вписывается, круг не перекрывает кнопку меню, слои повторно используют текстуры.
func test_assets_and_localized_calendar() -> void:
	var game := make_game()
	game.settings_state.text_scale=1.2
	var previous: String = game.LocaleSystem.current
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale,false)
		var checks: Array = Audit.check(game).filter(func(item):return String(item.code).ends_with(".calendar"))
		expect(checks.size()==1 and checks[0].passed,"calendar fits maximum scale in "+locale)
	game.LocaleSystem.set_locale(previous,false)
	for kind in ["sky","frame","landscape"]:
		var texture := Assets.texture(kind)
		expect(texture==Assets.texture(kind),"dial layer is cached: "+kind)
		expect(texture.get_size()==Vector2(512,512) and texture is CanvasTexture,"small independent dial layer: "+kind)
		expect(texture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"painted dial layer owns linear filtering: "+kind)
	expect(not Hud.CLOCK.intersects(Hub.OPEN_BUTTON),"dial and calendar avoid menu button")
	expect(Clock.dial_rect(Hud.CLOCK).get_center().x==Clock.calendar_rect(Hud.CLOCK).get_center().x,"calendar centered under fixed frame")
	game.free()

## Сценарий: рюкзак и обычная пауза открываются перед полуночью, затем игра продолжается.
## Исходное состояние: физический цикл управляет временем; анимация не использует часы компьютера.
## Ожидаемый результат: угол и фаза неизменны в меню, после закрытия появляется плавное движение и обучение.
func test_clock_freezes_and_resumes() -> void:
	var game := make_game()
	game.game_minutes=1439.75; game.day=14
	game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).first_day=6
	var angle := Clock.rotation_angle(game.day,game.game_minutes)
	game.open_inventory()
	for index in 60: game.GameLoop.physics_process(game,1.0/60.0)
	expect(Clock.rotation_angle(game.day,game.game_minutes)==angle,"backpack freezes the whole sky orbit")
	Hub.close(game); game.menu_state.pause_open=true
	game.GameLoop.physics_process(game,1.0)
	expect(Clock.rotation_angle(game.day,game.game_minutes)==angle,"pause freezes the same orbit")
	game.menu_state.pause_open=false; game.GameLoop.physics_process(game,0.3)
	expect(game.day==15 and game.game_minutes<1.0,"resume crosses midnight through real game clock")
	expect(absf(Clock.rotation_angle(game.day,game.game_minutes)-angle-TAU*0.3/1440.0)<0.000001,"resume advances exact elapsed game time")
	expect(game.tutorial_events_completed.has("celestial_clock"),"playing registers localized celestial clock tutorial")
	game.free()
