extends RefCounted

const TRIGGER_RADIUS := 38.0
const REENTRY_DELAY := 0.45


## Обновляет автоматический переход и повторно взводит его только после выхода героя из активной зоны.
static func update(game: Node, delta: float) -> bool:
	game.location_transition_cooldown = maxf(game.location_transition_cooldown - delta, 0.0)
	var transition := nearest_transition(game)
	if transition.is_empty():
		if game.location_transition_cooldown <= 0.0:
			game.location_transition_armed = true
		return false
	if not game.location_transition_armed or game.location_transition_cooldown > 0.0:
		return false
	game.location_transition_armed = false
	game.location_transition_cooldown = REENTRY_DELAY
	return activate(game, transition)


## Находит ближайшую дверь, проход, портал или границу локации без смешивания с предметными действиями.
static func nearest_transition(game: Node, distance_limit: float = TRIGGER_RADIUS) -> String:
	var nearest := ""
	if game.BuildingSystem.is_interior(game.current_location):
		var interior: Dictionary = game.BuildingSystem.INTERIORS[game.current_location]
		var exit_distance: float = game.player.distance_to(interior.exit)
		if exit_distance < distance_limit:
			distance_limit = exit_distance
			nearest = "interior_exit"
		for link in interior.get("links", []):
			var link_distance: float = game.player.distance_to(link.position)
			if link_distance < distance_limit:
				distance_limit = link_distance
				nearest = "interior_link:%s" % String(link.target)
		return nearest
	for building_id in game.BuildingSystem.buildings_at(game.current_location):
		var door_distance: float = game.player.distance_to(game.BuildingSystem.BUILDINGS[building_id].door)
		if door_distance < distance_limit:
			distance_limit = door_distance
			nearest = "building:%s" % building_id
	if game.current_location == "overworld":
		var cave_distance: float = game.player.distance_to(game.cave_entrance_position)
		if cave_distance < distance_limit:
			distance_limit = cave_distance
			nearest = "cave_entrance"
	elif game.current_location == "cave":
		var cave_distance: float = game.player.distance_to(game.cave_exit_position)
		if cave_distance < distance_limit:
			distance_limit = cave_distance
			nearest = "cave_exit"
	var gate_distance: float = game.player.distance_to(game.world_gate_position)
	if gate_distance < distance_limit:
		distance_limit = gate_distance
		nearest = "world_gate"
	var portal_position: Vector2 = game.WorldEventSystem.PORTAL_POSITION if game.current_location == "overworld" else game.WorldEventSystem.RETURN_PORTAL_POSITION
	var portal_available: bool = game.current_location == "moon_glade" or game.WorldEventSystem.eclipse_active(game.day, game.game_minutes)
	if portal_available and game.player.distance_to(portal_position) < distance_limit:
		nearest = "moon_portal"
	return nearest


## Выполняет найденный переход через его профильную систему, сохраняя музыку, обучение и сообщения локации.
static func activate(game: Node, transition: String) -> bool:
	if transition.begins_with("building:"):
		return game.BuildingSystem.enter(game, transition.get_slice(":", 1))
	if transition == "interior_exit":
		return game.BuildingSystem.leave(game)
	if transition.begins_with("interior_link:"):
		return game.BuildingSystem.travel_inside(game, transition.get_slice(":", 1))
	if transition == "cave_entrance":
		game.enter_cave()
		return true
	if transition == "cave_exit":
		game.exit_cave()
		return true
	if transition == "world_gate":
		if not game.FirstChapterSystem.can_use_world_gate(game): return false
		game.WorldSystem.travel(game)
		game.FirstChapterSystem.on_location_changed(game)
		return true
	if transition == "moon_portal":
		return game.WorldEventSystem.use_portal(game)
	return false
