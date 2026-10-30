extends SceneTree

const Points:=preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer:=preload("res://tools/qa/world/render_order_game.gd")
const Probe:=preload("res://tools/qa/world/transient_save_probe.gd")
const Reference:=preload("res://scripts/presentation/visual_reference_mode.gd")
const Clock:=preload("res://scripts/presentation/village_ground_clock.gd")
var output:=""
var profile:=""
var phase:=""
var size:=Vector2i(1152,648)
var game:Node
var rows:=[]
var errors:=[]

## Разрешает лишь свежий видимый QA-сеанс, отделённый от обычных слотов.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VCOMPAT-001-") or "/" in profile or phase not in ["before","after"] or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сравнивает обычную игру с реальными ссылками в metadata; сам slot остаётся тем же.
func _start()->void:
	DirAccess.make_dir_recursive_absolute(output)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery")
	preload("res://scripts/systems/world_projection_system.gd").set_reference_zoom(game,1.2)
	Reference.enable(game,true)
	root.title="VCOMPAT-001 | Save boundary | "+phase;root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	await _settle(1800);root.mode=Window.MODE_WINDOWED;root.size=size;await _settle(1000)
	var original:Dictionary=game.SaveSystem.snapshot(game)
	for present in [false,true]:
		if present:
			game.set_meta(&"qa_visual_payload",{"texture":game.PLANT_SHEET,"material":ShaderMaterial.new(),"canvas_rid":game.get_canvas_item(),"callback":Callable(game,"queue_redraw"),"bend":[Vector2(2,3)],"shader_time":93.25})
			game.set_meta(Clock.META,93.25)
		else:
			if game.has_meta(&"qa_visual_payload"):game.remove_meta(&"qa_visual_payload")
			game.set_meta(Clock.META,0.0)
		await _shot("metadata" if present else "plain",original)
	var result:=Probe.exercise("user://native-json-boundary.json")
	if not result.healthy_writes or result.unsafe_accepted!=(phase=="before") or not result.material_rid_valid:errors.append("writer control failed")
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VCOMPAT-001","phase":phase,"profile":profile,"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"performance_eligible":false,"rows":rows,"writer":result,"errors":errors})+"\n")
	print("TRANSIENT NATIVE: ",phase," ",rows.size()," frames; ",errors);quit(0 if errors.is_empty() else 2)

## Фиксирует два реальных draw, полный save и неизменную геометрию в каждом наблюдении.
func _shot(id:String,original:Dictionary)->void:
	game.observe_draw=false
	for i in 4:game.queue_redraw();await RenderingServer.frame_post_draw
	var before:Dictionary=game.SaveSystem.snapshot(game);game.draw_records.clear();game.observe_draw=true
	for i in 2:game.queue_redraw();await RenderingServer.frame_post_draw
	game.observe_draw=false
	var image:=root.get_texture().get_image();image.save_png(output.path_join(id+".png"))
	var data:={"id":id,"window":Points.pair(DisplayServer.window_get_size()),"image":Points.pair(image.get_size()),"logical":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"world":game.current_location,"metadata":game.has_meta(&"qa_visual_payload"),"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.duplicate(true)}
	rows.append(data)
	if data.window!=Points.pair(size) or data.image!=data.window or not data.focused or before!=original or data.after!=before or data.draws.size()!=2:errors.append(id+": frame/save/window failed")

## Ожидает только оконный сервер, не прокручивая игровую симуляцию.
func _settle(ms:int)->void:
	var until:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<until:game.queue_redraw();await process_frame
