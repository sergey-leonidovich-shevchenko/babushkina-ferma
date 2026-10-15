extends RefCounted

const Points := preload("res://tools/visual_camera_points.gd")

## Запускает проверки покрытия, реальной камеры и отказов при нарушении фиксированного состояния.
static func run(context: SceneTree) -> void:
	test_every_runtime_map_has_a_walkable_camera(context)
	test_changed_pose_is_rejected(context)

## Сценарий: каждая игровая карта воспроизводит закреплённую точку в новой сцене.
## Исходное состояние: реестр тридцати точек и одинаковый генератор до создания каждой игры.
## Ожидаемый результат: нет пропусков и повторов, камера совпадает, герой виден, точка проходима.
static func test_every_runtime_map_has_a_walkable_camera(context: SceneTree) -> void:
	var data:=Points.registry(); var seen:=[]; var ids:=[]; var runtime:=[]
	for point in data.points:
		var game:=Points.create_game(); game._ready(); Points.configure(game,point)
		if runtime.is_empty(): runtime=Points.Teleport.locations(game)
		context.expect(point.location in runtime,"camera point names real map: "+point.id)
		context.expect(point.location not in seen and point.id not in ids,"camera point is unique: "+point.id)
		seen.append(point.location); ids.append(point.id)
		context.expect(Points.errors(game,point).is_empty(),"camera contract: "+point.id+str(Points.errors(game,point)))
		context.expect(game.walk_animation_time==0 and game.facing==Vector2.DOWN,"camera fixes idle pose: "+point.id)
		context.expect(not game.is_processing() and not game.settings_state.pause_on_focus_loss,"camera static fixture: "+point.id)
		game.free()
	context.expect(seen.size()==runtime.size() and seen.size()==30,"all runtime maps covered")
	for location in runtime: context.expect(location in seen,"runtime map has camera: "+location)

## Сценарий: после фиксации кадра изменяется один параметр либо включается симуляция.
## Исходное состояние: настоящая сцена деревни с корректной точкой и независимыми испорченными ожиданиями.
## Ожидаемый результат: сдвиг камеры, другое время, seed, направление, непроходимость и открытое меню отклоняются.
static func test_changed_pose_is_rejected(context: SceneTree) -> void:
	var point:Dictionary=Points.registry().points[0]
	var game:=Points.create_game(); game._ready(); Points.configure(game,point)
	for key in ["camera","player","facing","minutes","phase","seed","weather"]:
		var bad:=point.duplicate(true)
		if key in ["camera","player","facing"]: bad[key][0]+=24
		elif key in ["minutes","seed"]: bad[key]+=1
		else: bad[key]="unknown"
		context.expect(not Points.errors(game,bad).is_empty(),"camera rejects changed "+key)
	game.set_physics_process(true)
	context.expect(not Points.errors(game,point).is_empty(),"camera rejects live simulation")
	game.set_physics_process(false); game.menu_state.pause_open=true
	context.expect(not Points.errors(game,point).is_empty(),"camera rejects modal")
	game.menu_state.pause_open=false; game.player=Vector2(-1000,-1000); game.update_camera()
	context.expect(not Points.errors(game,point).is_empty(),"camera rejects invalid landing")
	game.free()
