extends RefCounted

const HeroVisual := preload("res://scripts/systems/hero_visual_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const WorldVisibility := preload("res://scripts/systems/world_visibility_system.gd")
const META_KEY := "tree_occlusion_frame"
const HIDDEN_ALPHA := 0.34
const FADE_SECONDS := 0.20
const DEPTH_MARGIN := 6.0
const STALE_SECONDS := 0.60
const DEPTH_FLAG:=&"plant_depth_enabled"
const TRACE:=&"plant_depth_trace"


## Открывает один визуальный кадр: кэш не попадает в сохранение и сбрасывается при смене локации.
static func begin_frame(game: Node, delta: float = -1.0) -> void:
	var now := Time.get_ticks_usec() / 1000000.0
	var state: Dictionary = game.get_meta(META_KEY, {})
	if String(state.get("location", "")) != game.current_location:
		state = {"location":game.current_location, "entries":{}, "time":now}
	state.delta = clampf(now - float(state.time) if delta < 0.0 else delta, 0.0, 0.10)
	state.time = now
	state.queue = []
	state.seen = {}
	state.hero_bounds = hero_bounds(game)
	state.hero_ground = Pose.ground(game)
	state.visible_rect = WorldVisibility.visible_rect(game)
	for key in state.entries.keys():
		if now - float(state.entries[key].seen_at) > STALE_SECONDS: state.entries.erase(key)
	game.set_meta(META_KEY, state)


## Берёт границы текущего production-кадра героя, а не старый квадрат со смещением +24 пикселя.
static func hero_bounds(game: Node) -> Rect2:
	var moving: bool = game.PlayerSystem.is_visually_moving(game)
	var pose := HeroVisual.current_pose(game, game.facing, moving)
	var ground := Pose.ground(game)
	var frame := HeroVisual.destination(ground, pose)
	# Прозрачные поля мастер-листа и поднятый инструмент не считаются телом героя.
	var body := Rect2(ground - Vector2(25, 84), Vector2(50, 83))
	return frame.intersection(body)


## Сравнивает опоры объектов: южнее ствола герой всегда рисуется поверх дерева.
static func is_foreground(player: Vector2, ground_y: float) -> bool:
	return player.y < ground_y - DEPTH_MARGIN


## Включает общий путь низких растений только в первой карте; редактор и неверный флаг сохраняют прежний вывод.
static func enabled(game:Node)->bool:
	var value:Variant=game.get_meta(DEPTH_FLAG,true)
	return game.current_location=="overworld" and not game.LevelEditorSystem.active(game) and typeof(value)==TYPE_BOOL and value


## Не использует очередь прошлого мира даже при отдельном вызове renderer-а после переноса.
static func _frame(game:Node)->Dictionary:
	if not game.has_meta(META_KEY) or String(game.get_meta(META_KEY).location)!=game.current_location:begin_frame(game)
	return game.get_meta(META_KEY)


## Проверяет настоящее перекрытие тела кроной; дальние северные деревья не исчезают.
static func overlaps_hero(player: Vector2, body: Rect2, tree_rect: Rect2, ground_y: float) -> bool:
	if not is_foreground(player, ground_y) or body.size == Vector2.ZERO: return false
	var crown := Rect2(tree_rect.position + tree_rect.size * Vector2(0.10, 0.06), tree_rect.size * Vector2(0.80, 0.88))
	return crown.intersects(body)


## Плавно изменяет прозрачность за фиксированное время независимо от частоты кадров.
static func next_alpha(current: float, hidden: bool, delta: float, reduced_motion: bool = false) -> float:
	var target := HIDDEN_ALPHA if hidden else 1.0
	if reduced_motion: return target
	return move_toward(clampf(current, HIDDEN_ALPHA, 1.0), target, maxf(delta, 0.0) * (1.0 - HIDDEN_ALPHA) / FADE_SECONDS)


## Обновляет только визуальное состояние конкретного дерева; коллизии и урожай остаются неизменны.
static func opacity(game: Node, key: String, rect: Rect2, ground_y: float) -> float:
	var state:=_frame(game)
	var hidden := overlaps_hero(state.hero_ground, state.hero_bounds, rect, ground_y)
	var entry: Dictionary = state.entries.get(key, {"alpha":1.0, "seen_at":state.time})
	entry.alpha = next_alpha(float(entry.alpha), hidden, float(state.delta), game.settings_state.reduced_motion)
	entry.seen_at = state.time
	state.entries[key] = entry
	return float(entry.alpha)


## Создаёт одну команду дерева: передний слой откладывается до героя, задний рисуется немедленно.
static func submit(game: Node2D, key: String, texture: Texture2D, rect: Rect2, source: Rect2, ground_y: float, tint: Color = Color.WHITE, overlay: Callable = Callable(), fade:bool=true) -> void:
	var state:=_frame(game)
	if not (state.visible_rect as Rect2).intersects(rect, true): return
	# Один объект не должен иметь непрозрачного дубля под полупрозрачной кроной.
	if state.seen.has(key): return
	state.seen[key] = true
	var alpha := opacity(game, key, rect, ground_y) if fade else 1.0
	var front:=is_foreground(state.hero_ground,ground_y)
	var packet := {"key":key,"texture":texture,"rect":rect,"source":source,"ground_y":ground_y,"tint":Color(tint,tint.a*alpha),"alpha":alpha,"overlay":overlay,"front":front}
	if front: state.queue.append(packet)
	else: draw_packet(game, packet)


## Хранит составной рисунок только до переднего прохода текущего кадра; ключ блокирует повтор до и после flush.
static func submit_body(game:Node2D,key:String,rect:Rect2,ground_y:float,paint:Callable)->String:
	if not paint.is_valid():return "rejected"
	if not enabled(game):paint.call();return "legacy"
	var state:=_frame(game)
	if not (state.visible_rect as Rect2).intersects(rect,true):return "culled"
	if state.seen.has(key):return "duplicate"
	state.seen[key]=true
	var front:=is_foreground(state.hero_ground,ground_y)
	var packet:={"key":key,"rect":rect,"ground_y":ground_y,"alpha":1.0,"front":front,"paint":paint}
	if front:state.queue.append(packet);return "front"
	draw_packet(game,packet);return "back"


## При одинаковой глубине использует постоянный ключ; равная опора героя остаётся в заднем проходе.
static func _less(a:Dictionary,b:Dictionary)->bool:
	if float(a.ground_y)!=float(b.ground_y):return float(a.ground_y)<float(b.ground_y)
	return String(a.key)<String(b.key)


## Выводит отложенные деревья один раз в порядке их опоры; повторный вызов не добавляет дубли.
static func draw_foreground(game: Node2D) -> void:
	if not game.has_meta(META_KEY): return
	var state: Dictionary = game.get_meta(META_KEY)
	if state.location!=game.current_location:state.queue.clear();state.seen.clear();return
	if enabled(game):state.queue.sort_custom(_less)
	else:state.queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.ground_y) < float(b.ground_y))
	for packet in state.queue: draw_packet(game, packet)
	state.queue.clear()


## Рисует спрайт и зависимый погодный слой с одинаковой прозрачностью, без чтения PNG с GPU в кадре.
static func draw_packet(game: Node2D, packet: Dictionary) -> void:
	var paint:Callable=packet.get("paint",Callable())
	if paint.is_valid():paint.call();_record(game,packet,"body");return
	if Rect2(packet.source).size == Vector2.ZERO: game.draw_texture_rect(packet.texture, packet.rect, false, packet.tint)
	else: game.draw_texture_rect_region(packet.texture, packet.rect, packet.source, packet.tint)
	var overlay: Callable = packet.overlay
	if overlay.is_valid(): overlay.call(float(packet.alpha))
	_record(game,packet,"texture")


## Ограниченная QA-трасса записывает реальный dispatch; обычная игра не создаёт диагностический массив.
static func _record(game:Node,packet:Dictionary,kind:String)->void:
	if not game.has_meta(TRACE):return
	var trace:Variant=game.get_meta(TRACE)
	if not trace is Array or trace.size()>=512:return
	var rect:Rect2=packet.rect
	trace.append({"key":packet.key,"phase":"front" if packet.get("front",false) else "back","kind":kind,"ground_y":packet.ground_y,"alpha":packet.alpha,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})


## Формирует стабильный идентификатор нарисованного дерева, не меняя словарь игрового объекта.
static func key_for(family: String, position: Vector2) -> String:
	return "%s:%.3f:%.3f" % [family, position.x, position.y]
