extends SceneTree
const Points:=preload("res://tools/visual_camera_points.gd")
const Observer:=preload("res://tools/render_order_game.gd")
const Wind:=preload("res://scripts/presentation/foliage_wind.gd")
const Batch:=preload("res://scripts/presentation/foliage_wind_batch.gd")
const UV:=preload("res://scripts/presentation/foliage_uv.gd")
var output:=""
var profile:=""
var size:=Vector2i(1152,648)
var game:Node
var reference:SubViewport
var reference_nodes:=[]
var rows:=[]
var callbacks:=[]
var snapshots:=[]
var errors:=[]
var stored_phases:=[]

## Снимает только отдельный видимый QA-профиль; не принимает headless вместо графического движка.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VFOLIAGE-003-") or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сопоставляет штатную MultiMesh-группу с независимой CPU-геометрией при тех же опорах, камере и часах.
func _start()->void:
	DirAccess.make_dir_recursive_absolute(output)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery");game.settings_state.reduced_motion=false
	game.set_meta(&"camera_reference_zoom",1.2);game.player=Vector2(1944,648);game.camera_offset=game.player-Vector2(480,270)
	root.title="VFOLIAGE-003 | fixed roots / soft wind";root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1800)
	root.mode=Window.MODE_WINDOWED;root.size=size
	await _settle(1000)
	Wind.update(game);_prepare_reference()
	for group in game.get_node(Wind.NAME).batch.groups:group.draw.connect(_group_draw.bind(group))
	for i in 49:await _case("wind-%02d"%i,float(i)/12)
	game.menu_state.pause_open=true;var pause_seconds:=Wind.Clock.seconds(game)
	for i in 3:Wind.Clock.advance(game,2);await _case("pause-%d"%i,pause_seconds)
	game.menu_state.pause_open=false
	for mode in ["offscreen","return","low","reduced","flag_off","reference","interior","return_again"]:
		game.camera_offset=Vector2(1464,378);game.current_location="overworld";game.settings_state.reduced_motion=false;game.set_meta(Wind.FLAG,true);game.set_meta(Wind.QUALITY,"normal");preload("res://scripts/presentation/visual_reference_mode.gd").disable(game)
		if mode=="offscreen":game.camera_offset=Vector2(-8000,-8000)
		elif mode=="low":game.set_meta(Wind.QUALITY,"low")
		elif mode=="reduced":game.settings_state.reduced_motion=true
		elif mode=="flag_off":game.set_meta(Wind.FLAG,false)
		elif mode=="reference":preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
		elif mode=="interior":game.current_location="grandma_house"
		await _case(mode,pause_seconds)
	for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		game.clear_movement_keys();game.player=Wind.placements()[6].anchor+side*40
		game.move_left_held=side.x>0;game.move_right_held=side.x<0;game.move_up_held=side.y>0;game.move_down_held=side.y<0
		var before:Vector2=game.player
		for i in 5:game._physics_process(1.0/30)
		await _case("approach-"+str(rows.size()),Wind.Clock.seconds(game))
		rows.back().movement={"before":Points.pair(before),"after":Points.pair(game.player),"side":Points.pair(side)}
	game.clear_movement_keys();await _case("stop",Wind.Clock.seconds(game))
	game.player=Vector2(40,120);game.move_left_held=true
	var wall_start:Vector2=game.player
	for i in 5:game._physics_process(1.0/30)
	await _case("wall",Wind.Clock.seconds(game));rows.back().movement={"before":Points.pair(wall_start),"after":Points.pair(game.player)};game.clear_movement_keys()
	game.change_inventory_count(Points.Teleport.KIND,1)
	for target in ["forest","overworld"]:
		var traveled:=Points.Teleport.open(game) and Points.Teleport.travel(game,target)
		await _case("teleport-"+target,Wind.Clock.seconds(game));rows.back().teleport_success=traveled
		if not traveled:errors.append("actual QA teleport failed")
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VFOLIAGE-003","profile":profile,"display":DisplayServer.get_name(),"seed":game.world_loot_seed,"rows":rows,"snapshots":snapshots,"errors":errors,"hardware_input_accepted":false,"performance_eligible":false})+"\n")
	print("WIND NATIVE: ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

## Даёт оконному серверу завершить отложенную смену fullscreen до фиксации DPI и размеров target.
func _settle(ms:int)->void:
	var until:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<until:game.queue_redraw();await process_frame

## Подготавливает отдельные QA-узлы, применяющие CPU-изгиб к вершинам; production оставляет два общих MultiMesh.
func _prepare_reference()->void:
	var owner:=game.get_node(Wind.NAME);var scale:int=owner.batch.scale
	reference=SubViewport.new();reference.size=owner.batch.viewport.size;reference.transparent_bg=true;reference.disable_3d=true;reference.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(reference)
	for i in Wind.placements().size():
		var row:Dictionary=Wind.placements()[i];var passport:=Wind.Roots.profile(row.kind)
		var same_kind:=0
		for j in i:
			if Wind.placements()[j].kind==row.kind:same_kind+=1
		for group in owner.batch.groups:
			if group.name==row.kind:stored_phases.append(group.multimesh.get_instance_custom_data(same_kind).r)
		var node:=MeshInstance2D.new();var parameters:=UV.parameters(row.kind,Rect2i(row.source),Vector2i(Wind.Ambient.ATLAS.get_size()))
		var mask:=ImageTexture.create_from_image(Image.create(362,362,false,Image.FORMAT_L8))
		node.material=UV.make_material(parameters,Wind.Ambient.ATLAS,mask)
		var shader:=Shader.new();shader.code=UV.ShaderSource.code.replace("render_mode unshaded;","render_mode unshaded, blend_disabled;");node.material.shader=shader
		node.material.set_shader_parameter("flexible",false)
		node.position=(Batch.slot(i).position+Vector2.ONE*Batch.PAD+Vector2(passport.root)*72.0/Vector2(passport.size))*scale
		node.scale=Vector2.ONE*scale;reference.add_child(node);reference_nodes.append(node)

## Записывает фактический draw-сигнал группы с текущим shader/uniform и custom data каждого экземпляра.
func _group_draw(group:MultiMeshInstance2D)->void:
	var phases:=[]
	for i in group.multimesh.instance_count:phases.append(group.multimesh.get_instance_custom_data(i).r)
	callbacks.append({"name":group.name,"frame":Engine.get_process_frames(),"seconds":group.material.get_shader_parameter("seconds"),"shader_sha":group.material.shader.code.sha256_text(),"instances":group.multimesh.instance_count,"phases":phases,"material_rid":str(group.material.get_rid()),"parent":group.get_parent().name})

## Сохраняет полные target и окно после реальных production draw; все сравнения состояния относятся к одному случаю.
func _case(id:String,seconds:float)->void:
	game.set_meta(Wind.Clock.META,seconds);Wind.update(game)
	var owner:=game.get_node(Wind.NAME);var stats:=Wind.statistics(game);var request:int=owner.batch.viewport.render_target_update_mode;var folder:=output.path_join(id);DirAccess.make_dir_recursive_absolute(folder)
	for i in reference_nodes.size():
		var row:Dictionary=owner.batch.rows[i];var passport:=Wind.Roots.profile(row.kind);var data:=UV.mesh_data(row.kind,72.0/passport.size.x)
		var points:PackedVector2Array=data.arrays[Mesh.ARRAY_VERTEX];var uv:PackedVector2Array=data.arrays[Mesh.ARRAY_TEX_UV];var phase:float=stored_phases[i]
		var amount:=1.35*(0.78*sin(seconds*0.95+phase)+0.22*sin(seconds*1.61+phase*1.7))
		for v in points.size():points[v].x+=amount*pow(clampf((float(passport.lock_y)/passport.size.y-uv[v].y)/(float(passport.lock_y-passport.top)/passport.size.y),0,1),2)
		data.arrays[Mesh.ARRAY_VERTEX]=points;reference_nodes[i].mesh=UV.make_mesh(data)
	reference.render_target_update_mode=SubViewport.UPDATE_ONCE
	callbacks.clear();game.draw_records.clear();game.observe_draw=true
	var text:=JSON.stringify(game.SaveSystem.snapshot(game));var snapshot_index:=snapshots.find(text)
	if snapshot_index<0:snapshot_index=snapshots.size();snapshots.append(text)
	for frame in 2:
		for group in owner.batch.groups:group.queue_redraw()
		game.queue_redraw();await RenderingServer.frame_post_draw
	game.observe_draw=false
	owner.batch.viewport.get_texture().get_image().save_png(folder.path_join("atlas.png"));reference.get_texture().get_image().save_png(folder.path_join("reference.png"))
	root.get_texture().get_image().save_png(folder.path_join("window.png"))
	var draws:=[]
	for record in game.draw_records:draws.append({"equal":record.equal,"geometry_equal":record.geometry_equal,"before_sha":JSON.stringify(record.before).sha256_text(),"after_sha":JSON.stringify(record.after).sha256_text(),"frame":record.process_frame})
	var entry:={"id":id,"seconds":seconds,"ticks_usec":Time.get_ticks_usec(),"stats":stats,"callbacks":callbacks.duplicate(true),"draws":draws,"snapshot":snapshot_index,"snapshot_sha":text.sha256_text(),"after_sha":JSON.stringify(game.SaveSystem.snapshot(game)).sha256_text(),"world":game.current_location,"window":Points.pair(DisplayServer.window_get_size()),"target":Points.pair(owner.batch.viewport.size),"logical":Points.pair(root.get_visible_rect().size),"visible":root.visible,"focused":DisplayServer.window_is_focused(),"camera":Points.pair(game.camera_offset),"player":Points.pair(game.player)}
	rows.append(entry)
	entry.target_update_request=request
	if entry.snapshot_sha!=entry.after_sha or draws.size()!=2 or not root.visible or entry.window!=Points.pair(size):errors.append(id+": state/window/draw failure")
