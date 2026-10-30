extends RefCounted

const Points:=preload("res://tools/qa/camera/visual_camera_points.gd")
const Frame:=preload("res://scripts/presentation/post_motion_frame.gd")
const Pose:=preload("res://scripts/systems/presentation_pose_system.gd")
const Clock:=preload("res://scripts/presentation/village_ground_clock.gd")

## Проверяет реальные такты и безопасный контракт времени/контакта без пользовательского профиля.
static func run(context:SceneTree)->void:
	_test_tick(context)
	_test_wall(context)
	_test_pause_and_modes(context)
	_test_transitions(context)
	_test_rejection_and_reads(context)

## Создаёт штатную сцену и отключает только автоматическую подачу тактов QA.
static func fixture()->Node:
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0])
	game.settings_state.reduced_motion=false;game.player=Vector2(696,696);game.speed=90;game.update_camera();Pose.reset(game)
	return game

## Находит настоящую границу сплошной ограды; угол и скольжение не подменяют остановку.
static func wall(game:Node)->Vector2:
	for rect in game.BuildingSystem.farm_fence_rects():
		for distance in range(1,65):
			var p:=Vector2(rect.get_center().x,rect.position.y-distance)
			if game.is_position_walkable(p) and not game.is_position_walkable(p+Vector2(0,3)):return p
	return Vector2.INF

## Сценарий: обычный callback двигает героя, затем два отображаемых кадра читают один физический результат.
static func _test_tick(c:SceneTree)->void:
	var g:=fixture();c.expect(Frame.read(g).is_empty() and not g.has_meta(Frame.META),"cold read has no mutation or invented frame")
	var start:Vector2=g.player;g.move_right_held=true;g._physics_process(1.0/30.0)
	var value:=Frame.read(g)
	c.expect(not value.is_empty() and value.is_read_only(),"real runtime publishes a read-only frame")
	c.expect(g.player.x>start.x and value.player_world==g.player,"published point is the resolved post-movement point")
	c.expect(is_equal_approx(value.seconds,1.0/30.0) and Clock.seconds(g)==value.seconds,"decorative time advances exactly once after the runtime step")
	var saved:Dictionary=g.SaveSystem.snapshot(g)
	for alpha in [0.0,0.25,0.5,0.75,1.0]:
		Pose.present(g,alpha);var root:=Pose.ground(g)+Vector2(8,6)
		c.expect(Frame.contact(g,root,32).is_equal_approx(Vector2(-8,-6)/32),"contact uses the same interpolated visible foot as hero")
		c.expect(Frame.read(g)==value and g.SaveSystem.snapshot(g)==saved,"render reads never change the physical frame or full save")
	c.expect(not str(saved).contains(String(Frame.META)),"visual frame is absent from save schema")
	g.free()

## Сценарий: удержание вниз в существующую ограду не двигает точку и не касается дальней травы.
static func _test_wall(c:SceneTree)->void:
	var g:=fixture();var p:=wall(g)
	c.expect(p.is_finite(),"fixture uses a real fence collision")
	g.player=p;Pose.reset(g);g.move_down_held=true
	var stable:=true;var no_contact:=true
	for tick in 12:
		g._physics_process(1.0/30.0);Pose.present(g,0.5)
		stable=stable and g.player==p and Frame.read(g).get("player_world",Vector2.INF)==p
		no_contact=no_contact and Frame.contact(g,p+Vector2(0,64),32)==Vector2.ZERO
	c.expect(stable,"blocked movement publishes the fixed collision endpoint on every tick")
	c.expect(no_contact,"held input cannot bend grass beyond the fence")
	g.free()

## Сценарий: Escape, инвентарь, фокус, редактор и reduced motion не накапливают время или ложный контакт.
static func _test_pause_and_modes(c:SceneTree)->void:
	var g:=fixture();g._physics_process(0.02);Pose.present(g,0.5)
	var frozen:=Frame.read(g);var root:Vector2=Pose.ground(g)+Vector2(8,0);var contact:=Frame.contact(g,root,32)
	for mode in ["pause","inventory","focus","editor"]:
		match mode:
			"pause":g.MenuSystem.open_pause(g)
			"inventory":g.inventory_open=true
			"focus":g.settings_state.pause_on_focus_loss=true;g._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"editor":g.set_meta(g.LevelEditorSystem.META_KEY,{"active":true})
		for tick in 3:g._physics_process(0.1)
		c.expect(g.get_meta(Frame.META)==frozen and Clock.seconds(g)==frozen.seconds,"suspended "+mode+" freezes frame and phase without debt")
		if mode!="editor":c.expect(Frame.contact(g,root,32)==contact,"paused contact remains at the frozen displayed foot")
		else:c.expect(Frame.contact(g,root,32)==Vector2.ZERO,"manual editor never drives plant contact")
		g.MenuSystem.resume(g);g.inventory_open=false;g._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN);g.settings_state.pause_on_focus_loss=false;g.remove_meta(g.LevelEditorSystem.META_KEY)
	g.settings_state.reduced_motion=true;g._physics_process(0.02)
	c.expect(not Frame.read(g).active and Clock.seconds(g)==frozen.seconds and Frame.contact(g,root,32)==Vector2.ZERO,"reduced motion publishes safe position without advancing effects")
	g.settings_state.reduced_motion=false;g._physics_process(0.02)
	c.expect(is_equal_approx(Clock.seconds(g),frozen.seconds+0.02),"resume has only the current delta and no catch-up")
	g.free()

## Сценарий: обычный автоматический вход в дом происходит внутри update_player, затем настоящий возврат и внешний перенос.
static func _test_transitions(c:SceneTree)->void:
	var g:=fixture();g._physics_process(0.02)
	g.player=g.BuildingSystem.BUILDINGS.cottage.door;g.location_transition_armed=true;g.location_transition_cooldown=0;Pose.reset(g)
	g._physics_process(0.02)
	var inside:=Frame.read(g)
	c.expect(g.current_location=="cottage_interior" and inside.world==g.current_location and inside.player_world==g.player,"actual door transition publishes destination world and spawn")
	c.expect(not inside.active and Frame.contact(g,Vector2(696,696),32)==Vector2.ZERO,"interior cannot retain a first-map plant influence")
	g.BuildingSystem.leave(g)
	c.expect(Frame.read(g).is_empty() and Frame.contact(g,Vector2(696,696),32)==Vector2.ZERO,"external transition invalidates old packet before another tick")
	g.location_transition_armed=false;g._physics_process(0.02)
	c.expect(Frame.read(g).world=="overworld" and Frame.read(g).player_world==g.player,"return publishes a fresh first-map point")
	g.player+=Vector2(240,0)
	c.expect(Frame.read(g).is_empty() and Frame.contact(g,g.player,32)==Vector2.ZERO,"same-map teleport has no stale contact before publish")
	g.free()

## Сценарий: неподходящие дельты, радиусы и metadata читаются многократно без сохранений, ссылок на узлы и роста очереди.
static func _test_rejection_and_reads(c:SceneTree)->void:
	var g:=fixture();g._physics_process(0.02);var original:=Frame.read(g);var saved:Dictionary=g.SaveSystem.snapshot(g)
	for delta in [0.0,-1.0,NAN,INF]:c.expect(not Frame.publish(g,delta) and Frame.read(g)==original,"invalid delta cannot poison the frame")
	for radius in [0.0,-1.0,NAN,INF]:c.expect(Frame.contact(g,g.player,radius)==Vector2.ZERO,"invalid radius is neutral")
	c.expect(Frame.contact(g,Vector2.INF,32)==Vector2.ZERO,"non-finite root never reaches the shader")
	for bad in [null,[],{"world":"overworld"},original.duplicate()]:
		if bad==null:g.remove_meta(Frame.META)
		else:g.set_meta(Frame.META,bad)
		c.expect(Frame.read(g).is_empty(),"missing, foreign and mutable packets are rejected")
	g.set_meta(Frame.META,original)
	for tick in 1000:Frame.read(g);Frame.contact(g,g.player+Vector2(4,0),32)
	c.expect(Frame.read(g)==original and g.SaveSystem.snapshot(g)==saved,"one bounded primitive-only packet survives pure repeated reads")
	c.expect(original.keys().size()==4 and original.values().all(func(v:Variant)->bool:return not v is Object and not v is Callable),"packet owns no Node, Material, callback or gameplay state")
	g.free()
