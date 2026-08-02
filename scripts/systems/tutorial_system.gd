extends RefCounted

const STEP_IDS := [
	"move", "audio_feedback", "character_animation", "forage_harvest", "forage_regrow", "forage_sale",
	"talk", "hold_action", "plant", "water", "rewater", "harvest", "shop", "trade",
	"quest_complete", "fight", "combat_animation", "loot", "inventory", "hotbar", "eat", "equipment", "mine",
	"fish", "craft_window", "equip", "collision", "travel", "locations", "mission_accept",
	"mission_complete", "journal", "side_mission", "colored_crystal", "day", "level_up",
	"skill_point", "profession", "save", "wildlife", "world_loot", "watermelon", "potion",
	"shield", "lizard",
]


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func steps() -> Array:
	return STEP_IDS.map(func(event_id: String): return {"event": event_id})

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func notify(game: Node, event_name: String) -> bool:
	game.tutorial_events_completed[event_name] = true
	var previous_step: int = game.tutorial_step
	while game.tutorial_step < game.tutorial_steps.size():
		var required_event: String = game.tutorial_steps[game.tutorial_step].event
		if not game.tutorial_events_completed.has(required_event):
			break
		game.tutorial_step += 1
	return game.tutorial_step > previous_step

## Выполняет операцию «сброса» и возвращает результат согласно контракту метода.
static func reset(game: Node) -> void:
	game.tutorial_step = 0
	game.tutorial_events_completed.clear()
	game.seen_discoveries.clear()
	game.discovery_current.clear()
	game.discovery_timer = 0.0
	game.discovery_scan_timer = 0.0
	game.character_animation_directions.clear()
	game.tutorial_visible = true
	game.message = game.LocaleSystem.text("tutorial_reset")
