extends RefCounted
const Speed:=preload("res://scripts/presentation/foliage_speed.gd")
const Contact:=preload("res://scripts/presentation/foliage_contact.gd")
const Wind:=preload("res://scripts/presentation/foliage_wind.gd")
const Points:=preload("res://tools/visual_camera_points.gd")

## Проверяет ограниченную силу, настоящие шаги разных частот, упор и скольжение, паузу и сброс временных данных.
static func run(ctx:SceneTree)->void:
	var last:=1.0
	for value in range(0,801,10):
		var gain:=Speed.gain(Vector2(value,0))
		ctx.expect(is_finite(gain) and gain>=last and gain<=1.9,"speed gain is finite, monotonic and bounded")
		ctx.expect(is_equal_approx(gain,Speed.gain(Vector2(0,-value))),"gain does not depend on the approach direction")
		last=gain
	for v in [Vector2(NAN,0),Vector2.INF]:ctx.expect(Speed.gain(v)==1,"nonfinite speed cannot amplify the plant")
	ctx.expect(is_equal_approx(Speed.gain(Vector2(70,0)),1.05625) and is_equal_approx(Speed.gain(Vector2(210,0)),1.50625) and is_equal_approx(Speed.gain(Vector2(273,0)),1.8555625),"slow, normal and existing speed buff have distinct known gains")
	_scene(ctx)

## Проходит реальные коллизии одним игровым тактом; фиксирует прежнее поле и меняет только физически пройденный шаг.
static func _scene(ctx:SceneTree)->void:
	var game:=Points.create_game();ctx.root.add_child(game);Points.configure(game,Points.registry().points[0])
	game.WorkshopSystem.state(game,"pottery");game.settings_state.reduced_motion=false;game.set_meta(&"camera_reference_zoom",1.2)
	var anchor:Vector2=Wind.placements()[6].anchor
	for hz in [30,60,120]:
		for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			for pace in [70,210,273]:
				game.clear_movement_keys();game.speed=70.0 if pace==70 else 210.0;game.speed_timer=5.0 if pace==273 else 0.0
				var target:Vector2=anchor+side*16;game.player=target+side*float(pace)/hz;Contact.Pose.reset(game)
				_keys(game,-side);var origin:Vector2=game.player;game._physics_process(1.0/hz);Contact.Pose.present(game,1)
				ctx.expect(game.player.distance_to(target)<0.001,"real collision-resolved step ends at the shared comparison point")
				ctx.expect(Speed.read(game).is_equal_approx((game.player-origin)*hz),"recorded velocity uses actual displacement and simulation delta")
				ctx.expect(absf(Speed.read(game).length()-pace)<0.03,"three physical frequencies preserve the measured speed")
				var before:Dictionary=game.SaveSystem.snapshot(game);Wind.update(game);var owner:=game.get_node(Wind.NAME)
				ctx.expect(game.SaveSystem.snapshot(game)==before,"speed presentation leaves the complete save untouched")
				ctx.expect(owner.last_contacts[6].distance_to(Contact.displacement(Contact.Pose.ground(game),anchor)*Speed.gain(-side*pace))<0.0005,"actual GPU input scales the same spatial field by measured pace")
	game.clear_movement_keys();game._physics_process(1.0/60);Wind.update(game)
	ctx.expect(Speed.read(game)==Vector2.ZERO and Speed.strength(game)==1,"stopping immediately removes extra amplification without retained impulses")
	var bench:Vector2=game.workbench_position;game.workbench_position=anchor+Vector2(34,0);game.player=anchor-Vector2(16,0);Contact.Pose.reset(game);game.speed=210;game.speed_timer=0;_keys(game,Vector2.RIGHT)
	for i in 5:game._physics_process(1.0/60)
	Wind.update(game)
	ctx.expect(game.player.distance_to(anchor-Vector2(16,0))<0.001 and Speed.read(game)==Vector2.ZERO,"real nearby workbench blocks held input without fake velocity")
	ctx.expect(game.get_node(Wind.NAME).last_contacts[6].is_equal_approx(Contact.displacement(game.player,anchor)),"wall preserves only the weak stationary body contact")
	_keys(game,Vector2(1,1));var start:Vector2=game.player;game._physics_process(1.0/60)
	ctx.expect(absf(game.player.x-start.x)<0.001 and game.player.y>start.y and Speed.read(game).length()<210,"sliding scales by the real tangent movement, not requested diagonal speed")
	game.workbench_position=bench;game.clear_movement_keys();game.player=anchor-Vector2(16,0);Contact.Pose.reset(game);Contact.Frame.publish(game,1.0/60);Speed.publish(game,game.player-Vector2(3.5,0),"overworld",1.0/60);Wind.update(game)
	var saved:Dictionary=game.SaveSystem.snapshot(game);Speed.publish(game,game.player-Vector2.ONE,"overworld",1.0/60)
	ctx.expect(game.SaveSystem.snapshot(game)==saved,"transient measurement itself is excluded from the complete save")
	game.player=anchor-Vector2(20,0);Contact.Pose.reset(game);_keys(game,Vector2.RIGHT);game.FarmLifeSystem.state(game).hit_stop=1.0/120;game._physics_process(1.0/60);Wind.update(game)
	ctx.expect(absf(Speed.read(game).length()-210)<0.03 and absf(float(game.get_meta(Speed.META).delta)-1.0/120)<0.000001,"hit stop uses the actual reduced simulation delta, not the outer physics delta")
	var owner:=game.get_node(Wind.NAME);var frozen:PackedVector2Array=owner.last_contacts.duplicate();game.menu_state.pause_open=true
	for i in 5:game._physics_process(1.0/60);Wind.update(game)
	ctx.expect(owner.last_contacts==frozen,"pause freezes the existing speed-scaled field")
	game.menu_state.pause_open=false;game.clear_movement_keys();game._physics_process(1.0/60);Wind.update(game)
	ctx.expect(Speed.strength(game)==1,"first stationary tick after pause has no stored speed debt")
	for flag in [false,17,"yes"]:
		game.set_meta(Speed.FLAG,flag);ctx.expect(Speed.strength(game)==1,"invalid or disabled speed flag returns to the accepted spatial contact")
	game.set_meta(Speed.FLAG,true)
	for raw in [17,{}, {"world":"overworld"}]:game.set_meta(Speed.META,raw);ctx.expect(Speed.read(game)==Vector2.ZERO,"malformed metadata cannot amplify a plant")
	for delta in [0.0,-1.0,NAN,INF]:Speed.publish(game,game.player,"overworld",delta);ctx.expect(not game.has_meta(Speed.META),"invalid delta clears previous measurement")
	Speed.publish(game,Vector2.INF,"overworld",1.0/60);ctx.expect(not game.has_meta(Speed.META),"invalid origin cannot create a velocity")
	Speed.publish(game,game.player+Vector2(500,0),"overworld",1.0/60);ctx.expect(not game.has_meta(Speed.META),"same-world jump is rejected instead of becoming a burst")
	Speed.publish(game,game.player,"forest",1.0/60);ctx.expect(not game.has_meta(Speed.META),"cross-world origin cannot become movement")
	Speed.publish(game,game.player-Vector2.ONE,"overworld",1.0/60);game.player+=Vector2.ONE
	ctx.expect(Speed.read(game)==Vector2.ZERO,"position changed outside the captured physical tick invalidates speed")
	game.change_inventory_count(Points.Teleport.KIND,1)
	ctx.expect(Points.Teleport.open(game) and Points.Teleport.travel(game,"forest") and Speed.read(game)==Vector2.ZERO,"actual QA transfer invalidates the transient measurement")
	ctx.expect(Points.Teleport.open(game) and Points.Teleport.travel(game,"overworld") and Speed.read(game)==Vector2.ZERO,"return never reuses speed from another location")
	ctx.expect(owner.mesh_builds==1 and owner.batch.groups.size()==2,"speed changes never rebuild geometry or allocate additional groups")
	game.free()

## Задаёт только удерживаемое направление; реальная скорость и коллизии принадлежат штатному игровому циклу.
static func _keys(game:Node,direction:Vector2)->void:
	game.move_left_held=direction.x<0;game.move_right_held=direction.x>0;game.move_up_held=direction.y<0;game.move_down_held=direction.y>0
