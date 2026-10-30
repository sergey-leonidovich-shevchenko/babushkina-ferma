extends "res://tools/qa/foliage/foliage_contact_capture.gd"
const Speed:=preload("res://scripts/presentation/foliage_speed.gd")
var trace:={}

## Требует новый каталог и отдельный видимый профиль; нативная серия не выдаёт headless за графическую проверку.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VFOLIAGE-005-") or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile);_start.call_deferred()

## Сопоставляет реальные шаги при одной конечной точке и фазе ветра; отдельные проходы содержат только управляемые физические отсчёты.
func _start()->void:
	DirAccess.make_dir_recursive_absolute(output)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery");game.settings_state.reduced_motion=false;game.set_meta(&"camera_reference_zoom",1.2)
	root.title="VFOLIAGE-005 | actual step speed";root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1800);root.mode=Window.MODE_WINDOWED;root.size=size;await _settle(1000)
	var anchor:Vector2=Wind.placements()[6].anchor;_step(anchor-Vector2(16,0),Vector2.LEFT,210,1.0/60);Wind.update(game);_prepare_reference()
	for group in game.get_node(Wind.NAME).batch.groups:group.draw.connect(_group_draw.bind(group))
	var directions:=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
	for hz in [30,120]:
		for side in 4:
			for pace in [70,210,273]:
				_step(anchor+directions[side]*16,directions[side],pace,1.0/hz);await _case("rate-%d-%d-%d"%[hz,side,pace],12.0)
	for pace in [70,273]:
		for side in [0,2]:
			for step in 13:
				_step(anchor+directions[side]*(48-step*8),directions[side],pace,8.0/pace);await _case("sweep-%d-%d-%02d"%[pace,side,step],12.0)
	for pace in [70,273]:_step(anchor,Vector2.LEFT,pace,1.0/60);await _case("center-%d"%pace,12.0)
	_step(anchor-Vector2(16,0),Vector2.LEFT,273,1.0/60);game.clear_movement_keys();game._physics_process(1.0/60);Contact.Pose.present(game,1);_trace(Vector2(game.player),1.0/60,0);await _case("stop",Wind.Clock.seconds(game))
	for i in 10:Wind.update(game)
	await _case("stop-repeat",Wind.Clock.seconds(game))
	var bench:Vector2=game.workbench_position;game.workbench_position=anchor+Vector2(34,0);game.player=anchor-Vector2(16,0);Contact.Pose.reset(game);game.speed_timer=0;game.speed=210;_keys(Vector2.RIGHT)
	var origin:Vector2=game.player
	for i in 5:game._physics_process(1.0/60)
	Contact.Pose.present(game,1);_trace(origin,1.0/60,0);await _case("wall",Wind.Clock.seconds(game))
	origin=game.player;_keys(Vector2(1,1));game._physics_process(1.0/60);Contact.Pose.present(game,1);_trace(origin,1.0/60,210);await _case("slide",Wind.Clock.seconds(game));game.workbench_position=bench
	_step(anchor-Vector2(16,0),Vector2.LEFT,210,1.0/60,true);await _case("hitstop-half",12.0)
	_step(anchor-Vector2(16,0),Vector2.LEFT,273,1.0/60);await _case("pause-before",12.0);game.menu_state.pause_open=true;mode="pause"
	for i in 3:Wind.Clock.advance(game,2);await _case("pause-%d"%i,12.0)
	game.menu_state.pause_open=false;mode="normal"
	_step(anchor-Vector2(16,0),Vector2.LEFT,273,1.0/60)
	for fraction in [0.25,0.75]:Contact.Pose.present(game,fraction);await _case("interpolated-%d"%int(fraction*100),12.0)
	game.player+=Vector2(500,0);mode="jump";await _case("same-world-jump",12.0);mode="normal"
	for state in ["offscreen","return","low","reduced","reference","interior","return-again","malformed"]:
		game.current_location="overworld";game.settings_state.reduced_motion=false;game.set_meta(Wind.QUALITY,"normal");preload("res://scripts/presentation/visual_reference_mode.gd").disable(game)
		_step(anchor-Vector2(16,0),Vector2.LEFT,273,1.0/60);mode=state
		if state=="low":game.set_meta(Wind.QUALITY,"low")
		elif state=="reduced":game.settings_state.reduced_motion=true
		elif state=="reference":preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
		elif state=="interior":game.current_location="grandma_house"
		await _case(state,12.0)
	mode="normal";game.change_inventory_count(Points.Teleport.KIND,1)
	for target in ["forest","overworld"]:
		var success:=Points.Teleport.open(game) and Points.Teleport.travel(game,target)
		mode="teleport";await _case("teleport-"+target,Wind.Clock.seconds(game));rows.back().teleport_success=success
		if not success:errors.append("QA transfer failed")
	var anchors:=[]
	for row in Wind.placements():anchors.append(Points.pair(row.anchor))
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VFOLIAGE-005","profile":profile,"display":DisplayServer.get_name(),"seed":game.world_loot_seed,"anchors":anchors,"rows":rows,"snapshots":snapshots,"errors":errors,"hardware_input_accepted":false,"performance_eligible":false})+"\n")
	print("SPEED NATIVE: ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

## Применяет настоящий шаг из рассчитанной стартовой точки; ускорение273 принадлежит существующему эффекту скорости.
func _step(target:Vector2,side:Vector2,pace:int,delta:float,half:bool=false)->void:
	game.clear_movement_keys();game.speed=70.0 if pace==70 else 210.0;game.speed_timer=5.0 if pace==273 else 0.0
	var effective:=delta*0.5 if half else delta;game.player=target+side*pace*effective;Contact.Pose.reset(game);game.set_meta(Wind.Clock.META,12.0-effective)
	if half:game.FarmLifeSystem.state(game).hit_stop=delta*0.5
	_keys(-side);var origin:Vector2=game.player;game._physics_process(delta);Contact.Pose.present(game,1);_trace(origin,delta,pace)
	if game.player.distance_to(target)>0.001:errors.append("physical comparison target blocked: "+str(target))

## Сохраняет исходную точку и входной такт отдельно от фактического результата, чтобы проверка могла пересчитать скорость.
func _trace(origin:Vector2,delta:float,pace:int)->void:
	trace={"origin":Points.pair(origin),"input_delta":delta,"pace":pace,"end":Points.pair(game.player),"held":[game.move_left_held,game.move_right_held,game.move_up_held,game.move_down_held],"base_speed":game.speed}

## Задаёт удерживаемое направление для штатного движка коллизий, не назначая скорость или итог движения.
func _keys(direction:Vector2)->void:
	game.move_left_held=direction.x<0;game.move_right_held=direction.x>0;game.move_up_held=direction.y<0;game.move_down_held=direction.y>0

## Независимо умножает пространственное поле на квадрат фактически пройденной скорости; пауза сохраняет прежний кадр.
func _expected()->PackedVector2Array:
	var result:=Contact.empty()
	if not Wind.allowed(game) or Contact.Frame.read(game).is_empty():return result
	if mode=="pause":return expected.duplicate()
	var gain:=1.0;var raw:Dictionary=game.get_meta(Speed.META,{})
	if mode!="malformed" and not raw.is_empty() and raw.player==game.player and raw.world==game.current_location and raw.seconds==Wind.Clock.seconds(game):
		var velocity:Vector2=(Vector2(raw.player)-Vector2(raw.origin))/float(raw.delta);var fraction:=minf(velocity.length()/280.0,1.0);gain+=0.9*fraction*fraction
	var hero:Vector2=Contact.Pose.ground(game)
	for i in Wind.placements().size():
		var delta:Vector2=(hero-Wind.placements()[i].anchor)/36.0;var square:=delta.dot(delta)
		if square<1:result[i]=(-delta*8.0)*((1.0-square)*(1.0-square))*gain
	return result

## Снимает скорость вкл/выкл при одном состоянии; старый пространственный контакт остаётся включённым у обоих вариантов.
func _case(id:String,seconds:float)->void:
	game.camera_offset=Vector2(-8000,-8000) if mode=="offscreen" else Vector2(1464,378)
	Wind.WorldProjection.sync_background(game)
	expected=_expected();game.set_meta(Contact.FLAG,true);game.set_meta(Speed.FLAG,17 if mode=="malformed" else true);Wind.update(game)
	var owner:=game.get_node(Wind.NAME);var folder:=output.path_join(id);DirAccess.make_dir_recursive_absolute(folder)
	for i in reference_nodes.size():
		var row:Dictionary=owner.batch.rows[i];var passport:=Wind.Roots.profile(row.kind);var data:=UV.mesh_data(row.kind,72.0/passport.size.x);var phase:float=stored_phases[i]
		var amount:=Vector2(1.35*(0.78*sin(seconds*0.95+phase)+0.22*sin(seconds*1.61+phase*1.7)),0)+expected[i]
		var points:PackedVector2Array=data.arrays[Mesh.ARRAY_VERTEX];var coords:PackedVector2Array=data.arrays[Mesh.ARRAY_TEX_UV]
		for v in points.size():points[v]+=amount*pow(clampf((float(passport.lock_y)/passport.size.y-coords[v].y)/(float(passport.lock_y-passport.top)/passport.size.y),0,1),2)
		data.arrays[Mesh.ARRAY_VERTEX]=points;reference_nodes[i].mesh=UV.make_mesh(data)
	reference.render_target_update_mode=SubViewport.UPDATE_ONCE
	var variants:=[];var text:=JSON.stringify(game.SaveSystem.snapshot(game));var si:=snapshots.find(text)
	if si<0:si=snapshots.size();snapshots.append(text)
	for active in ([true] if mode=="pause" else [true,false]):
		game.set_meta(Speed.FLAG,17 if mode=="malformed" and active else active);Wind.update(game);callbacks.clear();game.draw_records.clear();game.observe_draw=true
		var stats:=Wind.statistics(game)
		for frame in 2:
			for group in owner.batch.groups:group.queue_redraw()
			game.queue_redraw();await RenderingServer.frame_post_draw
		game.observe_draw=false;var label:="on" if active else "off";owner.batch.viewport.get_texture().get_image().save_png(folder.path_join(label+".png"))
		if active or id in ["wall","rate-30-0-273","stop"]:root.get_texture().get_image().save_png(folder.path_join(label+"-window.png"))
		var draws:=[]
		for r in game.draw_records:draws.append({"before_sha":JSON.stringify(r.before).sha256_text(),"after_sha":JSON.stringify(r.after).sha256_text(),"equal":r.equal,"geometry_equal":r.geometry_equal,"frame":r.process_frame})
		variants.append({"active":active,"speed_flag":game.get_meta(Speed.FLAG),"gain":Speed.strength(game),"stats":stats,"callbacks":callbacks.duplicate(true),"draws":draws,"after_sha":JSON.stringify(game.SaveSystem.snapshot(game)).sha256_text()})
	reference.get_texture().get_image().save_png(folder.path_join("reference.png"))
	var expected_json:=[]
	for v in expected:expected_json.append(Points.pair(v))
	var raw:Dictionary=game.get_meta(Speed.META,{});var record:={}
	if not raw.is_empty():record={"world":raw.world,"player":Points.pair(raw.player),"seconds":raw.seconds,"origin":Points.pair(raw.origin),"delta":raw.delta,"velocity":Points.pair(raw.velocity),"immutable":raw.is_read_only()}
	rows.append({"id":id,"mode":mode,"seconds":seconds,"trace":trace.duplicate(true),"motion":record,"snapshot":si,"snapshot_sha":text.sha256_text(),"world":game.current_location,"player":Points.pair(game.player),"presented":Points.pair(Contact.Pose.ground(game)),"camera":Points.pair(game.camera_offset),"frame_valid":not Contact.Frame.read(game).is_empty(),"window":Points.pair(DisplayServer.window_get_size()),"logical":Points.pair(root.get_visible_rect().size),"target":Points.pair(owner.batch.viewport.size),"visible":root.visible,"focused":DisplayServer.window_is_focused(),"expected":expected_json,"variants":variants})
	var background:Node2D=game.get_node("WorldBackground");rows.back().background={"position":Points.pair(background.position),"scale":Points.pair(background.scale)}
	game.set_meta(Speed.FLAG,true);Wind.update(game)
	if not root.visible or Points.pair(DisplayServer.window_get_size())!=Points.pair(size):errors.append(id+": window invalid")
