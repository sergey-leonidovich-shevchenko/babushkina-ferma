extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Hero := preload("res://scripts/systems/hero_visual_system.gd")
const ActorRenderer := preload("res://scripts/systems/animation_renderer.gd")
const Village := preload("res://scripts/systems/village_map_data.gd")
const PATH := "res://docs/reports/visual-overhaul/vbase-005/routes.json"
const KEYS := [KEY_A,KEY_D,KEY_W,KEY_S]
var plan := {}
var tick := 0
var index := 0
var idle_ticks := 0
var previous := Vector2.ZERO
var previous_location := ""
var held := {}
var rows := []
var checkpoints := []
var events := []
var errors := []
var sent := []
var input_phase := "before"

## Читает закреплённый маршрут без пересоздания ожидаемой геометрии при ошибке.
static func registry() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))

## Готовит только тестовую сцену до первого шага; после старта координаты задаёт исключительно игра.
func prepare(game: Node) -> void:
	plan=registry()
	Points.configure(game,{"location":plan.location,"player":plan.start,"facing":[1,0],"day":plan.day,"minutes":plan.minutes})
	game.settings_state.reduced_motion=false; game.speed=plan.speed
	for actor_id in plan.crowd_fixture.actors:
		var state:Dictionary=game.npc_movement[actor_id]
		state.location="overworld"; state.position=Points.vector(plan.crowd_fixture.actors[actor_id])
		state.schedule_initialized=true; state.moving=false; state.schedule="QA overlap fixture"
	game.update_camera(); previous=game.player; previous_location=game.current_location
	rows.append(snapshot(game))

## Посылает только изменения клавиш через настоящий игровой обработчик ввода.
func key(game: Node, code: Key, pressed: bool) -> void:
	if held.get(code,false)==pressed: return
	held[code]=pressed
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	game._input(event)
	sent.append({"tick":tick,"phase":input_phase,"key":OS.get_keycode_string(code),"pressed":pressed})

## Удерживает только одну ось; диагональная поправка и назначение player не используются.
func direction(game: Node, value: Vector2) -> void:
	key(game,KEY_A,value.x<0); key(game,KEY_D,value.x>0)
	key(game,KEY_W,value.y<0); key(game,KEY_S,value.y>0)

## Выбирает следующий шаг до обычного физического обновления сцены.
func before_step(game: Node) -> void:
	input_phase="before"
	if finished(): direction(game,Vector2.ZERO); return
	tick+=1
	var step:Dictionary=plan.steps[index]
	if step.kind=="move":
		if game.current_location!=step.location: fail("unexpected move location"); return
		var difference:Vector2=Points.vector(step.target)-game.player
		direction(game,Vector2(signf(difference.x),0) if absf(difference.x)>absf(difference.y) else Vector2(0,signf(difference.y)))
	else:
		if game.current_location!=step.from: fail("unexpected travel location"); return
		direction(game,Points.vector(step.direction))

## Записывает результат после реальной физики, включая только штатные переходы через дверь.
func after_step(game: Node, delta: float = 1.0/60.0) -> void:
	if finished(): return
	input_phase="after"
	var row:=snapshot(game); row.physics_delta=delta; rows.append(row)
	var moved:float=game.player.distance_to(previous)
	if game.current_location!=previous_location:
		events.append({"tick":tick,"from":previous_location,"to":game.current_location,"before":Points.pair(previous),"after":Points.pair(game.player)})
		direction(game,Vector2.ZERO)
		idle_ticks=0
	else:
		if moved>game.speed/60.0+0.01: fail("non-physical jump")
		idle_ticks=idle_ticks+1 if moved<0.001 else 0
	if not bool(row.live) or not bool(row.walkable): fail("simulation stopped or blocked position")
	var step:Dictionary=plan.steps[index]
	var reached:bool=game.current_location==step.location and (step.kind=="travel" or game.player.distance_to(Points.vector(step.target))<=float(plan.tolerance))
	if reached:
		checkpoints.append({"id":step.id,"tick":tick,"location":game.current_location,"position":Points.pair(game.player),"camera":Points.pair(game.camera_offset)})
		index+=1; idle_ticks=0
	if idle_ticks>=int(plan.stuck_ticks) or tick>=int(plan.max_ticks): fail("route stuck or timed out")
	previous=game.player; previous_location=game.current_location
	if finished(): direction(game,Vector2.ZERO)

## Снимает опору, камеру, фактический ввод, жителей и расстояние до существующих дорог.
func snapshot(game: Node) -> Dictionary:
	var foot:Vector2=game.player
	var pose:=Hero.current_pose(game,game.facing,game.get_movement_direction()!=Vector2.ZERO)
	var destination:=Hero.destination(ActorRenderer.player_ground(game),pose)
	var rendered_foot:Vector2=destination.position+Vector2(pose.pivot)*float(pose.scale)
	var actors:=[]
	for actor_id in plan.crowd_fixture.actors:
		var state:Dictionary=game.npc_movement[actor_id]
		if state.location==game.current_location: actors.append({"id":actor_id,"position":Points.pair(state.position)})
	var distance:=INF
	if game.current_location=="overworld":
		for path in Village.routes():
			for n in range(1,path.size()): distance=minf(distance,foot.distance_to(Geometry2D.get_closest_point_to_segment(foot,path[n-1],path[n])))
	return {"tick":tick,"step":mini(index,plan.steps.size()-1),"location":game.current_location,"player":Points.pair(foot),"foot":Points.pair(rendered_foot),
		"camera":Points.pair(game.camera_offset),"minutes":game.game_minutes,"direction":Points.pair(game.get_movement_direction()),
		"live":not game.GameLoop.modal_active(game) and not game.GameLoop.gameplay_window_open(game),"auto_physics":game.is_physics_processing(),"walkable":game.is_position_walkable(foot),
		"road_distance":distance if is_finite(distance) else -1.0,"actors":actors,
		"ahead_reason":game.NavigationSystem.walkability_reason(game,foot+game.get_movement_direction()*3.5)}

## Останавливает сценарий на первом дефекте, сохраняя его причину и предыдущие шаги.
func fail(reason: String) -> void:
	if errors.is_empty(): errors.append("tick %d, step %d: %s"%[tick,index,reason])

## Отличает завершённый маршрут от ещё активного либо отклонённого.
func finished() -> bool:
	return not errors.is_empty() or (not plan.is_empty() and index>=plan.steps.size())
