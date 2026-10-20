extends RefCounted

const META := &"presentation_pose"
const Camera := preload("res://scripts/systems/camera_system.gd")

## Хранит только две физические опоры и отображаемый кадр; данные не входят в сохранения.
static func reset(game: Node) -> Dictionary:
	var clock := float(game.get_meta(&"player_walk_time", 0.0))
	var value := {"location":game.current_location,"previous":game.player,"current":game.player,
		"ground":game.player,"previous_clock":clock,"current_clock":clock,"clock":clock,"suspended":false,"presented":false}
	game.set_meta(META,value)
	return value

## Отклоняет устаревший кадр после загрузки, телепорта или смены карты, в том числе до нового такта.
static func valid(game: Node, value: Dictionary) -> bool:
	return not value.is_empty() and value.location==game.current_location and Vector2(value.current)==game.player

## Замораживает представление при модальных окнах и оставляет ручную камеру редактора её владельцу.
static func suspended(game: Node) -> bool:
	return game.language_screen or game.GameLoop.modal_active(game) or game.GameLoop.gameplay_window_open(game) or game.LevelEditorSystem.active(game)

## Открывает физический такт; игровой цикл по-прежнему работает только с настоящей позицией.
static func begin_tick(game: Node) -> void:
	var value: Dictionary = game.get_meta(META,{})
	if not valid(game,value): value=reset(game)
	if suspended(game): value.suspended=true; return
	if bool(value.suspended): value=reset(game)
	value.previous=game.player
	value.previous_clock=float(game.get_meta(&"player_walk_time",0.0))

## Запоминает результат коллизий; переносы и новый ракурс карты никогда не интерполируются через мир.
static func end_tick(game: Node, delta: float) -> void:
	var value: Dictionary = game.get_meta(META,{})
	if value.is_empty(): reset(game); return
	if suspended(game):
		if not valid(game,value): value=reset(game)
		value.suspended=true; return
	var limit := maxf(8.0, float(game.speed)*maxf(delta,0.0)*2.0)
	if value.location!=game.current_location or Vector2(value.previous).distance_to(game.player)>limit:
		reset(game); return
	value.current=game.player
	value.current_clock=float(game.get_meta(&"player_walk_time",0.0))
	value.presented=false
	if float(value.current_clock)<float(value.previous_clock): value.previous_clock=value.current_clock

## Строит один общий кадр между тактами; фон, ввод и герой используют одну и ту же камеру.
static func present(game: Node, fraction: float) -> bool:
	var value: Dictionary = game.get_meta(META,{})
	if not valid(game,value): value=reset(game)
	if suspended(game): value.suspended=true; return false
	if bool(value.suspended): value=reset(game)
	var alpha := clampf(fraction,0.0,1.0) if is_finite(fraction) else 1.0
	var before: Vector2 = value.ground
	var before_clock: float = value.clock
	value.ground=Vector2(value.previous).lerp(value.current,alpha)
	value.clock=lerpf(float(value.previous_clock),float(value.current_clock),alpha)
	value.presented=true
	var camera := Camera.offset_for_position(game,value.ground)
	var changed: bool = before!=value.ground or before_clock!=float(value.clock) or game.camera_offset!=camera
	game.camera_offset=camera
	Camera.WorldProjection.sync_background(game)
	return changed

## Даёт телу, тени и окружению одну отображаемую точку без записи в PlayerState.
static func ground(game: Node) -> Vector2:
	var value: Dictionary = game.get_meta(META,{})
	return Vector2(value.ground) if valid(game,value) and bool(value.presented) else Vector2(game.player)

## Передаёт циклу ног ту же фазу, что движению отображаемой опоры.
static func walk_clock(game: Node) -> float:
	var value: Dictionary = game.get_meta(META,{})
	return float(value.clock) if valid(game,value) and bool(value.presented) else float(game.get_meta(&"player_walk_time",0.0))

## Возвращает локальный вектор от корня к видимой ноге для визуальной реакции растений.
static func root_contact(game: Node, root: Vector2, radius: float) -> Vector2:
	var offset := ground(game)-root
	return offset/maxf(radius,0.001) if radius>0.0 and offset.length()<radius else Vector2.ZERO
