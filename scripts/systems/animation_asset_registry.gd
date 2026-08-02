extends RefCounted

const REQUIRED_DIRECTIONS := 8
const MIN_WALK_FRAMES := 3
const MAX_WALK_FRAMES := 5
const AUDIT := {
	"hero":{"directions":8,"frames":4,"asset":"directional/hero_*_walk_8dir.png"},
	"npc_grandmother":{"directions":8,"frames":4,"asset":"directional/npc_grandmother_walk_8dir.png"},
	"npc_official":{"directions":8,"frames":4,"asset":"directional/npc_official_walk_8dir.png"},
	"npc_herbalist":{"directions":8,"frames":4,"asset":"directional/npc_herbalist_walk_8dir.png"},
	"companion_mila":{"directions":8,"frames":4,"asset":"directional/companion_mila_walk_8dir.png"},
	"companion_borislav":{"directions":8,"frames":4,"asset":"directional/companion_borislav_walk_8dir.png"},
	"companion_luna":{"directions":8,"frames":4,"asset":"directional/companion_luna_walk_8dir.png"},
	"orc":{"directions":1,"frames":1,"asset":"enemy_rank_atlas.png"}, "skeleton":{"directions":1,"frames":1,"asset":"enemy_rank_atlas.png"},
	"undead":{"directions":1,"frames":1,"asset":"enemy_rank_atlas.png"}, "cave_guardian":{"directions":1,"frames":1,"asset":"enemy_rank_atlas.png"},
	"pirate":{"directions":1,"frames":1,"asset":"pirate_enemy_atlas.png"}, "zombie_pirate":{"directions":1,"frames":1,"asset":"pirate_enemy_atlas.png"},
	"sea_ghost":{"directions":1,"frames":1,"asset":"pirate_enemy_atlas.png"}, "drowned_captain":{"directions":1,"frames":1,"asset":"pirate_enemy_atlas.png"},
	"deer":{"directions":2,"frames":6,"asset":"deer_run.png"}, "fox":{"directions":2,"frames":6,"asset":"fox_run.png"}, "boar":{"directions":2,"frames":5,"asset":"boar_run.png"},
	"bat":{"directions":2,"frames":1,"asset":"fantasy_wildlife_atlas.png"}, "lizard":{"directions":2,"frames":3,"asset":"fantasy_wildlife_atlas.png"},
}


## Проверяет соответствие записи обязательному стандарту восьми направлений и трёх–пяти кадров.
static func is_compliant(actor_id: String) -> bool:
	if not AUDIT.has(actor_id): return false
	var data: Dictionary = AUDIT[actor_id]
	return data.directions == REQUIRED_DIRECTIONS and int(data.frames) >= MIN_WALK_FRAMES and int(data.frames) <= MAX_WALK_FRAMES


## Возвращает полный перечень подвижных объектов, которым необходимо дорисовать анимацию.
static func backlog() -> Array[String]:
	var result: Array[String] = []
	for actor_id in AUDIT:
		if not is_compliant(actor_id): result.append(actor_id)
	result.sort()
	return result


## Возвращает один из восьми индексов направления по часовой стрелке, начиная снизу.
static func direction_index(direction: Vector2) -> int:
	if direction.length_squared() < 0.001: return 0
	var angle := fposmod(atan2(-direction.x, direction.y), TAU)
	return int(round(angle / (TAU / 8.0))) % 8
