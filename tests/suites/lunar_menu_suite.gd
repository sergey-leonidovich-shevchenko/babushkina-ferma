extends "res://tests/suites/suite_base.gd"

const Hub := preload("res://scripts/systems/menu_hub_system.gd")
const Journal := preload("res://scripts/systems/quest_journal_system.gd")
const Clock := preload("res://scripts/presentation/celestial_clock_renderer.gd")
const Hud := preload("res://scripts/presentation/moon_hud_renderer.gd")

## Проверяет остановку настоящего игрового кадра, общий ввод меню, историю заданий и небесные часы.
func run() -> void:
	test_menu_freezes_world_and_resumes()
	test_menu_tabs_and_pointer_use_one_open_page()
	test_completed_journal_survives_reload_without_resources()
	test_celestial_clock_and_visual_health()

## Сценарий: герой открывает рюкзак рядом с врагом во время действующих эффектов и растущей грядки.
## Исходное состояние: время, HP, противник, растение и заклинание готовы изменяться физическим кадром.
## Ожидаемый результат: все разделы меню замораживают мир; после закрытия время и рост снова продолжаются.
func test_menu_freezes_world_and_resumes() -> void:
	var game := make_game()
	game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).first_day=6
	game.tutorial_visible=false; game.regeneration_timer=7; game.game_minutes=500
	var cell:=Vector2i(0,0)
	game.plots[cell].planted=true; game.plots[cell].watered=true; game.plots[cell].tilled=true
	game.SpellSystem.state(game).cooldowns.arcane_bolt=8.0
	game.enemy_nodes[0].position=game.player+Vector2(12,0); game.enemy_nodes[0].location=game.current_location; game.enemy_nodes[0].alive=true; game.enemy_nodes[0].attack_timer=0.0
	for target in Hub.PAGES:
		Hub.open(game,target)
		var snapshot: Dictionary = game.SaveSystem.snapshot(game)
		var enemies: Array = game.enemy_nodes.duplicate(true)
		var minutes: float = game.game_minutes; var hp: int = game.player_hp
		for frame in 60: game.GameLoop.physics_process(game,1.0/60.0)
		expect(game.game_minutes==minutes and game.player_hp==hp,"menu pauses the clock and protects HP in "+target)
		expect(game.SaveSystem.snapshot(game)==snapshot and game.enemy_nodes==enemies,"menu freezes crops events status effects enemies and saved world in "+target)
		expect(game.SpellSystem.state(game).cooldowns.arcane_bolt==8.0,"paused menu freezes spell cooldowns in "+target)
	Hub.close(game)
	var minutes: float = game.game_minutes
	game.GameLoop.physics_process(game,0.1)
	expect(game.game_minutes>minutes,"closing the last menu resumes simulation")
	game.free()

## Сценарий: пользователь переходит между рюкзаком, заданиями, героем и картой мышью, клавишами и геймпадом.
## Исходное состояние: полноэкранное меню открыто, герой не должен получать события движения или боя.
## Ожидаемый результат: остаётся ровно один раздел; Escape закрывает всё и скрытые кнопки HUD не срабатывают.
func test_menu_tabs_and_pointer_use_one_open_page() -> void:
	var game := make_game()
	game.open_inventory()
	for index in Hub.PAGES.size():
		var event:=InputEventMouseButton.new(); event.pressed=true; event.button_index=MOUSE_BUTTON_LEFT; event.position=Hub.tab_rect(index).get_center()
		game._input(event)
		expect(Hub.page(game)==Hub.PAGES[index],"painted hub tab opens its page")
		var count:=int(game.inventory_open)+int(game.quest_log_open)+int(game.skill_menu_open)+int(game.world_map_open)
		expect(count==1,"hub never leaves a second hidden page open")
	game._input(key_event(KEY_I,KEY_I,true))
	expect(game.inventory_open,"inventory shortcut switches from another hub page")
	game._input(key_event(KEY_M,KEY_M,true)); game._unhandled_input(key_event(KEY_M,KEY_M,true))
	expect(game.inventory_open and game.inventory_move_from==game.inventory_selected,"inventory keeps its M transfer action instead of opening the world page")
	var trigger:=joypad_motion_event(JOY_AXIS_TRIGGER_RIGHT,0.8)
	game._input(trigger)
	var filter: String = game.inventory_filter
	game._input(trigger)
	expect(filter!="all" and game.inventory_filter==filter,"inventory trigger changes one category per press")
	game._input(joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true))
	expect(game.quest_log_open,"controller shoulder switches the shared menu page")
	game._input(joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true))
	var command: String = game.state.player.companion_command
	game._input(joypad_button_event(JOY_BUTTON_Y,true))
	expect(game.skill_menu_open and game.state.player.companion_command!=command,"hero page keeps a controller action for companion commands")
	var position: Vector2 = game.player
	game._input(key_event(KEY_D,KEY_D,true)); game._input(key_event(KEY_F,KEY_F,true))
	expect(game.player==position,"menu keyboard cannot move or attack through the page")
	game._input(key_event(KEY_ESCAPE,KEY_ESCAPE,true))
	expect(not Hub.active(game),"Escape releases all hub pages")
	game.free()

## Сценарий: выполненное поручение загружается после сдачи всех предметов, рядом остаётся активное сюжетное задание.
## Исходное состояние: сохранены завершённая первая глава, выполненное поручение бабушки и побочная миссия.
## Ожидаемый результат: история восстанавливается из сохранения и разделяется по сюжету и поручениям.
func test_completed_journal_survives_reload_without_resources() -> void:
	var game := make_game()
	game.mission_states.side_seed="completed"; game.mission_states.story_relic="active"
	game.quest_complete=true; game.quest_active=false; game.carrots=0
	game.FirstChapterSystem.state(game).completed=true
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	var restored := make_game()
	expect(restored.SaveSystem.apply(restored,snapshot),"saved quest history reloads successfully")
	restored.set_meta("journal_group","side"); restored.set_meta("journal_status","completed")
	var ids: Array = Journal.filtered(restored).map(func(record):return record.id)
	expect("side_seed" in ids and "grandmother" in ids,"completed errands survive without their consumed resources")
	restored.set_meta("journal_group","story")
	expect(Journal.filtered(restored).any(func(record):return record.id=="chapter_one"),"completed main chapter has its own archive")
	restored.set_meta("journal_status","active")
	expect(Journal.filtered(restored).all(func(record):return record.group=="story" and record.status=="active"),"active story excludes completed and side quests")
	game.free(); restored.free()

## Сценарий: время пересекает рассвет и закат, лунный месяц проходит четверти, здоровье получает урон и лечение.
## Исходное состояние: доступны игровые часы и отдельное визуальное состояние HP без изменения боевой механики.
## Ожидаемый результат: день и ночь переключаются по игровому времени, фазы цикличны, след урона догоняет HP.
func test_celestial_clock_and_visual_health() -> void:
	expect(not Clock.is_day(359) and Clock.is_day(360) and not Clock.is_day(1080),"sun and moon change at dawn and sunset")
	expect(Clock.moon_phase(1)==0 and Clock.moon_phase(8)==0.25 and Clock.moon_phase(15)==0.5 and Clock.moon_phase(29)==0,"moon has waxing full waning and repeating phases")
	expect(Clock.orbit_progress(360,true)==0 and Clock.orbit_progress(720,true)==0.5 and Clock.orbit_progress(1080,true)==1,"sun position distinguishes morning noon and evening without a digital clock")
	expect(Clock.orbit_progress(1080,false)==0 and Clock.orbit_progress(1440,false)==0.5 and Clock.orbit_progress(1800,false)==1,"moon travels continuously through midnight to dawn")
	var game:=make_game()
	Hud.update(game,0.01); game.player_hp=40; Hud.update(game,0.01)
	var visual: Dictionary=game.get_meta("moon_health")
	expect(float(visual.display)>40 and float(visual.trail)>float(visual.display),"damage animates with a delayed trail")
	for frame in 120: Hud.update(game,1.0/60)
	expect(absf(float(game.get_meta("moon_health").display)-40)<0.1,"visual bar converges to real HP")
	game.settings_state.reduced_motion=true; game.player_hp=80; Hud.update(game,0.01)
	expect(float(game.get_meta("moon_health").display)==80,"reduced motion keeps the bar exact")
	var message: String=game.message
	game.select_hotbar(4)
	expect(game.message==message,"selected tools add no permanent or repeated name notification")
	game.touch_controls_visible=true
	var prompt: Rect2 = game.HudLayoutSystem.interaction_rect(game)
	expect(not prompt.intersects(game.SpellRenderer.cast_button_rect(game)) and not prompt.intersects(game.SpellRenderer.cycle_button_rect(game)),"touch context prompt stays clear of both spell controls")
	game.free()
