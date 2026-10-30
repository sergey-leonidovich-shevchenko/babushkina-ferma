extends SceneTree

const Scene := preload("res://main.tscn")
const Maintenance := preload("res://scripts/systems/runtime_maintenance_system.gd")
const Stone := preload("res://scripts/systems/qa_teleport_system.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
const Bounds := preload("res://scripts/systems/wildlife_visual_system.gd")
const Picker := preload("res://scripts/systems/level_editor_atlas_picker_renderer.gd")
const FOLDER := "res://docs/reports/runtime-cleanup-2026-10-15/"
const MAX_FRAME_SAMPLES := 60_000
var game: Node2D
var viewport: SubViewport
var locations: Array
var failed := false

## Запускает настоящий оконный обход после прогрева без чтения слотов и вмешательства в обычную игру пользователя.
func _initialize() -> void:
	_start.call_deferred()

## Наблюдает реальные тридцатисекундные циклы обслуживания на повторяемом маршруте с малыми временными ресурсами.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Runtime-Cleanup-Soak")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1152,648)
	var container := SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.audio_enabled=false; game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
	game.settings_state.pause_on_focus_loss=false
	game.FarmLifeSystem.state(game).first_day=6; game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).cutscene_timer=0
	game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true
	game.change_inventory_count(Stone.KIND,1); locations=Stone.locations(game)
	for index in locations.size()+2:
		set_case(index); await process_frame; await RenderingServer.frame_post_draw
	for frame in 120: await process_frame
	var duration := 180
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): duration=clampi(int(arg.get_slice("=",1)),60,7200)
	var started := Time.get_ticks_usec(); var previous := started; var next_sample := started
	var case_index := -1; var scanned := -1; var frames: Array[int]=[]; var slices: Array[int]=[]; var samples := []
	var created := 0; var rendered := 0
	while Time.get_ticks_usec()-started < duration*1_000_000 and not failed:
		await process_frame
		var now := Time.get_ticks_usec(); rendered+=1
		if frames.size()<MAX_FRAME_SAMPLES: frames.append(now-previous)
		previous=now
		var current: int = int((now-started)/3_000_000)
		if current!=case_index:
			case_index=current; set_case(current); churn(); created+=8
		game.menu_state.recovery_grace=5.0
		var state: Dictionary=game.get_meta(Maintenance.META,{})
		if int(state.get("scanned",0))!=scanned:
			scanned=int(state.get("scanned",0)); slices.append(int(state.get("last_usec",0)))
		if now>=next_sample:
			samples.append(snapshot((now-started)/1_000_000.0)); next_sample=now+10_000_000
			print("CLEANUP SOAK: ",int((now-started)/1_000_000),"s, cycles=",state.get("cycles",0))
	samples.append(snapshot((Time.get_ticks_usec()-started)/1_000_000.0))
	var report := {"pause_on_focus_loss":game.settings_state.pause_on_focus_loss,"protocol":"native fixed viewport; real-time periodic cleanup; warm route before sampling; intentional resource churn and transitions included in frame times","engine":Engine.get_version_info().string,"duration_seconds":(Time.get_ticks_usec()-started)/1_000_000.0,"window":[root.size.x,root.size.y],"viewport":[viewport.size.x,viewport.size.y],"adapter":RenderingServer.get_video_adapter_name(),"frames":rendered,"recorded_frame_limit":MAX_FRAME_SAMPLES,"frame_usec":frames,"cleanup_usec":slices,"temporary_created":created,"samples":samples,"failed":failed}
	DirAccess.make_dir_recursive_absolute(FOLDER)
	FileAccess.open(FOLDER+"native-soak.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("CLEANUP SOAK COMPLETE: ",report.duration_seconds,"s, ",rendered," frames")
	quit(1 if failed else 0)

## Чередует все карты, полный шкаф и рюкзак через настоящий QA-перенос, не подменяя боевые переходы.
func set_case(index: int) -> void:
	Stone.close(game); Cabinet.close(game); preload("res://scripts/systems/menu_hub_system.gd").close(game)
	var phase := index%(locations.size()+2)
	var target: String=locations[phase] if phase<locations.size() else "cottage_interior"
	if not Stone.open(game) or not Stone.travel(game,target): failed=true; push_error("Не выполнен переход стенда в "+target); return
	game.menu_state.recovery_grace=5.0
	if phase==locations.size(): game.player=Cabinet.POSITION; Cabinet.open(game)
	elif phase==locations.size()+1: game.open_inventory()
	game.update_camera()

## Имитирует небольшие временные предпросмотры, чьи исходники отпускаются после завершения вызова.
func churn() -> void:
	for index in 8:
		var image := Image.create(64,64,false,Image.FORMAT_RGBA8); image.fill(Color.CORNFLOWER_BLUE)
		var source := ImageTexture.create_from_image(image); var result := Matte.clean_texture(source)
		Bounds.visible_bounds(result,Rect2i(0,0,64,64)); Picker.visible_preview_source(result,Rect2(0,0,64,64))

## Снимает память движка, собственный RSS процесса и пределы кешей без сохранения ссылок на текстуры.
func snapshot(seconds: float) -> Dictionary:
	var output := []; var status := OS.execute("/bin/ps",["-o","rss=","-p",str(OS.get_process_id())],output)
	var rss: Variant = int(String(output[0]).strip_edges())*1024 if status==0 and not output.is_empty() else null
	return {"seconds":seconds,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"rss_bytes":rss,"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"maintenance":Maintenance.statistics(game)}
