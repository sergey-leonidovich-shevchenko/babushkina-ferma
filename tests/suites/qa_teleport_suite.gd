extends "res://tests/suites/suite_base.gd"

const Stone := preload("res://scripts/systems/qa_teleport_system.gd")
const Controls := preload("res://scripts/systems/qa_teleport_input.gd")
const Layout := preload("res://scripts/presentation/qa_teleport_renderer.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")

class BlockedNavigation:
	## Имитирует полностью занятую карту для отрицательного сценария посадки.
	static func walkability_reason(_game: Node, _point: Vector2, _ignored: int, _enemies: bool, _broadphase: bool) -> String:
		return "blocked"

class BlockedGame extends Node:
	const WorldSystem := preload("res://scripts/systems/world_system.gd")
	const WorldMapSystem := preload("res://scripts/systems/world_map_system.gd")
	const BuildingSystem := preload("res://scripts/systems/building_system.gd")
	const NavigationSystem := BlockedNavigation
	const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
	var current_location := "forest"
	var player := Vector2(300,400)
	var title_screen := false
	var language_screen := false
	## Подтверждает владение одним камнем без привлечения экономики к отрицательному стенду.
	func inventory_item_count(_kind: String) -> int:
		return 1
	## Позволяет проверить отказ модели без подключения окна к дереву сцены.
	func queue_redraw() -> void:
		pass

## Проверяет снабжение, все назначения, честную паузу, боевые хвосты, ввод и совместимость сохранений.
func run() -> void:
	test_stone_supply_and_disable()
	test_every_location_and_progress()
	test_pause_cancel_and_combat_cleanup()
	test_search_filters_and_devices()
	test_inventory_hotbar_and_save()
	test_occupied_and_unavailable_arrivals()

## Создаёт самостоятельный тестовый запуск без вступительной сцены и с одним многоразовым камнем.
func prepare() -> Node:
	var game := make_game()
	game.state.player.profile.created = true
	game.FarmLifeSystem.state(game).cutscene = ""; game.FarmLifeSystem.state(game).cutscene_timer = 0
	game.FirstChapterSystem.state(game).completed = true
	game.change_inventory_count(Stone.KIND,1)
	return game

## Сценарий: камень получают из шкафа, а выключенный режим разработки блокирует старые экземпляры.
## Исходное состояние: пустой новый рюкзак, полный шкаф и отдельные переключатели шкафа и телепорта.
## Ожидаемый результат: запас 999, выдача штатная, отключение не расходует камень и не удерживает паузу.
func test_stone_supply_and_disable() -> void:
	var game := make_game(); var setting: bool = ProjectSettings.get_setting(Stone.SETTING); var cabinet_setting: bool=ProjectSettings.get_setting(Cabinet.SETTING)
	expect(game.inventory_item_count(Stone.KIND)==0, "new game does not silently grant QA equipment")
	expect(Cabinet.state(game).stock[Stone.KIND]==999 and Cabinet.category(game,Stone.KIND)=="other", "QA stone belongs to cabinet other category")
	game.current_location="cottage_interior"; game.player=Cabinet.POSITION
	game.FirstChapterSystem.state(game).completed=true; game.FarmLifeSystem.state(game).cutscene=""
	expect(Cabinet.open(game) and Cabinet.take(game,Stone.KIND,1), "stone obtained through real cabinet transfer")
	Cabinet.close(game)
	expect(Stone.open(game), "owned stone opens selector")
	ProjectSettings.set_setting(Stone.SETTING,false)
	expect(not Stone.active(game) and not Stone.open(game) and not Stone.travel(game,"forest"), "QA switch blocks stale saved stone and active selector")
	expect(not game.GameLoop.gameplay_window_open(game) and game.inventory_item_count(Stone.KIND)==1, "disabled selector never holds simulation or consumes item")
	expect(not game.TutorialSystem.steps().any(func(step): return step.event=="qa_teleport"),"release tutorial does not require disabled QA feature")
	ProjectSettings.set_setting(Stone.SETTING,setting); Stone.close(game)
	ProjectSettings.set_setting(Cabinet.SETTING,false)
	expect(not Stone.open(game), "release cabinet flag also disables QA teleport")
	ProjectSettings.set_setting(Cabinet.SETTING,cabinet_setting)
	game.free()

## Сценарий: вход занят врагом либо вся целевая карта недоступна.
## Исходное состояние: живой враг в точке появления, затем независимая модель полностью занятой карты.
## Ожидаемый результат: герой появляется рядом на свободном месте, а невозможный перенос сохраняет исходную карту и позицию.
func test_occupied_and_unavailable_arrivals() -> void:
	var game := prepare(); game.current_location="forest"
	var spawn: Vector2=preload("res://scripts/systems/recovery_system.gd").safe_spawn(game)
	game.enemy_nodes[0].location="forest"; game.enemy_nodes[0].position=spawn; game.enemy_nodes[0].alive=true
	game.current_location="overworld"; Stone.open(game)
	expect(Stone.travel(game,"forest") and game.player.distance_to(spawn)>=game.PLAYER_RADIUS+30.0,"occupied arrival moves to neighboring safe ground")
	game.free()
	var blocked := BlockedGame.new(); Stone.state(blocked).open=true
	expect(not Stone.travel(blocked,"rocky") and blocked.current_location=="forest" and blocked.player==Vector2(300,400),"unavailable target preserves original map and position")
	expect(Stone.active(blocked) and not String(Stone.state(blocked).notice).is_empty(),"failed arrival keeps selector open with explanation")
	blocked.free()

## Сценарий: прямой перенос проходит по каждой зарегистрированной карте независимо от сюжетных дверей.
## Исходное состояние: герой с одним камнем, незавершёнными заданиями и без способностей доступа.
## Ожидаемый результат: нет повторов, посадки доступны, награды и затраты отсутствуют, двери не перебрасывают обратно.
func test_every_location_and_progress() -> void:
	var game := prepare(); var ids := Stone.locations(game); var seen := {}
	var counts: Dictionary=game.export_inventory_counts().duplicate(true); var missions: Dictionary=game.mission_states.duplicate(true)
	var energy: int=game.energy; var coins: int=game.coins; var hp: int=game.player_hp; var minutes: float=game.game_minutes
	for id in ids:
		expect(not seen.has(id),"unique destination: "+id); seen[id]=true
		expect(Stone.open(game) and Stone.travel(game,id),"teleport succeeds: "+id)
		expect(game.current_location==id and game.NavigationSystem.walkability_reason(game,game.player,-1,false,false)=="walkable", "real destination has safe terrain: "+id)
		expect(not Stone.active(game) and not game.location_transition_armed and not game.LocationTransitionSystem.update(game,0.0), "no active selector or immediate doorway bounce: "+id)
		game.update_camera()
		expect(game.camera_offset.is_finite(),"camera follows destination: "+id)
	for registry in [game.WorldMapSystem.LOCATIONS,game.BuildingSystem.INTERIORS,Stone.Villages.IDS,Stone.Caves.IDS]:
		for id in registry: expect(seen.has(id),"catalog contains registered destination: "+id)
	expect(counts==game.export_inventory_counts() and missions==game.mission_states,"all QA transfers preserve resources and quest states")
	expect(game.energy==energy and game.coins==coins and game.player_hp==hp and is_equal_approx(game.game_minutes,minutes),"all transfers cost no time, coins, stamina or health")
	expect(not game.state.world.cave_arena.relic_awarded and not game.state.world.cave_boss.active,"teleport neither awards boss relic nor starts battle")
	Stone.open(game); var original: String=game.current_location; var position: Vector2=game.player
	expect(not Stone.travel(game,"not_a_real_location") and game.current_location==original and game.player==position,"unknown destination rejected without mutation")
	game.free()

## Сценарий: выбор останавливает мир, отмена сохраняет бой, перенос убирает угрозы покинутой комнаты.
## Исходное состояние: активный бой босса с зонами, мухами, замахами и удержанными кнопками.
## Ожидаемый результат: часы и угрозы заморожены в меню, отмена ничего не лечит, подтверждение сбрасывает временные атаки.
func test_pause_cancel_and_combat_cleanup() -> void:
	var game := prepare(); game.current_location="cave_sanctum"
	game.state.world.cave_boss.active=true; game.state.world.cave_boss.fly_timer=3.0
	game.state.world.cave_boss.zones=[{"timer":2.0}]
	game.state.world.cave_boss.projectiles=[{"timer":2.0}]
	game.state.world.cave_boss.attack={"kind":"test"}
	game.action_held=true; game.attack_held=true; game.move_left_held=true; game.state.player.blocking=true
	var minutes: float=game.game_minutes; var hp: int=game.player_hp
	expect(Stone.open(game) and game.GameLoop.gameplay_window_open(game),"selector has simulation pause contract")
	expect(not game.action_held and not game.attack_held and not game.move_left_held and not game.state.player.blocking,"opening releases movement, attacks and block")
	for frame in 10: game.GameLoop.physics_process(game,0.5)
	expect(game.game_minutes==minutes and game.player_hp==hp and game.state.world.cave_boss.fly_timer==3.0,"clock, boss and damage stay frozen while choosing")
	Stone.close(game)
	expect(game.current_location=="cave_sanctum" and game.state.world.cave_boss.active and not game.state.world.cave_boss.attack.is_empty(),"cancel does not reset battle")
	Stone.open(game)
	game.slime_attack_pending=true; game.player_attack_timer=0.8
	expect(Stone.travel(game,"cottage_interior"),"QA stone escapes boss arena without victory")
	expect(not game.state.world.cave_boss.active and game.state.world.cave_boss.zones.is_empty() and game.state.world.cave_boss.projectiles.is_empty() and game.state.world.cave_boss.fly_timer==0,"old boss attacks and flies cannot follow hero")
	expect(not game.slime_attack_pending and game.player_attack_timer==0 and not game.GameLoop.gameplay_window_open(game),"ordinary windups cleared and pause released")
	game.free()

## Сценарий: список доступен с клавиатуры, мыши, геймпада и касания, а поиск не запускает игровое действие.
## Исходное состояние: все места доступны, выбран первый элемент, герой находится в деревне.
## Ожидаемый результат: разделы полны, поиск по имени и коду работает, осмотр строки не переносит героя.
func test_search_filters_and_devices() -> void:
	var game := prepare(); Stone.open(game); var value := Stone.state(game)
	var union := {}
	for section in Stone.GROUPS.slice(1):
		value.group=section
		for id in Stone.entries(game): expect(not union.has(id),"groups do not repeat destination: "+id); union[id]=true
	expect(union.size()==Stone.locations(game).size(),"groups cover entire catalog")
	value.group="all"; value.query="cave_sanctum"; Stone.select(game,0)
	expect(Stone.entries(game)==["cave_sanctum"],"technical location ID searchable")
	value.query="подвал"; Stone.select(game,0)
	expect(Stone.entries(game)==["cellar_workshop"],"Russian localized location name searchable")
	value.query=""; Controls.handle(game,key_event(KEY_END,KEY_END,true))
	expect(value.scroll==Stone.entries(game).size()-Stone.ROWS,"keyboard reaches end without pagination")
	Controls.handle(game,key_event(KEY_F,KEY_F,true)); var letter:=key_event(KEY_C,KEY_C,true); letter.unicode=1092
	Controls.handle(game,letter)
	expect(value.query=="ф" and value.selected==0,"search accepts Unicode and resets selection")
	Controls.handle(game,key_event(KEY_ESCAPE,KEY_ESCAPE,true))
	expect(Stone.active(game) and not value.searching,"first escape exits search without transferring")
	value.query=""; value.group="all"; Stone.select(game,0)
	var before: String=game.current_location
	var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Layout.row_rect(1).get_center()
	game._input(click)
	expect(value.selected==1 and game.current_location==before,"real input route click focuses only")
	game._input(joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true))
	expect(value.group=="world","controller shoulder filters destinations")
	var touch:=InputEventScreenTouch.new(); touch.pressed=true; touch.position=Layout.CLOSE.get_center(); game._input(touch)
	expect(not Stone.active(game),"touch closes modal")
	Stone.open(game); Stone.state(game).query="forest"; Stone.select(game,0)
	game._input(joypad_button_event(JOY_BUTTON_A,true))
	expect(not Stone.active(game) and game.current_location=="forest","controller confirm performs real teleport")
	Stone.open(game); Stone.state(game).query="missing_location"; Stone.select(game,0)
	expect(not Controls.confirm(game) and Stone.active(game),"empty search never teleports")
	Stone.state(game).query="cellar_workshop"; Stone.select(game,0)
	click.position=Layout.USE.get_center(); game._input(click)
	expect(game.current_location=="cellar_workshop" and not Stone.active(game),"mouse confirm performs real teleport")
	game.free()

## Сценарий: камень применяют из рюкзака и хотбара, затем сохраняют и загружают в старый либо новый слот.
## Исходное состояние: камень назначен на хотбар, рядом контекстное действие и открыт инвентарь.
## Ожидаемый результат: предмет многоразовый, подпись действия верная, окно не восстанавливается из сохранения.
func test_inventory_hotbar_and_save() -> void:
	var game := prepare(); game.open_inventory()
	game.inventory_selected=game.inventory_slots.find(Stone.KIND)
	expect(game.InventoryInputSystem.action_label(game,"eat").begins_with("Переместиться"),"stone action is teleport rather than eat")
	expect(game.consume_selected_item() and Stone.active(game) and not game.inventory_open,"inventory use opens one exclusive selector")
	Stone.close(game); game.hotbar_slots[0]=Stone.KIND; game.selected_hotbar=0
	game.current_location="cave_sanctum"; game.player=preload("res://scripts/systems/cave_boss_arena_data.gd").ALTAR
	game._input(key_event(KEY_E,KEY_E,true))
	expect(Stone.active(game) and not game.state.world.cave_boss.active,"hotbar QA stone takes priority over boss altar on non-farm map")
	Stone.travel(game,"cellar_workshop"); Stone.open(game)
	var save: Dictionary=game.SaveSystem.snapshot(game)
	expect(not save.has(Stone.META) and not save.profile.has(Stone.META),"selector UI is not serialized")
	expect(game.SaveSystem.apply(game,save) and not Stone.active(game) and game.inventory_item_count(Stone.KIND)==1,"save/load preserves reusable stone and clears modal")
	var old: Dictionary=save.duplicate(true); old.counts.erase(Stone.KIND)
	expect(game.SaveSystem.apply(game,old) and game.inventory_item_count(Stone.KIND)==0,"old save without QA item defaults to zero")
	game.free()
