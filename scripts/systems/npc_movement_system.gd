extends RefCounted

const WALK_SPEED := 34.0
const WANDER_RADIUS := 58.0
const PAUSE_MIN := 1.4
const PAUSE_STEP := 0.37
const VILLAGE_WORK := {"miron":"guild_interior","agafya":"village_garden","varvara":"village_river","gavrila":"village_workyard","dunya":"village_market"}
const VILLAGE_HOME := {"miron":"guild_interior","agafya":"cottage_interior","varvara":"cottage_interior","gavrila":"guild_interior","dunya":"shop_interior"}
const MapData:=preload("res://scripts/systems/village_map_data.gd")
const WORK_ANCHORS := {"miron":Vector2(690,310),"agafya":preload("res://scripts/systems/village_region_data.gd").NPC_POINTS.agafya,"varvara":preload("res://scripts/systems/village_region_data.gd").NPC_POINTS.varvara,"gavrila":preload("res://scripts/systems/village_region_data.gd").NPC_POINTS.gavrila,"dunya":preload("res://scripts/systems/village_region_data.gd").NPC_POINTS.dunya}
static var SOCIAL_ANCHORS:Dictionary=MapData.NPCS.merged(preload("res://scripts/systems/village_region_data.gd").NPC_POINTS)
static var _interior_anchors:Dictionary={}


## Создаёт детерминированное состояние движения для бабушки и всех квестовых жителей.
static func initialize(game: Node) -> void:
	game.npc_movement.clear()
	add_actor(game, "grandmother", "overworld", game.npc_position, 0)
	var index := 1
	for npc_id in game.QuestSystem.NPCS:
		add_actor(game, npc_id, String(game.QuestSystem.NPCS[npc_id].location), game.QuestSystem.npc_position(game, npc_id), index)
		index += 1


## Добавляет одного жителя с собственной фазой маршрута и исходной точкой дома.
static func add_actor(game: Node, actor_id: String, location: String, home: Vector2, index: int) -> void:
	game.npc_movement[actor_id] = {
		"actor_id":actor_id, "location": location, "home_location": location, "home": home, "position": home,
		"direction": Vector2.DOWN, "moving": false,
		"timer": PAUSE_MIN + float(index % 4) * PAUSE_STEP, "route_index": index % 8,
	}


## Обновляет безопасные короткие прогулки NPC только на активной локации.
static func update(game: Node, delta: float) -> void:
	for actor_id in game.npc_movement:
		var state: Dictionary = game.npc_movement[actor_id]
		var anchor: Vector2 = schedule_anchor(game, state)
		if state.location != game.current_location:
			state.moving = false
			continue
		state.timer -= delta
		if state.timer <= 0.0:
			choose_next_phase(state)
		if not state.moving:
			continue
		var next_position: Vector2 = state.position + state.direction * WALK_SPEED * delta
		if next_position.distance_to(anchor) > WANDER_RADIUS or not game.NavigationSystem.is_walkable(game, next_position):
			state.direction = state.position.direction_to(anchor)
			next_position = state.position + state.direction * WALK_SPEED * delta
			if not game.NavigationSystem.is_walkable(game, next_position):
				state.moving = false
				state.timer = PAUSE_MIN
				continue
		state.position = next_position
		game.notify_tutorial("npc_wander")


## Возвращает сменяющуюся по времени и погоде точку распорядка жителя.
static func schedule_anchor(game: Node, state: Dictionary) -> Vector2:
	var previous_location: String = state.location; var previous_position: Vector2 = state.position
	var previous_schedule: String = state.get("schedule","")
	var actor_id := String(state.get("actor_id", "grandmother"))
	var hour: int = int(game.game_minutes / 60.0)
	var weather: String = game.WorldEventSystem.weather_for_day(game.day)
	if not VILLAGE_HOME.has(actor_id):
		var shift := Vector2(-18,-24) if weather in ["rain", "storm", "snow"] else (Vector2(-34,18) if hour < 8 else (Vector2(38,22) if hour >= 18 else Vector2(22,-18)))
		state.location = state.home_location; state.schedule = "shelter" if weather in ["rain", "storm", "snow"] else ("morning" if hour < 8 else ("evening" if hour >= 18 else "work"))
		game.notify_tutorial("npc_schedule"); return Vector2(state.home) + shift
	var shelter := weather in ["rain", "storm", "snow"]
	if hour < 6 or hour >= 22:
		state.location = VILLAGE_HOME[actor_id]; state.schedule = "сон"
	elif shelter:
		state.location = VILLAGE_HOME[actor_id]; state.schedule = "укрывается от непогоды"
	elif hour < 9:
		state.location = game.QuestSystem.NPCS[actor_id].location; state.schedule = "идёт на работу"
	elif hour < 17:
		state.location = VILLAGE_WORK[actor_id]; state.schedule = "работает"
	elif hour < 20:
		state.location = game.QuestSystem.NPCS[actor_id].location; state.schedule = "гуляет по своему району"
	else:
		state.location = VILLAGE_HOME[actor_id]; state.schedule = "возвращается домой"
	var target:Vector2=interior_anchor(game,state.location,actor_id) if game.BuildingSystem.is_interior(state.location) else (WORK_ANCHORS.get(actor_id,state.home) if state.schedule=="работает" else SOCIAL_ANCHORS.get(actor_id,state.home))
	var initialized: bool = state.get("schedule_initialized",false)
	if initialized and state.location != previous_location and (visible(game,previous_location,previous_position) or visible(game,state.location,target)):
		state.location=previous_location; state.position=previous_position; state.schedule=previous_schedule
		state.moving=false; state.schedule_deferred=true; return previous_position
	state.schedule_initialized=true; state.schedule_deferred=false
	if state.location != previous_location or (state.position.distance_to(target) > WANDER_RADIUS * 4.0 and (not initialized or not visible(game,state.location,state.position))): state.position = target
	game.notify_tutorial("npc_schedule")
	return target

## Проверяет видимость старой и новой опоры, не допуская исчезновения и появления жителя перед камерой.
static func visible(game: Node, location: String, position: Vector2) -> bool:
	return location == game.current_location and preload("res://scripts/systems/world_visibility_system.gd").visible_rect(game).grow(80).has_point(position)


## Кеширует устойчивую точку на свободном полу, не повторяя поиск среди неизменной мебели каждый кадр.
static func interior_anchor(game: Node, location: String, actor_id: String) -> Vector2:
	var key:=location+":"+actor_id
	if _interior_anchors.has(key): return _interior_anchors[key]
	var data: Dictionary = game.BuildingSystem.interior(location)
	if data.is_empty(): return Vector2(576, 330)
	var phase := posmod(actor_id.hash(), 5)
	var target:Vector2=data.room.get_center()+Vector2(-110+phase*48,70 if phase%2==0 else -20)
	if game.BuildingSystem.is_walkable_inside(location,target,game.PLAYER_RADIUS): _interior_anchors[key]=target; return target
	var nearest:=Vector2.INF; var distance:=INF
	for y in range(int(data.room.position.y)+48,int(data.room.end.y)-48,48):
		for x in range(int(data.room.position.x)+48,int(data.room.end.x)-48,48):
			var point:=Vector2(x,y)
			if point.distance_to(target)<distance and game.BuildingSystem.is_walkable_inside(location,point,game.PLAYER_RADIUS): nearest=point; distance=point.distance_to(target)
	var result:Vector2=nearest if nearest!=Vector2.INF else data.spawn
	_interior_anchors[key]=result; return result


## Чередует остановку и одно из восьми направлений без случайности, удобной для тестов.
static func choose_next_phase(state: Dictionary) -> void:
	if state.moving:
		state.moving = false
		state.timer = PAUSE_MIN
		return
	var directions := [Vector2.DOWN, Vector2(-1, 1).normalized(), Vector2.LEFT, Vector2(-1, -1).normalized(), Vector2.UP, Vector2(1, -1).normalized(), Vector2.RIGHT, Vector2(1, 1).normalized()]
	state.route_index = (int(state.route_index) + 3) % directions.size()
	state.direction = directions[state.route_index]
	state.moving = true
	state.timer = 1.1


## Возвращает текущее состояние жителя либо безопасное состояние покоя в переданном месте.
static func actor(game: Node, actor_id: String, fallback: Vector2) -> Dictionary:
	return game.npc_movement.get(actor_id, {"position": fallback, "direction": Vector2.DOWN, "moving": false})
