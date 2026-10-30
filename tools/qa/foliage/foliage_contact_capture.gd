extends "res://tools/qa/foliage/foliage_wind_capture.gd"
const Contact:=preload("res://scripts/presentation/foliage_contact.gd")
var expected:=Contact.empty()
var mode:="normal"

## Запускает отдельный видимый профиль контакта, сохраняя старые QA-инструменты ветра без изменения.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VFOLIAGE-004-") or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile);_start.call_deferred()

## Снимает контролируемые проходы, настоящее движение, точный центр, паузу, стену и штатный перенос без пользовательских слотов.
func _start()->void:
	DirAccess.make_dir_recursive_absolute(output)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery");game.settings_state.reduced_motion=false;game.set_meta(&"camera_reference_zoom",1.2)
	root.title="VFOLIAGE-004 | hero contact / fixed roots";root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1800);root.mode=Window.MODE_WINDOWED;root.size=size;await _settle(1000)
	var anchor:Vector2=Wind.placements()[6].anchor;_position(anchor+Vector2(48,0));Wind.update(game);_prepare_reference()
	for group in game.get_node(Wind.NAME).batch.groups:group.draw.connect(_group_draw.bind(group))
	var directions:=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
	for side in 4:
		for step in 13:
			_position(anchor+directions[side]*(48-step*8));await _case("sweep-%d-%02d"%[side,step],Wind.Clock.seconds(game))
	_position(anchor);await _case("center",Wind.Clock.seconds(game))
	for i in 3:await _case("stop-%d"%i,Wind.Clock.seconds(game))
	_position(anchor-Vector2(8,0));var pose:=Contact.Pose.reset(game);pose.previous=anchor-Vector2(24,0)
	for fraction in [0.25,0.75]:
		Contact.Pose.present(game,fraction);await _case("interpolated-"+str(int(fraction*100)),Wind.Clock.seconds(game))
	_position(anchor-Vector2(12,0));await _case("pause-before",Wind.Clock.seconds(game));game.menu_state.pause_open=true;mode="pause"
	for i in 3:
		Wind.Clock.advance(game,2);await _case("pause-%d"%i,Wind.Clock.seconds(game))
	game.menu_state.pause_open=false;mode="normal"
	for side in 4:
		_position(anchor+directions[side]*40);game.clear_movement_keys();game.move_left_held=directions[side].x>0;game.move_right_held=directions[side].x<0;game.move_up_held=directions[side].y>0;game.move_down_held=directions[side].y<0
		for step in 4:
			game._physics_process(1.0/30);Contact.Pose.present(game,1.0);await _case("physics-%d-%d"%[side,step],Wind.Clock.seconds(game))
	game.clear_movement_keys();game._physics_process(1.0/30);await _case("physical-stop",Wind.Clock.seconds(game))
	_position(Vector2(40,120));game.move_left_held=true
	for i in 5:game._physics_process(1.0/30)
	await _case("wall",Wind.Clock.seconds(game));game.clear_movement_keys()
	for state in ["offscreen","return","low","reduced","reference","interior","return-again"]:
		game.current_location="overworld";game.settings_state.reduced_motion=false;game.set_meta(Wind.QUALITY,"normal");preload("res://scripts/presentation/visual_reference_mode.gd").disable(game);mode=state
		_position(anchor-Vector2(12,0))
		if state=="offscreen":game.camera_offset=Vector2(-8000,-8000)
		elif state=="low":game.set_meta(Wind.QUALITY,"low")
		elif state=="reduced":game.settings_state.reduced_motion=true
		elif state=="reference":preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
		elif state=="interior":game.current_location="grandma_house"
		await _case(state,Wind.Clock.seconds(game))
	mode="normal";game.change_inventory_count(Points.Teleport.KIND,1)
	for target in ["forest","overworld"]:
		var success:=Points.Teleport.open(game) and Points.Teleport.travel(game,target)
		mode="teleport";await _case("teleport-"+target,Wind.Clock.seconds(game));rows.back().teleport_success=success
		if not success:errors.append("QA teleport failed")
	var anchors:=[]
	for row in Wind.placements():anchors.append(Points.pair(row.anchor))
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VFOLIAGE-004","profile":profile,"display":DisplayServer.get_name(),"seed":game.world_loot_seed,"anchors":anchors,"rows":rows,"snapshots":snapshots,"errors":errors,"hardware_input_accepted":false,"performance_eligible":false})+"\n")
	print("CONTACT NATIVE: ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

## Публикует допустимый физический кадр; не заменяет реальные движения теста физики или аппаратную клавиатуру.
func _position(point:Vector2)->void:
	game.player=point;Contact.Pose.reset(game);Contact.Frame.publish(game,1.0/120);game.camera_offset=Vector2(1464,378)

## Вычисляет независимое ожидаемое поле по видимой стопе; пауза сохраняет прежнюю реакцию, невалидный кадр даёт ноль.
func _expected()->PackedVector2Array:
	var result:=Contact.empty()
	if not Wind.allowed(game) or Contact.Frame.read(game).is_empty():return result
	if mode=="pause":return expected.duplicate()
	var hero:Vector2=Contact.Pose.ground(game)
	for i in Wind.placements().size():
		var delta:Vector2=(hero-Wind.placements()[i].anchor)/36.0;var square:=delta.dot(delta)
		if square<1:result[i]=(-delta*8.0)*((1.0-square)*(1.0-square))
	return result

## Записывает настоящие GPU-индексы и числовой буфер каждого материала дополнительно к прежним draw-сигналам.
func _group_draw(group:MultiMeshInstance2D)->void:
	super._group_draw(group)
	var slots:=[];var values:=[]
	for i in group.multimesh.instance_count:slots.append(group.multimesh.get_instance_custom_data(i).g)
	for point in group.material.get_shader_parameter("contact_bends"):values.append(Points.pair(point))
	callbacks.back().slots=slots;callbacks.back().contacts=values

## Сравнивает on/off при одном snapshot и камере, а on — с отдельно деформированной CPU-сеткой.
func _case(id:String,seconds:float)->void:
	game.camera_offset=Vector2(-8000,-8000) if mode=="offscreen" else Vector2(1464,378)
	expected=_expected();game.set_meta(Contact.FLAG,true);Wind.update(game)
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
		game.set_meta(Contact.FLAG,active);Wind.update(game);callbacks.clear();game.draw_records.clear();game.observe_draw=true
		var stats:=Wind.statistics(game)
		for frame in 2:
			for group in owner.batch.groups:group.queue_redraw()
			game.queue_redraw();await RenderingServer.frame_post_draw
		game.observe_draw=false
		var label:="on" if active else "off";owner.batch.viewport.get_texture().get_image().save_png(folder.path_join(label+".png"))
		if active or id in ["center","pause-before","return"]:root.get_texture().get_image().save_png(folder.path_join(label+"-window.png"))
		var draws:=[]
		for r in game.draw_records:draws.append({"before_sha":JSON.stringify(r.before).sha256_text(),"after_sha":JSON.stringify(r.after).sha256_text(),"equal":r.equal,"geometry_equal":r.geometry_equal,"frame":r.process_frame})
		variants.append({"active":active,"stats":stats,"callbacks":callbacks.duplicate(true),"draws":draws,"after_sha":JSON.stringify(game.SaveSystem.snapshot(game)).sha256_text()})
	reference.get_texture().get_image().save_png(folder.path_join("reference.png"))
	var expected_json:=[]
	for v in expected:expected_json.append(Points.pair(v))
	rows.append({"id":id,"mode":mode,"seconds":seconds,"snapshot":si,"snapshot_sha":text.sha256_text(),"world":game.current_location,"player":Points.pair(game.player),"presented":Points.pair(Contact.Pose.ground(game)),"camera":Points.pair(game.camera_offset),"frame_valid":not Contact.Frame.read(game).is_empty(),"window":Points.pair(DisplayServer.window_get_size()),"logical":Points.pair(root.get_visible_rect().size),"target":Points.pair(owner.batch.viewport.size),"visible":root.visible,"focused":DisplayServer.window_is_focused(),"expected":expected_json,"variants":variants})
	game.set_meta(Contact.FLAG,true);Wind.update(game)
	if not root.visible or Points.pair(DisplayServer.window_get_size())!=Points.pair(size):errors.append(id+": window invalid")
