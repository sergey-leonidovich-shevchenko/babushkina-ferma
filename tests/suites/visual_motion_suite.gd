extends RefCounted

const Route := preload("res://tools/qa/camera/visual_motion_route.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")

## Проверяет настоящий ввод и физику без выдачи headless за графическое устройство или FPS.
static func run(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready()
	var route:=Route.new(); route.prepare(game)
	while not route.finished():
		route.before_step(game); game.GameLoop.physics_process(game,1.0/60.0); route.after_step(game)
	context.expect(route.errors.is_empty() and route.checkpoints.size()==route.plan.steps.size(),"motion route reaches all input-driven checkpoints")
	context.expect(route.events.size()==2 and route.events[0].to=="cottage_interior" and route.events[1].to=="overworld","door round trip uses real location transitions")
	context.expect(route.rows[-1].location=="overworld" and game.player.distance_to(Vector2(432,696))<=4,"route ends at its observed physical target")
	context.expect(absf(game.game_minutes-(360.0+route.tick/60.0))<0.0001,"full world advances with each replayed physics step")
	var crossed:=0; var grass:=0; var overlap:=0
	for row in route.rows:
		if row.location=="overworld" and row.player[0]>830 and row.player[0]<898 and row.player[1]>400 and row.player[1]<520: crossed+=1
		if row.location=="overworld" and row.road_distance>=48 and route.plan.steps[int(row.step)].tag=="grass": grass+=1
		if row.actors.size()==4: overlap+=1
	context.expect(crossed>20 and grass>12 and overlap>20,"live route exercises bridge, grass and existing-resident fixture")
	context.expect(game.get_movement_direction()==Vector2.ZERO,"completion releases all held keys")
	context.expect(route.sent.any(func(edge):return edge.phase=="after" and not edge.pressed),"door transitions explicitly release synthetic held input")
	game.free()
	test_failures(context)

## Сценарий: после подготовленной сцены ввод игнорируется, мир заморожен или внесён скачок.
## Исходное состояние: новые тестовые экземпляры без сохранений пользователя.
## Ожидаемый результат: остановка с причиной вместо подстановки координат и ложной готовности.
static func test_failures(context: SceneTree) -> void:
	for kind in ["blocked","paused","teleport"]:
		var game:=Points.create_game(); game._ready()
		var route:=Route.new(); route.prepare(game)
		if kind=="blocked":
			route.plan.steps[0].target=[1296,672]; route.plan.max_ticks=120
		while not route.finished():
			route.before_step(game)
			if kind=="paused": game.menu_state.pause_open=true
			game.GameLoop.physics_process(game,1.0/60.0)
			if kind=="teleport": game.player+=Vector2(100,0)
			route.after_step(game)
		context.expect(not route.errors.is_empty(),"motion rejects "+kind+" without faking completion")
		context.expect(route.checkpoints.size()<route.plan.steps.size(),"rejected "+kind+" cannot cover route")
		game.free()
