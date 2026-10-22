extends RefCounted
const Contact:=preload("res://scripts/presentation/foliage_contact.gd")
const Wind:=preload("res://scripts/presentation/foliage_wind.gd")
const Points:=preload("res://tools/visual_camera_points.gd")

## Проверяет гладкое компактное поле четырёх направлений, точный центр и ограниченный изгиб без нормализации.
static func run(ctx:SceneTree)->void:
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var previous:=Vector2.ZERO
		for step in range(-48,49):
			var value:=Contact.displacement(direction*step,Vector2.ZERO)
			ctx.expect(value.is_finite() and value.length()<2.3,"finite bounded reaction through the root and both radius edges")
			if step>-48:ctx.expect(value.distance_to(previous)<0.223,"one world-unit step has no abrupt bend")
			ctx.expect(value.is_equal_approx(-Contact.displacement(-direction*step,Vector2.ZERO)),"opposite approaches are antisymmetric")
			previous=value
	ctx.expect(Contact.displacement(Vector2.ZERO,Vector2.ZERO)==Vector2.ZERO,"exact root has no arbitrary normalized direction")
	for point in [Vector2(NAN,0),Vector2.INF]:ctx.expect(Contact.displacement(point,Vector2.ZERO)==Vector2.ZERO,"nonfinite foot is rejected")
	for radius in [0.0,-1.0,NAN,INF]:ctx.expect(Contact.displacement(Vector2.ONE,Vector2.ZERO,radius)==Vector2.ZERO,"invalid radius cannot create NaN")
	_scene(ctx)

## Использует настоящий Game внутри готового SceneTree: окончательную физику, видимую стопу, паузу и безопасный сброс.
static func _scene(ctx:SceneTree)->void:
	var game:=Points.create_game();ctx.root.add_child(game);Points.configure(game,Points.registry().points[0])
	game.WorkshopSystem.state(game,"pottery");game.settings_state.reduced_motion=false;game.set_meta(&"camera_reference_zoom",1.2)
	var anchor:Vector2=Wind.placements()[6].anchor;game.player=anchor+Vector2(-12,0);game.update_camera()
	Contact.Pose.reset(game);Contact.Frame.publish(game,1.0/60)
	var before:Dictionary=game.SaveSystem.snapshot(game);Wind.update(game)
	var owner:=game.get_node(Wind.NAME)
	ctx.expect(owner.last_contacts[6].x>0 and owner.last_contacts[6].y==0,"published left foot bends the visible tuft right")
	ctx.expect(game.SaveSystem.snapshot(game)==before,"contact preparation does not change gameplay or saves")
	for group in owner.batch.groups:
		ctx.expect(group.multimesh.instance_count==(6 if String(group.name)=="reeds" else 2),"bounded species groups keep all eight original plants; GPU custom slots require native verification")
	game.menu_state.pause_open=true;var frozen:PackedVector2Array=owner.last_contacts.duplicate();var stats:=Wind.statistics(game)
	for i in 8:Wind.update(game)
	ctx.expect(owner.last_contacts==frozen and Wind.statistics(game)==stats,"pause freezes contact and performs no repeated upload")
	game.menu_state.pause_open=false
	var pose:=Contact.Pose.reset(game);pose.previous=anchor-Vector2(24,0);pose.current=game.player
	Contact.Pose.present(game,0.25);Wind.update(game);var first:PackedVector2Array=owner.last_contacts.duplicate();var clock_uploads:int=owner.uploads
	Contact.Pose.present(game,0.75);Wind.update(game)
	ctx.expect(first!=owner.last_contacts and owner.uploads==clock_uploads,"interpolated foot updates reaction without advancing the physical wind clock")
	ctx.expect(owner.last_contacts[6].is_equal_approx(Contact.displacement(Contact.Pose.ground(game),anchor)),"contact and hero use the same presented pose")
	for flag in [false,17,"yes"]:
		game.set_meta(Contact.FLAG,flag);Wind.update(game);ctx.expect(owner.last_contacts==Contact.empty(),"invalid/disabled contact rolls back to wind alone")
	game.set_meta(Contact.FLAG,true);Wind.update(game)
	game.camera_offset=Vector2(-8000,-8000);Wind.update(game)
	ctx.expect(owner.last_contacts==Contact.empty() and owner.contacts_dirty,"offscreen clears CPU contact and marks GPU state for reset")
	game.player=anchor+Vector2(800,0);game.camera_offset=Vector2(1464,378);Wind.update(game)
	ctx.expect(owner.last_contacts==Contact.empty() and not owner.contacts_dirty,"same-clock return clears stale GPU contacts even without a new physical frame")
	for group in owner.batch.groups:
		var values:Variant=group.material.get_shader_parameter("contact_bends")
		ctx.expect(values==Contact.empty(),"both live materials receive the cleared buffer")
	game.player=anchor;Contact.Pose.reset(game);Contact.Frame.publish(game,1.0/60);Wind.update(game)
	ctx.expect(owner.last_contacts[6]==Vector2.ZERO,"standing at the exact real root has zero contact bend")
	for i in 10:Wind.update(game)
	ctx.expect(owner.mesh_builds==1 and game.get_node(Wind.NAME)==owner,"stop and return never allocate another owner or geometry")
	game.player=Vector2(40,120);game.move_left_held=true
	for i in 5:game._physics_process(1.0/30)
	Wind.update(game);ctx.expect(game.player==Vector2(40,120) and owner.last_contacts==Contact.empty(),"wall contact uses actual post-collision position, not intended movement")
	game.clear_movement_keys();game.change_inventory_count(Points.Teleport.KIND,1)
	ctx.expect(Points.Teleport.open(game) and Points.Teleport.travel(game,"forest"),"actual QA stone transfers out of the world")
	Wind.update(game);ctx.expect(owner.last_contacts==Contact.empty(),"other world has no retained contact")
	ctx.expect(Points.Teleport.open(game) and Points.Teleport.travel(game,"overworld"),"actual QA stone returns to the world")
	Wind.update(game);ctx.expect(owner.last_contacts==Contact.empty() and owner.mesh_builds==1,"transfer invalidates stale frame and reuses one bounded owner")
	game.free()
