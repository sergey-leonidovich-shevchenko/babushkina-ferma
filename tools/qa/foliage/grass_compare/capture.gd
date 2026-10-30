extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const ObserverGame := preload("res://tools/qa/world/render_order_game.gd")
const Field := preload("res://tools/qa/foliage/grass_compare/field.gd")
const Data := preload("res://tools/qa/foliage/grass_compare/mesh_data.gd")
const Observer := preload("res://tools/qa/foliage/grass_compare/observer.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
var folder := ""
var profile := ""
var mode := "quality"
var method := "batch"
var count := 256
var seconds := 20
var size := Vector2i(1152,648)
var game: Node
var field: Node
var observer: Node
var started_utc := 0.0
var render_values := PackedFloat64Array()
var render_count := 0
var previous_render_usec := 0
var results := []
var errors := []
var saved_before := {}

## Разделяет управляемые кадры и измерения времени, изолируя профиль до загрузки Game.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
		elif arg.begins_with("--method="): method=arg.trim_prefix("--method=")
		elif arg.begins_with("--count="): count=int(arg.trim_prefix("--count="))
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VRENDER-002-") or "/" in profile or "\\" in profile or mode not in ["quality","bench"] or method not in ["none","cpu","items","batch"] or count not in [256,1024]:
		push_error("Fresh grass comparison profile/output and valid mode required"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Готовит одну production-композицию с остановленной симуляцией и отдельным слоем за актёрами.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile) or DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Native display and fresh isolated output required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Points.create_game(); game.set_script(ObserverGame); game.world_loot_seed=Points.SEED; root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0]); WorldProjection.set_reference_zoom(game,1.2)
	game.player=Vector2(600.25,700.25); game.update_camera(); Pose.reset(game); Reference.enable(game,true)
	root.title="VRENDER-002 | "+mode+" | "+method+" | "+str(count)
	await _settle(1000); root.mode=Window.MODE_WINDOWED; await _settle(1000)
	root.size=size; root.show(); root.grab_focus(); await _settle(1000)
	if mode=="quality": await _quality(); return
	field=Field.new(); game.add_child(field); field.configure(game,method,Data.positions(game,count)); field.controlled=false
	await _redraw(20)
	root.get_texture().get_image().save_png(folder.path_join("before.png"))
	if not DisplayServer.window_is_focused() or DisplayServer.window_get_size()!=size:
		errors.append("initial host/focus mismatch"); _write("rejected.json",{"errors":errors}); quit(2); return
	_write("geometry.json",{"roots":field.roots.map(func(p: Vector2): return Points.pair(p)),"statistics":field.statistics()})
	saved_before=game.SaveSystem.snapshot(game)
	observer=Observer.new(); observer.controller=self; root.add_child(observer)
	render_values.resize(Observer.CAPACITY*4); RenderingServer.frame_post_draw.connect(_render_observed)
	create_timer(seconds+60.0).timeout.connect(_timeout)
	print("GRASS BENCH SAMPLING ",method," ",count)

## Сравнивает фиксированные фазы и реальные route/пауза/слои при одинаковых корнях всех вариантов.
func _quality() -> void:
	var roots:=Data.positions(game,256)
	for variant in ["cpu","items","batch"]:
		field=Field.new(); game.add_child(field); field.configure(game,variant,roots)
		_set_pose(Vector2(600.25,700.25))
		for index in 3:
			field.set_time([0.0,1.25,3.5][index]); await _shot(variant+"-phase-"+str(index))
		var tree:=Vector2(744,744)
		for food in game.food_nodes:
			if food.kind=="apple" and food.get("location","overworld")=="overworld": tree=food.position; break
		_set_pose(tree+Vector2(0,-20)); await _shot(variant+"-tree")
		var bush:=Vector2.ZERO
		for food in game.food_nodes:
			if food.kind=="berries" and food.get("location","overworld")=="overworld": bush=food.position; break
		_set_pose(bush+Vector2(0,8)); await _shot(variant+"-bush")
		_set_pose(game.VillageLayoutSystem.BRIDGES[0].get_center()); await _shot(variant+"-bridge")
		_set_pose(Vector2(600.25,700.25)); field.controlled=false; await _redraw(15)
		var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=true; game._unhandled_input(event)
		if not game.menu_state.pause_open: errors.append("manual pause did not open")
		var frozen:float=field.wind_time; var uploads:int=field.vertex_updates
		await _redraw(20)
		if field.wind_time!=frozen or field.vertex_updates!=uploads: errors.append("wind/upload advanced in manual pause")
		await _shot(variant+"-pause")
		game.MenuSystem.resume(game); await _redraw(15)
		if field.wind_time<=frozen: errors.append("wind did not resume")
		field.controlled=true; field.set_time(1.25)
		var builds:int=field.mesh_builds
		if not game.BuildingSystem.enter(game,"cottage"): errors.append("home entry failed")
		await _shot(variant+"-interior")
		if field.visible: errors.append("grass leaked into interior")
		if not game.BuildingSystem.leave(game): errors.append("home exit failed")
		_set_pose(Vector2(600.25,700.25)); await _shot(variant+"-returned")
		if not field.visible or field.mesh_builds!=builds: errors.append("grass lifecycle rebuilt or failed to restore")
		field.queue_free(); await process_frame
	_write("quality.json",{"task":"VRENDER-002","profile":profile,"pid":OS.get_process_id(),"display_server":DisplayServer.get_name(),"size":Points.pair(size),"results":results,"errors":errors,"performance_eligible":false})
	quit(0 if errors.is_empty() else 2)

## Снимает полный framebuffer, а snapshot-наблюдатель работает только вне benchmark.
func _shot(id: String) -> void:
	game.message=""; game.observe_draw=false; await _redraw(6)
	game.draw_records.clear(); game.observe_draw=true; await _redraw(4); game.observe_draw=false
	var image:=root.get_texture().get_image(); image.save_png(folder.path_join(id+".png"))
	_write(id+"-draws.json",game.draw_records)
	for row in game.draw_records:
		if not row.equal or not row.geometry_equal or row.queue_after!=0: errors.append(id+": gameplay/geometry/foreground changed")
	if image.get_size()!=size: errors.append(id+": actual readback size differs")
	results.append({"id":id,"location":game.current_location,"camera":Points.pair(game.camera_offset),"player":Points.pair(game.player),
		"size":Points.pair(image.get_size()),"logical":Points.pair(root.get_visible_rect().size),"statistics":field.statistics(),
		"shader_time":field.shader_material.get_shader_parameter("wind_time"),"visible":field.visible,"draws":game.draw_records.size(),"pause":game.menu_state.pause_open})
	print("GRASS SHOT ",id)

## Наблюдает границу рендера отдельно от idle и CPU update; это не GPU completion timer.
func _render_observed() -> void:
	var now:=Time.get_ticks_usec()
	if observer.warm<=120: previous_render_usec=now; return
	if observer.finished: return
	if render_count>=Observer.CAPACITY: observer.errors.append("render capacity reached"); observer.finished=true; _finish_bench.call_deferred(); return
	var offset:=render_count*4
	render_values[offset]=now; render_values[offset+1]=float(now-previous_render_usec)/1000.0
	render_values[offset+2]=Engine.get_frames_drawn(); render_values[offset+3]=Engine.get_process_frames()
	render_count+=1; previous_render_usec=now

## Завершает оба raw-журнала до readback, сохраняя все хвосты без выбора лучшего повтора.
func _finish_bench() -> void:
	var ended:=Time.get_unix_time_from_system(); field.set_process(false)
	var raw:=FileAccess.open(folder.path_join("rows.csv"),FileAccess.WRITE); raw.store_line(",".join(Observer.FIELDS))
	for row in observer.count:
		var values:=PackedStringArray()
		for col in Observer.FIELDS.size(): values.append(str(observer.values[row*Observer.FIELDS.size()+col]))
		raw.store_line(",".join(values))
	raw.close()
	raw=FileAccess.open(folder.path_join("render.csv"),FileAccess.WRITE); raw.store_line("usec,interval_ms,render_frame,process_frame")
	for row in render_count:
		var values:=PackedStringArray()
		for col in 4: values.append(str(render_values[row*4+col]))
		raw.store_line(",".join(values))
	raw.close()
	var image:=root.get_texture().get_image(); image.save_png(folder.path_join("after.png"))
	var saved_after:Dictionary=game.SaveSystem.snapshot(game)
	_write("states.json",{"before":saved_before,"after":saved_after})
	if saved_before!=saved_after: observer.errors.append("visual benchmark mutated saved gameplay")
	_write("run.json",{"task":"VRENDER-002","profile":profile,"pid":OS.get_process_id(),"method":method,"count":count,"seconds":seconds,
		"started_utc":started_utc,"ended_utc":ended,"samples":observer.count,"render_samples":render_count,"errors":observer.errors,
		"display_server":DisplayServer.get_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"engine":Engine.get_version_info().string,
		"adapter":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,
		"simulation_frozen":true,"performance_scope":"isolated visual effect; not live gameplay FPS","gpu_time_ms":null,
		"gpu_time_status":"unavailable; render submission boundary is not GPU completion","observer_buffer_bytes":Observer.CAPACITY*(Observer.FIELDS.size()+4)*8,
		"statistics":field.statistics(),"readback":Points.pair(image.get_size()),"camera":Points.pair(game.camera_offset),"focused":DisplayServer.window_is_focused()})
	quit(0 if observer.errors.is_empty() else 2)

## Не превращает сорванную серию в короткий положительный замер.
func _timeout() -> void:
	if observer!=null and not observer.finished: observer.errors.append("sampling timeout"); observer.finished=true; _finish_bench()

## Меняет только диагностическую позу; камера и фон используют штатную общую матрицу.
func _set_pose(position: Vector2) -> void:
	game.player=position; game.facing=Vector2.DOWN; game.update_camera(); Pose.reset(game)

## Запрашивает настоящие GPU-кадры вне измерений или для управляемых статичных кадров.
func _redraw(amount: int) -> void:
	for i in amount: game.queue_redraw(); await RenderingServer.frame_post_draw

## Ожидает оконную систему по монотонным часам, сохраняя фокус до начала измерений.
func _settle(milliseconds: int) -> void:
	var until:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<until: game.queue_redraw(); await RenderingServer.frame_post_draw

## Пишет результат только вне измеряемых callbacks.
func _write(name: String, data: Variant) -> void:
	FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(data)+"\n")
