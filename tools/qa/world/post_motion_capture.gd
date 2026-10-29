extends SceneTree

const Points:=preload("res://tools/visual_camera_points.gd")
const Observer:=preload("res://tools/qa/world/post_motion_game.gd")
const Pose:=preload("res://scripts/systems/presentation_pose_system.gd")
const WorldProjection:=preload("res://scripts/systems/world_projection_system.gd")
const Clock:=preload("res://scripts/presentation/village_ground_clock.gd")
const Regions:=preload("res://scripts/systems/village_region_system.gd")
var folder:=""
var profile:=""
var phase:="before"
var size:=Vector2i(1152,648)
var game:Node
var frame_code
var probe:ContactProbe
var rows:=[]
var errors:=[]
var root_point:=Vector2.ZERO

class ContactProbe extends Node2D:
	## Отдельный QA-пучок имеет неподвижный корень; uniform изгибает только вершины.
	func _draw()->void:
		for x in [-7,0,7]:draw_colored_polygon(PackedVector2Array([Vector2(x-2,0),Vector2(x,-24),Vector2(x+2,0)]),Color("b2cf71"))
		draw_circle(Vector2.ZERO,2,Color("ffd36d"))

## Требует собственный профиль и новую папку, не открывая сохранения пользователя.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VRENDER-008-") or "/" in profile or "\\" in profile or phase not in ["before","after"]:quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Проходит прежнюю первую карту и существующие переходы; фиксированный шаг не измеряет FPS.
func _start()->void:
	if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):quit(2);return
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);WorldProjection.set_reference_zoom(game,1.2)
	game.settings_state.reduced_motion=false;game.speed=90
	# Existing interior status lazily initializes this default; prepare the same empty state before either route.
	game.WorkshopSystem.state(game,"pottery")
	if phase=="after":frame_code=load("res://scripts/presentation/post_motion_frame.gd")
	root.title="VRENDER-008 | Время и контакт после движения";root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1500);root.mode=Window.MODE_WINDOWED;await _settle(750);root.size=size;root.grab_focus();await _settle(1000)
	probe=ContactProbe.new();probe.z_index=100;root.add_child(probe)
	var shader:=Shader.new();shader.code="shader_type canvas_item; uniform vec2 contact; void vertex(){ VERTEX.xy -= contact * 10.0 * max(0.0,-VERTEX.y/24.0); }"
	var mat:=ShaderMaterial.new();mat.shader=shader;probe.material=mat
	seed(Points.SEED)
	_place(Vector2(696,696));root_point=game.player+Vector2(12,0);game.move_right_held=true
	await _steps("walk",8)
	var wall:=_wall();_place(wall);root_point=wall+Vector2(0,64);game.move_down_held=true
	await _steps("wall",8)
	var tree:=Vector2.ZERO;var bush:=Vector2.ZERO
	for food in game.food_nodes:
		if food.kind=="apple" and tree==Vector2.ZERO:tree=food.position
		if food.kind=="berries" and bush==Vector2.ZERO:bush=food.position
	for item in [["tree",tree+Vector2(0,-20)],["bush",bush+Vector2(0,8)],["bridge-west",Vector2(864,456)],["bridge-east",Vector2(1608,960)]]:
		_place(item[1]);root_point=game.player+Vector2(10,0);await _steps(item[0],2)
	_place(Vector2(696,696));root_point=game.player+Vector2(10,0);await _steps("returned",2)
	_key(KEY_ESCAPE);await _steps("pause",4);game.MenuSystem.resume(game)
	game.inventory_open=true;await _steps("inventory",2);game.inventory_open=false
	_key(KEY_F12);await _steps("editor",2);_key(KEY_F12)
	game.player=game.BuildingSystem.BUILDINGS.cottage.door;game.location_transition_armed=true;game.location_transition_cooldown=0
	await _steps("interior",2)
	if game.current_location!="cottage_interior":errors.append("actual door entry failed")
	if not game.BuildingSystem.leave(game):errors.append("actual door exit failed")
	game.player=Vector2(2232,672);game.location_transition_armed=true;game.location_transition_cooldown=0
	await _steps("other-map",2)
	if game.current_location!="village_market":errors.append("actual map transition failed")
	game.player=preload("res://scripts/systems/village_region_data.gd").port_position("village_market","left")
	if not Regions.travel(game,"left"):errors.append("map return failed")
	_place(Vector2(696,696));root_point=game.player+Vector2(10,0);await _steps("returned",2)
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VRENDER-008","phase":phase,"profile":profile,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"window":Points.pair(size),"performance_eligible":false,"fixed_physics_hz":30,"video_hz":10,"rows":rows,"errors":errors})+"\n")
	print("POST MOTION CAPTURE: ",phase," ",rows.size()," frames; ",errors);quit(0 if errors.is_empty() else 2)

## Находит настоящий сплошной участок ограды и его последнюю проходимую точку без подмены коллизий.
func _wall()->Vector2:
	for rect in game.BuildingSystem.farm_fence_rects():
		for distance in range(1,65):
			var p:=Vector2(rect.get_center().x,rect.position.y-distance)
			if game.is_position_walkable(p) and not game.is_position_walkable(p+Vector2(0,3)):return p
	errors.append("no genuine fence wall");return Vector2(40,696)

## Не интерполирует перестановку QA-сцены, оставляя физику каждого шага настоящему callback игры.
func _place(point:Vector2)->void:
	game.clear_movement_keys();game.player=point;game.facing=Vector2.DOWN;game.update_camera();Pose.reset(game)

## Использует настоящие обработчики ручной паузы и F12.
func _key(code:Key)->void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true
	if code==KEY_F12:game._input(event)
	else:game._unhandled_input(event)

## Сохраняет результат коллизий, реальный uniform, пару callbacks и полный save вокруг draw.
func _steps(id:String,count:int)->void:
	for tick in count:
		var start:Vector2=game.player;var start_world:String=game.current_location;var start_seconds:=Clock.seconds(game)
		game._physics_process(1.0/30.0);Pose.present(game,0.5)
		var contact:Vector2=Pose.root_contact(game,root_point,32) if phase=="before" else frame_code.contact(game,root_point,32)
		var packet:Dictionary={}
		if phase=="after":
			var value:Dictionary=frame_code.read(game)
			if not value.is_empty():packet={"world":value.world,"player_world":Points.pair(value.player_world),"seconds":value.seconds,"active":value.active,"read_only":value.is_read_only()}
		probe.visible=game.current_location=="overworld" and not game.LevelEditorSystem.active(game);probe.position=WorldProjection.world_to_screen(game,root_point);probe.scale=Vector2.ONE*WorldProjection.zoom(game)
		probe.material.set_shader_parameter("contact",contact);probe.queue_redraw();game.message=""
		var before:Dictionary=game.SaveSystem.snapshot(game);game.draw_records.clear();game.observe_draw=true
		for draw in 2:game.queue_redraw();await RenderingServer.frame_post_draw
		game.observe_draw=false
		var picture:=root.get_texture().get_image();var name:="frames/%04d.png"%rows.size();picture.save_png(folder.path_join(name))
		var row:={"id":id,"tick":tick,"index":rows.size(),"image_file":name,"start":Points.pair(start),"start_world":start_world,"start_seconds":start_seconds,"player":Points.pair(game.player),"ground":Points.pair(Pose.ground(game)),"world":game.current_location,"seconds":Clock.seconds(game),"camera":Points.pair(game.camera_offset),"root":Points.pair(root_point),"radius":32,"contact":Points.pair(contact),"shader_contact":Points.pair(probe.material.get_shader_parameter("contact")),"packet":packet,"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.duplicate(true),"window":Points.pair(DisplayServer.window_get_size()),"image":Points.pair(picture.get_size()),"logical":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"visible":root.visible,"pause":game.menu_state.pause_open,"inventory":game.inventory_open,"editor":game.LevelEditorSystem.active(game),"input":Points.pair(game.get_movement_direction())}
		rows.append(row)
		if row.before!=row.after or row.window!=Points.pair(size) or row.image!=Points.pair(size) or not row.visible or row.draws.size()!=2:errors.append(id+": invalid native frame")
	print("POST MOTION CASE ",id)

## Ожидает оконный сервер, сохраняя активную симуляцию выключенной вне заданных тактов.
func _settle(milliseconds:int)->void:
	var end:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<end:game.queue_redraw();await process_frame
