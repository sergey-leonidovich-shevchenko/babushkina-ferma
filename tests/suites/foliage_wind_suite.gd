extends RefCounted
const Wind:=preload("res://scripts/presentation/foliage_wind.gd")
const Batch:=preload("res://scripts/presentation/foliage_wind_batch.gd")
const Clock:=preload("res://scripts/presentation/village_ground_clock.gd")
const Points:=preload("res://tools/qa/camera/visual_camera_points.gd")

## Проверяет настоящие восемь опор, пространственные фазы, ограничение изгиба и отсутствие вертикального скольжения.
static func run(ctx:SceneTree)->void:
	var rows:=Wind.placements();ctx.expect(rows.size()==8 and rows.size()<Batch.CAPACITY,"only eight existing flexible plants enter one bounded atlas")
	var phases:=[]
	for i in rows.size():
		var row:Dictionary=rows[i];var root:Vector2=Wind.Roots.world_anchor(row.kind,row.rect)
		ctx.expect(row.anchor==root and row.rect.size==Vector2(72,72),"original root and aspect preserved")
		phases.append(Batch.phase(root))
		for step in 41:
			var bend:=Batch.bend(float(step)/4,root)
			ctx.expect(absf(bend.x)<=Batch.AMPLITUDE+0.0001 and bend.y==0,"bounded horizontal motion without vertical translation")
		for j in range(i+1,rows.size()):ctx.expect(not Batch.slot(i).intersects(Batch.slot(j)),"raster slots never overlap")
	ctx.expect(phases[0]!=phases[1] and phases[6]!=phases[7],"spatial roots produce distinct deterministic phases")
	ctx.expect(Batch.bend(NAN,Vector2.ZERO)==Vector2.ZERO and Batch.bend(0,Vector2.INF)==Vector2.ZERO,"nonfinite wind is refused")
	ctx.expect(Batch.build([],Wind.Ambient.ATLAS,2).is_empty() and Batch.build(rows,Wind.Ambient.ATLAS,0).is_empty(),"invalid batches are refused")
	_game(ctx)
	_replay(ctx)

## Проверяет жизненный цикл настоящей сцены: флаги, паузу, offscreen, перенос, low и неподвижное сохранение.
static func _game(ctx:SceneTree)->void:
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0]);ctx.root.add_child(game)
	game.settings_state.reduced_motion=false;game.set_meta(&"camera_reference_zoom",1.2);game.camera_offset=Vector2(1464,378)
	var before:Dictionary=game.SaveSystem.snapshot(game)
	Wind.update(game);var initial:=Wind.statistics(game)
	ctx.expect(initial.active>0 and initial.owners==1 and initial.groups==2 and initial.builds==1,"one owner and two species groups, no per-tuft nodes")
	ctx.expect(game.SaveSystem.snapshot(game)==before,"resource preparation changes no save fields")
	for i in 20:Wind.update(game)
	ctx.expect(Wind.statistics(game)==initial,"unchanged seconds neither rebuild nor upload")
	game.menu_state.pause_open=true;var seconds:=Clock.seconds(game)
	Clock.advance(game,5);Wind.update(game)
	ctx.expect(Clock.seconds(game)==seconds and Wind.statistics(game).uploads==initial.uploads,"pause has no clock debt or GPU upload")
	game.menu_state.pause_open=false;Clock.advance(game,0.25);Wind.update(game)
	ctx.expect(Wind.statistics(game).uploads==initial.uploads+1 and Clock.seconds(game)==seconds+0.25,"resume advances only allowed delta")
	var count:=game.get_child_count();var owner:=game.get_node(Wind.NAME)
	for repeat in 4:
		game.camera_offset=Vector2(-8000,-8000);Wind.update(game)
		ctx.expect(Wind.statistics(game).active==0 and owner.batch.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"offscreen stops rendering")
		game.camera_offset=Vector2(1464,378);Wind.update(game)
		ctx.expect(Wind.statistics(game).active==initial.active and Wind.statistics(game).builds==1 and game.get_child_count()==count,"return reuses bounded resources")
		ctx.expect(owner.batch.viewport.render_target_update_mode==SubViewport.UPDATE_ONCE,"return refreshes a potentially cancelled target even when paused seconds are unchanged")
	for value in [false,17,"yes"]:
		game.set_meta(Wind.FLAG,value);Wind.update(game);ctx.expect(not Wind.allowed(game) and Wind.statistics(game).active==0,"false or malformed flag is safe")
	game.set_meta(Wind.FLAG,true)
	for mode in ["low","reduced","reference","interior","winter"]:
		game.current_location="overworld";game.day=1;game.settings_state.reduced_motion=false;game.set_meta(Wind.QUALITY,"normal")
		preload("res://scripts/presentation/visual_reference_mode.gd").disable(game)
		if mode=="low":game.set_meta(Wind.QUALITY,"low")
		elif mode=="reduced":game.settings_state.reduced_motion=true
		elif mode=="reference":preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
		elif mode=="interior":game.current_location="grandma_house"
		else:game.day=1+3*game.WorldEventSystem.DAYS_PER_SEASON
		Wind.update(game);ctx.expect(Wind.statistics(game).active==0,"fallback is inactive: "+mode)
	game.free()

## Сравнивает всю сохраняемую игру при одинаковом настоящем вводе и seed, с ветром и без него.
static func _replay(ctx:SceneTree)->void:
	var a:=Points.create_game();a._ready();ctx.root.add_child(a);Points.configure(a,Points.registry().points[0])
	var b:=Points.create_game();b._ready();ctx.root.add_child(b);Points.configure(b,Points.registry().points[0])
	for game in [a,b]:
		game.settings_state.reduced_motion=false;game.player=Vector2(1944,648);game.update_camera()
	b.set_meta(Wind.FLAG,false)
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.ZERO]:
		for tick in 8:
			for game in [a,b]:
				seed(7301+tick);game.clear_movement_keys();game.move_right_held=direction.x>0;game.move_left_held=direction.x<0;game.move_down_held=direction.y>0;game.move_up_held=direction.y<0
				game._physics_process(1.0/30);Wind.update(game)
			ctx.expect(a.SaveSystem.snapshot(a)==b.SaveSystem.snapshot(b),"wind leaves the complete deterministic gameplay replay intact")
	ctx.expect(Wind.statistics(a).builds==1 and Wind.statistics(b).owners==0,"real movement never creates per-tuft owners or disabled resources")
	a.free();b.free()
