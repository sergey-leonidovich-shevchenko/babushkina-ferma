extends SceneTree

const Scene := preload("res://main.tscn")
const Village := preload("res://scripts/systems/village_map_data.gd")
const Pacing := preload("res://scripts/systems/render_pacing_system.gd")
const SIZE := Vector2i(1152,648)
const SEED := 20261015
const WARMUP := 120
const KEYS := [KEY_A,KEY_D,KEY_W,KEY_S]
var game: Node
var folder := ""
var profile := ""
var repeat := 0
var fault := ""
var route: Array[Vector2] = []
var checkpoints: Array = []
var index := 0
var ticks := 0
var measuring := false
var held := {}
var terrain_draws := 0
var faults := []
var setup_states := []

## Изолирует профиль до создания игровых служб и измерительного интервала.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--repeat="): repeat=int(arg.trim_prefix("--repeat="))
		elif arg.begins_with("--fault="): fault=arg.trim_prefix("--fault=")
	if folder.is_empty() or not profile.begins_with("Codex-VBASE-001-") or "/" in profile or "\\" in profile:
		push_error("Нужны --output и отдельный --profile=Codex-VBASE-001-..."); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Создаёт живую сцену в единственном оконном viewport без дополнительной композиции SubViewport.
func _start() -> void:
	if DisplayServer.get_name()=="headless": push_error("VBASE требует нативную графику"); quit(2); return
	if not OS.get_user_data_dir().ends_with(profile): push_error("Профиль не изолирован"); quit(2); return
	if FileAccess.file_exists("user://farm-settings.cfg") or FileAccess.file_exists("user://farm-save.json"):
		push_error("Повтор требует свежий профиль"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	root.title="VBASE-001 · контролируемый маршрут"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	seed(SEED)
	game=Scene.instantiate(); game.world_loot_seed=SEED; game.set_meta("capture_windowed",true)
	root.add_child(game); current_scene=game; game.set_physics_process(false)
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.settings_state.pause_on_focus_loss=false
	game.settings_state.fullscreen_enabled=false; game.settings_state.vsync_enabled=true
	game.settings_state.reduced_motion=false; game.settings_state.high_contrast=false
	game.settings_state.text_scale=1.0; game.settings_state.touch_scale=1.0
	game.settings_state.screen_shake_enabled=false
	game.InputSystem.apply_control_preset("standard")
	game.AudioSystem.set_enabled(game,true); game.LocaleSystem.set_locale("ru",false)
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
	game.FarmLifeSystem.state(game).first_day=6
	game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).cutscene_timer=0.0
	game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true
	game.current_location="overworld"; game.player=Village.START; game.day=1; game.game_minutes=360.0
	game.benchmark_autoplay=false; game.message=""; game.discovery_current.clear()
	game.clear_movement_keys(); game.sync_background_location(); game.update_camera()
	Pacing.apply(); root.grab_focus()
	game.get_node("WorldBackground").terrain_canvas.draw.connect(func(): terrain_draws+=1)
	_build_route()
	# macOS завершает fullscreen асинхронно: не посылаем сотни повторных переключений.
	await create_timer(2.0).timeout
	setup_states.append(_conditions())
	root.mode=Window.MODE_WINDOWED
	await create_timer(2.0).timeout
	root.size=SIZE; root.grab_focus()
	await create_timer(2.0).timeout
	setup_states.append(_conditions())
	for frame in WARMUP:
		game.queue_redraw(); await RenderingServer.frame_post_draw
	var initial := _conditions()
	print("VBASE WINDOW: ",JSON.stringify(initial))
	var start_image := root.get_texture().get_image()
	var start_pixels := _point(start_image.get_size())
	start_image.save_png(folder.path_join("start.png"))
	if not initial.valid or start_pixels!=_point(SIZE):
		FileAccess.open(folder.path_join("setup-rejected.json"),FileAccess.WRITE).store_string(JSON.stringify({"conditions":initial,"setup_states":setup_states,"readback":start_pixels},"\t"))
		push_error("Начальные окно/framebuffer/фокус не соответствуют preset"); quit(2); return
	for frame in 8:
		game.queue_redraw(); await RenderingServer.frame_post_draw
	await _measure(initial,start_pixels)

## Берёт ортогональные точки действующей дороги и возвращается тем же путём к дому.
func _build_route() -> void:
	var outward: Array[Vector2] = []
	for point in Village.routes()[0]:
		if outward.is_empty() and Vector2(point)!=Vector2(648,672): continue
		outward.append(point)
		if Vector2(point)==Vector2(1320,744): break
	route.assign(outward)
	for i in range(outward.size()-2,-1,-1): route.append(outward[i])
	route.append(Village.START)

## Ведёт героя штатными обработчиками клавиш и коллизиями; позиция внутри замера не присваивается.
func _drive() -> void:
	if not measuring: return
	ticks+=1
	if index>=route.size(): return
	var difference: Vector2=route[index]-game.player
	if difference.length()<=4.0:
		checkpoints.append({"index":index,"tick":ticks,"position":_point(game.player),"target":_point(route[index]),"minutes":game.game_minutes})
		index+=1
		if index>=route.size():
			for code in KEYS: _key(code,false)
			return
		difference=route[index]-game.player
	_key(KEY_A,difference.x < -1.5); _key(KEY_D,difference.x > 1.5)
	_key(KEY_W,difference.y < -1.5); _key(KEY_S,difference.y > 1.5)

## Посылает только переход клавиши, без накопления одинаковых событий в каждом физическом тике.
func _key(code: Key, pressed: bool) -> void:
	if held.get(code,false)==pressed: return
	held[code]=pressed
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	game._input(event)

## Читает дешёвые размеры viewport и окна; копирование пикселей выполняется только вне интервала.
func _conditions() -> Dictionary:
	var window:=DisplayServer.window_get_size()
	var texture:=root.get_texture().get_size()
	var focused:=DisplayServer.window_is_focused()
	var mode:=DisplayServer.window_get_mode()
	var vsync:=DisplayServer.window_get_vsync_mode()
	return {"window":_point(window),"framebuffer":_point(texture),"root_size":_point(root.size),"focused":focused,"mode":mode,"vsync":vsync,
		"valid":window==SIZE and Vector2i(texture)==SIZE and root.size==SIZE and focused and mode==DisplayServer.WINDOW_MODE_WINDOWED and vsync==DisplayServer.VSYNC_ENABLED}

## Сохраняет все интервалы отрисовки, включая рывки, и доказывает продвижение мира на том же маршруте.
func _measure(initial: Dictionary, start_pixels: Array) -> void:
	var rows:=[]; var conditions:={}; var observed_frames:=[]
	var start_draws:=terrain_draws
	var world_start: float=game.game_minutes
	var start_position:=_point(game.player); var start_camera:=_point(game.camera_offset)
	var first:=Time.get_ticks_usec(); var previous:=first
	physics_frame.connect(_drive); measuring=true; game.set_physics_process(true)
	while index<route.size() and Time.get_ticks_usec()-first<90000000:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		var state:=_conditions(); var key:=JSON.stringify(state)
		if not conditions.has(key): conditions[key]=conditions.size(); observed_frames.append({"conditions":state,"frames":0})
		var condition_id: int=conditions[key]; observed_frames[condition_id].frames+=1
		var live: bool=game.is_physics_processing() and not paused and not game.GameLoop.modal_active(game) and not game.GameLoop.gameplay_window_open(game)
		rows.append([now-previous,now-first,Engine.get_frames_drawn(),ticks,game.game_minutes,game.player.x,game.player.y,condition_id,live,
			Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),Performance.get_monitor(Performance.MEMORY_STATIC)])
		previous=now
		if rows.size()==30 and not fault.is_empty():
			faults.append(fault)
			if fault=="resize": root.size=Vector2i(1000,600)
			elif fault=="pause": game.set_physics_process(false); game.queue_redraw()
			elif fault=="focus":
				root.gui_embed_subwindows=false
				var focus_probe:=Window.new(); focus_probe.title="VBASE · отрицательный контроль фокуса"
				focus_probe.size=Vector2i(240,100); root.add_child(focus_probe); focus_probe.show(); focus_probe.grab_focus()
		if not state.valid or not live: break
	measuring=false; game.set_physics_process(false)
	for code in KEYS: _key(code,false)
	var end_image:=root.get_texture().get_image()
	var end_pixels:=_point(end_image.get_size()); end_image.save_png(folder.path_join("end.png"))
	var route_points:=[]
	for point in route: route_points.append(_point(point))
	var report:={"schema":1,"preset":"village-cardinal-1152-v1","repeat":repeat,"seed":SEED,"map_revision":Village.REVISION,
		"setup_states":setup_states,
		"engine":Engine.get_version_info().string,"driver":RenderingServer.get_current_rendering_driver_name(),"display_server":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"requested_window":_point(SIZE),"requested_framebuffer":_point(SIZE),"readback_start":start_pixels,"readback_end":end_pixels,"initial_conditions":initial,"condition_groups":observed_frames,
		"screen":_point(DisplayServer.screen_get_size()),"screen_scale":DisplayServer.screen_get_scale(),"screen_refresh_hz":DisplayServer.screen_get_refresh_rate(),
		"content_scale_mode":root.content_scale_mode,"content_scale_factor":root.content_scale_factor,"max_fps":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,
		"low_processor_usage":OS.low_processor_usage_mode,"idle_sleep_usec":OS.low_processor_usage_mode_sleep_usec,"pause_on_focus_loss":game.settings_state.pause_on_focus_loss,
		"profile":profile,"pid":OS.get_process_id(),"warmup_rendered_frames":WARMUP,"settle_after_readback":8,"warmup_world_frozen":true,
		"route_start":start_position,"route_targets":route_points,"route_checkpoints":checkpoints,"route_finished":index==route.size(),"location":game.current_location,
		"start_camera":start_camera,"end_camera":_point(game.camera_offset),"world_start_minutes":world_start,"world_end_minutes":game.game_minutes,
		"fault_injection":faults,"terrain_rebuilds":terrain_draws-start_draws,"sample_count":rows.size(),"interval_span_usec":previous-first,
		"columns":["interval_usec","elapsed_usec","draw_index","physics_tick","world_minutes","x","y","condition_id","simulation_live","process_ms","physics_ms","draw_calls","texture_bytes","static_bytes"],"frames":rows}
	FileAccess.open(folder.path_join("native.json"),FileAccess.WRITE).store_string(JSON.stringify(report)+"\n")
	print("VBASE COMPLETE: frames=",rows.size()," checkpoints=",index,"/",route.size()," seconds=",(previous-first)/1000000.0)
	quit(0 if index==route.size() and faults.is_empty() else 2)

## Записывает точные координаты без округления траектории для анализа отклонений и пропущенных шагов.
func _point(value: Vector2) -> Array:
	return [value.x,value.y]
