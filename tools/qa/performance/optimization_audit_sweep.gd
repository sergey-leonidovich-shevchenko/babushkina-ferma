extends SceneTree

var game:Node
var rows:Array=[]
var report:Dictionary={"schema":1,"seed":20261014,"cases":rows}
var previous_draw:int=0
var intervals:Array=[]
var directory:="res://docs/reports/optimization-audit-2026-10-14/sweep"
var case_started_ms:=0
var last_draw_ms:=0
var case_name:=""
var case_limit_ms:=60000

## Завершает зависший сценарий с частичным отчётом, если перестали поступать кадры либо превышен минутный лимит.
func _process(_delta:float) -> bool:
	if case_started_ms==0: return false
	var now:=Time.get_ticks_msec()
	if now-case_started_ms<=case_limit_ms and now-last_draw_ms<=10000: return false
	report.status="TIMEOUT"; report.incomplete_case=case_name; report.timeout_snapshot=snapshot()
	FileAccess.open(directory+"/timeout.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("AUDIT TIMEOUT: ",case_name)
	quit(4); return true

## Запускает измерение реального окна после создания дерева, сохраняя отдельный профиль пользователя.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Optimization-Sweep-20261014")
	_start.call_deferred()

## Измеряет загрузку сцены, первые показы и установившиеся кадры всех карт и основных окон.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): directory=argument.trim_prefix("--report-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	seed(20261014)
	report.before_load=snapshot()
	var started:=Time.get_ticks_usec()
	var scene:PackedScene=load("res://main.tscn")
	report.scene_load_ms=(Time.get_ticks_usec()-started)/1000.0
	started=Time.get_ticks_usec()
	game=scene.instantiate(); game.set_script(load("res://tools/qa/performance/cpu_profile_game.gd")); game.set_meta("capture_windowed",true)
	game.world_loot_seed=20261014; root.add_child(game); current_scene=game
	report.instantiate_ready_ms=(Time.get_ticks_usec()-started)/1000.0
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1152,648)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	preload("res://scripts/systems/render_pacing_system.gd").apply()
	game.language_screen=false; game.title_screen=false
	game.LocaleSystem.current="ru"; game.benchmark_autoplay=false
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0.0
	game.settings_state.text_scale=1.0; game.settings_state.reduced_motion=false
	game.AudioSystem.set_enabled(game,true)
	RenderingServer.frame_post_draw.connect(_drawn)
	for _index in 120: await next_draw()
	if "--require-window" in OS.get_cmdline_user_args():
		root.mode=Window.MODE_WINDOWED
		await create_timer(0.8).timeout
		root.size=Vector2i(1152,648)
		await create_timer(0.3).timeout
	if "--require-window" in OS.get_cmdline_user_args() and (DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_WINDOWED or DisplayServer.window_get_size()!=Vector2i(1152,648)):
		var rejection:Dictionary={"status":"REJECTED","reason":"window_mode_not_applied","expected":[1152,648],"actual":snapshot(),"mode":DisplayServer.window_get_mode()}
		FileAccess.open(directory+"/rejected.json",FileAccess.WRITE).store_string(JSON.stringify(rejection,"\t")+"\n")
		print("AUDIT REJECTED: ",JSON.stringify(rejection))
		quit(3); return
	report.after_warmup=snapshot(); report.textures=texture_inventory()
	var locations:Array=game.WorldMapSystem.LOCATIONS.keys()+game.BuildingSystem.INTERIORS.keys()
	for location in preload("res://scripts/systems/cave_room_data.gd").IDS+preload("res://scripts/systems/village_region_data.gd").IDS+["cellar_workshop"]:
		if location not in locations: locations.append(location)
	if "--ui-only" not in OS.get_cmdline_user_args():
		for location in locations: await measure("location:"+location,60)
	for kind in ["milk","egg","apple","plank","honey","sunflower","stone","field_mint"]: game.change_inventory_count(kind,80)
	for label in ["inventory","cabinet","cabinet-scroll","cabinet-search","chest","workbench","cauldron","alchemy","furnace","quests","hero","world","pause","settings"]:
		await measure(label,120)
		if label in ["inventory","cabinet","cauldron"]: await measure(label,120)
	await measure("cabinet-churn",600)
	report.after_sweep=snapshot()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--soak-seconds="): await soak(clampi(int(argument.trim_prefix("--soak-seconds=")),1,7200))
	report.engine=Engine.get_version_info().string; report.gpu=RenderingServer.get_video_adapter_name()
	report.window=[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y]
	report.window_mode=DisplayServer.window_get_mode(); report.root_mode=root.mode
	report.vsync=DisplayServer.window_get_vsync_mode(); report.max_fps=Engine.max_fps
	report.low_processor_usage=OS.low_processor_usage_mode
	report.focused=DisplayServer.window_is_focused(); report.physics_hz=Engine.physics_ticks_per_second
	report.note="Native window, real physics and renderer. Location setup uses direct safe placement (not a walking transition); menu commands use public APIs. First-present includes command, first draw and display wait. CPU instrumentation overhead is included. Memory counters are engine allocations, not OS RSS. No user save files are accessed."
	FileAccess.open(directory+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("OPTIMIZATION SWEEP: ",rows.size()," cases; ",directory)
	quit()

## Повторяет один прогретый цикл шкафа и ограничивает память самих CPU-таймеров при длительном контроле.
func soak(seconds:int) -> void:
	case_name="soak"; case_started_ms=Time.get_ticks_msec(); last_draw_ms=case_started_ms; case_limit_ms=(seconds+10)*1000
	report.soak=[]
	report.soak_samples=0
	var stream:=FileAccess.open(directory+"/soak.jsonl",FileAccess.WRITE)
	var started:=Time.get_ticks_msec(); var last_second:=-1; var frame:=0
	while Time.get_ticks_msec()-started<seconds*1000:
		var elapsed:=int((Time.get_ticks_msec()-started)/1000)
		if elapsed!=last_second:
			reset_windows()
			if elapsed%10<5: prepare("cabinet")
			else: prepare("location:cottage_interior")
			var sample:Dictionary={"second":elapsed,"state":snapshot()}
			stream.store_line(JSON.stringify(sample)); stream.flush()
			report.soak.append(sample); report.soak_samples+=1
			if report.soak.size()>180: report.soak.pop_front()
			game.set_meta("cpu_samples",{})
			intervals=[]
			last_second=elapsed
			if elapsed%30==0: print("AUDIT SOAK: ",elapsed," / ",seconds," seconds")
		if elapsed%10<5 and frame%5==0:
			preload("res://scripts/systems/storage_grid_system.gd").select(game,true,1,frame%preload("res://scripts/systems/dev_cabinet_system.gd").items(game).size())
		await next_draw(); frame+=1
	stream.close()
	report.soak_duration_ms=Time.get_ticks_msec()-started; report.after_soak=snapshot()
	case_started_ms=0; case_limit_ms=60000

## Считает только завершённые отрисовки, не принимая пустые проходы главного цикла за игровые кадры.
func _drawn() -> void:
	var now:=Time.get_ticks_usec()
	last_draw_ms=Time.get_ticks_msec()
	if previous_draw>0: intervals.append((now-previous_draw)/1000.0)
	previous_draw=now

## Дожидается настоящей отрисовки без принудительного второго рендера поверх штатного цикла.
func next_draw() -> void:
	game.queue_redraw()
	await RenderingServer.frame_post_draw

## Записывает отдельный первый показ, серию кадров, CPU-секции, память и честный признак остановки мира.
func measure(label:String, count:int) -> void:
	case_name=label; case_started_ms=Time.get_ticks_msec(); last_draw_ms=case_started_ms
	reset_windows()
	var started:=Time.get_ticks_usec()
	prepare(label)
	var command_ms:=(Time.get_ticks_usec()-started)/1000.0
	await next_draw()
	var first_ms:=(Time.get_ticks_usec()-started)/1000.0
	intervals=[]; previous_draw=Time.get_ticks_usec(); game.set_meta("cpu_samples",{})
	var minute:float=game.game_minutes; var location:String=game.current_location
	var begin:=snapshot()
	for index in count:
		game.player_hp=game.player_max_hp
		if label.begins_with("cabinet"):
			var grid=load("res://scripts/systems/storage_grid_system.gd")
			if label in ["cabinet-scroll","cabinet-churn"]: grid.scroll(game,true,1,1 if index%120<60 else -1)
			if label=="cabinet-churn": grid.select(game,true,1,index%preload("res://scripts/systems/dev_cabinet_system.gd").items(game).size())
		await next_draw()
	var cpu:Dictionary={}
	for section in game.get_meta("cpu_samples",{}): cpu[section]=stats(game.get_meta("cpu_samples")[section])
	rows.append({"case":label,"location":location,"actual_location":game.current_location,"command_ms":command_ms,"first_present_ms":first_ms,"draw":stats(intervals),"intervals_ms":intervals.duplicate(),"cpu_ms":cpu,"start":begin,"end":snapshot(),"simulation_minutes":game.game_minutes-minute,"frames":count,"inventory_items":game.inventory_slots.size()})
	print("AUDIT CASE: ",label," first=",snappedf(first_ms,0.01)," p95=",stats(intervals).p95," ms; window=",DisplayServer.window_get_size()," focused=",DisplayServer.window_is_focused())
	FileAccess.open(directory+"/progress.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"INCOMPLETE","last_case":label,"completed_cases":rows.size(),"last_result":rows.back()},"\t")+"\n")
	case_started_ms=0

## Сбрасывает только тестовые окна, не меняя инвентарь, время мира и пользовательские настройки.
func reset_windows() -> void:
	preload("res://scripts/systems/dev_cabinet_system.gd").close(game)
	for field in ["inventory_open","quest_log_open","skill_menu_open","world_map_open","storage_open","crafting_open","shop_open","forge_open","contract_open"]: game.set(field,false)
	game.menu_state.pause_open=false; game.menu_state.settings_open=false
	game.tutorial_visible=false; game.discovery_current={}; game.message=""
	game.clear_movement_keys()

## Готовит общедоступную карту либо открывает настоящее окно штатным игровым методом.
func prepare(label:String) -> void:
	var cabinet=preload("res://scripts/systems/dev_cabinet_system.gd")
	game.current_location=label.trim_prefix("location:") if label.begins_with("location:") else "cottage_interior"
	game.player=preload("res://scripts/systems/recovery_system.gd").safe_spawn(game)
	game.sync_background_location(); game.update_camera()
	if label.begins_with("location:"): return
	if label.begins_with("cabinet"):
		game.player=cabinet.POSITION
		if not cabinet.open(game): push_error("Audit cabinet not open")
		if label=="cabinet-search": preload("res://scripts/systems/dev_cabinet_input.gd").query(game,"essence")
	elif label=="chest":
		game.home_chest_owned=true
		for kind in game.InventorySystem.ITEM_DATA: game.home_chest_counts[kind]=999
		game.StorageSystem.open(game)
	elif label in ["inventory","quests","hero","world"]: preload("res://scripts/systems/menu_hub_system.gd").open(game,label)
	elif label in ["pause","settings"]:
		game.MenuSystem.open_pause(game)
		if label=="settings": game.MenuSystem.open_settings(game,false)
	else: game.CraftingSystem.open(game,label)

## Сохраняет штатные счётчики памяти и ресурсов без дорогого обхода всех текстур на каждом кадре.
func snapshot() -> Dictionary:
	return {"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"text_cache":preload("res://scripts/systems/ui_text_metrics_cache_system.gd").statistics(),"preview_cache":preload("res://scripts/presentation/prepared_item_icon_system.gd").cache_info(),"window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"focused":DisplayServer.window_is_focused()}

## Перечисляет уже кешированные PNG; расчёт RGBA8 является оценкой, отдельной от счётчика видеопамяти.
func texture_inventory() -> Array:
	var result:Array=cached_textures("res://assets")
	result.sort_custom(func(a,b): return int(a.estimated_rgba8_bytes)>int(b.estimated_rgba8_bytes))
	return result

## Обходит имена ресурсов и обращается только к уже загруженным текстурам, не прогревая будущие сцены.
func cached_textures(path:String) -> Array:
	var result:Array=[]
	for file in DirAccess.get_files_at(path):
		var resource:=path.path_join(file)
		if file.ends_with(".png") and ResourceLoader.has_cached(resource):
			var texture:Texture2D=load(resource)
			result.append({"path":resource,"width":texture.get_width(),"height":texture.get_height(),"estimated_rgba8_bytes":texture.get_width()*texture.get_height()*4})
	for child in DirAccess.get_directories_at(path): result.append_array(cached_textures(path.path_join(child)))
	return result

## Вычисляет перцентили по исходным кадрам с сохранением всех выбросов.
func stats(values:Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted:=values.duplicate(); sorted.sort(); var total:=0.0; var slow:=0; var stalled:=0
	for value in sorted:
		total+=value
		if value>33.333: slow+=1
		if value>100: stalled+=1
	return {"count":values.size(),"mean":total/values.size(),"p50":sorted[floori((values.size()-1)*0.5)],"p95":sorted[floori((values.size()-1)*0.95)],"p99":sorted[floori((values.size()-1)*0.99)],"max":sorted.back(),"over33":slow,"over100":stalled}
