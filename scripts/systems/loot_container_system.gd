extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const TYPES := {
	"chest": {"name":"Старый сундук","rolls":3,"table":[["coins",8,24,30],["metal",1,3,18],["blue_gem",1,1,8],["crystal",1,3,16],["apple",1,2,15],["healing_potion",1,1,8],["oak_shield",1,1,5]]},
	"bone_pile": {"name":"Груда костей","rolls":2,"table":[["bones",1,4,45],["ancient_key",1,1,8],["bat_wing",1,2,17],["coins",3,12,20],["blue_gem",1,1,10]]},
	"sack": {"name":"Брошенный мешок","rolls":2,"table":[["seeds",2,6,27],["carrot",1,3,18],["apple",1,2,13],["berries",1,3,13],["watermelon",1,1,9],["fiber",1,3,20]]},
	"trash": {"name":"Куча хлама","rolls":2,"table":[["stone",1,3,25],["wood",1,3,25],["metal",1,2,18],["coins",1,8,18],["orange",1,1,4],["fiber",1,3,10]]},
}

const SPAWNS := [
	{"location":"overworld","count":3,"types":["sack","trash"],"positions":[Vector2(1080,760),Vector2(1710,780),Vector2(2050,410),Vector2(1180,350),Vector2(2140,720)]},
	{"location":"forest","count":3,"types":["chest","sack","trash"],"positions":[Vector2(540,690),Vector2(1260,730),Vector2(1800,350),Vector2(2060,680),Vector2(780,300)]},
	{"location":"rocky","count":2,"types":["chest","trash"],"positions":[Vector2(620,380),Vector2(1450,680),Vector2(1980,420),Vector2(950,720)]},
	{"location":"ruins","count":3,"types":["chest","bone_pile","trash"],"positions":[Vector2(560,650),Vector2(990,330),Vector2(1570,690),Vector2(1960,380),Vector2(760,760)]},
	{"location":"cave","count":3,"types":["chest","bone_pile"],"positions":[Vector2(400,690),Vector2(740,750),Vector2(1200,650),Vector2(1880,420),Vector2(2140,700)]},
	{"location":"cursed","count":3,"types":["bone_pile","chest"],"positions":[Vector2(490,390),Vector2(930,710),Vector2(1510,650),Vector2(1930,360),Vector2(2180,700)]},
	{"location":"glassworks","count":2,"types":["chest","sack"],"positions":[Vector2(650,690),Vector2(1380,360),Vector2(1980,680),Vector2(1050,720)]},
]

static func random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()

static func generate(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array = []
	var next_id := 0
	for spawn in SPAWNS:
		var available: Array = spawn.positions.duplicate()
		for _slot in spawn.count:
			var point_index := rng.randi_range(0, available.size() - 1)
			var position: Vector2 = available[point_index]
			available.remove_at(point_index)
			var kind: String = spawn.types[rng.randi_range(0, spawn.types.size() - 1)]
			result.append({"id":next_id,"kind":kind,"location":spawn.location,"position":position,"opened":false,"contents":roll_contents(rng, kind)})
			next_id += 1
	return result

static func roll_contents(rng: RandomNumberGenerator, kind: String) -> Dictionary:
	var data: Dictionary = TYPES[kind]
	var contents := {}
	for _roll in data.rolls:
		var entry: Array = weighted_entry(rng, data.table)
		var item_kind: String = entry[0]
		var count := rng.randi_range(entry[1], entry[2])
		contents[item_kind] = contents.get(item_kind, 0) + count
	return contents

static func weighted_entry(rng: RandomNumberGenerator, table: Array) -> Array:
	var total := 0
	for entry in table:
		total += entry[3]
	var roll := rng.randi_range(1, total)
	for entry in table:
		roll -= entry[3]
		if roll <= 0:
			return entry
	return table.back()

static func open(game: Node, index: int) -> bool:
	if index < 0 or index >= game.world_loot_nodes.size():
		return false
	var container: Dictionary = game.world_loot_nodes[index]
	if container.opened or container.location != game.current_location or game.player.distance_to(container.position) > 92.0:
		return false
	container.opened = true
	var rewards: Array[String] = []
	for kind in container.contents:
		var count: int = container.contents[kind]
		if kind == "coins":
			game.coins += count
			rewards.append("%d монет" % count)
		else:
			game.change_inventory_count(kind, count)
			rewards.append("%s ×%d" % [game.inventory_item_name(kind), count])
	game.world_loot_nodes[index] = container
	game.message = "%s: %s" % [LocaleSystem.entity(container.kind), ", ".join(rewards)]
	game.play_sfx("pickup")
	game.notify_tutorial("world_loot")
	return true
