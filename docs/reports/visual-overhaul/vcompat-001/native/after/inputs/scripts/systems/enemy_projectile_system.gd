extends RefCounted

const KEY := "enemy_projectiles"
const BODY_OFFSET := Vector2(0,-24)

## Возвращает временные снаряды; они не переносятся в сохранения и другие локации.
static func state(game: Node) -> Array:
	if not game.has_meta(KEY): game.set_meta(KEY,[])
	return game.get_meta(KEY)

## Выпускает снаряд по зафиксированной в начале замаха цели и учитывает остаток большого кадра.
static func launch(game: Node, enemy: Dictionary, remaining_delta: float = 0.0) -> void:
	var arrow: bool=enemy.action_kind=="shoot"
	launch_at(game,enemy.position,enemy.action_target,game.CombatSystem.boss_attack_damage(enemy),"arrow" if arrow else ("spit" if enemy.kind=="plant" else "magic"),320.0 if arrow else 240.0,maxf(260.0,float(game.CombatSystem.TYPES[enemy.kind].range)*1.8),enemy.kind,enemy.kind=="drowned_captain" and game.CombatSystem.boss_phase(enemy)==2,remaining_delta)

## Выпускает заряд неподвижного растения либо стрелка из одной физической модели полёта.
static func launch_at(game: Node, origin: Vector2, target: Vector2, damage: int, kind: String, speed: float, distance: float, source: String, steal: bool = false, remaining_delta: float = 0.0) -> void:
	var direction:=origin.direction_to(target)
	if direction.is_zero_approx(): return
	var shot:={"position":origin+direction*56.0,"direction":direction,"damage":damage,"kind":kind,"speed":speed,"remaining":distance,"location":game.current_location,"source":source,"steal":steal}
	if advance(game,shot,maxf(remaining_delta,0.0)): state(game).append(shot)
	game.notify_tutorial("enemy_projectiles")

## Двигает только существующие снаряды активной локации, сохраняя паузу всех игровых меню.
static func update(game: Node, delta: float) -> void:
	if game.menu_state.pause_open or game.menu_state.settings_open or game.menu_state.defeat_open or game.GameLoop.gameplay_window_open(game): return
	var survivors: Array=[]
	for shot in state(game):
		if shot.location==game.current_location and advance(game,shot,maxf(delta,0.0)): survivors.append(shot)
		if game.menu_state.defeat_open or preload("res://scripts/systems/recovery_system.gd").protected(game): survivors.clear(); break
	game.set_meta(KEY,survivors)

## Проверяет весь пройденный путь до препятствия или контакта, включая быстрые снаряды и редкие кадры.
static func advance(game: Node, shot: Dictionary, delta: float) -> bool:
	if preload("res://scripts/systems/recovery_system.gd").protected(game): return false
	var distance:=minf(float(shot.remaining),float(shot.speed)*delta)
	var steps:=maxi(1,ceili(distance/6.0))
	for step in steps:
		var previous: Vector2=shot.position
		var next: Vector2=previous+Vector2(shot.direction)*distance/steps
		if game.NavigationSystem.walkability_reason(game,next,-1,false)!="walkable": return false
		if Geometry2D.get_closest_point_to_segment(game.player,previous,next).distance_to(game.player)<=game.PLAYER_RADIUS+3.0:
			var dealt: int=game.CombatSystem.damage_player(game,int(shot.damage),game.LocaleSystem.entity(shot.source),previous)
			if dealt>0 and bool(shot.steal) and not preload("res://scripts/systems/recovery_system.gd").protected(game): game.coins=maxi(0,game.coins-2); game.notify_tutorial("boss_identity")
			game.notify_tutorial("enemy_projectiles")
			return false
		shot.position=next
	shot.remaining=maxf(0.0,float(shot.remaining)-distance)
	return float(shot.remaining)>0.0

## Очищает угрозы при успешной загрузке и новом игровом цикле.
static func reset(game: Node) -> void:
	game.set_meta(KEY,[])

## Рисует наконечник стрелы и магический заряд в той же позиции, которая участвует в столкновении.
static func draw(game: Node2D) -> void:
	for shot in state(game):
		if shot.location!=game.current_location: continue
		var position: Vector2=Vector2(shot.position)+BODY_OFFSET
		var direction: Vector2=shot.direction
		if shot.kind=="arrow":
			game.draw_line(position-direction*24.0,position,Color("d0a86c"),2.0)
			var normal:=direction.orthogonal()
			game.draw_colored_polygon(PackedVector2Array([position,position-direction*7+normal*3,position-direction*7-normal*3]),Color("e1e7df"))
			for side in [-1,1]: game.draw_line(position-direction*18,position-direction*24+normal*side*3,Color("dce0c5"),1.5)
		else:
			var color:=Color("91cc4e") if shot.kind=="spit" else Color("b098eb")
			game.draw_circle(position,7,Color(color,0.24)); game.draw_circle(position,3,color)
