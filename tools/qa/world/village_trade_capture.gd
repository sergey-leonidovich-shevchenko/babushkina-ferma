extends SceneTree

const Regions:=preload("res://scripts/systems/village_region_system.gd")
const RegionData:=preload("res://scripts/systems/village_region_data.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/render_order_game.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
var folder := ""
var profile := ""
var phase := "before"
var size := Vector2i(1152,648)
var game: Node
var board: Node
var rows := []
var errors := []

## Отделяет торговую нативную проверку от обычных слотов пользователя.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VPROP-007-") or "/" in profile or "\\" in profile or phase not in ["before","after"]:
		push_error("Fresh VPROP-007 profile/output required");quit(2);return
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
	root.title="VPROP-007 | Торговый декор — "+phase;root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1500);root.mode=Window.MODE_WINDOWED;await _settle(1000)
	root.size=size;root.show();root.grab_focus();await _settle(1500)
	game.state.world.estate.event="market"
	game.world_loot_nodes=game.world_loot_nodes.filter(func(c):return c.location!="overworld")
	var slots:Array=game.LootContainerSystem.SPAWNS[0].positions
	for i in slots.size():game.world_loot_nodes.append({"id":900+i,"kind":"sack","location":"overworld","position":slots[i],"opened":false,"contents":{"seeds":2,"coins":3}})
	for offset in [Vector2(0,72),Vector2(0,-12),Vector2(-80,12),Vector2(80,12)]:
		game.player=Vector2(1128,720)+offset;game.update_camera();Pose.reset(game)
		await _shot("market-"+str(int(offset.x))+"-"+str(int(offset.y)))
	for i in slots.size():
		game.player=slots[i]+Vector2(0,48);game.update_camera();Pose.reset(game)
		await _shot("sack-"+str(i)+"-closed")
		var index:int=game.world_loot_nodes.size()-slots.size()+i
		if not game.LootContainerSystem.open(game,index):errors.append("actual sack open failed")
		await _shot("sack-"+str(i)+"-opened")
	for event in ["festival","traveler","raid"]:
		game.state.world.estate.event=event;game.game_minutes=1200
		game.player=game.VillageEventSystem.POSITIONS[event]+Vector2(0,90);game.update_camera();Pose.reset(game)
		await _shot("event-"+event+"-control")
	game.state.world.estate.event="market";game.game_minutes=600
	for pair in [["shop-control",Vector2(1416,624)],["sale-control",Vector2(1512,624)],["bridge-west",Vector2(864,456)],["bridge-east",Vector2(1608,960)]]:
		game.player=pair[1];game.update_camera();Pose.reset(game);await _shot(pair[0])
	game.player=Vector2(1128,792);game.update_camera();Pose.reset(game)
	var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;game._unhandled_input(key)
	await _shot("manual-pause");game.MenuSystem.resume(game)
	if not game.BuildingSystem.enter(game,"cottage"):errors.append("home entry failed")
	await _shot("interior")
	if not game.BuildingSystem.leave(game):errors.append("home exit failed")
	game.player=Vector2(2232,672)
	if not Regions.travel(game,"right"):errors.append("market transition failed")
	await _shot("market-control")
	game.player=RegionData.port_position("village_market","left")
	if not Regions.travel(game,"left"):errors.append("return transition failed")
	game.player=Vector2(1128,792);game.update_camera();Pose.reset(game);await _shot("returned")
	if phase=="after":
		board=load("res://tools/qa/world/village_trade_gallery.gd").new();board.game=game;root.add_child(board)
		for kind in ["stall","crate","barrel","sack"]:
			board.kind=kind
			for background in ["light","dark","grass","evening"]:
				board.background=background;await _shot("gallery-"+kind+"-"+background)
		board.queue_free();await process_frame
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VPROP-007","phase":phase,"profile":profile,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"window":Points.pair(size),"performance_eligible":false,"rows":rows,"errors":errors})+"\n")
	print("TRADE CAPTURE: ",phase," ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

## Записывает настоящий кадр и четыре наблюдаемых вызова без изменения сохранённого мира.
func _shot(id: String, normal_effects: bool=false) -> void:
	DisplayServer.window_move_to_foreground();root.grab_focus();await _settle(250)
	game.message="";game.observe_draw=false
	if normal_effects:Reference.disable(game)
	else:Reference.enable(game,true)
	if is_instance_valid(board):board.observe=false
	for i in 6:
		game.queue_redraw()
		if is_instance_valid(board):board.queue_redraw()
		await RenderingServer.frame_post_draw
	var before:Dictionary=game.SaveSystem.snapshot(game);game.draw_records.clear();game.observe_draw=true
	if is_instance_valid(board):board.records.clear();board.observe=true
	for i in 4:
		game.queue_redraw()
		if is_instance_valid(board):board.queue_redraw()
		await RenderingServer.frame_post_draw
	game.observe_draw=false
	if is_instance_valid(board):
		board.observe=false
		FileAccess.open(folder.path_join(id+"-gallery-draws.json"),FileAccess.WRITE).store_string(JSON.stringify(board.records)+"\n")
	var picture:=root.get_texture().get_image();picture.save_png(folder.path_join(id+".png"))
	FileAccess.open(folder.path_join(id+"-draws.json"),FileAccess.WRITE).store_string(JSON.stringify(game.draw_records)+"\n")
	var projected:=[]
	for prop in game.VillageLayoutSystem.PROP_PLACEMENTS:
		if prop.kind=="lamp":projected.append(Points.pair(prop.position-game.camera_offset))
	var record:={"id":id,"window":Points.pair(DisplayServer.window_get_size()),"image":Points.pair(picture.get_size()),"logical":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"visible":root.visible,"focus_required":false,"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"location":game.current_location,"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.size(),"legacy_lamp_anchors":projected,"locale":game.LocaleSystem.current,"minutes":game.game_minutes,"darkness":game.WorldEventSystem.darkness(game.game_minutes),"normal_effects":normal_effects,"weather":game.WorldEventSystem.weather(game)}
	rows.append(record)
	if not record.visible or record.before!=record.after or record.window!=Points.pair(size) or record.image!=Points.pair(size) or record.draws!=4:errors.append(id+": invalid native frame or changed save")
	print("TRADE FRAME ",id)

## Ожидает оконный сервер по монотонным часам без фиктивного draw.
func _settle(milliseconds: int) -> void:
	var end:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<end:game.queue_redraw();await process_frame
