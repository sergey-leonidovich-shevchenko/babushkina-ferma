extends "res://tests/suites/suite_base.gd"

const Focus := preload("res://scripts/systems/focus_pause_system.gd")

## Проверяет платформенные границы, игровую паузу, опцию, сохранение настроек и сброс удержания.
func run() -> void:
	test_focus_freezes_world_but_services_continue()
	test_resume_keeps_manual_menus_and_releases_input()
	test_saved_setting_and_legacy_default()

## Готовит реальную игру без вступительных модальных окон и очереди без требования физического присутствия.
func active_game() -> Node:
	var game:=make_game(); game.tutorial_visible=false
	game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.FurnaceSystem.state(game).heat=30
	game.FurnaceSystem.state(game).queue=[{"id":"furnace:ore","duration":12.0,"remaining":8.0,"paid":{"iron_ore":2}}]
	return game

## Сценарий: потеря фокуса и приостановка приложения происходят во время мира и оплаченной обработки.
## Исходное состояние: игровое время, энергия, снаряд и очередь имеют известные значения.
## Ожидаемый результат: мир, бой и производство заморожены, служебная обратная связь продолжает кадры; отключённая опция разрешает фон.
func test_focus_freezes_world_but_services_continue() -> void:
	var game:=active_game(); game.settings_state.pause_on_focus_loss=true
	game.menu_state.recovery_grace=2; game.hud_hp_flash=1; game.player_attack_timer=0.5
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var before:Dictionary=game.SaveSystem.snapshot(game); var remaining:float=game.FurnaceSystem.state(game).queue[0].remaining
	game._physics_process(3)
	expect(Focus.blocked(game) and game.SaveSystem.snapshot(game)==before,"focus loss freezes the entire persistent simulation")
	expect(game.player_attack_timer==0.5 and game.menu_state.recovery_grace==2 and game.FurnaceSystem.state(game).queue[0].remaining==remaining,"combat protection and production do not consume paused time")
	expect(game.hud_hp_flash<1,"HUD service continues while world simulation is paused")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED); game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(Focus.blocked(game),"focus alone cannot resume a suspended application")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	expect(not Focus.blocked(game),"paired platform resume releases only automatic pause")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT); game.settings_state.pause_on_focus_loss=false
	var minutes:float=game.game_minutes; game._physics_process(0.25)
	expect(not Focus.blocked(game) and game.game_minutes>minutes and game.FurnaceSystem.state(game).queue[0].remaining<remaining,"explicit opt-out keeps real simulation running in background")
	game.free()

## Сценарий: возврат в окно при открытой ручной паузе, рюкзаке и настройках после удержанных действий.
## Исходное состояние: движение, атака, блок и строительная кнопка были зажаты до ухода.
## Ожидаемый результат: меню остаётся открытым, движение и повтор не возобновляются; новый отдельный ввод работает.
func test_resume_keeps_manual_menus_and_releases_input() -> void:
	var game:=active_game(); game.settings_state.pause_on_focus_loss=true
	for screen in ["pause","inventory","settings"]:
		game.menu_state.pause_open=screen=="pause"; game.menu_state.settings_open=screen=="settings"; game.inventory_open=screen=="inventory"
		game.move_right_held=true; game.attack_held=true; game.action_held=true; game.state.player.blocking=true
		game.BasementSystem.ui(game).holding=42
		game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT); game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		expect(not game.move_right_held and not game.attack_held and not game.action_held and not game.state.player.blocking and game.BasementSystem.ui(game).holding==0,"focus return releases every held world action: "+screen)
		expect(game.menu_state.pause_open==(screen=="pause") and game.menu_state.settings_open==(screen=="settings") and game.inventory_open==(screen=="inventory"),"automatic pause never changes manual menus: "+screen)
	game.menu_state.settings_open=false; game.menu_state.pause_open=false; game.inventory_open=false
	var echo_event:=key_event(KEY_D,KEY_D,true); echo_event.echo=true; game._input(echo_event)
	expect(not game.move_right_held,"OS key repeat cannot restart a key released by focus loss")
	game._input(key_event(KEY_D,KEY_D,true)); expect(game.move_right_held,"fresh deliberate key press works after focus return")
	game.free()

## Сценарий: переключение новой опции записывается рядом с языком и мигрирует старый конфиг.
## Исходное состояние: отдельный временный файл настроек версии пять без нового параметра.
## Ожидаемый результат: старый конфиг по умолчанию безопасен, выключенная настройка переживает загрузку, язык сохраняется.
func test_saved_setting_and_legacy_default() -> void:
	var path:="/private/tmp/farm-safe-focus-%d.cfg"%Time.get_ticks_usec(); var config:=ConfigFile.new()
	config.set_value("meta","schema_version",5); config.set_value("language","locale","de"); config.save(path)
	var game:=active_game(); game.SettingsSystem.load(game,path,false)
	expect(game.settings_state.pause_on_focus_loss,"old settings default to focus pause")
	game.menu_state.settings_selected=game.MenuSystem.SETTING_ITEMS.find("pause_on_focus_loss")
	game.MenuSystem.adjust_setting(game,1,path,false)
	var restored:=active_game(); restored.SettingsSystem.load(restored,path,false)
	expect(not restored.settings_state.pause_on_focus_loss,"menu toggle persists and loads the opt-out")
	config.load(path); expect(int(config.get_value("meta","schema_version"))==6 and config.has_section_key("language","locale"),"new settings schema keeps language and saves its focus policy")
	DirAccess.remove_absolute(path); game.free(); restored.free()
