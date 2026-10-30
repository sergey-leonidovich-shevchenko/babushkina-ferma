extends SceneTree

const Points:=preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer:=preload("res://tools/qa/foliage/foliage_root_observer.gd")
const Board:=preload("res://tools/qa/foliage/foliage_root_board.gd")
const Ambient:=preload("res://scripts/systems/village_ambient_renderer.gd")
const Pose:=preload("res://scripts/systems/presentation_pose_system.gd")
const CASES:=["west","east","north","south","stop","wall","teleport","pause","offscreen","low"]
var output:=""
var profile:=""
var size:=Vector2i(1152,648)
var game:Node
var board:Node2D
var rows:=[]
var errors:=[]
var selected:={}
var initial:={}

## Запускает только свежий отдельный нативный профиль и не принимает headless вместо окна.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VFOLIAGE-001-") or "/" in profile or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Показывает все паспорта и обычную игру при чтении корней/без него; материалы ветра не подключает.
func _start()->void:
	DirAccess.make_dir_recursive_absolute(output)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery")
	game.set_meta(&"camera_reference_zoom",1.2);preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
	initial=game.SaveSystem.snapshot(game);selected=_select_root()
	if selected.is_empty():errors.append("no existing plant with four safe approaches");quit(2);return
	var layer:=CanvasLayer.new();layer.layer=100;root.add_child(layer);board=Board.new();layer.add_child(board);board.hide();board.prepare(output.path_join("masks"))
	root.title="VFOLIAGE-001 | Roots and masks";root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1800);root.mode=Window.MODE_WINDOWED;root.size=size;await _settle(1000)
	for page in 4:
		board.page=page;board.show();await _shot("sheet-"+str(page+1),true)
	board.hide()
	for i in CASES.size():
		var motion:=_prepare_case(CASES[i],i)
		game.query_roots=false;await _shot(CASES[i]+"-plain",false,motion)
		game.query_roots=true;await _shot(CASES[i]+"-roots",false,motion)
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VFOLIAGE-001","contract":"static-root-data-v1","hardware_input_accepted":false,"profile":profile,"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"performance_eligible":false,"selected":selected,"profiles":board.entries,"rows":rows,"errors":errors})+"\n")
	print("ROOT NATIVE: ",rows.size()," frames; ",errors);quit(0 if errors.is_empty() else 2)

## Находит уже нарисованное растение с четырьмя свободными подходами; воду или коллизию не изменяет.
func _select_root()->Dictionary:
	var candidates:=Ambient.PLACEMENTS.duplicate(true)
	for p in preload("res://scripts/systems/village_map_data.gd").FLOWERS:candidates.append({"kind":"flowers","position":p})
	for item in candidates:
		if item.kind not in ["grass","flowers"]:continue
		var anchor:Vector2=Ambient.root_anchor(item.kind,item.position);var safe:=true
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			if game.NavigationSystem.walkability_reason(game,anchor+direction*48,-1,true,false)!="walkable":safe=false
		if safe:return {"kind":item.kind,"position":[item.position.x,item.position.y],"anchor":Points.pair(anchor)}
	return {}

## Пропускает настоящий ввод через физический цикл; стена и перенос используют существующие правила.
func _prepare_case(id:String,index:int)->Dictionary:
	game.SaveSystem.apply(game,initial);game.menu_state.pause_open=false;game.settings_state.reduced_motion=false;game.clear_movement_keys();game.benchmark_autoplay=false;seed(9100+index)
	var anchor:=Vector2(selected.anchor[0],selected.anchor[1]);var side:Vector2={"west":Vector2.LEFT,"east":Vector2.RIGHT,"north":Vector2.UP,"south":Vector2.DOWN}.get(id,Vector2.LEFT)
	game.player=anchor+side*48;game.root_origin=Vector2(selected.position[0],selected.position[1])
	var direction:Vector2=-side
	if id=="wall":game.player=game.workbench_position+Vector2(0,48);direction=Vector2.UP
	elif id=="pause":game.menu_state.pause_open=true
	elif id=="offscreen":game.root_origin=Vector2(-8000,4000)
	elif id=="low":game.settings_state.reduced_motion=true
	elif id=="teleport":
		game.change_inventory_count(Points.Teleport.KIND,1)
		if not Points.Teleport.open(game) or not Points.Teleport.travel(game,"overworld"):errors.append("actual teleport refused")
	var start:Vector2=game.player;var positions:=[]
	for step in 12:
		var move:Vector2=Vector2.ZERO if id=="stop" and step>=4 else direction
		game.clear_movement_keys();game.move_left_held=move.x<0;game.move_right_held=move.x>0;game.move_up_held=move.y<0;game.move_down_held=move.y>0
		game._physics_process(1.0/30);positions.append(Points.pair(game.player))
	game.clear_movement_keys();game.update_camera();Pose.reset(game)
	return {"id":id,"direction":Points.pair(direction),"start":Points.pair(start),"positions":positions,"pause":game.menu_state.pause_open,"reduced_motion":game.settings_state.reduced_motion,"root_origin":Points.pair(game.root_origin)}

## Снимает два настоящих игровых callback и два callback витрины; полный snapshot до/после обязан совпадать.
func _shot(id:String,sheet:bool,motion:Dictionary={})->void:
	var previous_motion:bool=game.settings_state.reduced_motion
	game.settings_state.reduced_motion=true
	DisplayServer.window_move_to_foreground();root.grab_focus();await _settle(250)
	game.observe_draw=false;board.observing=false
	for i in 4:game.queue_redraw();board.queue_redraw();await RenderingServer.frame_post_draw
	var before:Dictionary=game.SaveSystem.snapshot(game);game.draw_records.clear();game.root_records.clear();board.draw_frames.clear();game.observe_draw=true;board.observing=sheet
	for i in 2:game.queue_redraw();board.queue_redraw();await RenderingServer.frame_post_draw
	game.observe_draw=false;board.observing=false
	var image:=root.get_texture().get_image();image.save_png(output.path_join(id+".png"))
	var data:={"id":id,"sheet":sheet,"static_reduced_motion":game.settings_state.reduced_motion,"window":Points.pair(DisplayServer.window_get_size()),"image":Points.pair(image.get_size()),"logical":Points.pair(root.get_visible_rect().size),"visible":root.visible,"focused":DisplayServer.window_is_focused(),"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.duplicate(true),"roots":game.root_records.duplicate(true),"board_frames":board.draw_frames.duplicate(),"motion":motion,"camera":Points.pair(game.camera_offset),"player":Points.pair(game.player),"query_roots":game.query_roots,"world":game.current_location}
	rows.append(data)
	if data.window!=Points.pair(size) or data.image!=data.window or not data.visible or data.before!=data.after or data.draws.size()!=2 or (sheet and data.board_frames.size()!=2) or (not sheet and game.query_roots and data.roots.size()!=2):errors.append(id+": native state/window/callback failed")
	game.settings_state.reduced_motion=previous_motion

## Ожидает оконный сервер без самостоятельного продвижения симуляции.
func _settle(ms:int)->void:
	var until:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<until:game.queue_redraw();await process_frame
