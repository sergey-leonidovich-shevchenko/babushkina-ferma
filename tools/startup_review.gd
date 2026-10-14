extends SceneTree

var report:Dictionary={"schema":1}
var directory:="res://docs/reports/startup-perf-2026-10-14/before"
var game:Node

## Отделяет проверку запуска от пользовательских настроек и слотов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Startup-Perf-20261014")
	_start.call_deferred()

## Измеряет настоящий старт либо независимую холодную подготовку графических сервисов.
func _start() -> void:
	if DisplayServer.get_name()=="headless": print("STARTUP REVIEW REJECTED: native renderer required"); quit(2); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): directory=argument.trim_prefix("--report-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory+"/.gdignore",FileAccess.WRITE).close()
	report.entry_engine_ms=Time.get_ticks_usec()/1000.0
	var started:=Time.get_ticks_usec()
	var scene:PackedScene=load("res://main.tscn")
	report.load_scene_ms=(Time.get_ticks_usec()-started)/1000.0
	started=Time.get_ticks_usec(); game=scene.instantiate(); game.world_loot_seed=20261014
	report.instantiate_ms=(Time.get_ticks_usec()-started)/1000.0
	if "--services" in OS.get_cmdline_user_args(): await services()
	else:
		game.set_meta("capture_windowed",true)
		started=Time.get_ticks_usec(); root.add_child(game); current_scene=game
		report.ready_ms=(Time.get_ticks_usec()-started)/1000.0
		game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
		game.FarmLifeSystem.state(game).first_day=6; game.FarmLifeSystem.state(game).cutscene=""
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayServer.window_move_to_foreground()
		game.queue_redraw(); await RenderingServer.frame_post_draw
		report.first_world_engine_ms=Time.get_ticks_usec()/1000.0
		report.first_world_from_entry_ms=report.first_world_engine_ms-report.entry_engine_ms
		for _frame in 120: game.queue_redraw(); await RenderingServer.frame_post_draw
		report.warmed=monitors()
		root.get_texture().get_image().save_png(directory+"/first-world.png")
	report.mode="services" if "--services" in OS.get_cmdline_user_args() else "startup"
	report.version=ProjectSettings.get_setting("application/config/version")
	report.gpu=RenderingServer.get_video_adapter_name(); report.engine=Engine.get_version_info().string
	report.window=[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y]
	report.status="COMPLETE"
	report.note="Separate userdata, no player slot opened. Engine ticks plus scene-load/instantiate/ready/first-world timings; does not include app launcher. Service mode is an independent cold resource probe, not the full game startup."
	FileAccess.open(directory+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("STARTUP REVIEW: ",JSON.stringify(report))
	if not game.is_inside_tree(): game.free()
	quit()

## Делит холодную графическую подготовку на реально вызываемые сервисы, не выдавая её за полный управляемый старт.
func services() -> void:
	report.services={}
	var operations:Array=[
		["item_icons",func(): game.VisualAssetSystem.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())],
		["hero",func(): game.DirectionalCharacterSystem.HeroVisualSystem.warmup()],
		["dial",func(): load("res://scripts/systems/celestial_dial_assets_system.gd").warmup()],
		["grandmother",func(): game.DirectionalCharacterSystem.GrandmotherVisualSystem.warmup()],
		["residents",func():
			for texture in game.DirectionalCharacterSystem.NPC_TEXTURES.slice(1)+game.DirectionalCharacterSystem.COMPANION_TEXTURES.values(): game.DirectionalCharacterSystem.Residents.warmup(texture)],
		["events",func(): game.WorldPolishRenderer.warmup_events()],
		["portal",func(): game.EnvironmentVisualSystem.texture("moon_portal")],
		["wildlife",func(): load("res://scripts/systems/wildlife_visual_system.gd").warmup(game)],
	]
	for operation in operations:
		var started:=Time.get_ticks_usec(); operation[1].call()
		report.services[operation[0]]=(Time.get_ticks_usec()-started)/1000.0
		print("STARTUP SERVICE: ",operation[0]," ",report.services[operation[0]]," ms")
	report.warmed=monitors()

## Записывает движковую память отдельно от оценочного RGBA-размера и памяти процесса ОС.
func monitors() -> Dictionary:
	return {"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"item_sources_loaded":game.VisualAssetSystem.item_icon_cache.size(),"item_previews":preload("res://scripts/presentation/prepared_item_icon_system.gd").cache_info()}
