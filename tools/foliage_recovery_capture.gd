extends "res://tools/foliage_contact_capture.gd"
const Recovery:=preload("res://scripts/presentation/foliage_recovery.gd")
var audit:=[]
var oracle:=Contact.empty()
var oracle_seconds:=-1.0
var oracle_player:=Vector2.INF

## Требует новый каталог и отдельный нативный профиль без доступа к пользовательским слотам.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VFOLIAGE-006-") or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile);_start.call_deferred()

## Снимает четыре прохода и хвосты восстановления; физические отсчёты не выдаются за аппаратный ввод или замер FPS.
func _start()->void:
	DirAccess.make_dir_recursive_absolute(output)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery");game.settings_state.reduced_motion=false;game.set_meta(&"camera_reference_zoom",1.2)
	root.title="VFOLIAGE-006 | soft plant recovery";root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1800);root.mode=Window.MODE_WINDOWED;root.size=size;await _settle(1000)
	_prime();_prepare_reference()
	for group in game.get_node(Wind.NAME).batch.groups:group.draw.connect(_group_draw.bind(group))
	var anchor:Vector2=Wind.placements()[6].anchor;var sides:=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
	for side in 4:
		game.player=anchor+sides[side]*48;Contact.Pose.reset(game);game.clear_movement_keys();Contact.Frame.publish(game,1.0/30);_sample(true)
		await _case("sweep-%d-00"%side,Wind.Clock.seconds(game))
		_keys(-sides[side]);game.speed_timer=5.0 if side==0 else 0.0
		for tick in range(1,49):
			game._physics_process(1.0/30);Contact.Pose.present(game,1);_sample()
			if tick in [4,8,12,16,20,24,30,38,48]:await _case("sweep-%d-%02d"%[side,tick],Wind.Clock.seconds(game))
	_prime();await _case("stop",Wind.Clock.seconds(game));await _case("stop-repeat",Wind.Clock.seconds(game))
	game.menu_state.pause_open=true;mode="pause"
	for i in 3:game._physics_process(1.0/30);Wind.Clock.advance(game,2);_sample();await _case("pause-%d"%i,Wind.Clock.seconds(game))
	game.menu_state.pause_open=false;mode="normal";game._physics_process(1.0/30);_sample();await _case("resume",Wind.Clock.seconds(game))
	var bench:Vector2=game.workbench_position;_prime();game.workbench_position=anchor+Vector2(34,0);_keys(Vector2.RIGHT)
	for i in 5:game._physics_process(1.0/60);Contact.Pose.present(game,1);_sample()
	await _case("wall",Wind.Clock.seconds(game));game.workbench_position=bench
	for state in ["offscreen","return","low","reduced","reference","interior","jump","invalid-frame","rollback","malformed"]:
		_prime();mode=state
		if state=="low":game.set_meta(Wind.QUALITY,"low")
		elif state=="reduced":game.settings_state.reduced_motion=true
		elif state=="reference":preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
		elif state=="interior":game.current_location="grandma_house"
		elif state=="jump":game.player+=Vector2(500,0);Contact.Frame.publish(game,1.0/60)
		elif state=="invalid-frame":game.remove_meta(Contact.Frame.META)
		elif state=="rollback":game.set_meta(Recovery.FLAG,false)
		elif state=="malformed":game.set_meta(Recovery.FLAG,17)
		_sample();await _case(state,Wind.Clock.seconds(game))
	_prime();game.change_inventory_count(Points.Teleport.KIND,1)
	for target in ["forest","overworld"]:
		var success:=Points.Teleport.open(game) and Points.Teleport.travel(game,target);mode="teleport";_sample();await _case("teleport-"+target,Wind.Clock.seconds(game));rows.back().teleport_success=success
		if not success:errors.append("QA transfer failed")
	var anchors:=[]
	for row in Wind.placements():anchors.append(Points.pair(row.anchor))
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VFOLIAGE-006","profile":profile,"display":DisplayServer.get_name(),"seed":game.world_loot_seed,"anchors":anchors,"rows":rows,"audit":audit,"snapshots":snapshots,"errors":errors,"hardware_input_accepted":false,"performance_eligible":false})+"\n")
	print("RECOVERY NATIVE: ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

## Готовит контакт остановившегося героя; исходная позиция и сброс принадлежат только QA-фикстуре.
func _prime()->void:
	mode="normal";game.menu_state.pause_open=false;game.current_location="overworld";game.settings_state.reduced_motion=false;game.set_meta(Wind.QUALITY,"normal");game.set_meta(Recovery.FLAG,true);preload("res://scripts/presentation/visual_reference_mode.gd").disable(game)
	game.player=Wind.placements()[6].anchor-Vector2(16,0);game.speed=210;game.speed_timer=0;game.clear_movement_keys();Contact.Pose.reset(game);Contact.Frame.publish(game,1.0/60);_sample(true)
	for i in 12:game._physics_process(1.0/60);Contact.Pose.present(game,1);_sample()

## Задаёт удерживаемые направления штатному движку движения и коллизий.
func _keys(direction:Vector2)->void:
	game.move_left_held=direction.x<0;game.move_right_held=direction.x>0;game.move_up_held=direction.y<0;game.move_down_held=direction.y>0

## Независимо пересчитывает поле и экспоненту, записывая все промежуточные отсчёты, включая не снятые в PNG.
func _sample(reset:bool=false)->void:
	game.camera_offset=Vector2(-8000,-8000) if mode=="offscreen" else Vector2(1464,378);Wind.WorldProjection.sync_background(game)
	var owner:=game.get_node_or_null(Wind.NAME)
	if reset:
		if owner!=null:owner.recovery.clear()
		oracle=Contact.empty();oracle_seconds=-1;oracle_player=Vector2.INF
	Wind.update(game);owner=game.get_node(Wind.NAME)
	var seconds:=Wind.Clock.seconds(game);var desired:=Contact.empty();var valid:=Wind.allowed(game) and not Contact.Frame.read(game).is_empty()
	var motion:Dictionary=game.get_meta(Contact.Speed.META,{});var gain:=1.0
	if not motion.is_empty() and motion.player==game.player and motion.seconds==seconds and motion.world==game.current_location:
		gain+=0.9*pow(minf((Vector2(motion.player)-Vector2(motion.origin)).length()/float(motion.delta)/280.0,1.0),2)
	if valid:
		for i in Wind.placements().size():
			var offset:=(Contact.Pose.ground(game)-Vector2(Wind.placements()[i].anchor))/36.0;var square:=offset.dot(offset)
			if square<1:desired[i]=-offset*8.0*(1.0-square)*(1.0-square)*gain
	var flag:Variant=game.get_meta(Recovery.FLAG,true);var disabled:bool=typeof(flag)!=TYPE_BOOL or not flag
	var elapsed:=maxf(0,seconds-oracle_seconds) if oracle_seconds>=0 else 0.0
	var jump:=oracle_player.is_finite() and Vector2(game.player).distance_to(oracle_player)>maxf(8,720*elapsed)
	if not valid or disabled or seconds<oracle_seconds or jump:
		oracle=Contact.empty();oracle_seconds=-1;oracle_player=Vector2.INF;elapsed=0
	if valid and not disabled:
		for i in 64:
			if i not in owner.visible_rows:oracle[i]=Vector2.ZERO;continue
			var tau:=0.18 if desired[i].length_squared()<oracle[i].length_squared() else 0.08
			if elapsed>0:oracle[i]=desired[i]+(oracle[i]-desired[i])*exp(-elapsed/tau)
			if desired[i]==Vector2.ZERO and oracle[i].length()<=0.005:oracle[i]=Vector2.ZERO
		oracle_seconds=seconds;oracle_player=game.player
	expected=desired.duplicate() if valid and disabled else oracle.duplicate()
	for i in 64:
		if expected[i].distance_to(owner.render_contacts[i])>0.00001:errors.append("oracle mismatch %d:%d"%[audit.size(),i])
	var raw:=[];var actual:=[];var filtered:=[]
	for i in 8:raw.append(Points.pair(desired[i]));actual.append(Points.pair(owner.render_contacts[i]));filtered.append(Points.pair(expected[i]))
	var step:={}
	if not motion.is_empty():step={"origin":Points.pair(motion.origin),"player":Points.pair(motion.player),"delta":motion.delta,"world":motion.world,"seconds":motion.seconds,"velocity":Points.pair(motion.velocity)}
	audit.append({"reset":reset,"valid":valid,"seconds":seconds,"player":Points.pair(game.player),"presented":Points.pair(Contact.Pose.ground(game)),"world":game.current_location,"mode":mode,"flag":flag,"visible":owner.visible_rows.duplicate(),"raw":raw,"actual":actual,"expected":filtered,"active":owner.recovery.entries.size(),"motion":step})

## Сравнивает фильтр и технический откат при одном состоянии; после пары возвращает точное исходное состояние фильтра.
func _case(id:String,seconds:float)->void:
	var owner:=game.get_node(Wind.NAME);var folder:=output.path_join(id);DirAccess.make_dir_recursive_absolute(folder)
	for i in reference_nodes.size():
		var row:Dictionary=owner.batch.rows[i];var passport:=Wind.Roots.profile(row.kind);var data:=UV.mesh_data(row.kind,72.0/passport.size.x);var phase:float=stored_phases[i]
		var amount:=Vector2(1.35*(0.78*sin(seconds*0.95+phase)+0.22*sin(seconds*1.61+phase*1.7)),0)+expected[i]
		var points:PackedVector2Array=data.arrays[Mesh.ARRAY_VERTEX];var coords:PackedVector2Array=data.arrays[Mesh.ARRAY_TEX_UV]
		for v in points.size():points[v]+=amount*pow(clampf((float(passport.lock_y)/passport.size.y-coords[v].y)/(float(passport.lock_y-passport.top)/passport.size.y),0,1),2)
		data.arrays[Mesh.ARRAY_VERTEX]=points;reference_nodes[i].mesh=UV.make_mesh(data)
	reference.render_target_update_mode=SubViewport.UPDATE_ONCE
	var state:=[owner.recovery.entries.duplicate(),owner.recovery.last_seconds,owner.recovery.last_player,owner.recovery.last_world];var original:Variant=game.get_meta(Recovery.FLAG,true)
	var text:=JSON.stringify(game.SaveSystem.snapshot(game));var si:=snapshots.find(text)
	if si<0:si=snapshots.size();snapshots.append(text)
	var variants:=[]
	for active in ([true] if mode=="pause" else [true,false]):
		game.set_meta(Recovery.FLAG,original if active else false);Wind.update(game);callbacks.clear();game.draw_records.clear();game.observe_draw=true;var stats:=Wind.statistics(game)
		for frame in 2:
			for group in owner.batch.groups:group.queue_redraw()
			game.queue_redraw();await RenderingServer.frame_post_draw
		game.observe_draw=false;var label:="on" if active else "off";owner.batch.viewport.get_texture().get_image().save_png(folder.path_join(label+".png"))
		if active:root.get_texture().get_image().save_png(folder.path_join("window.png"))
		var draws:=[]
		for r in game.draw_records:draws.append({"before_sha":JSON.stringify(r.before).sha256_text(),"after_sha":JSON.stringify(r.after).sha256_text(),"equal":r.equal,"geometry_equal":r.geometry_equal,"frame":r.process_frame})
		variants.append({"active":active,"flag":game.get_meta(Recovery.FLAG),"stats":stats,"callbacks":callbacks.duplicate(true),"draws":draws,"after_sha":JSON.stringify(game.SaveSystem.snapshot(game)).sha256_text()})
	reference.get_texture().get_image().save_png(folder.path_join("reference.png"))
	var background:Node2D=game.get_node("WorldBackground")
	rows.append({"id":id,"sample":audit.size()-1,"seconds":seconds,"mode":mode,"world":game.current_location,"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"background":{"position":Points.pair(background.position),"scale":Points.pair(background.scale)},"snapshot":si,"snapshot_sha":text.sha256_text(),"window":Points.pair(DisplayServer.window_get_size()),"logical":Points.pair(root.get_visible_rect().size),"target":Points.pair(owner.batch.viewport.size),"visible":root.visible,"focused":DisplayServer.window_is_focused(),"variants":variants})
	game.set_meta(Recovery.FLAG,original);owner.recovery.entries=state[0];owner.recovery.last_seconds=state[1];owner.recovery.last_player=state[2];owner.recovery.last_world=state[3];Wind.update(game)
	if not root.visible or Points.pair(DisplayServer.window_get_size())!=Points.pair(size):errors.append(id+": invalid window")
