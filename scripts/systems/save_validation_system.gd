extends RefCounted

const PLOT := {"!": ["x", "y", "tilled", "planted", "watered", "growth", "stage"], "x":"n", "y":"n", "tilled":"b", "planted":"b", "watered":"b", "growth":"n", "stage":"n", "crop_kind":"s", "location":"s"}
const CORE := {
	"player":"p", "location":"s", "day":"n", "minutes":"n", "energy":"n", "coins":"n", "xp":"n", "level":"n", "hp":"n",
	"counts":{"*":"n"}, "slots":["s"], "hotbar":["s"], "equipment":{"*":"s"}, "quest_active":"b", "quest_complete":"b",
	"weapons":{"!":["sword", "bow", "crystal", "equipped"], "sword":"b", "bow":"b", "crystal":"b", "equipped":"s"},
	"plots":[PLOT], "resource_hits":["n"],
}
const MEMORY := {"mission":"s", "day":"n", "state":"s", "gift_day":"n", "last_gift":"s", "personal_done":"b", "personal_day":"n"}
const EXPANSION := {
	"first_day":"n", "animals":{"*":{"!":["fed_day", "collected_day", "bond"], "fed_day":"n", "collected_day":"n", "bond":"n"}},
	"furniture":[{"!":["kind", "position"], "kind":"s", "position":"p"}], "build_mode":"b", "build_index":"n",
	"museum":["s"], "encyclopedia":["s"], "achievements":["s"], "secrets":{"*":"b"}, "reputation":"n", "relationship_scenes":["s"],
	"cutscene":"s", "cutscene_timer":"n", "compendium":"b", "page":"n", "photo_mode":"b", "photo_grid":"b",
	"projectiles":[{"!":["from", "to", "progress", "kind"], "from":"p", "to":"p", "progress":"n", "kind":"s"}],
	"hit_stop":"n", "active_slot":"n", "autosaved_day":"n",
	"first_chapter":{"stage":"n", "events":{"*":"b"}, "bridge_repaired":"b", "reward_pending":"b", "reward_choice":"s", "completed":"b", "started_day":"n"},
	"fences":[{"!":["location", "cell"], "location":"s", "cell":"p", "style":"n", "kind":"s", "orientation":"n", "open":"b"}],
}
const OPTIONAL := {
	"profile":{"character":{"created":"b", "name":"s", "farm_name":"s", "appearance":"n", "clothes":"n", "specialization":"s"}, "relationships":{"*":"n"}, "quest_memory":{"*":MEMORY}},
	"inventory_meta":{"backpack_level":"n", "durability":{"*":"n"}},
	"progression":{"points":"n", "levels":{"*":"n"}, "xp":{"*":"n"}, "talents":{"*":"n"}, "craft_count":"n", "mana":"n"},
	"effects":{"strength":"n", "regeneration":"n", "speed":"n", "invisibility":"n", "defense":"n"},
	"fishing":{"caught":"n", "records":{"*":"n"}, "counts":{"*":"n"}, "qualities":{"*":"s"}, "perfect":"n", "best_control":"n", "traps":[{"!":["location", "position"], "location":"s", "position":"p", "ready_day":"n"}]},
	"companions":{"recruited":["s"], "active":["s"], "command":"s", "bonds":{"*":"n"}}, "storage":{"owned":"b", "counts":{"*":"n"}},
	"forge":{"*":"n"}, "contracts":{"day":"n", "statuses":{"*":"s"}, "completed":"n"}, "missions":{"*":"s"},
	"tutorial":{"step":"n", "events":{"*":"b"}, "seen":{"*":"b"}, "animation":["n"]},
	"moon_glade":{"event_day":"n", "flower_collected":"b", "crystal_charged":"b", "echoes":["b"], "altar_activated":"b", "guardian_alive":"b", "guardian_defeated":"b", "guardian_hp":"n", "guardian_attack_timer":"n", "guardian_windup":"n", "guardian_hurt_timer":"n", "chest_opened":"b", "completed_runs":"n"},
	"castle_campaign":{"stage":"n", "clues":["b"], "boss_alive":"b", "boss_defeated":"b", "boss_hp":"n", "boss_phase":"n", "boss_timer":"n", "telegraph":"n", "boss_hurt_timer":"n", "choice":"s", "completed":"b"},
	"estate":{"level":"n", "map_revision":"n", "qualities":{"*":{"*":"n"}}, "discovered":["s"], "event_day":"n", "event":"s", "event_state":{"day":"n", "used":"b", "spawned":"b", "rewarded":"b"}, "expansion":EXPANSION},
	"world_plots":[{"location":"s", "x":"n", "y":"n", "tilled":"b", "planted":"b", "watered":"b", "growth":"n", "stage":"n", "crop_kind":"s"}],
	"trees":[{"!":["health", "stage", "regrow_timer"], "health":"n", "stage":"n", "regrow_timer":"n"}], "food_active":["b"],
	"forage":[{"!":["active", "ready_at"], "active":"b", "ready_at":"n", "stage":"n", "kind":"s", "location":"s", "position":"p", "planted_by_player":"b"}],
	"enemies":[{"!":["hp", "alive"], "hp":"n", "alive":"b", "level":"n", "position":"p", "direction":"p", "attack_timer":"n"}],
	"hazards":[{"cooldown":"n"}], "wildlife":[{"!":["hp", "alive", "position"], "hp":"n", "alive":"b", "position":"p"}], "world_loot_seed":"n",
	"containers":[{"!":["id", "kind", "location", "position", "opened", "contents"], "id":"n", "kind":"s", "location":"s", "position":"p", "opened":"b", "contents":{"*":"n"}}],
	"drops":[{"!":["kind", "count", "position"], "kind":"s", "count":"n", "position":"p"}],
}


## Проверяет весь читаемый загрузчиком документ до первого изменения живого состояния.
static func valid(data: Dictionary) -> bool:
	for key in CORE:
		if not data.has(key) or not _matches(data[key], CORE[key]): return false
	if not _matches(data, OPTIONAL): return false
	# Панель инструментов обращается к десяти ячейкам по фиксированным индексам.
	return data.hotbar.size() == 10 and not data.location.is_empty()


## Принимает только конечные числа, исключая нечисловые значения и бесконечные координаты.
static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


## Проверяет вложенные записи и коллекции, допуская отсутствующие новые поля старых версий.
static func _matches(value: Variant, schema: Variant) -> bool:
	if schema is String:
		match schema:
			"n": return number(value)
			"b": return value is bool
			"s": return value is String
			"p": return value is Array and value.size() == 2 and number(value[0]) and number(value[1])
	if schema is Array:
		if not value is Array: return false
		for item in value:
			if not _matches(item, schema[0]): return false
		return true
	if not value is Dictionary: return false
	for key in schema.get("!", []):
		if not value.has(key): return false
	for key in value:
		if not (key is String or key is StringName): return false
		if schema.has("*"):
			if not _matches(value[key], schema["*"]): return false
		elif schema.has(key) and not _matches(value[key], schema[key]): return false
	return true
