extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
const WildlifeNavigation := preload("res://scripts/systems/wildlife_navigation_system.gd")

const FEAR_RADIUS := 220.0
const ROAM_RADIUS := 320.0
const HURT_DURATION := 0.26
const DEATH_DURATION := 1.25
const BOAR_ATTACK_DISTANCE := 72.0
const FLEE_BURST := 1.05
const FLEE_RECOVERY := 1.6

const TYPES := {
	"deer": {"name":"Лесной олень","hp":3,"speed":250.0,"frames":6,"xp":5,"loot":{"raw_meat":2,"hide":1}},
	"fox": {"name":"Рыжая лиса","hp":3,"speed":275.0,"frames":6,"xp":5,"loot":{"raw_meat":1,"fur":1}},
	"boar": {"name":"Дикий кабан","hp":5,"speed":220.0,"frames":5,"xp":7,"loot":{"raw_meat":3,"tusk":1}},
	"bat": {"name":"Пещерная летучая мышь","hp":2,"speed":290.0,"frames":4,"xp":4,"loot":{"bat_wing":2},"flying":true},
	"lizard": {"name":"Луговой листохвост","hp":4,"speed":235.0,"frames":1,"xp":6,"loot":{"lizard_scale":2}},
}
const SPAWNS := [
	{"kind":"deer","location":"overworld","position":Vector2(2040,696),"home":Vector2(2040,696),"direction":Vector2.RIGHT,"hp":3,"alive":true,"animation":0.0,"wander_timer":0.0,"panic":0.0},
	{"kind":"fox","location":"overworld","position":Vector2(2232,696),"home":Vector2(2232,696),"direction":Vector2.LEFT,"hp":3,"alive":true,"animation":0.4,"wander_timer":0.8,"panic":0.0},
	{"kind":"deer","location":"forest","position":Vector2(720,650),"home":Vector2(720,650),"direction":Vector2.DOWN,"hp":3,"alive":true,"animation":0.8,"wander_timer":1.0,"panic":0.0},
	{"kind":"fox","location":"forest","position":Vector2(1560,360),"home":Vector2(1560,360),"direction":Vector2.RIGHT,"hp":3,"alive":true,"animation":1.2,"wander_timer":0.3,"panic":0.0},
	{"kind":"boar","location":"forest","position":Vector2(2040,620),"home":Vector2(2040,620),"direction":Vector2.LEFT,"hp":5,"alive":true,"animation":0.2,"wander_timer":1.2,"panic":0.0},
	{"kind":"boar","location":"rocky","position":Vector2(1100,530),"home":Vector2(1100,530),"direction":Vector2.RIGHT,"hp":5,"alive":true,"animation":0.6,"wander_timer":0.5,"panic":0.0},
	{"kind":"bat","location":"cave","position":Vector2(680,430),"home":Vector2(680,430),"direction":Vector2.UP,"hp":2,"alive":true,"animation":0.0,"wander_timer":0.0,"panic":0.0},
	{"kind":"bat","location":"cave","position":Vector2(1780,610),"home":Vector2(1780,610),"direction":Vector2.LEFT,"hp":2,"alive":true,"animation":0.7,"wander_timer":1.0,"panic":0.0},
	{"kind":"bat","location":"cursed","position":Vector2(840,390),"home":Vector2(840,390),"direction":Vector2.RIGHT,"hp":2,"alive":true,"animation":1.4,"wander_timer":0.4,"panic":0.0},
	{"kind":"lizard","location":"forest","position":Vector2(1180,620),"home":Vector2(1180,620),"direction":Vector2.RIGHT,"hp":4,"alive":true,"animation":0.3,"wander_timer":0.5,"panic":0.0},
	{"kind":"lizard","location":"overworld","position":Vector2(2112,816),"home":Vector2(2112,816),"direction":Vector2.LEFT,"hp":4,"alive":true,"animation":1.1,"wander_timer":1.0,"panic":0.0},
]


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_animals() -> Array:
	var result := SPAWNS.duplicate(true)
	for animal in result:
		animal.visual_state = "idle"; animal.state_timer = 0.0; animal.moving = false; animal.attack_timer = 0.0
		animal.flee_timer = 0.0; animal.recovery_timer = 0.0; animal.habitat_validated = false
	return result


## Переносит штатных зверей старой деревни на новые места, сохраняя здоровье, смерть и полученную игроком добычу.
static func migrate_village_habitats(game: Node) -> void:
	for index in mini(SPAWNS.size(), game.wildlife_nodes.size()):
		var spawn: Dictionary = SPAWNS[index]
		var animal: Dictionary = game.wildlife_nodes[index]
		if spawn.location != "overworld" or animal.kind != spawn.kind or animal.location != "overworld": continue
		animal.position = spawn.position; animal.home = spawn.home
		animal.habitat_validated = false; animal.flee_timer = 0.0; animal.recovery_timer = 0.0

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func update(game: Node, delta: float) -> void:
	# Навигационные подшаги зверей повторно используют только выборку текущего синхронного обновления.
	# Сами словари препятствий живые; при смене карты запрос автоматически возвращается к полному обходу.
	var query: Dictionary = {}
	for index in game.wildlife_nodes.size():
		var animal: Dictionary = game.wildlife_nodes[index]
		if animal.location != game.current_location:
			continue
		animal.state_timer = maxf(float(animal.get("state_timer", 0.0)) - delta, 0.0)
		animal.attack_timer = maxf(float(animal.get("attack_timer", 0.0)) - delta, 0.0)
		if not animal.alive:
			animal.visual_state = "death"
			game.wildlife_nodes[index] = animal
			continue
		if query.get("location", "") != game.current_location:
			query = game.NavigationSystem.location_query(game)
		WildlifeNavigation.ensure_habitat(game, animal, query)
		animal.animation += delta
		animal.wander_timer -= delta
		animal.panic = maxf(animal.panic - delta, 0.0)
		var distance_to_player: float = animal.position.distance_to(game.player)
		animal.recovery_timer = maxf(float(animal.get("recovery_timer", 0.0)) - delta, 0.0)
		var previous_flee := float(animal.get("flee_timer", 0.0))
		animal.flee_timer = maxf(previous_flee - delta, 0.0)
		if previous_flee > 0.0 and animal.flee_timer <= 0.0:
			animal.recovery_timer = FLEE_RECOVERY
		if (
			(distance_to_player <= FEAR_RADIUS or animal.panic > 0.0)
			and animal.recovery_timer <= 0.0
			and animal.flee_timer <= 0.0
		):
			animal.flee_timer = FLEE_BURST
		var afraid: bool = animal.flee_timer > 0.0
		if animal.visual_state == "hurt" and animal.state_timer > 0.0:
			game.wildlife_nodes[index] = animal
			continue
		if animal.visual_state == "attack" and animal.state_timer > 0.0:
			if animal.state_timer <= 0.12 and not bool(animal.get("attack_hit", false)):
				animal.attack_hit = true
				if distance_to_player <= BOAR_ATTACK_DISTANCE + 12.0:
					game.CombatSystem.damage_player(
						game, 7, LocaleSystem.entity("boar"), animal.position
					)
			animal.moving = false
			game.wildlife_nodes[index] = animal
			continue
		if (
			animal.kind == "boar"
			and distance_to_player <= BOAR_ATTACK_DISTANCE
			and animal.attack_timer <= 0.0
		):
			animal.direction = animal.position.direction_to(game.player)
			animal.visual_state = "attack"
			animal.state_timer = 0.34
			animal.attack_timer = 1.2
			animal.attack_hit = false
			animal.moving = false
			game.wildlife_nodes[index] = animal
			game.notify_tutorial("wildlife_behavior")
			continue
		var direction: Vector2 = animal.direction
		var move_speed := 38.0
		if animal.position.distance_to(animal.home) >= ROAM_RADIUS - 8.0:
			direction = animal.position.direction_to(animal.home)
			move_speed = 70.0
		elif afraid:
			direction = (animal.position - game.player).normalized()
			if direction == Vector2.ZERO:
				direction = Vector2.RIGHT
			move_speed = TYPES[animal.kind].speed
		elif animal.recovery_timer > 0.0:
			move_speed = 0.0
		elif animal.wander_timer <= 0.0:
			var angle: float = animal.animation * 1.7 + float(index) * 2.13
			direction = Vector2(cos(angle), sin(angle)).normalized()
			animal.wander_timer = 1.6 + fmod(float(index) * 0.71, 1.8)
		var next_position := WildlifeNavigation.steer(
			game, animal, direction, move_speed * delta, ROAM_RADIUS, query
		)
		animal.moving = next_position.distance_squared_to(animal.position) > 0.01
		if animal.moving:
			animal.direction = animal.position.direction_to(next_position)
		animal.position = next_position
		animal.visual_state = ("flee" if afraid else "run") if animal.moving else "idle"
		game.wildlife_nodes[index] = animal

## Выполняет операцию «ближайшего» и возвращает результат согласно контракту метода.
static func nearest(game: Node) -> int:
	var result := -1
	var limit: float = game.WeaponSystem.range_of(game.equipped_weapon)
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
	return preload("res://scripts/systems/player_attack_system.gd").begin(game,"wildlife",index)

## Меняет здоровье и награды зверя только после подтверждённого контакта оружия или снаряда.
static func apply_damage(game: Node, index: int, damage: int) -> bool:
	if index < 0 or index >= game.wildlife_nodes.size():
		return false
	var animal: Dictionary = game.wildlife_nodes[index]
	if not animal.alive or animal.location != game.current_location:
		return false
	if damage <= 0: return false
	animal.hp -= damage
	game.play_sfx("defeat" if animal.hp <= 0 else "hit")
	animal.panic = 3.0; animal.visual_state = "hurt"; animal.state_timer = HURT_DURATION
	if animal.hp <= 0:
		animal.alive = false; animal.visual_state = "death"; animal.state_timer = DEATH_DURATION
		game.award_xp(TYPES[animal.kind].xp)
		game.SkillSystem.award_profession_xp(game, "combat", maxi(1, TYPES[animal.kind].xp / 2))
		for kind in TYPES[animal.kind].loot:
			game.dropped_items.append({"kind":kind,"count":TYPES[animal.kind].loot[kind],"position":animal.position,"location":game.current_location})
		game.message = "%s: +%d XP" % [LocaleSystem.entity(animal.kind), TYPES[animal.kind].xp]
	else:
		game.message = "%s: -%d HP" % [LocaleSystem.entity(animal.kind), damage]
	game.wildlife_nodes[index] = animal
	game.notify_tutorial("combat_animation")
	game.notify_tutorial("wildlife")
	if animal.kind == "lizard":
		game.notify_tutorial("lizard")
	return true
