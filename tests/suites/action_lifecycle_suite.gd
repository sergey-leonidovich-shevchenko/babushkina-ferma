extends "res://tests/suites/suite_base.gd"

const Attack := preload("res://scripts/systems/player_attack_system.gd")
const EnemyShots := preload("res://scripts/systems/enemy_projectile_system.gd")
const BossShots := preload("res://scripts/systems/cave_boss_projectile_system.gd")
const Basement := preload("res://scripts/systems/basement_system.gd")
const Build := preload("res://scripts/systems/basement_construction_system.gd")
const Hub := preload("res://scripts/systems/menu_hub_system.gd")

## Проверяет матрицу паузы, устройств, обычных переходов, оплаченной стройки, загрузки и спасения.
func run() -> void:
	test_pause_preserves_started_combat_for_all_close_devices()
	test_location_change_cancels_all_old_threats_immediately()
	test_construction_progress_survives_but_holding_does_not()
	test_unpaid_charge_and_recovery_cleanup()

## Готовит живой мир без вступительных модальных окон и фиксирует исходную локацию обработчиком переходов.
func prepared() -> Node:
	var game:=make_game(); game.current_location="cave_sanctum"; game.player=Vector2(1200,600)
	game.tutorial_visible=false; game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.sync_background_location(); game.discovery_current.clear(); game.discovery_timer=0
	return game

## Начинает настоящий оплаченный замах и создаёт физические снаряды, не подменяя их таймерами отложенного урона.
func start_combat(game: Node) -> void:
	game.change_inventory_count("sword",1); game.InventorySystem.equip(game,"sword")
	var enemy:Dictionary=game.enemy_nodes[0]; enemy.location=game.current_location; enemy.position=game.player+Vector2(70,0); enemy.hp=30; enemy.max_hp=30; enemy.alive=true
	expect(Attack.begin(game,"enemy",0),"real contact attack starts before lifecycle boundary")
	EnemyShots.launch_at(game,game.player+Vector2(220,0),game.player,1,"arrow",320,600,"skeleton")
	BossShots.launch(game,game.player+Vector2(180,0),Vector2.LEFT,1)
	game.state.world.cave_boss.active=true; game.state.world.cave_boss.fly_timer=3; game.state.world.cave_boss.fly_tick=0.25
	expect(not EnemyShots.state(game).is_empty() and not game.state.world.cave_boss.projectiles.is_empty(),"actual projectile fixtures exist on a valid arena floor")

## Создаёт реальное событие закрытия общего меню для четырёх путей управления.
func close_event(device: String) -> InputEvent:
	if device=="keyboard": return key_event(KEY_ESCAPE,KEY_ESCAPE,true)
	if device=="gamepad": return joypad_button_event(JOY_BUTTON_B,true)
	if device=="mouse":
		var event:=InputEventMouseButton.new(); event.position=Hub.CLOSE.get_center(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; return event
	var event:=InputEventScreenTouch.new(); event.position=Hub.CLOSE.get_center(); event.index=0; event.pressed=true; return event

## Сценарий: рюкзак либо системная пауза открывается посреди честного замаха, стрелы и укусов мух.
## Исходное состояние: активный бой, незавершённый перенос слота и четыре разных события закрытия.
## Ожидаемый результат: пауза сохраняет бой без продвижения, закрытие отменяет жесты, начатый удар доходит один раз.
func test_pause_preserves_started_combat_for_all_close_devices() -> void:
	for device in ["keyboard","gamepad","mouse","touch","pause_menu"]:
		var game:=prepared(); start_combat(game)
		var attack:Dictionary=game.get_meta(Attack.KEY).duplicate(true); var shots:=EnemyShots.state(game).duplicate(true)
		var timer:float=game.player_attack_timer; var minutes:float=game.game_minutes; var hp:int=game.player_hp
		game.state.player.blocking=true; game.attack_held=true; game.action_held=true
		if device=="pause_menu": game.MenuSystem.open_pause(game)
		else: game.open_inventory(); game.inventory_move_from=0; game.inventory_touch_drag_y=18
		game._physics_process(5)
		expect(game.get_meta(Attack.KEY,{})==attack and EnemyShots.state(game)==shots and game.player_attack_timer==timer,"pause preserves exact started attack and projectile state: "+device)
		expect(game.game_minutes==minutes and game.player_hp==hp and game.state.world.cave_boss.fly_timer==3,"pause freezes time and fly damage: "+device)
		game._input(key_event(KEY_ESCAPE,KEY_ESCAPE,true) if device=="pause_menu" else close_event(device))
		expect(not game.inventory_open and not game.menu_state.pause_open and game.inventory_move_from==-1 and game.inventory_touch_drag_y==0,"close cancels uncommitted slot gesture: "+device)
		expect(not game.attack_held and not game.action_held and not game.state.player.blocking,"close never resumes held attack or block: "+device)
		var health:int=game.enemy_nodes[0].hp; Attack.update(game,1); var after:int=game.enemy_nodes[0].hp; Attack.update(game,1)
		expect(after<health and game.enemy_nodes[0].hp==after,"honest paused contact resumes exactly once: "+device)
		game.free()

## Сценарий: обычная синхронизация прежней карты и затем реальный переход через дверь дома.
## Исходное состояние: боевые угрозы, инструмент, рыбалка и жест переноса принадлежат старой карте.
## Ожидаемый результат: прежняя карта ничего не сбрасывает, переход очищает всё сразу, без следующего физического кадра.
func test_location_change_cancels_all_old_threats_immediately() -> void:
	var game:=prepared(); start_combat(game); var pending:Dictionary=game.get_meta(Attack.KEY).duplicate(true)
	game.sync_background_location()
	expect(game.get_meta(Attack.KEY,{})==pending and game.state.world.cave_boss.fly_timer==3,"same-location sync never cancels an honest battle")
	game.current_location="overworld"; game.sync_background_location(); start_combat(game)
	game.HeroActionSystem.begin(game,"chop",game.player); game.state.fishing.phase=game.FishingSystem.PHASE_WAITING; game.state.fishing.cast_location="overworld"
	game.state.fishing.cast_target=Vector2(1000,600); game.inventory_move_from=2; game.inventory_touch_drag_y=40
	game.BasementSystem.ui(game).holding=42; game.set_meta("basement_active_station",42)
	var counts:Dictionary=game.export_inventory_counts().duplicate(true); var hp:int=game.player_hp; var energy:float=game.energy
	expect(game.BuildingSystem.enter(game,"cottage"),"ordinary door enters the cottage through its production transition")
	expect(not game.has_meta(Attack.KEY) and EnemyShots.state(game).is_empty() and game.state.world.cave_boss.projectiles.is_empty() and game.state.world.cave_boss.fly_timer==0,"door clears player shot enemy shot boss shot and fly before the next tick")
	expect(game.HeroActionSystem.pose(game).is_empty() and game.state.fishing.phase==game.FishingSystem.PHASE_IDLE and game.BasementSystem.ui(game).holding==0 and not game.has_meta("basement_active_station"),"old tool fishing and station binding cannot follow the hero")
	expect(game.inventory_move_from==-1 and game.inventory_touch_drag_y==0 and game.export_inventory_counts()==counts and game.player_hp==hp and game.energy==energy,"transition cancels gestures without consuming or granting permanent resources")
	game.free()

## Сценарий: оплаченный недострой прерывается настоящим рюкзаком, покидает комнату и загружается из JSON.
## Исходное состояние: закреплённый старый гончарный круг с двумя секундами работы и журналом компонентов.
## Ожидаемый результат: прогресс и оплата сохраняются, молоток и удержание исчезают, работа требует нового нажатия.
func test_construction_progress_survives_but_holding_does_not() -> void:
	var game:=prepared(); var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v2-production.json"))
	expect(game.SaveSystem.apply(game,data),"paid historical foundation loads into lifecycle test")
	game.current_location=Basement.Data.LOCATION; game.sync_background_location()
	var item:Dictionary=Basement.state(game).objects[0]; game.player=Basement.Layout.center(Basement.Layout.approach_cell(item))
	preload("res://scripts/systems/basement_station_system.gd").interact(game,int(item.id)); Build.update_hold(game,0.25)
	var work:float=item.work; var energy:float=game.energy; var paid:Dictionary=item.paid.duplicate(true)
	game.open_inventory(); game._physics_process(5); game._input(close_event("keyboard")); Build.update_hold(game,5)
	expect(item.work==work and game.energy==energy and item.paid==paid and Basement.ui(game).holding==0 and game.HeroActionSystem.pose(game).is_empty(),"backpack preserves paid construction while stopping physical hammer hold")
	expect(game.BuildingSystem.leave(game),"cellar exit uses the ordinary room transition")
	var snapshot:Dictionary=game.SaveSystem.snapshot(game); var restored:=prepared()
	expect(restored.SaveSystem.apply(restored,JSON.parse_string(JSON.stringify(snapshot))),"partial foundation survives actual JSON loading")
	var loaded:Dictionary=Basement.state(restored).objects[0]
	expect(loaded.work==work and JSON.parse_string(JSON.stringify(loaded.paid))==JSON.parse_string(JSON.stringify(paid)) and Basement.ui(restored).holding==0,"load restores work and paid ledger without held input")
	game.free(); restored.free()

## Сценарий: окно открывается во время неоплаченной подготовки удочки, затем происходит смертельное попадание.
## Исходное состояние: заряд ещё не выпущен, затем активны разные угрозы и сохранён обычный предмет.
## Ожидаемый результат: меню не выпускает леску само, спасение очищает угрозы сразу и сохраняет немодальное восстановление без тряски.
func test_unpaid_charge_and_recovery_cleanup() -> void:
	var game:=prepared(); var durability:int=game.state.inventory.durability.get("fishing_rod",100)
	game.state.fishing.phase=game.FishingSystem.PHASE_CHARGING; game.state.fishing.cast_location=game.current_location; game.action_held=true
	game.open_inventory(); game._input(close_event("keyboard")); game.FishingSystem.update(game,0.1)
	expect(game.state.fishing.phase==game.FishingSystem.PHASE_IDLE and game.state.inventory.durability.get("fishing_rod",100)==durability,"closing UI cannot release an unintended paid cast")
	start_combat(game); game.change_inventory_count("apple",4); var apples:int=game.inventory_item_count("apple"); var coins:int=game.coins
	game.inventory_move_from=0; game.state.player.blocking=false; game.CombatSystem.damage_player(game,999,"lifecycle test")
	expect(game.player_hp==game.player_max_hp and game.coins==maxi(0,coins-5) and game.inventory_item_count("apple")==apples,"recovery preserves inventory and charges only its existing penalty")
	expect(not game.menu_state.defeat_open and not game.GameLoop.modal_active(game) and game.menu_state.recovery_grace==2 and game.state.player.feedback.camera_shake==0,"recovery remains immediate nonmodal and without camera shake")
	expect(EnemyShots.state(game).is_empty() and game.state.world.cave_boss.fly_timer==0 and not game.has_meta(Attack.KEY) and game.inventory_move_from==-1,"death cleanup clears all threats and pending gestures before any new frame")
	game.free()
