extends "res://tests/suites/suite_base.gd"

const Recovery := preload("res://scripts/systems/recovery_system.gd")
const Notice := preload("res://scripts/presentation/recovery_notice_renderer.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")
const SETTINGS := "user://recovery-suite-settings.cfg"

## Проверяет восстановление, свободный ввод, защиту, таймеры и совместимость прежних настроек.
func run() -> void:
	test_recovery_is_immediate_and_does_not_capture_input()
	test_notice_expires_and_pauses_with_inventory()
	test_retry_protection_and_projectile_reset()
	test_rescue_text_fits_all_languages()
	test_old_shake_preference_cannot_move_camera()
	test_legacy_surface_api_is_smooth_and_scalable()
	test_every_location_has_an_accessible_recovery_point()

## Создаёт спокойную модель без угроз и вступительного ролика для настоящего игрового кадра.
func prepared_game() -> Node:
	var game:=make_game(); game.enemy_nodes.clear(); game.hazard_nodes.clear(); game.slime_alive=false
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""
	game.player_hp=1; game.coins=12; game.tutorial_visible=false; game.InputSystem.apply_control_preset("standard")
	return game

## Сценарий: герой получает смертельный удар и продолжает игру без кнопки подтверждения.
## Исходное состояние: один HP, двенадцать монет, знакомый предмет и выполненное событие обучения.
## Ожидаемый результат: HP восстановлены, списано пять монет, прогресс сохранён, время и клавиши работают при видимой плашке.
func test_recovery_is_immediate_and_does_not_capture_input() -> void:
	var game:=prepared_game(); game.change_inventory_count("apple",4); game.tutorial_events_completed["mine"]=true
	game.state.fishing.total_caught=7; game.state.fishing.phase=game.FishingSystem.PHASE_WAITING
	game.HeroActionSystem.begin(game,"chop",game.player)
	game.CombatSystem.damage_player(game,999,"Скелет")
	expect(game.player_hp==game.player_max_hp and game.coins==7 and game.inventory_item_count("apple")==4 and game.tutorial_events_completed.has("mine"),"automatic rescue preserves progress and charges its penalty exactly once")
	expect(not game.menu_state.defeat_open and not game.GameLoop.modal_active(game) and Notice.visible(game),"visible rescue notice does not create a blocking modal")
	game._input(key_event(KEY_D,KEY_D,true))
	var old:Vector2=game.player; var minutes:float=game.game_minutes
	game._physics_process(0.1)
	expect(game.player.distance_to(old)>0 and game.game_minutes>minutes and Notice.visible(game),"keyboard movement and world clock continue under the notice")
	expect(game.tutorial_events_completed.has("rescue"),"automatic recovery records its dedicated tutorial event")
	expect(game.state.fishing.phase==game.FishingSystem.PHASE_IDLE and game.state.fishing.total_caught==7 and game.HeroActionSystem.pose(game).is_empty(),"recovery cancels fishing and held tool pose without resetting permanent statistics")
	game.free()

## Сценарий: игрок открывает рюкзак во время короткого сообщения о поражении.
## Исходное состояние: действующая плашка и защита после восстановления.
## Ожидаемый результат: меню скрывает плашку и сохраняет таймеры, после закрытия они продолжаются и очищаются.
func test_notice_expires_and_pauses_with_inventory() -> void:
	var game:=prepared_game(); game.CombatSystem.damage_player(game,999,"Скелет")
	game.open_inventory(); Recovery.update(game,20)
	expect(not Notice.visible(game) and game.menu_state.recovery_notice==Recovery.NOTICE_SECONDS and Recovery.protected(game),"backpack hides recovery and freezes remaining reading and protection time")
	game.inventory_open=false; Recovery.update(game,1)
	expect(Notice.visible(game) and game.menu_state.recovery_notice==6 and game.menu_state.recovery_grace==1,"closing backpack resumes recovery timers without acknowledgement")
	Recovery.update(game,10)
	expect(not Notice.visible(game) and not Recovery.protected(game) and game.menu_state.defeat_source.is_empty(),"recovery notice and protection expire and release their transient data")
	game.free()

## Сценарий: во время поражения остаётся снаряд, затем сразу приходит ещё один смертельный удар.
## Исходное состояние: очередь стрел и восстановление с одной жизни.
## Ожидаемый результат: угрозы очищены, защита предотвращает повторное списание, после двух секунд бой снова наносит урон.
func test_retry_protection_and_projectile_reset() -> void:
	var game:=prepared_game(); var shots:=preload("res://scripts/systems/enemy_projectile_system.gd")
	shots.launch_at(game,Vector2(800,500),Vector2(900,500),20,"arrow",320,400,"skeleton")
	game.CombatSystem.damage_player(game,999,"Скелет"); var coins:int=game.coins
	expect(shots.state(game).is_empty() and game.CombatSystem.damage_player(game,999,"Повторный удар")==0 and game.coins==coins,"recovery clears arrows and prevents repeated lethal damage and penalty")
	Recovery.update(game,2.01); game.state.player.dodge_timer=0
	expect(game.CombatSystem.damage_player(game,1,"Следующий бой")>0 and game.player_hp<game.player_max_hp,"damage resumes after finite recovery protection")
	game.CombatSystem.reset_transients(game)
	expect(not Notice.visible(game) and not Recovery.protected(game),"loading or resetting combat clears old recovery state")
	game.free()

## Сценарий: сообщение о спасении показывает длинное имя противника на всех языках.
## Исходное состояние: компактная плашка под часами и масштаб текста сто двадцать процентов.
## Ожидаемый результат: две строки причины помещаются внутри панели и экрана при читаемом размере шрифта.
func test_rescue_text_fits_all_languages() -> void:
	var game:=prepared_game(); game.settings_state.text_scale=1.2
	expect(Rect2(0,0,1152,648).encloses(Notice.PANEL) and Notice.PANEL.size.x*Notice.PANEL.size.y<1152*648*0.05,"recovery occupies less than five percent of the screen")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale)
		var text:String=game.LocaleSystem.ui("defeat_saved",[game.LocaleSystem.entity("cave_guardian")])
		var size:int=game.UiScaleSystem.fitted_multiline_font_size(game,game.UI_FONT,text,292,32,11)
		expect(size>=8 and game.UI_FONT.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,292,size,2).y<=32,"recovery cause fits two readable lines in "+locale)
		expect(game.LocaleSystem.tutorial("rescue")!="rescue","recovery tutorial is localized in "+locale)
	game.free()

## Сценарий: старый конфиг включает дрожание, а удар оставил большое смещение в состоянии.
## Исходное состояние: прежняя схема настроек с громкостью и выбранным языком.
## Ожидаемый результат: остальные настройки сохранены, дрожание мигрирует в выключенное состояние, камера неподвижна.
func test_old_shake_preference_cannot_move_camera() -> void:
	var config:=ConfigFile.new(); config.set_value("meta","schema_version",4); config.set_value("accessibility","screen_shake",true); config.set_value("audio","master",0.4); config.set_value("language","locale","de"); config.save(SETTINGS)
	var game:=prepared_game(); game.SettingsSystem.load(game,SETTINGS,false); config.load(SETTINGS)
	expect(not game.settings_state.screen_shake_enabled and not bool(config.get_value("accessibility","screen_shake",true)) and game.settings_state.master_volume==0.4 and config.get_value("language","locale")=="de","old shake preference migrates without changing unrelated preferences")
	expect("screen_shake" not in game.MenuSystem.SETTING_ITEMS,"settings offer no switch that can restore unwanted camera shake")
	game.settings_state.screen_shake_enabled=true; game.state.player.feedback.camera_shake=100
	expect(game.AdventurePolishSystem.shake_offset(game)==Vector2.ZERO,"legacy state cannot move the rendered world")
	game.WeaponSystem.hit_player(game,game.player-Vector2(30,0)); game.AdventurePolishSystem.begin_action(game,"mine",game.player)
	expect(game.state.player.feedback.camera_shake==0 and game.AdventurePolishSystem.shake_offset(game)==Vector2.ZERO,"hit reactions and tools retain their animation with a steady camera")
	game.free(); DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))

## Сценарий: старый экран запрашивает оформление панели или кнопки через прежний интерфейс темы.
## Исходное состояние: все исторические компоненты и новые поверхности доступны в одном каталоге.
## Ожидаемый результат: совместимые вызовы дают непрозрачные гладкие панели с тонкой рамкой без деревянных текстур.
func test_legacy_surface_api_is_smooth_and_scalable() -> void:
	for component in Kit.TEXTURES:
		var surface:StyleBoxFlat=Kit.style(component)
		expect(surface.bg_color.a==1 and surface.border_width_left==1 and surface.corner_radius_top_left==5,"legacy component uses smooth opaque chrome: "+component)

## Сценарий: герой погибает в любом биоме, деревенском районе, пещерной комнате или помещении.
## Исходное состояние: штатные карты, мебель, вода и стены без подвижных врагов.
## Ожидаемый результат: точка восстановления физически доступна; на первой карте используется штатный старт текущего чертежа.
func test_every_location_has_an_accessible_recovery_point() -> void:
	var game:=prepared_game(); var areas:Array=game.WorldSystem.LOCATIONS.duplicate(); var seen:={}
	areas.append("moon_glade"); areas.append_array(preload("res://scripts/systems/village_region_data.gd").IDS)
	areas.append_array(preload("res://scripts/systems/cave_room_data.gd").IDS); areas.append_array(game.BuildingSystem.INTERIORS.keys())
	for area in areas:
		if seen.has(area): continue
		seen[area]=true; game.current_location=area
		var point:=Recovery.safe_spawn(game)
		expect(game.NavigationSystem.walkability_reason(game,point,-1,false,false)=="walkable","recovery point is accessible in "+area)
	game.current_location="overworld"
	expect(Recovery.safe_spawn(game)==game.VillageLayoutSystem.MapData.START and Recovery.safe_spawn(game)!=Vector2(260,360),"recovery uses the current map start instead of a legacy coordinate")
	game.free()
