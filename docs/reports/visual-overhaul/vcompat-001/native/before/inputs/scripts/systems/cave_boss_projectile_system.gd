extends RefCounted

const Data := preload("res://scripts/systems/cave_boss_data.gd")

## Создаёт прямолинейный снаряд с фиксированным направлением и конечной дальностью.
static func launch(game: Node, position: Vector2, direction: Vector2, damage: int, kind: String = "shard", speed: float = 250.0) -> void:
	game.state.world.cave_boss.projectiles.append({"position":position,"direction":direction.normalized(),"damage":damage,"kind":kind,"speed":speed,"remaining":640.0,"age":0.0})

## Продвигает снаряды подшагами и проверяет весь пройденный отрезок, включая большие кадры.
static func update(game: Node, delta: float) -> void:
	var state: Dictionary = game.state.world.cave_boss
	var survivors: Array = []
	for shot in state.projectiles:
		if preload("res://scripts/systems/recovery_system.gd").protected(game): survivors.clear(); break
		var distance := minf(float(shot.remaining), float(shot.speed) * delta)
		var before: Vector2 = shot.position
		var steps := maxi(1, ceili(distance / 8.0))
		var collided := false
		for _step in steps:
			var next: Vector2 = shot.position + shot.direction * distance / steps
			if game.NavigationSystem.walkability_reason(game, next, -1, false) != "walkable": collided = true; break
			if Geometry2D.get_closest_point_to_segment(game.player, shot.position, next).distance_to(game.player) <= 23.0:
				if shot.kind == "fly": attach_fly(game)
				else: hit(game, int(shot.damage), before)
				collided = true; break
			shot.position = next
		shot.remaining -= distance; shot.age += delta
		if not collided and float(shot.remaining) > 0.0: survivors.append(shot)
	state.projectiles = survivors

## Ограничивает частоту попаданий группы существ, сохраняя действие блока и уклонения.
static func hit(game: Node, damage: int, source: Vector2) -> int:
	var state: Dictionary = game.state.world.cave_boss
	if float(state.hit_cooldown) > 0.0 or game.menu_state.defeat_open or preload("res://scripts/systems/recovery_system.gd").protected(game): return 0
	var dealt: int = game.CombatSystem.damage_player(game, damage, game.LocaleSystem.entity("cave_guardian"), source)
	if dealt > 0: state.hit_cooldown = 0.65
	return dealt

## Прикрепляет одну муху на случайные две–пять секунд; повторное попадание не складывает урон.
static func attach_fly(game: Node, duration: float = -1.0) -> bool:
	if game.state.player.dodge_timer > 0.0 or game.menu_state.defeat_open or preload("res://scripts/systems/recovery_system.gd").protected(game): return false
	if preload("res://scripts/systems/alchemy_system.gd").remaining(game,"repellent")>0.0: return false
	if game.state.player.blocking and game.energy > 0: game.energy -= 1; return false
	var state: Dictionary = game.state.world.cave_boss
	if float(state.fly_timer) > 0.0: return false
	state.fly_timer = preload("res://scripts/systems/world_rng_system.gd").real(game,"combat",2.0,5.0) if duration < 0.0 else clampf(duration, 2.0, 5.0)
	state.fly_tick = 0.0
	game.notify_tutorial("cave_boss_flies")
	return true

## Наносит небольшой периодический урон только за действительно прошедшее время прикрепления.
static func update_bites(game: Node, delta: float) -> void:
	var state: Dictionary = game.state.world.cave_boss
	var elapsed := minf(delta, float(state.fly_timer))
	state.fly_timer = maxf(0.0, float(state.fly_timer) - delta)
	state.fly_tick += elapsed
	while float(state.fly_tick) >= 1.0:
		state.fly_tick -= 1.0
		game.CombatSystem.damage_player(game, 1, Data.word(game, "flies", [float(state.fly_timer)]), game.player)
		if game.menu_state.defeat_open or preload("res://scripts/systems/recovery_system.gd").protected(game): state.fly_timer = 0.0; state.fly_tick = 0.0; break
	if float(state.fly_timer) <= 0.0: state.fly_tick = 0.0
