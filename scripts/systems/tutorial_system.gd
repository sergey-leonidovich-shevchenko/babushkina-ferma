extends RefCounted

static func notify(game: Node, event_name: String) -> bool:
	game.tutorial_events_completed[event_name] = true
	var previous_step: int = game.tutorial_step
	while game.tutorial_step < game.tutorial_steps.size():
		var required_event: String = game.tutorial_steps[game.tutorial_step].event
		if not game.tutorial_events_completed.has(required_event):
			break
		game.tutorial_step += 1
	return game.tutorial_step > previous_step

static func reset(game: Node) -> void:
	game.tutorial_step = 0
	game.tutorial_events_completed.clear()
	game.seen_discoveries.clear()
	game.discovery_current.clear()
	game.discovery_timer = 0.0
	game.discovery_scan_timer = 0.0
	game.tutorial_visible = true
	game.message = "Обучение начато заново"
