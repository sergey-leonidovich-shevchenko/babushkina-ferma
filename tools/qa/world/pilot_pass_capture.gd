extends SceneTree

const Regions:=preload("res://scripts/systems/village_region_system.gd")
const RegionData:=preload("res://scripts/systems/village_region_data.gd")
const Points := preload("res://tools/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/pilot_pass_game.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
var folder := ""
var profile := ""
var phase := "before"
var size := Vector2i(1152,648)
var game: Node
var board: Node
var PassCode
var rows := []
var errors := []

## Отделяет проверку прохода объекта от обычных слотов пользователя.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VRENDER-005-") or "/" in profile or "\\" in profile or phase not in ["before","after"]:
		push_error("Fresh VRENDER-005 profile/output required");quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает одинаковые камеры, реальные перекрытия, паузу, дом и прежний соседний район.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder): quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0])
	preload("res://scripts/systems/world_projection_system.gd").set_reference_zoom(game,1.2)
	root.title="VRENDER-005 | Один проход объекта — "+phase;root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1500);root.mode=Window.MODE_WINDOWED;await _settle(1000)
	root.size=size;root.show();root.grab_focus();await _settle(1500)
	if phase=="after":PassCode=load("res://scripts/presentation/pilot_object_pass.gd")
	for pair in [["board-front",Vector2(648,648)],["board-back",Vector2(648,564)],["board-left",Vector2(600,612)],["board-right",Vector2(696,612)],["outside-board",Vector2(1656,600)]]:
		_place(pair[1]);await _pair(pair[0])
	var tree:=Vector2.ZERO;var bush:=Vector2.ZERO
	for food in game.food_nodes:
		if food.kind=="apple" and tree==Vector2.ZERO:tree=food.position
		if food.kind=="berries" and bush==Vector2.ZERO:bush=food.position
	if tree==Vector2.ZERO or bush==Vector2.ZERO:errors.append("actual orchard subjects missing")
	for pair in [["tree-behind",tree+Vector2(0,-20)],["tree-front",tree+Vector2(0,50)],["bush",bush+Vector2(0,8)],["bridge-west",Vector2(864,456)],["bridge-east",Vector2(1608,960)]]:
		_place(pair[1]);await _pair(pair[0])
	_place(Vector2(648,648));_key(KEY_ESCAPE)
	if not game.menu_state.pause_open:errors.append("Escape pause failed")
	await _pair("manual-pause");game.MenuSystem.resume(game)
	game.storage_open=true;await _pair("opaque-storage");game.storage_open=false
	_key(KEY_F12)
	if not game.LevelEditorSystem.active(game):errors.append("F12 open failed")
	await _pair("editor");_key(KEY_F12)
	if game.LevelEditorSystem.active(game):errors.append("F12 close failed")
	if not game.BuildingSystem.enter(game,"cottage"):errors.append("home entry failed")
	await _pair("interior")
	if not game.BuildingSystem.leave(game):errors.append("home exit failed")
	game.player=Vector2(2232,672)
	if not Regions.travel(game,"right"):errors.append("actual map transition failed")
	await _pair("other-map")
	game.player=RegionData.port_position("village_market","left")
	if not Regions.travel(game,"left"):errors.append("actual map return failed")
	_place(Vector2(648,648));await _pair("returned")
	for probe in ["invalid-source","foreign-world","foreign-layer","missing-resource","material-mismatch","inherited-material"]:
		await _pair(probe,probe)
	if game.has_meta("pilot_object_pass_enabled"):game.remove_meta("pilot_object_pass_enabled")
	await _shot("default")
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VRENDER-005","phase":phase,"profile":profile,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"window":Points.pair(size),"performance_eligible":false,"rows":rows,"errors":errors})+"\n")
	print("PILOT PASS CAPTURE: ",phase," ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

## Сохраняет реальные опору и камеру без шага симуляции.
func _place(point:Vector2)->void:
	game.player=point;game.facing=Vector2.DOWN;game.update_camera();Pose.reset(game)

## Выполняет настоящий обработчик клавиши для паузы и существующего редактора.
func _key(code:Key)->void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true
	if code==KEY_F12:game._input(event)
	else:game._unhandled_input(event)

## Сравнивает выключенный флаг и реально включённый проход при одинаковом состоянии.
func _pair(id:String,probe:String="")->void:
	game.material=CanvasItemMaterial.new() if probe=="material-mismatch" else null
	game.use_parent_material=probe=="inherited-material"
	if phase=="after" and probe in ["invalid-source","foreign-world","foreign-layer","missing-resource"]:
		var spec:Dictionary=PassCode.packet().duplicate()
		match probe:
			"invalid-source":spec.source=Rect2(-1,0,2,2)
			"foreign-world":spec.world="forest"
			"foreign-layer":spec.layer="foreground"
			"missing-resource":spec.texture=null
		spec.make_read_only();PassCode._packets[0]=spec
	game.set_meta("pilot_object_pass_enabled",false);await _shot(id+"-legacy")
	if phase=="after":game.set_meta("pilot_object_pass_enabled",true);await _shot(id+"-command")
	game.material=null;game.use_parent_material=false
	if phase=="after" and probe in ["invalid-source","foreign-world","foreign-layer","missing-resource"]:PassCode._packets.erase(0)

## Записывает настоящий кадр, четыре production callbacks и наблюдаемый атомарный fallback.
func _shot(id:String)->void:
	DisplayServer.window_move_to_foreground();root.grab_focus();await _settle(250)
	game.message="";game.observe_draw=false;Reference.enable(game,true)
	for i in 6:game.queue_redraw();await RenderingServer.frame_post_draw
	var before:Dictionary=game.SaveSystem.snapshot(game);game.draw_records.clear();game.pass_records.clear();game.observe_draw=true
	for i in 4:game.queue_redraw();await RenderingServer.frame_post_draw
	game.observe_draw=false
	var picture:=root.get_texture().get_image();picture.save_png(folder.path_join(id+".png"))
	FileAccess.open(folder.path_join(id+"-draws.json"),FileAccess.WRITE).store_string(JSON.stringify(game.draw_records)+"\n")
	FileAccess.open(folder.path_join(id+"-routes.json"),FileAccess.WRITE).store_string(JSON.stringify(game.pass_records)+"\n")
	var record:={"id":id,"window":Points.pair(DisplayServer.window_get_size()),"image":Points.pair(picture.get_size()),"logical":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"visible":root.visible,"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"location":game.current_location,"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.size(),"flag":game.get_meta("pilot_object_pass_enabled","default"),"editor":game.LevelEditorSystem.active(game),"pause":game.menu_state.pause_open,"storage":game.storage_open,"root_material":game.material!=null,"inherited_material":game.use_parent_material,"minutes":game.game_minutes,"weather":game.WorldEventSystem.weather(game)}
	rows.append(record)
	if not record.visible or record.before!=record.after or record.window!=Points.pair(size) or record.image!=Points.pair(size) or record.draws!=4:errors.append(id+": invalid native frame or changed save")
	print("PILOT PASS FRAME ",id)

## Ожидает оконный сервер по монотонным часам без фиктивного draw.
func _settle(milliseconds:int)->void:
	var end:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<end:game.queue_redraw();await process_frame
