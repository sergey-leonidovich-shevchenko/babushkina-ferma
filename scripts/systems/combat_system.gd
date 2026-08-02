extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const TYPES := {
	"plant": {"name":"Хищное растение","hp":5,"damage":12,"xp":14,"color":Color("4d9b4f"),"loot":{"fiber":2,"rare_seeds":1}},
	"orc": {"name":"Орк-разбойник","hp":8,"damage":18,"xp":22,"color":Color("789348"),"loot":{"metal":2,"coins":15,"orc_blade":1}},
	"skeleton": {"name":"Скелет","hp":6,"damage":16,"xp":18,"color":Color("d8d3ba"),"loot":{"bones":3,"ancient_key":1}},
	"undead": {"name":"Проклятый рыцарь","hp":10,"damage":22,"xp":30,"color":Color("745c86"),"loot":{"bones":2,"blue_gem":1}},
	"cave_guardian": {"name":"Хранитель глубин","hp":12,"damage":24,"xp":40,"color":Color("527f91"),"loot":{"moon_relic":1,"blue_gem":2}}
}
const SPAWNS := [
	{"kind":"plant","location":"forest","position":Vector2(920,430),"hp":5,"alive":true,"visual_state":"idle","visual_time":0.0},
	{"kind":"orc","location":"ruins","position":Vector2(1180,500),"hp":8,"alive":true,"visual_state":"idle","visual_time":0.0},
	{"kind":"skeleton","location":"cave","position":Vector2(880,520),"hp":6,"alive":true,"visual_state":"idle","visual_time":0.0},
	{"kind":"undead","location":"cursed","position":Vector2(1320,460),"hp":10,"alive":true,"visual_state":"idle","visual_time":0.0},
	{"kind":"cave_guardian","location":"cave","position":Vector2(1450,500),"hp":12,"alive":true,"visual_state":"idle","visual_time":0.0},
]


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_enemies() -> Array:
	return SPAWNS.duplicate(true)

## Выполняет операцию «ближайшего» и возвращает результат согласно контракту метода.
static func nearest(game: Node) -> int:
	var result := -1
	var distance_limit := 280.0 if game.equipped_weapon == "bow" else 105.0
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if enemy.alive and enemy.location == game.current_location:
			var distance: float = game.player.distance_to(enemy.position)
			if distance < distance_limit:
				distance_limit = distance; result = index
	return result

## Выполняет операцию «атаки» и возвращает результат согласно контракту метода.
static func attack(game: Node, index: int) -> bool:
	if index < 0 or index >= game.enemy_nodes.size(): return false
	var enemy: Dictionary = game.enemy_nodes[index]
	if not enemy.alive or enemy.location != game.current_location: return false
	var attack_range := 280.0 if game.equipped_weapon == "bow" else 105.0
	if game.player.distance_to(enemy.position) > attack_range: return false
	var damage: int = 1 + (1 if game.strength_timer > 0 else 0) + game.InventorySystem.damage_bonus(game)
	if game.equipped_weapon == "forest_sword": damage += 1
	elif game.equipped_weapon == "crystal_sword": damage += 2
	elif game.equipped_weapon == "bow": damage += 1
	enemy.hp -= damage
	game.AnimationSystem.begin_player_attack(game)
	enemy = game.AnimationSystem.hit_enemy(enemy, enemy.hp <= 0)
	game.play_sfx("attack")
	game.play_sfx("defeat" if enemy.hp <= 0 else "hit")
	if enemy.hp <= 0:
		enemy.alive = false
		game.award_xp(TYPES[enemy.kind].xp)
		game.SkillSystem.award_profession_xp(game, "combat", TYPES[enemy.kind].xp / 2)
		for kind in TYPES[enemy.kind].loot:
			var count: int = TYPES[enemy.kind].loot[kind]
			if kind == "coins": game.coins += count
			else: game.dropped_items.append({"kind":kind,"count":count,"position":enemy.position})
		game.message = "%s: +%d XP" % [LocaleSystem.entity(enemy.kind), TYPES[enemy.kind].xp]
	else: game.message = "%s: -%d HP" % [LocaleSystem.entity(enemy.kind), damage]
	game.enemy_nodes[index] = enemy
	game.notify_tutorial("combat_animation")
	return true
