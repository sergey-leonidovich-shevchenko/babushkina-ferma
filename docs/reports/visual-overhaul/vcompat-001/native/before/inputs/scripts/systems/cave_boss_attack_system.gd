extends RefCounted

const Data := preload("res://scripts/systems/cave_boss_data.gd")
const Shots := preload("res://scripts/systems/cave_boss_projectile_system.gd")

## Запоминает направление замаха и строит отдельную геометрию каждой из двенадцати атак.
static func begin(game: Node, id: String, boss: Dictionary) -> void:
	var state: Dictionary = game.state.world.cave_boss
	var origin: Vector2 = boss.position
	var target: Vector2 = game.player
	var direction := origin.direction_to(target)
	if direction.is_zero_approx(): direction = Vector2.DOWN
	state.attack = {"id":id,"elapsed":0.0,"origin":origin,"target":target,"direction":direction,"bursts":0,"hit":false}
	state.zones.clear()
	var delay: float = Data.ATTACKS[id].windup
	match id:
		"slam": zone(state, "circle", origin, origin, 132.0, delay)
		"fan": zone(state, "cone", origin, origin + direction * 560.0, 0.55, delay)
		"charge", "triple_charge":
			var previous := origin
			for index in (3 if id == "triple_charge" else 1):
				var end := safe_endpoint(game, previous, direction.rotated([0.0,0.75,-0.75][index]) * 260.0)
				zone(state, "charge", previous, end, 46.0, delay + index * 1.1)
				previous = end
		"fissure":
			for index in 4: zone(state, "circle", origin + direction * (78.0 + index * 85.0), origin, 56.0, delay + index * 0.25)
		"rockfall":
			for offset in [Vector2.ZERO, Vector2(-105,65), Vector2(105,-65)]:
				var center: Vector2 = target + offset
				if safe(game, center): zone(state, "circle", center, origin, 68.0, delay + state.zones.size() * 0.3)
		"burst", "spiral": zone(state, "circle", origin, origin, 55.0, delay)
		"sweep": zone(state, "cone", origin, origin + direction * 180.0, PI / 3.0, delay)
		"prison":
			for index in range(1, 7):
				var center := target + Vector2.from_angle(direction.angle() + index * TAU / 8.0) * 125.0
				if safe(game, center): zone(state, "crystal", center, origin, 38.0, delay)
		"cross":
			for axis in [Vector2.RIGHT, Vector2.DOWN]: zone(state, "line", origin - axis * 330.0, origin + axis * 330.0, 42.0, delay)
		"pulse": zone(state, "ring", origin, origin, 360.0, delay)
	game.notify_tutorial("cave_boss_attacks")

## Добавляет предупреждение с независимым временем контакта и состоянием нанесённого удара.
static func zone(state: Dictionary, shape: String, position: Vector2, end: Vector2, radius: float, trigger: float) -> void:
	state.zones.append({"shape":shape,"position":position,"end":end,"radius":radius,"trigger":trigger,"resolved":false})

## Останавливает запланированную траекторию на последней проходимой точке перед скалой.
static func safe_endpoint(game: Node, start: Vector2, motion: Vector2) -> Vector2:
	var result := start
	for index in maxi(1, ceili(motion.length() / 8.0)):
		var point := start + motion.normalized() * minf(motion.length(), (index + 1) * 8.0)
		if not safe(game, point): break
		result = point
	return result

## Проверяет сухой пол арены без учёта подвижных существ.
static func safe(game: Node, point: Vector2) -> bool:
	return Data.ARENA.has_point(point) and game.NavigationSystem.walkability_reason(game, point, -1, false) == "walkable"

## Обновляет контактные моменты, движения рывков и залпы снарядов без мгновенного урона.
static func update(game: Node, boss_index: int, delta: float) -> void:
	var state: Dictionary = game.state.world.cave_boss
	if state.attack.is_empty(): return
	var attack: Dictionary = state.attack
	var before := float(attack.elapsed)
	attack.elapsed += delta
	var config: Dictionary = Data.ATTACKS[attack.id]
	if attack.id in ["fan","burst","spiral"]: fire_bursts(game, attack, before)
	for area in state.zones:
		var age := float(attack.elapsed) - float(area.trigger)
		if age < 0.0: continue
		if area.shape == "charge": move_charge(game, boss_index, area, before, float(attack.elapsed))
		var continuous: bool = area.shape in ["charge","ring","crystal"]
		var lifetime := 0.45 if area.shape == "charge" else (1.0 if continuous else 0.3)
		if age > lifetime and continuous: continue
		if not bool(area.resolved) and attack.id not in ["fan","burst","spiral"]:
			if contains(area, game.player, age) and not bool(attack.hit):
				if Shots.hit(game, int(config.damage), area.position) > 0: attack.hit = true
			if not continuous: area.resolved = true
			if age <= delta: state.effects.append({"position":area.position,"row":int(config.effect),"time":0.0,"size":112.0})
	if float(attack.elapsed) >= float(config.duration):
		state.attack = {}; state.zones.clear(); state.recovery = float(config.recovery)

## Продвигает босса только на объявленном отрезке рывка и проверяет столкновения сцены.
static func move_charge(game: Node, boss_index: int, area: Dictionary, before: float, elapsed: float) -> void:
	var step := clampf(elapsed - float(area.trigger), 0.0, 0.45) - clampf(before - float(area.trigger), 0.0, 0.45)
	if step <= 0.0: return
	var motion: Vector2 = (area.end - area.position) * step / 0.45
	var boss: Dictionary = game.enemy_nodes[boss_index]
	var old: Vector2 = boss.position
	var next: Vector2 = game.NavigationSystem.move_enemy(game, boss_index, motion)
	# Персонаж не блокирует сам факт контакта при остановке рывка у его тела.
	if Geometry2D.get_closest_point_to_segment(game.player, old, next).distance_to(game.player) < 60.0:
		var attack: Dictionary = game.state.world.cave_boss.attack
		if not attack.hit and Shots.hit(game, int(Data.ATTACKS[attack.id].damage), old) > 0: attack.hit = true
	boss.position = next; boss.direction = motion.normalized()

## Испускает веер, радиальный круг или три повёрнутых залпа по фиксированному расписанию.
static func fire_bursts(game: Node, attack: Dictionary, _before: float) -> void:
	var id := String(attack.id)
	var delay: float = Data.ATTACKS[id].windup
	var count := 3 if id == "spiral" else 1
	while int(attack.bursts) < count and float(attack.elapsed) >= delay + int(attack.bursts) * 0.5:
		var burst := int(attack.bursts)
		var shots := 5 if id == "fan" else 8
		for index in shots:
			var angle := -0.48 + index * 0.24 if id == "fan" else index * TAU / shots + burst * 0.24
			var direction: Vector2 = attack.direction.rotated(angle) if id == "fan" else Vector2.from_angle(angle)
			Shots.launch(game, attack.origin + direction * 42.0, direction, int(Data.ATTACKS[id].damage), "amber" if id == "spiral" else "shard", 220.0)
		attack.bursts += 1

## Сверяет позицию героя с точной геометрией круга, коридора, конуса или растущего кольца.
static func contains(area: Dictionary, point: Vector2, age: float = 0.0) -> bool:
	var origin: Vector2 = area.position
	match area.shape:
		"circle", "crystal": return origin.distance_to(point) <= float(area.radius) + 14.0
		"line": return Geometry2D.get_closest_point_to_segment(point, origin, area.end).distance_to(point) <= float(area.radius) + 14.0
		"charge": return false
		"cone":
			var direction := origin.direction_to(area.end)
			return origin.distance_to(point) <= origin.distance_to(area.end) + 14.0 and absf(direction.angle_to(origin.direction_to(point))) <= float(area.radius)
		"ring": return absf(origin.distance_to(point) - (110.0 + clampf(age,0.0,1.0) * 250.0)) <= 28.0
	return false
