extends "res://tools/reference_zoom_capture.gd"

const WARM_FRAMES := 120
const SAMPLE_FRAMES := 240
var observer: LiveObserver

class LiveObserver extends Node:
	var game: Node
	var owner_tree: SceneTree
	var warm := 0
	var previous_usec := 0
	var samples := []
	var faults := []
	var completed := false
	## Наблюдает настоящий idle после production _process; часы и физические callbacks не назначаются вручную.
	func _process(_delta: float) -> void:
		if completed: return
		var now:=Time.get_ticks_usec()
		warm+=1
		if warm<=120: previous_usec=now; return
		var interval:=float(now-previous_usec)/1000.0; previous_usec=now
		var value:Dictionary=game.get_meta("presentation_pose",{})
		var current_ground:Vector2=game.AnimationRenderer.player_ground(game)
		var window:=DisplayServer.window_get_size()
		var focused:=DisplayServer.window_is_focused()
		if not focused or interval<=0 or value.is_empty() or not game.is_physics_processing() or not game.is_processing(): faults.append("focus/clock/automatic callbacks "+str(samples.size()))
		samples.append({"index":samples.size(),"usec":now,"interval_ms":interval,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
			"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
			"player":Points.pair(game.player),"ground":Points.pair(current_ground),"camera":Points.pair(game.camera_offset),"minutes":game.game_minutes,
			"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"interpolation":Engine.get_physics_interpolation_fraction(),
			"focused":focused,"window":Points.pair(window),"mode":DisplayServer.window_get_mode(),"automatic_physics":game.is_physics_processing(),"automatic_render":game.is_processing(),
			"visible":Points.pair(game.get_viewport_rect().size),"location":game.current_location,"paused":game.GameLoop.modal_active(game) or game.GameLoop.gameplay_window_open(game)})
		if samples.size()<240: return
		completed=true; owner_tree.call_deferred("_finish_live")

## Готовит нативное окно и прогревает обычную видимую игру; никаких GPU-readback в измеряемых callbacks.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or probe or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg") or DirAccess.dir_exists_absolute(folder):
		push_error("Live timing needs native focused window and new profile/output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Points.create_game(); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0]); WorldProjection.set_reference_zoom(game,amount); game.update_camera()
	root.title="VCAMERA-006 live timing | "+str(roundi(amount*100))+"%"
	await _settle(2000); root.mode=Window.MODE_WINDOWED; root.show()
	await _settle(2000); root.size=requested; root.grab_focus(); await _settle(2000)
	var image:=root.get_texture().get_image()
	initial={"window":Points.pair(DisplayServer.window_get_size()),"root":Points.pair(root.size),"readback":Points.pair(image.get_size()),"focused":DisplayServer.window_is_focused(),"mode":root.mode}
	if DisplayServer.window_get_size()!=requested or image.get_size()!=requested or not DisplayServer.window_is_focused(): push_error("Live initial window/readback/focus"); quit(2); return
	Points.configure(game,Points.registry().points[0]); WorldProjection.set_reference_zoom(game,amount)
	game.player=Vector2(600.25,700.25); game.speed=18; game.update_camera(); Pose.reset(game)
	game.set_process_input(true); game.set_process_unhandled_input(true)
	_key(KEY_D,true); _key(KEY_S,true)
	game.set_physics_process(true); game.set_process(true)
	observer=LiveObserver.new(); observer.game=game; observer.owner_tree=self; observer.process_priority=100; root.add_child(observer)
	create_timer(120.0).timeout.connect(_live_timeout)

## Фиксирует итоговое изображение только после последней измеренной строки, затем освобождает собственный процесс.
func _finish_live() -> void:
	game.set_physics_process(false); game.set_process(false); game.clear_movement_keys()
	game.queue_redraw(); await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var end_state:={"readback":Points.pair(image.get_size()),"window":Points.pair(DisplayServer.window_get_size()),"focused":DisplayServer.window_is_focused(),"mode":root.mode}
	if image.get_size()!=requested or not DisplayServer.window_is_focused(): observer.faults.append("final readback/focus")
	image.save_png(folder.path_join("after-measurement.png"))
	var report:={"schema":1,"task":"VCAMERA-006","kind":"zoom-live-timing","performance_eligible":true,
		"gpu_readback_during_samples":false,"manual_simulation":false,"warmup_frames":WARM_FRAMES,"sample_frames":SAMPLE_FRAMES,
		"profile":profile,"pid":OS.get_process_id(),"zoom":amount,"requested":Points.pair(requested),"initial":initial,"final":end_state,
		"samples":observer.samples,"errors":observer.faults,"inputs":sent,"physics_hz":Engine.physics_ticks_per_second,"max_fps":Engine.max_fps,
		"vsync_mode":DisplayServer.window_get_vsync_mode(),"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"screen_scale":DisplayServer.screen_get_scale(),"hidpi":ProjectSettings.get_setting("display/window/dpi/allow_hidpi"),
		"field":Points.pair(WorldProjection.field_size(game)),"world_zoom":WorldProjection.zoom(game),"hud_zoom":1.0,
		"memory_note":"Observed engine counters, not resident VRAM; zero texture counter means unsupported/unknown"}
	FileAccess.open(folder.path_join("timing.json"),FileAccess.WRITE).store_string(JSON.stringify(report)+"\n")
	print("LIVE ZOOM: ",observer.samples.size()," rows; ",observer.faults)
	quit(0 if observer.faults.is_empty() else 2)

## Не превращает недостающие кадры в удачную короткую серию.
func _live_timeout() -> void:
	if observer!=null and not observer.completed:
		observer.faults.append("live sample timeout"); observer.completed=true; _finish_live()
