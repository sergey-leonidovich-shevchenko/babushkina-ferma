extends RefCounted

const TYPES := {
	"plant": {"name":"Хищное растение","hp":5,"damage":12,"xp":14,"color":Color("4d9b4f"),"loot":{"fiber":2,"rare_seeds":1}},
	"orc": {"name":"Орк-разбойник","hp":8,"damage":18,"xp":22,"color":Color("789348"),"loot":{"metal":2,"coins":15,"orc_blade":1}},
	"skeleton": {"name":"Скелет","hp":6,"damage":16,"xp":18,"color":Color("d8d3ba"),"loot":{"bones":3,"ancient_key":1}},
	"undead": {"name":"Проклятый рыцарь","hp":10,"damage":22,"xp":30,"color":Color("745c86"),"loot":{"bones":2,"blue_gem":1}}
}

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
	if enemy.hp <= 0:
		enemy.alive = false
		game.award_xp(TYPES[enemy.kind].xp)
		for kind in TYPES[enemy.kind].loot:
			var count: int = TYPES[enemy.kind].loot[kind]
			if kind == "coins": game.coins += count
			else: game.dropped_items.append({"kind":kind,"count":count,"position":enemy.position})
		game.message = "%s побеждён: +%d XP" % [TYPES[enemy.kind].name, TYPES[enemy.kind].xp]
	else: game.message = "%s: -%d HP" % [TYPES[enemy.kind].name, damage]
	game.enemy_nodes[index] = enemy
	return true
