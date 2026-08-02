extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const FEAR_RADIUS := 220.0
const ROAM_RADIUS := 320.0

const TYPES := {
	"deer": {"name":"Лесной олень","hp":3,"speed":250.0,"frames":6,"xp":5,"loot":{"raw_meat":2,"hide":1}},
	"fox": {"name":"Рыжая лиса","hp":3,"speed":275.0,"frames":6,"xp":5,"loot":{"raw_meat":1,"fur":1}},
	"boar": {"name":"Дикий кабан","hp":5,"speed":220.0,"frames":5,"xp":7,"loot":{"raw_meat":3,"tusk":1}},
	"bat": {"name":"Пещерная летучая мышь","hp":2,"speed":290.0,"frames":4,"xp":4,"loot":{"bat_wing":2},"flying":true},
	"lizard": {"name":"Луговой листохвост","hp":4,"speed":235.0,"frames":1,"xp":6,"loot":{"lizard_scale":2}},
}
const SPAWNS := [
	{"kind":"deer","location":"overworld","position":Vector2(1320,430),"home":Vector2(1320,430),"direction":Vector2.RIGHT,"hp":3,"alive":true,"animation":0.0,"wander_timer":0.0,"panic":0.0},
	{"kind":"fox","location":"overworld","position":Vector2(1930,540),"home":Vector2(1930,540),"direction":Vector2.LEFT,"hp":3,"alive":true,"animation":0.4,"wander_timer":0.8,"panic":0.0},
	{"kind":"deer","location":"forest","position":Vector2(720,650),"home":Vector2(720,650),"direction":Vector2.DOWN,"hp":3,"alive":true,"animation":0.8,"wander_timer":1.0,"panic":0.0},
	{"kind":"fox","location":"forest","position":Vector2(1560,360),"home":Vector2(1560,360),"direction":Vector2.RIGHT,"hp":3,"alive":true,"animation":1.2,"wander_timer":0.3,"panic":0.0},
	{"kind":"boar","location":"forest","position":Vector2(2040,620),"home":Vector2(2040,620),"direction":Vector2.LEFT,"hp":5,"alive":true,"animation":0.2,"wander_timer":1.2,"panic":0.0},
	{"kind":"boar","location":"rocky","position":Vector2(1100,530),"home":Vector2(1100,530),"direction":Vector2.RIGHT,"hp":5,"alive":true,"animation":0.6,"wander_timer":0.5,"panic":0.0},
	{"kind":"bat","location":"cave","position":Vector2(680,430),"home":Vector2(680,430),"direction":Vector2.UP,"hp":2,"alive":true,"animation":0.0,"wander_timer":0.0,"panic":0.0},
	{"kind":"bat","location":"cave","position":Vector2(1780,610),"home":Vector2(1780,610),"direction":Vector2.LEFT,"hp":2,"alive":true,"animation":0.7,"wander_timer":1.0,"panic":0.0},
	{"kind":"bat","location":"cursed","position":Vector2(840,390),"home":Vector2(840,390),"direction":Vector2.RIGHT,"hp":2,"alive":true,"animation":1.4,"wander_timer":0.4,"panic":0.0},
	{"kind":"lizard","location":"forest","position":Vector2(1180,620),"home":Vector2(1180,620),"direction":Vector2.RIGHT,"hp":4,"alive":true,"animation":0.3,"wander_timer":0.5,"panic":0.0},
	{"kind":"lizard","location":"overworld","position":Vector2(1040,510),"home":Vector2(1040,510),"direction":Vector2.LEFT,"hp":4,"alive":true,"animation":1.1,"wander_timer":1.0,"panic":0.0},
]


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_animals() -> Array:
	return SPAWNS.duplicate(true)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
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

## Выполняет операцию «ближайшего» и возвращает результат согласно контракту метода.
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

## Выполняет операцию «атаки» и возвращает результат согласно контракту метода.
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
	game.AnimationSystem.begin_player_attack(game)
	game.play_sfx("attack")
	game.play_sfx("defeat" if animal.hp <= 0 else "hit")
	animal.panic = 3.0
	if animal.hp <= 0:
		animal.alive = false
		game.award_xp(TYPES[animal.kind].xp)
		game.SkillSystem.award_profession_xp(game, "combat", maxi(1, TYPES[animal.kind].xp / 2))
		for kind in TYPES[animal.kind].loot:
			game.dropped_items.append({"kind":kind,"count":TYPES[animal.kind].loot[kind],"position":animal.position})
		game.message = "%s: +%d XP" % [LocaleSystem.entity(animal.kind), TYPES[animal.kind].xp]
	else:
		game.message = "%s: -%d HP" % [LocaleSystem.entity(animal.kind), damage]
	game.wildlife_nodes[index] = animal
	game.notify_tutorial("combat_animation")
	game.notify_tutorial("wildlife")
	if animal.kind == "lizard":
		game.notify_tutorial("lizard")
	return true
