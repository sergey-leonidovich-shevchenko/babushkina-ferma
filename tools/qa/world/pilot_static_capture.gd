extends SceneTree

const Regions:=preload("res://scripts/systems/village_region_system.gd")
const RegionData:=preload("res://scripts/systems/village_region_data.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/render_order_game.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
var folder := ""
var profile := ""
var phase := "static"
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
	if folder.is_empty() or not profile.begins_with("Codex-VRELEASE-002-") or "/" in profile or "\\" in profile or phase!="static":
		push_error("Fresh VRELEASE-002 profile/output required");quit(2);return
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
	root.title="VRELEASE-002 | Торговый декор — "+phase;root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1500);root.mode=Window.MODE_WINDOWED;await _settle(1000)
	root.size=size;root.show();root.grab_focus();await _settle(1500)
	await _shot("ordinary")
	var modules:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/reports/visual-overhaul/vart-008/modules.json"))
	board=load("res://tools/qa/world/pilot_static_scene.gd").new();board.game=game;board.data=modules;board.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for p:Dictionary in modules.parts:
		board.parts[p.id]=p
		var image:=Image.load_from_file("res://docs/reports/visual-overhaul/vart-008/native/sprites/"+p.id+".png");image.generate_mipmaps();board.textures[p.id]=ImageTexture.create_from_image(image)
	for kind in ["bench","well","cart","lamp","board","fence"]:board.legacy[kind]=load("res://assets/game/locations/overworld/modular/prop_"+kind+"_v1.png")
	board.legacy.sign=board.legacy.board
	board.legacy.market=game.WorldPolishRenderer.event_texture(0)
	var viewport:=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.size_2d_override=Vector2i(960,540);viewport.size_2d_override_stretch=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);viewport.add_child(board)
	var preview:=TextureRect.new();preview.texture=viewport.get_texture();preview.size=Vector2(1152,648);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(preview)
	for style in ["legacy","painted"]:
		board.style=style
		for variant in ["a","b"]:
			board.variant=variant
			for mode in ["front","back","bridge","grid"]:
				board.mode=mode;await _shot("study-"+style+"-"+variant+"-"+mode)
	preview.queue_free();board.queue_free();viewport.queue_free();await process_frame
	await _shot("rollback")
	if not game.BuildingSystem.enter(game,"cottage"):errors.append("normal home entry failed")
	await _shot("normal-home-enter")
	if not game.BuildingSystem.leave(game):errors.append("normal home exit failed")
	await _shot("normal-home-exit")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	var fixture_path:="user://v1-isolated.json"
	var legacy:String=FileAccess.get_file_as_string("res://tests/fixtures/saves/v1-core.json")
	FileAccess.open(fixture_path,FileAccess.WRITE).store_string(legacy)
	if not game.SaveSystem.load_at(game,fixture_path):errors.append("actual old slot load failed")
	game.title_screen=false;game.language_screen=false;game.set_physics_process(false);game.set_process(false);game.message="";game.update_camera();Pose.reset(game)
	if game.coins!=41 or game.inventory_item_count("wood")!=14 or game.inventory_item_count("apple")!=2:errors.append("old slot values changed")
	await _shot("old-slot-interior")
	if not game.BuildingSystem.leave(game):errors.append("old slot home exit failed")
	await _shot("old-slot-overworld")
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VRELEASE-002","phase":phase,"profile":profile,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"window":Points.pair(size),"performance_eligible":false,"rows":rows,"errors":errors})+"\n")
	print("STATIC PILOT CAPTURE: ",phase," ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

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
	var record:={"id":id,"window":Points.pair(DisplayServer.window_get_size()),"image":Points.pair(picture.get_size()),"logical":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"visible":root.visible,"focus_required":false,"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"location":game.current_location,"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.size(),"legacy_lamp_anchors":projected,"study":is_instance_valid(board),"locale":game.LocaleSystem.current,"minutes":game.game_minutes,"darkness":game.WorldEventSystem.darkness(game.game_minutes),"normal_effects":normal_effects,"weather":game.WorldEventSystem.weather(game)}
	rows.append(record)
	if not record.visible or record.before!=record.after or record.window!=Points.pair(size) or record.image!=Points.pair(size) or record.draws!=4:errors.append(id+": invalid native frame or changed save")
	print("STATIC PILOT FRAME ",id)

## Ожидает оконный сервер по монотонным часам без фиктивного draw.
func _settle(milliseconds: int) -> void:
	var end:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<end:game.queue_redraw();await process_frame
