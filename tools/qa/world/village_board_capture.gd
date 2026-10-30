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

## Отделяет нативный просмотр фонарей от обычных слотов пользователя.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VPROP-006-") or "/" in profile or "\\" in profile or phase not in ["before","after"]:
		push_error("Fresh VPROP-006 profile/output required");quit(2);return
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
	root.title="VPROP-006 | Фонарь и свечение — "+phase;root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1500);root.mode=Window.MODE_WINDOWED;await _settle(1000)
	root.size=size;root.show();root.grab_focus();await _settle(1500)
	for point in [Vector2(648,576),Vector2(1656,528)]:
		for offset in [Vector2(0,62),Vector2(0,-10),Vector2(-60,12),Vector2(60,12)]:
			game.player=point+offset;game.facing=Vector2.DOWN;game.update_camera();Pose.reset(game)
			await _shot("board-"+str(int(point.x))+"-"+str(int(offset.x))+"-"+str(int(offset.y)))
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale,false)
		for link in RegionData.passages("overworld"):
			game.player=link.position+RegionData.INWARD[link.port]*80;game.update_camera();Pose.reset(game)
			await _shot("sign-"+String(link.port)+"-"+locale)
	game.LocaleSystem.set_locale("ru",false)
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
	await _shot("returned")
	game.player=Vector2(336,1020);game.update_camera();Pose.reset(game);await _shot("fence-control")
	if phase=="after":
		board=load("res://tools/qa/world/village_board_gallery.gd").new();board.game=game;root.add_child(board)
		for kind in ["board","sign"]:
			board.kind=kind
			for background in ["light","dark","grass","evening"]:
				board.background=background;await _shot("gallery-"+kind+"-"+background)
		board.queue_free();await process_frame
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VPROP-006","phase":phase,"profile":profile,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"window":Points.pair(size),"performance_eligible":false,"rows":rows,"errors":errors})+"\n")
	print("BOARD CAPTURE: ",phase," ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

## Записывает настоящий кадр и четыре наблюдаемых вызова без изменения сохранённого мира.
func _shot(id: String, normal_effects: bool=false) -> void:
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
	var record:={"id":id,"window":Points.pair(DisplayServer.window_get_size()),"image":Points.pair(picture.get_size()),"logical":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"location":game.current_location,"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.size(),"lamp_anchors":projected,"locale":game.LocaleSystem.current,"minutes":game.game_minutes,"darkness":game.WorldEventSystem.darkness(game.game_minutes),"normal_effects":normal_effects,"weather":game.WorldEventSystem.weather(game)}
	rows.append(record)
	if not record.focused or record.before!=record.after or record.window!=Points.pair(size) or record.image!=Points.pair(size) or record.draws!=4:errors.append(id+": invalid native frame or changed save")
	print("BOARD FRAME ",id)

## Ожидает оконный сервер по монотонным часам без фиктивного draw.
func _settle(milliseconds: int) -> void:
	var end:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<end:game.queue_redraw();await process_frame
