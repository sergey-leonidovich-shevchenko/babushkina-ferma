extends "res://tools/qa/world/post_motion_capture.gd"

var physical_index:=0
var tree_ground:=Vector2.ZERO
var bush_ground:=Vector2.ZERO
var crop_ground:=Vector2.ZERO
var pair_indices:=[]

## Отделяет исходную и новую серии первой карты от обычного профиля пользователя.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VRENDER-006-") or "/" in profile or "\\" in profile or phase not in ["before","after"]:quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Проверяет настоящие растения, одинаковую глубину, постепенный проход, паузу, F12 и другие карты.
func _start()->void:
	if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Points.create_game();game.set_script(preload("res://tools/plant_depth_game.gd"));game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);WorldProjection.set_reference_zoom(game,1.2);game.WorkshopSystem.state(game,"pottery")
	game.settings_state.reduced_motion=false;game.speed=30
	var tree:Dictionary={};var bush:Dictionary={}
	for index in game.food_nodes.size():
		var food:Dictionary=game.food_nodes[index]
		if food.get("location","overworld")!="overworld":continue
		if food.kind=="apple" and tree.is_empty():tree=food
		if food.kind=="berries" and bush.is_empty():bush=food;pair_indices.append(index)
	if tree.is_empty() or bush.is_empty():errors.append("actual plants missing");quit(2);return
	tree_ground=Vector2(tree.position)+Vector2(0,18);bush_ground=game.ForageSystem.ground_anchor(bush.position)
	var twin:=bush.duplicate(true);twin.position+=Vector2(48,0);pair_indices.append(game.food_nodes.size());game.food_nodes.append(twin)
	var cell:Vector2i=game.plots.keys()[0];var plot:Dictionary=game.plots[cell]
	plot.planted=true;plot.watered=true;plot.stage=3;plot.crop_kind="carrot";plot.growth=game.CropCatalogSystem.growth_duration("carrot")*0.7;plot.stage_flash=0.0
	var crop_rect:Rect2=game.FarmVisualSystem.plot_rect(Vector2(game.FARM_ORIGIN),cell);crop_ground=Vector2(crop_rect.get_center().x,crop_rect.end.y)
	root.title="VRENDER-006 | Глубина героя и растений";root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1500);root.mode=Window.MODE_WINDOWED;await _settle(750);root.size=size;root.grab_focus();await _settle(1000);seed(Points.SEED)
	for offset in [-24.0,-6.125,-6.0,-5.875,0.0,24.0]:
		_place(tree_ground+Vector2(48,offset));await _pair("tree:"+str(offset))
	for offset in [-24.0,-6.0,0.0,24.0]:
		_place(bush_ground+Vector2(36,offset));await _pair("bush:"+str(offset))
	for offset in [-24.0,-6.0,0.0,24.0]:
		_place(crop_ground+Vector2(0,offset));await _pair("crop:"+str(offset))
	_place(bush_ground+Vector2(24,-30));await _pair("same-depth:a")
	var original:Dictionary=game.food_nodes[pair_indices[0]];game.food_nodes[pair_indices[0]]=game.food_nodes[pair_indices[1]];game.food_nodes[pair_indices[1]]=original
	await _pair("same-depth:b")
	game.food_nodes[pair_indices[1]]=game.food_nodes[pair_indices[0]];game.food_nodes[pair_indices[0]]=original
	_place(tree_ground+Vector2(48,-12));game.move_down_held=true
	for step in 24:
		var previous:Vector2=game.player;game._physics_process(1.0/30.0);Pose.present(game,0.5)
		if game.player.y<=previous.y:errors.append("real sweep blocked")
		await _pair("sweep:"+str(step))
	game.clear_movement_keys()
	for item in [["bridge-west",Vector2(864,456)],["bridge-east",Vector2(1608,960)]]:_place(item[1]);await _pair(item[0])
	_place(tree_ground+Vector2(48,-12));_key(KEY_ESCAPE);await _pair("pause");game.MenuSystem.resume(game)
	game.storage_open=true;await _pair("storage");game.storage_open=false
	_key(KEY_F12);await _pair("editor");_key(KEY_F12)
	if not game.BuildingSystem.enter(game,"cottage"):errors.append("home entry failed")
	await _pair("interior")
	if not game.BuildingSystem.leave(game):errors.append("home exit failed")
	game.player=Vector2(2232,672)
	if not Regions.travel(game,"right"):errors.append("map exit failed")
	await _pair("other-map")
	game.player=preload("res://scripts/systems/village_region_data.gd").port_position("village_market","left")
	if not Regions.travel(game,"left"):errors.append("map return failed")
	_place(tree_ground+Vector2(48,-12));await _pair("returned")
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VRENDER-006","phase":phase,"profile":profile,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"window":Points.pair(size),"performance_eligible":false,"fixed_physics_hz":30,"video_hz":10,"physical_frames":physical_index,"tree_ground":Points.pair(tree_ground),"bush_ground":Points.pair(bush_ground),"crop_ground":Points.pair(crop_ground),"rows":rows,"errors":errors})+"\n")
	print("PLANT DEPTH CAPTURE: ",phase," ",rows.size()," frames; ",errors);quit(0 if errors.is_empty() else 2)

## Сравнивает прежний путь и включённую сортировку без шага симуляции между парой.
func _pair(id:String)->void:
	game.set_meta("plant_depth_enabled",false);await _shot(id,"legacy")
	if phase=="after":game.set_meta("plant_depth_enabled",true);await _shot(id,"enabled")
	physical_index+=1

## Сохраняет два настоящих callbacks, конечную очередь и полный save вокруг отрисовки.
func _shot(id:String,mode:String)->void:
	game.message="";game.observe_draw=false
	for warm in 2:game.queue_redraw();await RenderingServer.frame_post_draw
	var before:Dictionary=game.SaveSystem.snapshot(game);game.draw_records.clear();game.depth_records.clear();game.observe_draw=true
	for draw in 2:game.queue_redraw();await RenderingServer.frame_post_draw
	game.observe_draw=false
	var subdir:="frames/"+mode;DirAccess.make_dir_recursive_absolute(folder.path_join(subdir))
	var picture:=root.get_texture().get_image();var name:=subdir+"/%04d.png"%physical_index;picture.save_png(folder.path_join(name))
	var depths:=[]
	for value in game.depth_records:
		var record:Dictionary=value.duplicate(true)
		if record.hero_ground is Vector2:record.hero_ground=Points.pair(record.hero_ground)
		depths.append(record)
	var row:={"id":id,"index":physical_index,"mode":mode,"image_file":name,"player":Points.pair(game.player),"ground":Points.pair(Pose.ground(game)),"world":game.current_location,"camera":Points.pair(game.camera_offset),"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.duplicate(true),"depths":depths,"window":Points.pair(DisplayServer.window_get_size()),"image":Points.pair(picture.get_size()),"logical":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"visible":root.visible,"pause":game.menu_state.pause_open,"storage":game.storage_open,"editor":game.LevelEditorSystem.active(game)}
	rows.append(row)
	if row.before!=row.after or row.window!=Points.pair(size) or row.image!=Points.pair(size) or not row.visible or row.draws.size()!=2:errors.append(id+": invalid native frame")
