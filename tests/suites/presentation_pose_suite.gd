extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Trees := preload("res://scripts/systems/tree_occlusion_system.gd")

## Проверяет фазы, настоящие физические шаги, визуальные опоры и сбросы без пользовательских слотов.
static func run(context: SceneTree) -> void:
	test_phases(context)
	test_discontinuities(context)
	test_runtime_tick(context)

## Создаёт отдельную игровую сцену, не включая автоматическую симуляцию.
static func fixture() -> Node:
	var game := Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	game.player=Vector2(600.25,700.25); game.update_camera(); Pose.reset(game)
	return game

## Сценарий: два отображаемых кадра на физический такт, три частоты и порог камеры.
## Ожидаемый результат: тело, тень, часы ног, дерево и корень используют одну фазу; физика не меняется.
static func test_phases(context: SceneTree) -> void:
	var game := fixture()
	for rate in [30,60,120]:
		for start in [Vector2(40.25,700.25),Vector2(575.75,700.25),Vector2(600.25,700.25),Vector2(2359.5,1287.5)]:
			game.player=start; game.set_meta(&"player_walk_time",1.0); Pose.reset(game)
			Pose.begin_tick(game)
			game.player+=Vector2.ONE*(18.0/sqrt(2.0)/rate)
			game.set_meta(&"player_walk_time",1.0+1.0/rate)
			Pose.end_tick(game,1.0/rate)
			var physical: Vector2 = game.player; var minutes: float = game.game_minutes
			for alpha in [0.0,0.25,0.5,0.75,1.0]:
				Pose.present(game,alpha)
				var expected: Vector2 = start.lerp(physical,alpha)
				context.expect(Pose.ground(game).is_equal_approx(expected),"phase interpolates the completed collision endpoints")
				context.expect(game.AnimationRenderer.player_ground(game)==Pose.ground(game),"hero and environment share the identical foot")
				context.expect(game.camera_offset==game.CameraSystem.offset_for_position(game,expected),"camera clamps the displayed foot at threshold and edge")
				context.expect(game.get_node("WorldBackground").position==-game.camera_offset,"background has the same phase as actor")
				context.expect(is_equal_approx(Pose.walk_clock(game),1.0+alpha/rate),"foot animation uses the same phase")
				var root: Vector2 = expected+Vector2(5,8)
				context.expect(Pose.root_contact(game,root,24).is_equal_approx(Vector2(-5,-8)/24.0),"root contact follows visible foot instead of the next physical endpoint")
				context.expect(Trees.hero_bounds(game).position.x>=expected.x-25.01,"tree body bounds follow the displayed foot")
				context.expect(game.player==physical and game.game_minutes==minutes,"presentation never moves physics or clocks")
				if alpha<1.0: context.expect(expected!=physical,"fixture exposes a physical/displayed phase mismatch")
	context.expect(Pose.root_contact(game,game.player+Vector2(300,0),24)==Vector2.ZERO and Pose.root_contact(game,game.player,0)==Vector2.ZERO,"far and invalid-radius plants do not react")
	game.free()

## Сценарий: пауза, фокус, загрузка, дверь, редактор, остановка у стены и аномальная фаза.
## Ожидаемый результат: нет шлейфа переноса или перезаписи ручной камеры; выход из паузы не доигрывает старый шаг.
static func test_discontinuities(context: SceneTree) -> void:
	var game := fixture()
	Pose.begin_tick(game); game.player+=Vector2(2,0); Pose.end_tick(game,1.0/60.0); Pose.present(game,0.5)
	var frozen := Pose.ground(game); var camera: Vector2 = game.camera_offset
	game.menu_state.pause_open=true
	for tick in 4:
		Pose.begin_tick(game); Pose.end_tick(game,1.0/60.0); Pose.present(game,0.99)
		context.expect(Pose.ground(game)==frozen and game.camera_offset==camera,"pause freezes the displayed frame across repeated ticks")
	game.menu_state.pause_open=false; Pose.present(game,0.1)
	context.expect(Pose.ground(game)==game.player,"resume discards stale phase")
	game.player=Vector2(1000,800); Pose.present(game,0.5)
	context.expect(Pose.ground(game)==game.player,"external same-map teleport or load resets immediately")
	Pose.begin_tick(game); game.player=Vector2(1600,900); Pose.end_tick(game,1.0/60.0); Pose.present(game,0.3)
	context.expect(Pose.ground(game)==game.player,"large in-tick teleport has no interpolated trail")
	game.current_location="cottage_interior"; game.player=Vector2(576,470); Pose.present(game,0.5)
	context.expect(Pose.ground(game)==game.player and game.camera_offset==game.CameraSystem.target_offset(game),"door switches room bounds without old frame")
	Pose.begin_tick(game); game.set_meta(&"player_walk_time",0.0); Pose.end_tick(game,1.0/60.0); Pose.present(game,0.4)
	context.expect(Pose.walk_clock(game)==0.0,"blocked or stopped movement resets feet without reverse animation")
	game.settings_state.pause_on_focus_loss=true
	preload("res://scripts/systems/focus_pause_system.gd").state(game).focused=false
	var before := Pose.ground(game); Pose.present(game,0.9)
	context.expect(Pose.ground(game)==before,"focus pause freezes presentation")
	game.settings_state.pause_on_focus_loss=false
	game.set_meta(game.LevelEditorSystem.META_KEY,{"active":true})
	game.camera_offset=Vector2(321,123); Pose.present(game,0.5)
	context.expect(game.camera_offset==Vector2(321,123),"F12 retains its manually panned camera")
	game.set_meta(game.LevelEditorSystem.META_KEY,{"active":false})
	Pose.present(game,NAN)
	context.expect(Pose.ground(game).is_finite(),"invalid phase cannot poison rendering")
	game.free()

## Сценарий: штатный физический callback и клавиши движения, затем два отображаемых кадра.
## Ожидаемый результат: snapshot окружает настоящий GameLoop; шаг и сохранение остаются физическими.
static func test_runtime_tick(context: SceneTree) -> void:
	var game := fixture(); game.speed=18
	game.move_right_held=true; game.move_down_held=true
	var start: Vector2 = game.player
	game._physics_process(1.0/60.0)
	var physical: Vector2 = game.player
	Pose.present(game,0.25); var first := Pose.ground(game)
	Pose.present(game,0.75); var second := Pose.ground(game)
	context.expect(physical.distance_to(start)>0 and first.distance_to(start)<second.distance_to(start),"ordinary callback presents distinct frames between physical ticks")
	context.expect(game.player==physical and Points.vector(game.SaveSystem.snapshot(game).player)==physical,"saved hero stays at the physical endpoint")
	context.expect(second.distance_to(physical)<=18.0/60.0,"lag is bounded by one physical tick")
	game.free()
