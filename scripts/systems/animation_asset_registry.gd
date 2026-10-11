extends RefCounted

const REQUIRED_DIRECTIONS := 8
const MIN_WALK_FRAMES := 3
const MAX_WALK_FRAMES := 5
const AUDIT := {
	"hero":{"directions":4,"required_directions":4,"frames":4,"asset":"hero_v3/walk_master.png"},
	"npc_grandmother":{"directions":4,"required_directions":4,"frames":4,"asset":"grandmother_v2/walk_master.png"},
	"npc_official":{"directions":8,"frames":4,"asset":"directional/npc_official_walk_8dir.png"},
	"npc_herbalist":{"directions":8,"frames":4,"asset":"directional/npc_herbalist_walk_8dir.png"},
	"companion_mila":{"directions":8,"frames":4,"asset":"directional/companion_mila_walk_8dir.png"},
	"companion_borislav":{"directions":8,"frames":4,"asset":"directional/companion_borislav_walk_8dir.png"},
	"companion_luna":{"directions":8,"frames":4,"asset":"directional/companion_luna_walk_8dir.png"},
	"orc":{"directions":8,"frames":3,"asset":"animated/core_enemy_walk_8dir.png"}, "skeleton":{"directions":8,"frames":3,"asset":"skeleton_v2/walk.png"},
	"undead":{"directions":8,"frames":3,"asset":"animated/core_enemy_walk_8dir.png"}, "cave_guardian":{"directions":8,"frames":3,"asset":"animated/core_enemy_walk_8dir.png"},
	"pirate":{"directions":8,"frames":3,"asset":"animated/pirate_enemy_walk_8dir.png"}, "zombie_pirate":{"directions":8,"frames":3,"asset":"animated/pirate_enemy_walk_8dir.png"},
	"sea_ghost":{"directions":8,"frames":3,"asset":"animated/pirate_enemy_walk_8dir.png"}, "drowned_captain":{"directions":8,"frames":3,"asset":"animated/pirate_enemy_walk_8dir.png"},
	"deer":{"directions":4,"required_directions":4,"frames":3,"asset":"directional/deer_actions_8dir.png:curated"},
	"fox":{"directions":4,"required_directions":4,"frames":4,"asset":"directional/fox_walk_4dir_v2.png"},
	"boar":{"directions":4,"required_directions":4,"minimum_frames":2,"frames":2,"asset":"directional/boar_actions_8dir.png:curated"},
	"bat":{"directions":4,"required_directions":4,"frames":4,"asset":"directional/bat_flight_4dir_v2.png"},
	"lizard":{"directions":4,"required_directions":4,"frames":4,"asset":"directional/lizard_walk_4dir_v2.png"},
}


## Проверяет явный контракт семейства: четыре стороны у новых зверей, восемь у остальных; кабан сохраняет два честных кадра.
static func is_compliant(actor_id: String) -> bool:
	if not AUDIT.has(actor_id): return false
	var data: Dictionary = AUDIT[actor_id]
	return data.directions == int(data.get("required_directions", REQUIRED_DIRECTIONS)) and int(data.frames) >= int(data.get("minimum_frames", MIN_WALK_FRAMES)) and int(data.frames) <= MAX_WALK_FRAMES


## Возвращает полный перечень подвижных объектов, которым необходимо дорисовать анимацию.
static func backlog() -> Array[String]:
	var result: Array[String] = []
	for actor_id in AUDIT:
		if not is_compliant(actor_id): result.append(actor_id)
	result.sort()
	return result


## Возвращает строку фактического атласа против часовой стрелки, начиная с направления вниз.
static func direction_index(direction: Vector2) -> int:
	if direction.length_squared() < 0.001: return 0
	var angle := fposmod(atan2(-direction.x, direction.y), TAU)
	return int(round(angle / (TAU / 8.0))) % 8
