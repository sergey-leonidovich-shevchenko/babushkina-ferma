extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Maintenance := preload("res://scripts/systems/runtime_maintenance_system.gd")
const SIZE := Vector2i(1152,648)
const FIELDS := ["usec","interval_ms","engine_frame_ms","engine_physics_ms","callback_span_ms","draw_calls","static_bytes","texture_bytes","process_frame","physics_frame","absolute_minutes","camera_x","camera_y","focused","window_x","window_y","modal","maintenance_cycles"]
const CAPACITY := 90000
var game: Node
var folder := ""
var profile := ""
var seconds := 30
var fault := ""
var before: BeforeObserver
var after: AfterObserver
var initial := {}
var started_utc := 0.0
var render_values := PackedFloat64Array()
var render_count := 0
var previous_render_usec := 0

class BeforeObserver extends Node:
	var stamp := 0
	## Отмечает начало группы idle callbacks, не вызывает игровую симуляцию вручную.
	func _process(_delta: float) -> void:
		stamp=Time.get_ticks_usec()

class AfterObserver extends Node:
	var owner_tree: SceneTree
	var warm := 0
	var count := 0
	var previous := 0
	var started := 0
	var finished := false
	var errors := []
	var values := PackedFloat64Array()
	## Измеряет настоящие callbacks; всё хранилище выделено до прогрева, readback и запись выполняются позже.
	func _process(_delta: float) -> void:
		if finished: return
		var now:=Time.get_ticks_usec()
		warm+=1
		if warm<=120:
			previous=now; started=now; return
		var g:Node=owner_tree.game
		if count==0: owner_tree.started_utc=Time.get_unix_time_from_system()
		var win:=DisplayServer.window_get_size()
		var modal:bool=g.GameLoop.modal_active(g) or g.GameLoop.gameplay_window_open(g)
		var focus:=DisplayServer.window_is_focused()
		var camera:Vector2=g.camera_offset
		var cycle:=int(owner_tree.Maintenance.statistics(g).get("cycles",0))
		var row:=[now,float(now-previous)/1000.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,float(now-owner_tree.before.stamp)/1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.MEMORY_STATIC),
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),Engine.get_process_frames(),Engine.get_physics_frames(),
			(g.day-1)*1440.0+g.game_minutes,camera.x,camera.y,1 if focus else 0,win.x,win.y,1 if modal else 0,cycle]
		for i in row.size(): values[count*row.size()+i]=float(row[i])
		count+=1; previous=now
		if not focus or win!=SIZE or modal or not g.is_processing() or not g.is_physics_processing() or g.current_location!="overworld":
			errors.append("focus/window/modal/automatic simulation changed")
		if camera.distance_to(Vector2(120.25,430.25))>0.001: errors.append("camera changed")
		if owner_tree.fault=="pause" and count==30: g.menu_state.pause_open=true
		if count>=owner_tree.CAPACITY: errors.append("sample capacity reached")
		if now-started>=owner_tree.seconds*1000000 or not errors.is_empty():
			finished=true; owner_tree.call_deferred("_finish")

## Требует явный свежий профиль, каталог и один из двух сроков протокола; headless не измеряет кадры.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--seconds="): seconds=int(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--fault="): fault=arg.trim_prefix("--fault=")
	if folder.is_empty() or not profile.begins_with("Codex-VPERF-001-") or "/" in profile or "\\" in profile or seconds not in [30,600] or fault not in ["","resize","pause"]:
		push_error("Need fresh VPERF-001 profile/output and protocol duration"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Готовит одну production-сцену, фиксированную камеру и настоящий оконный framebuffer до измерений.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg") or DirAccess.dir_exists_absolute(folder):
		push_error("Native display and fresh isolation required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	print("PERF setup create")
	game=Points.create_game(); root.add_child(game); current_scene=game
	print("PERF setup configured")
	Points.configure(game,Points.registry().points[0]); WorldProjection.set_reference_zoom(game,1.2)
	game.player=Vector2(600.25,700.25); game.update_camera(); Pose.reset(game)
	root.title="VPERF-001 | live protocol | "+str(seconds)+"s"
	await _settle(2000); root.mode=Window.MODE_WINDOWED
	await _settle(2000); root.size=SIZE; root.show(); root.grab_focus()
	await _settle(2000)
	if fault=="resize": root.size=Vector2i(960,540); await _settle(1000)
	game.queue_redraw(); await RenderingServer.frame_post_draw
	print("PERF setup readback")
	var image:=root.get_texture().get_image(); image.save_png(folder.path_join("before.png"))
	initial=_conditions(image)
	if initial.window!=Points.pair(SIZE) or initial.readback!=Points.pair(SIZE) or not initial.focused:
		FileAccess.open(folder.path_join("rejected.json"),FileAccess.WRITE).store_string(JSON.stringify({"initial":initial,"reason":"host/framebuffer mismatch or focus"})+"\n")
		quit(2); return
	game.clear_movement_keys(); game.set_process_input(false); game.set_process_unhandled_input(false)
	game.set_physics_process(true); game.set_process(true)
	before=BeforeObserver.new(); before.process_priority=-100; root.add_child(before)
	after=AfterObserver.new(); after.owner_tree=self; after.process_priority=100
	after.values.resize(CAPACITY*FIELDS.size()); render_values.resize(CAPACITY*4); root.add_child(after)
	RenderingServer.frame_post_draw.connect(_render_observed)
	create_timer(float(seconds)+60.0).timeout.connect(_timeout)
	print("PERF CONTRACT SAMPLING ",seconds,"s")

## Записывает все raw строки после измерений, затем финальный GPU-кадр и параметры; GPU время недоступно.
func _finish() -> void:
	var ended_utc:=Time.get_unix_time_from_system()
	game.set_process(false); game.set_physics_process(false)
	var raw:=FileAccess.open(folder.path_join("rows.csv"),FileAccess.WRITE)
	raw.store_line(",".join(FIELDS))
	for row in after.count:
		var parts:=PackedStringArray()
		for col in FIELDS.size(): parts.append(str(after.values[row*FIELDS.size()+col]))
		raw.store_line(",".join(parts))
	raw.close()
	var rendered:=FileAccess.open(folder.path_join("render-rows.csv"),FileAccess.WRITE)
	rendered.store_line("usec,interval_ms,render_frame,process_frame")
	for row in render_count:
		var parts:=PackedStringArray()
		for col in 4: parts.append(str(render_values[row*4+col]))
		rendered.store_line(",".join(parts))
	rendered.close()
	var image:=root.get_texture().get_image(); image.save_png(folder.path_join("after.png"))
	var result:={"schema":1,"task":"VPERF-001","profile":profile,"pid":OS.get_process_id(),"seconds":seconds,"fault":fault,
		"started_utc":started_utc,"ended_utc":ended_utc,"initial":initial,"final":_conditions(image),"samples":after.count,"errors":after.errors,
		"display_server":DisplayServer.get_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"engine":Engine.get_version_info().string,"vsync":DisplayServer.window_get_vsync_mode(),"physics_hz":Engine.physics_ticks_per_second,
		"max_fps":Engine.max_fps,"hidpi":ProjectSettings.get_setting("display/window/dpi/allow_hidpi"),"screen_scale":DisplayServer.screen_get_scale(),
		"warmup_frames":120,"zoom":WorldProjection.zoom(game),"field":Points.pair(WorldProjection.field_size(game)),"hud_zoom":1.0,
		"readback_during_samples":false,"manual_simulation":false,"disk_io_during_samples":false,"observer_buffer_bytes":CAPACITY*(FIELDS.size()+4)*8,
		"render_samples":render_count,"render_boundary":"RenderingServer.frame_post_draw; submission boundary, not GPU/present timer",
		"gpu_time_ms":null,"gpu_time_status":"unavailable; no supported GPU timer collected; never derived from CPU/frame interval",
		"camera_policy":"fixed hero/production camera; live world/time, no input or transitions","reduced_motion":game.settings_state.reduced_motion,
		"pause_on_focus_loss":game.settings_state.pause_on_focus_loss,"audio_enabled":game.audio_enabled}
	FileAccess.open(folder.path_join("run.json"),FileAccess.WRITE).store_string(JSON.stringify(result)+"\n")
	print("PERF CONTRACT COMPLETE ",after.count," rows; ",after.errors)
	quit(0 if after.errors.is_empty() else 2)

## Читает наблюдаемые размеры; логический canvas не выдаётся за физическое окно или readback.
func _conditions(image: Image) -> Dictionary:
	return {"window":Points.pair(DisplayServer.window_get_size()),"root":Points.pair(root.size),"readback":Points.pair(image.get_size()),
		"visible":Points.pair(root.get_visible_rect().size),"focused":DisplayServer.window_is_focused(),"mode":root.mode,"camera":Points.pair(game.camera_offset)}

## Неполная серия никогда не превращается в успешный короткий повтор.
func _timeout() -> void:
	if after!=null and not after.finished:
		after.errors.append("sampling timeout"); after.finished=true; _finish()

## Прогревает оконную отрисовку по монотонным часам до начала измерений.
func _settle(milliseconds: int) -> void:
	var deadline:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline: game.queue_redraw(); await RenderingServer.frame_post_draw

## Наблюдает завершённую отрисовку отдельно от idle callbacks; не читает GPU и не продвигает часы вручную.
func _render_observed() -> void:
	var now:=Time.get_ticks_usec()
	if after.warm<=120: previous_render_usec=now; return
	if after.finished: return
	if previous_render_usec>0:
		if render_count>=CAPACITY:
			after.errors.append("render sample capacity reached"); after.finished=true; _finish.call_deferred(); return
		var offset:=render_count*4
		render_values[offset]=now; render_values[offset+1]=float(now-previous_render_usec)/1000.0
		render_values[offset+2]=Engine.get_frames_drawn(); render_values[offset+3]=Engine.get_process_frames()
		render_count+=1
	previous_render_usec=now
