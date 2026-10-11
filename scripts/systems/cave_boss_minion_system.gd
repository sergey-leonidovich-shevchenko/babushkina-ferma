extends RefCounted

const Data := preload("res://scripts/systems/cave_boss_data.gd")
const Attacks := preload("res://scripts/systems/cave_boss_attack_system.gd")
const Shots := preload("res://scripts/systems/cave_boss_projectile_system.gd")
const TYPES := {
	"skeleton":{"hp":8,"speed":80.0,"damage":9},
	"zombie":{"hp":12,"speed":48.0,"damage":7},
	"vampire":{"hp":10,"speed":115.0,"damage":10},
}

## Призывает доступные текущей стадии виды на свободные сухие точки с ограничением числа живых существ.
static func summon(game: Node, kinds: Array) -> int:
	var state: Dictionary = game.state.world.cave_boss
	var created := 0
	for kind in kinds:
		if living_count(game) >= Data.MINION_LIMIT or not TYPES.has(kind): break
		var position := spawn_position(game)
		if not position.is_finite(): break
		state.minions.append({"kind":kind,"position":position,"hp":int(TYPES[kind].hp),"alive":true,"age":0.0,"emerge":1.25,"attack":0.0,"cooldown":2.5,"fly_cooldown":4.0,"fly_windup":0.0,"fly_target":position,"death":0.0,"moving":false})
		created += 1
	return created

## Подбирает точку вдали от героя, скал, ресурсов и уже призванных существ без бесконечного поиска.
static func spawn_position(game: Node) -> Vector2:
	var start := randi_range(0, 31)
	for index in 32:
		var angle := (index + start) * TAU / 32.0
		var point: Vector2 = Data.ARENA.get_center() + Vector2(cos(angle) * 235.0, sin(angle) * 215.0)
		if point.distance_to(game.player) < 145.0 or not safe_floor(game, point): continue
		if game.NavigationSystem.walkability_reason(game, point) != "walkable": continue
		var occupied := false
		for minion in game.state.world.cave_boss.minions:
			if minion.alive and point.distance_to(minion.position) < 76.0: occupied = true; break
		if not occupied: return point
	return Vector2.INF

## Считает появляющихся и действующих существ, исключая завершённые тела.
static func living_count(game: Node) -> int:
	var count := 0
	for minion in game.state.world.cave_boss.minions:
		if minion.alive: count += 1
	return count

## Использует реальные основания новой арены, не оставляя невидимых колонн прежней комнаты.
static func safe_floor(game: Node, point: Vector2) -> bool:
	return Attacks.safe(game,point)

## Обновляет выход из земли, погоню, читаемые замахи, броски мух и короткую анимацию смерти.
static func update(game: Node, delta: float) -> void:
	var state: Dictionary = game.state.world.cave_boss
	var survivors: Array = []
	for minion in state.minions:
		minion.age += delta; minion.moving = false
		if not minion.alive:
			minion.death += delta
			if float(minion.death) < 1.0: survivors.append(minion)
			continue
		survivors.append(minion)
		if float(minion.emerge) > 0.0: minion.emerge = maxf(0.0, float(minion.emerge) - delta); continue
		if game.invisibility_timer > 0.0: continue
		var data: Dictionary = TYPES[minion.kind]
		minion.cooldown = maxf(0.0, float(minion.cooldown) - delta)
		if float(minion.attack) > 0.0:
			minion.attack = maxf(0.0, float(minion.attack) - delta)
			if float(minion.attack) <= 0.0 and game.player.distance_to(minion.position) < 70.0: Shots.hit(game, int(data.damage), minion.position)
			continue
		if minion.kind == "zombie" and update_fly(game, minion, delta): continue
		var distance: float = game.player.distance_to(minion.position)
		if distance > 54.0:
			var next := move(game, minion, minion.position.direction_to(game.player) * float(data.speed) * delta)
			minion.moving = next.distance_to(minion.position) > 0.1; minion.position = next
		elif float(minion.cooldown) <= 0.0: minion.attack = 0.5; minion.cooldown = 1.8
	state.minions = survivors

## Фиксирует цель броска в начале замаха и выпускает муху без последующего наведения.
static func update_fly(game: Node, minion: Dictionary, delta: float) -> bool:
	minion.fly_cooldown = maxf(0.0, float(minion.fly_cooldown) - delta)
	if float(minion.fly_windup) > 0.0:
		minion.fly_windup = maxf(0.0, float(minion.fly_windup) - delta)
		if float(minion.fly_windup) <= 0.0:
			var direction: Vector2 = minion.position.direction_to(minion.fly_target)
			Shots.launch(game, minion.position + direction * 30.0, direction, 0, "fly", 215.0)
		return true
	if float(minion.fly_cooldown) <= 0.0 and game.player.distance_to(minion.position) <= 410.0:
		minion.fly_target = game.player; minion.fly_windup = 0.65; minion.fly_cooldown = 6.0
		return true
	return false

## Перемещает существо с проверкой скал и непроникновения в соседей и героя.
static func move(game: Node, minion: Dictionary, motion: Vector2) -> Vector2:
	var result: Vector2 = minion.position
	var steps := maxi(1, ceili(motion.length() / 6.0))
	for _step in steps:
		for axis in [Vector2(motion.x / steps, 0), Vector2(0, motion.y / steps)]:
			var next: Vector2 = result + axis
			if not safe_floor(game, next) or next.distance_to(game.player) < 42.0: continue
			var blocked := false
			for enemy in game.enemy_nodes:
				if enemy.alive and enemy.location == game.current_location and next.distance_to(enemy.position) < 48.0: blocked = true; break
			for other in game.state.world.cave_boss.minions:
				if other == minion or not other.alive or float(other.emerge) > 0.0: continue
				if next.distance_to(other.position) < 38.0 and next.distance_to(other.position) < result.distance_to(other.position): blocked = true; break
			if not blocked: result = next
	return result

## Находит ближайшее уязвимое призванное существо для оружия, магии или напарника.
static func nearest(game: Node, origin: Vector2, radius: float) -> int:
	if game.current_location != Data.LOCATION or not game.state.world.cave_boss.active: return -1
	var result := -1
	for index in game.state.world.cave_boss.minions.size():
		var minion: Dictionary = game.state.world.cave_boss.minions[index]
		if not minion.alive or float(minion.emerge) > 0.0: continue
		var distance := origin.distance_to(Vector2(minion.position))
		if distance < radius: radius = distance; result = index
	return result

## Наносит урон призванному существу без фарма наград за бесконечные волны.
static func damage(game: Node, index: int, amount: int) -> bool:
	var state: Dictionary = game.state.world.cave_boss
	if game.current_location != Data.LOCATION or not state.active or index < 0 or index >= state.minions.size() or amount <= 0: return false
	var minion: Dictionary = state.minions[index]
	if not minion.alive or float(minion.emerge) > 0.0: return false
	minion.hp = maxi(0, int(minion.hp) - amount)
	if int(minion.hp) <= 0: minion.alive = false; minion.death = 0.0
	game.play_sfx("hit" if minion.alive else "defeat")
	return true

## Проводит обычную атаку героя через анимацию, критический удар и износ оружия.
static func attack(game: Node, index: int) -> bool:
	var amount: int = game.CombatSystem.player_attack_damage(game)
	game.state.player.combat_hits += 1
	var critical: bool = game.state.player.combat_hits % 4 == 0
	if critical: amount *= 2; game.notify_tutorial("critical_hit")
	if not damage(game, index, amount): return false
	game.PotionSystem.break_invisibility(game)
	game.AnimationSystem.begin_player_attack(game); game.play_sfx("attack")
	game.FarmLifeSystem.register_player_attack(game, game.state.world.cave_boss.minions[index].position, critical)
	game.AdventurePolishSystem.consume_durability(game, "weapon")
	return true
