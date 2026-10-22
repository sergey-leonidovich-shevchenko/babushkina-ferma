extends RefCounted

const KEY := &"player_projectiles"
const BODY_OFFSET := Vector2(0,-24)
const Targets := preload("res://scripts/systems/player_attack_targets.gd")

## Возвращает временные реальные стрелы и заряды, которые никогда не записываются в сохранение.
static func state(game: Node) -> Array:
	if not game.has_meta(KEY): game.set_meta(KEY,[])
	return game.get_meta(KEY)

## Выпускает снаряд из текущей руки по направлению начала замаха, без повторного наведения на цель.
static func launch(game: Node, attack: Dictionary, residual: float = 0.0) -> void:
	var shot := attack.duplicate(true)
	shot.position=game.player
	shot.remaining=game.WeaponSystem.range_of(attack.weapon)
	shot.speed=440.0 if game.WeaponSystem.weapon_class(attack.weapon)=="bow" else 340.0
	if advance(game,shot,28.0/float(shot.speed)) and advance(game,shot,maxf(residual,0.0)): state(game).append(shot)

## Сохраняет паузу и удаляет снаряды другой локации, не перенося угрозы между комнатами.
static func update(game: Node, delta: float) -> void:
	if game.GameLoop.gameplay_window_open(game) or game.GameLoop.modal_active(game): return
	var survivors := []
	for shot in state(game):
		if shot.location==game.current_location and advance(game,shot,maxf(delta,0.0)): survivors.append(shot)
	game.set_meta(KEY,survivors)

## Проверяет короткие отрезки всей траектории, препятствия и ближайшее тело при редких кадрах.
static func advance(game: Node, shot: Dictionary, delta: float) -> bool:
	var distance := minf(float(shot.remaining),float(shot.speed)*delta)
	var steps := maxi(1,ceili(distance/6.0))
	var targets := Targets.all(game)
	for step in steps:
		var previous: Vector2 = shot.position
		var next: Vector2 = previous+Vector2(shot.aim)*distance/steps
		var reason: String = game.NavigationSystem.walkability_reason(game,next,-1,false)
		if reason not in ["walkable","guardian"]: return false
		var first := {}; var closest := INF
		for target in targets:
			var point := Geometry2D.get_closest_point_to_segment(target.position,previous,next)
			if point.distance_to(target.position)<=float(target.radius)+3.0 and previous.distance_to(point)<closest:
				first=target; closest=previous.distance_to(point)
		if not first.is_empty():
			# Обратное обращение через игровой узел избегает циклических preload двух фаз атаки.
			game.WeaponSystem.apply_projectile_contact(game,shot,first); return false
		shot.position=next
	shot.remaining=maxf(0.0,float(shot.remaining)-distance)
	return float(shot.remaining)>0.0

## Убирает летящие заряды после успешной загрузки или поражения.
static func reset(game: Node) -> void:
	game.set_meta(KEY,[])

## Рисует стрелу или светящийся заряд в той же позиции, которая проверяется на столкновение.
static func draw(game: Node2D) -> void:
	for shot in state(game):
		if shot.location!=game.current_location: continue
		var position: Vector2 = Vector2(shot.position)+BODY_OFFSET
		var direction: Vector2 = shot.aim
		if game.WeaponSystem.weapon_class(shot.weapon)=="bow":
			var normal := direction.orthogonal()
			game.draw_line(position-direction*22.0,position,Color("cfaa6d"),2.0)
			game.draw_colored_polygon(PackedVector2Array([position,position-direction*7+normal*3,position-direction*7-normal*3]),Color("edf2df"))
			for side in [-1,1]: game.draw_line(position-direction*16,position-direction*22+normal*side*3,Color("e4ddc3"),1.5)
		else:
			game.draw_circle(position,9,Color(0.2,0.85,1,0.20)); game.draw_circle(position,5,Color("73dafa")); game.draw_circle(position,2,Color("e2fbff"))
