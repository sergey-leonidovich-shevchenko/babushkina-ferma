extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Observer := preload("res://tools/render_order_game.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
var folder := ""
var profile := ""
var size := Vector2i(1152,648)
var game: Node
var results := []
var errors := []
var probes := []
var tree_position := Vector2.ZERO
var tree_key := ""

## Изолирует обычные слоты до загрузки сцены; эта съёмка не измеряет производительность.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VRENDER-004-") or "/" in profile or "\\" in profile:
		push_error("Fresh isolated VRENDER-004 profile/output required"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сравнивает исходные и наблюдаемые команды на девяти случаях при двух физических размерах окна.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Native display and fresh output required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	print("OBJECT COMMAND INIT scene; pid=",OS.get_process_id())
	game=Points.create_game(); game.set_script(Observer); game.world_loot_seed=Points.SEED; root.add_child(game); current_scene=game
	print("OBJECT COMMAND INIT scene ready")
	Points.configure(game,Points.registry().points[0]); WorldProjection.set_reference_zoom(game,1.2)
	root.title="VRENDER-004 | Проверка команды объекта — закроется автоматически"
	root.mode=Window.MODE_WINDOWED; root.size=size; root.show(); root.grab_focus()
	print("OBJECT COMMAND INIT window shown; focused=",DisplayServer.window_is_focused())
	await _settle(1500); root.mode=Window.MODE_WINDOWED
	await _settle(1000); root.size=size; root.show(); root.grab_focus(); await _settle(1500)
	await _case("village",Vector2(600.25,700.25))
	for food in game.food_nodes:
		if food.kind=="apple" and food.get("location","overworld")=="overworld": tree_position=food.position; break
	if tree_position==Vector2.ZERO: errors.append("actual orchard tree missing")
	tree_key=game.TreeOcclusion.key_for("orchard_apple",tree_position)
	await _case("tree-behind",tree_position+Vector2(0,-20))
	await _case("tree-front",tree_position+Vector2(0,50))
	var bush:=Vector2.ZERO
	for food in game.food_nodes:
		if food.kind=="berries" and food.get("location","overworld")=="overworld": bush=food.position; break
	if bush==Vector2.ZERO: errors.append("actual berry bush missing")
	await _case("bush",bush+Vector2(0,8))
	await _case("bridge",Layout.BRIDGES[0].get_center())
	var key:=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true; game._unhandled_input(key)
	if not game.menu_state.pause_open: errors.append("Escape did not open manual pause")
	await _pair("manual-pause")
	game.MenuSystem.resume(game)
	game.storage_open=true; await _pair("opaque-storage"); game.storage_open=false
	if not game.BuildingSystem.enter(game,"cottage"): errors.append("real home entry failed")
	await _pair("interior")
	if not game.BuildingSystem.leave(game): errors.append("real home exit failed")
	await _case("returned",Vector2(600.25,700.25))
	await _probes()
	var report:={"task":"VRENDER-004","profile":profile,"pid":OS.get_process_id(),"display_server":DisplayServer.get_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(),"engine":Engine.get_version_info().string,
		"simulation_frozen":true,"performance_eligible":false,"gpu_time_ms":null,"production_pass_enabled":false,"probe_size":[256,224],"probes":probes,"requested_size":Points.pair(size),"cases":results,"errors":errors}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report)+"\n")
	print("RENDER ORDER CAPTURE: ",results.size()," cases; ",errors)
	quit(0 if errors.is_empty() else 2)

## Ставит одну фиксированную композицию; следующий draw не двигает героя, камеру или игровые часы.
func _case(id: String, player: Vector2) -> void:
	game.player=player; game.facing=Vector2.DOWN; game.update_camera(); Pose.reset(game)
	await _pair(id)

## Проверяет полный snapshot на настоящих draw callbacks и сохраняет пары GPU-кадров.
func _pair(id: String) -> void:
	game.message=""; Reference.enable(game,true); game.observe_draw=false
	await _redraw(8)
	var saved:Dictionary=game.SaveSystem.snapshot(game)
	var before:=root.get_texture().get_image(); before.save_png(folder.path_join(id+"-baseline.png"))
	var packet:Dictionary=preload("res://scripts/presentation/world_workbench_visual_system.gd").command(game.workbench_position+Vector2(0,24))
	if packet.is_empty(): errors.append(id+": real bench descriptor missing")
	game.draw_records.clear(); game.observe_draw=true
	await _redraw(4); game.observe_draw=false
	var after:=root.get_texture().get_image(); after.save_png(folder.path_join(id+"-observed.png"))
	FileAccess.open(folder.path_join(id+"-draws.json"),FileAccess.WRITE).store_string(JSON.stringify(game.draw_records)+"\n")
	if game.draw_records.size()<4: errors.append(id+": no real draw callbacks")
	for record in game.draw_records:
		if not record.equal or not record.geometry_equal or record.queue_after!=0: errors.append(id+": draw mutated gameplay or left foreground queue")
	var bg:Node=game.get_node("WorldBackground")
	var tree_entry:Dictionary=game.get_meta("tree_occlusion_frame",{}).get("entries",{}).get(tree_key,{})
	if id in ["tree-behind","tree-front"] and tree_entry.is_empty(): errors.append(id+": actual tree was not submitted")
	var record:={"id":id,"location":game.current_location,"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),
		"snapshot_before":saved,"snapshot_after":game.SaveSystem.snapshot(game),"zoom":WorldProjection.zoom(game),"window":Points.pair(DisplayServer.window_get_size()),"readback":Points.pair(after.get_size()),
		"visible":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"pause":game.menu_state.pause_open,
		"storage":game.storage_open,"draws":game.draw_records.size(),"root_material_null":game.material==null,
		"background_material_null":bg.material==null,"background_behind_parent":bg.show_behind_parent,
		"terrain_ready":bg.terrain_ready,"terrain_size":Points.pair(bg.terrain_viewport.size),"terrain_material_null":bg.terrain_canvas.material==null,
		"tree_position":Points.pair(tree_position),"tree_key":tree_key,"tree_alpha":tree_entry.get("alpha",1.0)}
	results.append(record)
	if before.get_size()!=size or after.get_size()!=size or DisplayServer.window_get_size()!=size: errors.append(id+": physical size mismatch")
	print("RENDER CASE ",id," ",record.draws)

## Сравнивает один изолированный QA-узел с прежними командами, не подключая новый проход к игре.
func _probes() -> void:
	var canvas:=preload("res://tools/qa/world/object_command_canvas.gd").new();canvas.game=game
	var target:=SubViewport.new();target.disable_3d=true;target.transparent_bg=true;target.size=Vector2i(256,224)
	target.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(target);target.add_child(canvas)
	for id in ["south","west","east","source-region","translucent","shader","material-mismatch","invalid-source","foreign-world","foreign-layer","missing-resource"]:
		var direction:int={"west":1,"east":3}.get(id,0)
		var spec:Dictionary=preload("res://scripts/presentation/world_workbench_visual_system.gd").command(Vector2(128.25,176.5),direction).duplicate()
		if id=="source-region":
			spec.texture=preload("res://assets/game/environment/forest_tree_growth_atlas_v1.png")
			spec.source=Rect2(768,0,256,256);spec.bounds=Rect2(48.25,16.5,160,192)
		if id=="translucent": spec.modulate=Color(0.8,1,0.9,0.34)
		if id=="shader":
			var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){ COLOR *= vec4(0.8,0.9,1.0,1.0); }"
			var shader_material:=ShaderMaterial.new();shader_material.shader=shader;spec.material=shader_material
		canvas.observe=false;canvas.packet=preload("res://scripts/presentation/object_draw_command.gd").create(spec)
		canvas.submitted=canvas.packet;canvas.material=spec.material;canvas.scope_world="overworld";canvas.scope_layer="behind_actors"
		if id in ["invalid-source","missing-resource","material-mismatch"]:
			canvas.submitted=spec.duplicate()
			if id=="invalid-source": canvas.submitted.source=Rect2(-1,0,5,5)
			elif id=="missing-resource": canvas.submitted.texture=null
			else: canvas.submitted.material=CanvasItemMaterial.new()
		if id=="foreign-world":canvas.scope_world="cottage_interior"
		if id=="foreign-layer":canvas.scope_layer="foreground"
		var witnesses:=[]
		for legacy in [true,false]:
			canvas.observe=false;canvas.legacy=legacy
			for i in 4:canvas.queue_redraw();await RenderingServer.frame_post_draw
			canvas.records.clear();canvas.observe=true
			for i in 4:canvas.queue_redraw();await RenderingServer.frame_post_draw
			canvas.observe=false
			var suffix:="legacy" if legacy else "command"
			target.get_texture().get_image().save_png(folder.path_join("probe-"+id+"-"+suffix+".png"))
			FileAccess.open(folder.path_join("probe-"+id+"-"+suffix+"-draws.json"),FileAccess.WRITE).store_string(JSON.stringify(canvas.records)+"\n")
			witnesses.append(canvas.records.size())
		probes.append({"id":id,"packet":canvas.describe(canvas.packet),"draws":witnesses,"expected":"fallback" if id in ["material-mismatch","invalid-source","foreign-world","foreign-layer","missing-resource"] else "command"})
		print("OBJECT COMMAND PROBE ",id)
	canvas.observe=false;target.queue_free();await process_frame

## Ожидает действительную отрисовку; не подменяет её ручным вызовом renderer вне draw.
func _redraw(count: int) -> void:
	for i in count:
		game.queue_redraw(); await RenderingServer.frame_post_draw

## Даёт оконному серверу завершить первоначальное размещение окна по монотонным часам.
func _settle(milliseconds: int) -> void:
	var deadline:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline: game.queue_redraw(); await process_frame
