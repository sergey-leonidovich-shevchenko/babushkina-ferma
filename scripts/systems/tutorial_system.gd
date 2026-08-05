extends RefCounted

const STEP_IDS := [
	"move", "village_paths", "audio_feedback", "character_animation", "npc_wander", "npc_schedule", "forage_harvest", "forage_regrow", "forage_sale",
	"talk", "hold_action", "plant", "water", "rewater", "harvest", "shop", "trade",
	"quest_complete", "fight", "combat_animation", "combat_dodge", "combat_block", "critical_hit", "loot", "inventory", "inventory_filters", "hotbar", "eat", "equipment", "mine", "tree_chop", "tree_fall", "tree_regrow",
	"fish_cast", "fish_hook", "fish_control", "fish", "craft_window", "equip", "collision", "travel", "locations", "mission_accept", "story_chain", "side_quests",
	"mission_complete", "journal", "side_mission", "colored_crystal", "day", "level_up",
	"skill_point", "profession", "pause_menu", "settings", "save", "wildlife", "wildlife_behavior", "world_loot", "watermelon", "potion",
	"shield", "lizard",
	"building_enter", "locked_building", "castle_floor", "companion_recruit", "companion_change", "companion_commands",
	"enemy_levels", "enemy_movement", "enemy_attack_styles", "boss_identity", "contact_hazard", "static_attacker", "hero_skin",
	"chest_install", "chest_open", "chest_deposit", "chest_withdraw", "estate_upgrade", "item_quality", "world_calendar", "world_map",
	"forge_open", "weapon_sharpen", "armor_upgrade", "arrow_sharpen",
	"contract_board", "contract_accept", "contract_complete", "guild_rank",
	"pirate_ship", "pirate_quest", "pirate_loot", "invisibility", "season", "weather", "night", "eclipse", "moon_portal", "moon_flower", "moon_crystal", "moon_echoes", "moon_altar", "moon_guardian", "moon_treasure", "story_after_eclipse", "castle_investigation", "quest_investigation", "boss_phases", "story_choice",
	"character_creation", "dialogue_choices", "npc_gift", "personal_request", "market_event", "festival_event", "night_trader", "raid_event", "interior_furniture", "debug_inspector", "target_lock", "durability_low", "durability_broken", "repair", "backpack_upgrade", "animal_feed", "animal_product", "museum", "secret_puzzle", "furniture_place", "photo_mode",
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
