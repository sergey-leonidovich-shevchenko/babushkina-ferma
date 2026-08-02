extends RefCounted

const WALK_SPEED := 34.0
const WANDER_RADIUS := 58.0
const PAUSE_MIN := 1.4
const PAUSE_STEP := 0.37


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
		"location": location, "home": home, "position": home,
		"direction": Vector2.DOWN, "moving": false,
		"timer": PAUSE_MIN + float(index % 4) * PAUSE_STEP, "route_index": index % 8,
	}


## Обновляет безопасные короткие прогулки NPC только на активной локации.
static func update(game: Node, delta: float) -> void:
	for actor_id in game.npc_movement:
		var state: Dictionary = game.npc_movement[actor_id]
		if state.location != game.current_location:
			state.moving = false
			continue
		state.timer -= delta
		if state.timer <= 0.0:
			choose_next_phase(state)
		if not state.moving:
			continue
		var next_position: Vector2 = state.position + state.direction * WALK_SPEED * delta
		if next_position.distance_to(state.home) > WANDER_RADIUS or not game.NavigationSystem.is_walkable(game, next_position):
			state.direction = state.position.direction_to(state.home)
			next_position = state.position + state.direction * WALK_SPEED * delta
			if not game.NavigationSystem.is_walkable(game, next_position):
				state.moving = false
				state.timer = PAUSE_MIN
				continue
		state.position = next_position
		game.notify_tutorial("npc_wander")


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
