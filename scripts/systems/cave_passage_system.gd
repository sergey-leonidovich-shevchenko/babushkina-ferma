extends RefCounted

const Rooms := preload("res://scripts/systems/cave_room_data.gd")


## Находит ближайший настоящий туннель активной комнаты, не принимая дверь другой комнаты.
static func nearest(game: Node, distance_limit: float) -> String:
	var result := ""
	for passage in Rooms.passages(game.current_location):
		var distance: float = game.player.distance_to(passage.position)
		if distance < distance_limit:
			distance_limit = distance; result = "cave_passage:%s" % passage.port
	return result


## Переводит героя в связанную комнату за пределы обратного триггера, сохраняя состояние всех её объектов.
static func travel(game: Node, port: String) -> bool:
	for passage in Rooms.passages(game.current_location):
		if passage.port != port or game.player.distance_to(passage.position) > 92.0: continue
		game.current_location = passage.target; game.player = passage.spawn
		game.location_transition_armed = false; game.location_transition_cooldown = game.LocationTransitionSystem.REENTRY_DELAY
		game.companion_positions.clear()
		for companion_id in game.active_companions: game.companion_positions[companion_id] = game.player + Vector2(-48,24)
		game.state.player.adventure_ui.target_enemy = -1
		game.sync_background_location(); game.update_camera(); game.play_sfx("travel")
		game.message = game.LocaleSystem.location(game.current_location)
		game.DiscoverySystem.show_location(game, game.current_location); game.notify_tutorial("cave_labyrinth")
		return true
	return false
