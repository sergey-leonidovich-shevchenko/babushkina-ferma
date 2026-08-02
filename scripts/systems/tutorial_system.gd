extends RefCounted

static func notify(game: Node, event_name: String) -> bool:
	if game.tutorial_step >= game.tutorial_steps.size():
		return false
	if game.tutorial_steps[game.tutorial_step].event != event_name:
		return false
	game.tutorial_step += 1
	return true

static func reset(game: Node) -> void:
	game.tutorial_step = 0
	game.tutorial_visible = true
	game.message = "Обучение начато заново"
