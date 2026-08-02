extends RefCounted

const FEAR_RADIUS := 220.0
const ROAM_RADIUS := 320.0

const TYPES := {
	"deer": {"name":"Лесной олень","hp":3,"speed":250.0,"frames":6,"xp":5,"loot":{"raw_meat":2,"hide":1}},
	"fox": {"name":"Рыжая лиса","hp":3,"speed":275.0,"frames":6,"xp":5,"loot":{"raw_meat":1,"fur":1}},
	"boar": {"name":"Дикий кабан","hp":5,"speed":220.0,"frames":5,"xp":7,"loot":{"raw_meat":3,"tusk":1}},
	"bat": {"name":"Пещерная летучая мышь","hp":2,"speed":290.0,"frames":4,"xp":4,"loot":{"bat_wing":2},"flying":true},
}

static func update(game: Node, delta: float) -> void:
	for index in game.wildlife_nodes.size():
		var animal: Dictionary = game.wildlife_nodes[index]
		if not animal.alive or animal.location != game.current_location:
			continue
		animal.animation += delta
		animal.wander_timer -= delta
		animal.panic = maxf(animal.panic - delta, 0.0)
		var distance_to_player: float = animal.position.distance_to(game.player)
		var afraid: bool = distance_to_player <= FEAR_RADIUS or animal.panic > 0.0
		var direction: Vector2 = animal.direction
		var move_speed := 38.0
		if afraid:
			direction = (animal.position - game.player).normalized()
			if direction == Vector2.ZERO:
				direction = Vector2.RIGHT
			move_speed = TYPES[animal.kind].speed
		elif animal.position.distance_to(animal.home) > ROAM_RADIUS:
			direction = animal.position.direction_to(animal.home)
			move_speed = 70.0
		elif animal.wander_timer <= 0.0:
			var angle: float = animal.animation * 1.7 + float(index) * 2.13
			direction = Vector2(cos(angle), sin(angle)).normalized()
			animal.wander_timer = 1.6 + fmod(float(index) * 0.71, 1.8)
		animal.direction = direction
		var next_position: Vector2 = animal.position + direction * move_speed * delta
		next_position.x = clampf(next_position.x, 55.0, game.WORLD_SIZE.x - 55.0)
		next_position.y = clampf(next_position.y, 130.0, game.WORLD_SIZE.y - 90.0)
		if TYPES[animal.kind].get("flying", false) or game.is_position_walkable(next_position):
			animal.position = next_position
		else:
			animal.direction = -direction
			animal.wander_timer = 0.0
		game.wildlife_nodes[index] = animal

static func nearest(game: Node) -> int:
	var result := -1
	var limit := 280.0 if game.equipped_weapon == "bow" else 105.0
	for index in game.wildlife_nodes.size():
		var animal: Dictionary = game.wildlife_nodes[index]
		if animal.alive and animal.location == game.current_location:
			var distance: float = animal.position.distance_to(game.player)
			if distance < limit:
				limit = distance
				result = index
	return result

static func attack(game: Node, index: int) -> bool:
	if index < 0 or index >= game.wildlife_nodes.size():
		return false
	var animal: Dictionary = game.wildlife_nodes[index]
	if not animal.alive or animal.location != game.current_location:
		return false
	var attack_range := 280.0 if game.equipped_weapon == "bow" else 105.0
	if animal.position.distance_to(game.player) > attack_range:
		return false
	var damage: int = 1 + (1 if game.strength_timer > 0.0 else 0) + game.InventorySystem.damage_bonus(game)
	if game.equipped_weapon == "forest_sword": damage += 1
	elif game.equipped_weapon == "crystal_sword": damage += 2
	elif game.equipped_weapon == "bow": damage += 1
	animal.hp -= damage
	animal.panic = 3.0
	if animal.hp <= 0:
		animal.alive = false
		game.award_xp(TYPES[animal.kind].xp)
		game.SkillSystem.award_profession_xp(game, "combat", maxi(1, TYPES[animal.kind].xp / 2))
		for kind in TYPES[animal.kind].loot:
			game.dropped_items.append({"kind":kind,"count":TYPES[animal.kind].loot[kind],"position":animal.position})
		game.message = "%s добыт: +%d XP" % [TYPES[animal.kind].name, TYPES[animal.kind].xp]
	else:
		game.message = "%s пугается и убегает: -%d HP" % [TYPES[animal.kind].name, damage]
	game.wildlife_nodes[index] = animal
	game.notify_tutorial("wildlife")
	return true
