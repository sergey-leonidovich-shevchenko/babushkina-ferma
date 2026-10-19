extends RefCounted

const REGISTRY := "res://docs/reports/visual-overhaul/vbase-003/camera-points.json"
const Teleport := preload("res://scripts/systems/qa_teleport_system.gd")
const Scene := preload("res://main.tscn")
const SIZE := Vector2i(1152,648)
const SEED := 20261015

## Читает зафиксированные точки; обычная проверка никогда не пересоздаёт эталон.
static func registry() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))

## Создаёт исходную сцену с одинаковым генератором до инициализации всех игровых служб.
static func create_game() -> Node:
	seed(SEED)
	var game:=Scene.instantiate()
	game.world_loot_seed=SEED; game.set_meta("capture_windowed",true)
	return game

## Фиксирует положение, календарь и позу без движения симуляции и без доступа к сохранению пользователя.
static func configure(game: Node, point: Dictionary) -> void:
	game.set_physics_process(false); game.set_process(false)
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.settings_state.pause_on_focus_loss=false; game.settings_state.fullscreen_enabled=false
	game.settings_state.vsync_enabled=true; game.settings_state.screen_shake_enabled=false
	game.settings_state.reduced_motion=true; game.settings_state.high_contrast=false
	game.settings_state.text_scale=1.0; game.settings_state.touch_scale=1.0
	game.AudioSystem.set_enabled(game,false); game.LocaleSystem.set_locale("ru",false)
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
	game.FarmLifeSystem.state(game).first_day=6
	game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).cutscene_timer=0.0
	game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true
	game.current_location=point.location; game.player=vector(point.player)
	game.facing=vector(point.facing); game.day=int(point.day); game.game_minutes=float(point.minutes)
	game.state.world.weather_day=0; game.state.world.weather=""
	game.walk_animation_time=0.0; game.benchmark_autoplay=false
	game.message=""; game.discovery_current.clear(); game.touch_controls_visible=false
	game.clear_movement_keys(); game.sync_background_location(); game.sync_background_environment(); game.update_camera()

## Возвращает фактическую геометрию, климат и состояние, которое сравнивается между запусками.
static func snapshot(game: Node, point: Dictionary) -> Dictionary:
	return {"id":point.id,"location":game.current_location,"player":pair(game.player),"camera":pair(game.camera_offset),
		"facing":pair(game.facing),"day":game.day,"minutes":game.game_minutes,"phase":"day" if game.game_minutes>=600 and game.game_minutes<1080 else "other",
		"seed":game.world_loot_seed,"season":game.WorldEventSystem.season(game.day),"weather":game.WorldEventSystem.weather(game),
		"walkable":game.NavigationSystem.walkability_reason(game,game.player,-1,true,false),"physics_processing":game.is_physics_processing()}

## Отклоняет несовпадение реальной камеры, позиции, климата или режима со статическим контрактом.
static func errors(game: Node, point: Dictionary) -> Array:
	var result:=[]; var actual:=snapshot(game,point)
	for key in ["location","player","camera","facing","day","minutes","phase","seed","season","weather"]:
		var equal:bool=vector(actual[key])==vector(point[key]) if key in ["player","camera","facing"] else actual[key]==point[key]
		if not equal: result.append("%s: %s differs"%[point.id,key])
	if actual.walkable!="walkable": result.append("%s: blocked: %s"%[point.id,actual.walkable])
	if actual.physics_processing: result.append("%s: static point is moving"%point.id)
	if game.GameLoop.modal_active(game) or game.GameLoop.gameplay_window_open(game): result.append("%s: modal"%point.id)
	var screen:Vector2=game.player-game.camera_offset
	if not game.CameraSystem.playfield_rect(game).has_point(screen): result.append("%s: hero outside playfield"%point.id)
	return result

## Переводит координаты JSON в вектор без изменения масштаба.
static func vector(value: Array) -> Vector2:
	return Vector2(value[0],value[1])

## Сохраняет числовую пару без округления координат.
static func pair(value: Vector2) -> Array:
	return [value.x,value.y]
