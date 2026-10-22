extends RefCounted

const NOTICE_SECONDS := 7.0
const GRACE_SECONDS := 2.0

## Выбирает доступную точку текущей карты вместо старых общих координат, которые могли оказаться в воде или мебели.
static func safe_spawn(game:Node) -> Vector2:
	var location:String=game.current_location
	var regions:=preload("res://scripts/systems/village_region_data.gd")
	var point:=Vector2(260,360)
	if preload("res://scripts/systems/cave_room_data.gd").is_cave(location): point=preload("res://scripts/systems/cave_layout_system.gd").safe_start(location)
	elif game.BuildingSystem.is_interior(location): point=game.BuildingSystem.INTERIORS[location].spawn
	elif location=="overworld": point=game.VillageLayoutSystem.MapData.START
	elif regions.added(location):
		var port:String=regions.passages(location)[0].port
		point=regions.port_position(location,port)+regions.INWARD[port]*96
	if _walkable(game,point): return point
	for radius in range(24,289,24):
		for index in 16:
			var candidate:Vector2=(point+Vector2.from_angle(index*TAU/16)*radius).snapped(Vector2(12,12))
			if _walkable(game,candidate): return candidate
	return game.player

## Проверяет реальную землю и препятствия без устаревшего кеша предыдущей позиции или соседней комнаты.
static func _walkable(game:Node, point:Vector2) -> bool:
	return game.NavigationSystem.walkability_reason(game,point,-1,false,false)=="walkable"

## Проверяет короткую защиту восстановленного героя, не останавливая управление и события мира.
static func protected(game:Node) -> bool:
	return game.menu_state.recovery_grace>0.0

## Запоминает результат поражения в немодальном уведомлении и немедленно возвращает управление.
static func begin(game:Node, source:String, lost_coins:int) -> void:
	preload("res://scripts/systems/action_lifecycle_system.gd").cancel_transients(game)
	var menu=game.menu_state
	menu.defeat_open=false; menu.defeat_source=source; menu.defeat_lost_coins=maxi(0,lost_coins)
	menu.recovery_notice=NOTICE_SECONDS; menu.recovery_grace=GRACE_SECONDS
	menu.pause_open=false; menu.settings_open=false; menu.confirmation=""
	game.clear_movement_keys(); game.state.player.blocking=false
	game.player_hurt_timer=0.0; game.player_attack_timer=0.0
	game.state.fishing.reset_cast()
	if game.has_meta(game.HeroActionSystem.META): game.remove_meta(game.HeroActionSystem.META)
	game.message=""; game.hud_message_timer=0.0
	game.state.player.feedback.camera_shake=0.0
	game.notify_tutorial("rescue"); game.update_camera(); game.queue_redraw()

## Отсчитывает время уведомления и защиты только при доступной симуляции, сохраняя чтение при открытии меню.
static func update(game:Node, delta:float) -> void:
	if game.GameLoop.modal_active(game) or game.GameLoop.gameplay_window_open(game) or game.LevelEditorSystem.active(game): return
	var elapsed:=maxf(0,delta)
	game.menu_state.recovery_notice=maxf(0,game.menu_state.recovery_notice-elapsed)
	game.menu_state.recovery_grace=maxf(0,game.menu_state.recovery_grace-elapsed)
	if game.menu_state.recovery_notice<=0:
		game.menu_state.defeat_source=""; game.menu_state.defeat_lost_coins=0

## Убирает устаревшее уведомление и защиту при загрузке другого состояния либо новом игровом цикле.
static func clear(game:Node) -> void:
	game.menu_state.defeat_open=false; game.menu_state.defeat_source=""; game.menu_state.defeat_lost_coins=0
	game.menu_state.recovery_notice=0.0; game.menu_state.recovery_grace=0.0
