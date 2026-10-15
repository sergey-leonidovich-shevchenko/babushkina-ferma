extends "res://tools/optimization_audit_sweep.gd"

var focus_draws:={"focused":0,"unfocused":0}
var windows:Dictionary={}
var sample_frames:=360
var repeats:=1
var variants:Array=["full","ui-only","flat-ui"]
var uninstrumented:=false

## Отделяет воспроизводимый профиль хранилищ от игровых слотов и прежних диагностических настроек.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Storage-Perf-20261014")
	_start.call_deferred()

## Запускает настоящее окно, сравнивая обычный renderer и контрольные варианты на одинаковых данных.
func _start() -> void:
	if DisplayServer.get_name()=="headless": print("STORAGE PERF REJECTED: native renderer required"); quit(2); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): directory=argument.trim_prefix("--report-dir=")
		if argument.begins_with("--frames="): sample_frames=clampi(int(argument.trim_prefix("--frames=")),120,10000)
		if argument.begins_with("--repeats="): repeats=clampi(int(argument.trim_prefix("--repeats=")),1,3)
		if argument.begins_with("--variants="): variants=Array(argument.trim_prefix("--variants=").split(","))
	uninstrumented="--uninstrumented" in OS.get_cmdline_user_args()
	if uninstrumented: variants=["full"]
	case_limit_ms=maxi(60000,sample_frames*100+10000)
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory+"/.gdignore",FileAccess.WRITE).close()
	seed(20261014)
	var started:=Time.get_ticks_usec()
	var scene:PackedScene=load("res://main.tscn")
	report.scene_load_ms=(Time.get_ticks_usec()-started)/1000.0
	started=Time.get_ticks_usec()
	game=scene.instantiate()
	if not uninstrumented: game.set_script(load("res://tools/storage_perf_game.gd"))
	game.set_meta("capture_windowed",true)
	game.world_loot_seed=20261014; root.add_child(game); current_scene=game
	report.instantiate_ready_ms=(Time.get_ticks_usec()-started)/1000.0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	DisplayServer.window_move_to_foreground()
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
	game.LocaleSystem.current="ru"; game.benchmark_autoplay=false
	game.FarmLifeSystem.state(game).first_day=6
	game.FarmLifeSystem.state(game).cutscene=""
	game.settings_state.text_scale=1.0
	game.settings_state.pause_on_focus_loss=false
	RenderingServer.frame_post_draw.connect(_drawn)
	for _index in 120: await next_draw()
	for kind in ["milk","egg","apple","plank","honey","sunflower","stone","field_mint"]: game.change_inventory_count(kind,80)
	report.version=ProjectSettings.get_setting("application/config/version")
	report.gpu=RenderingServer.get_video_adapter_name(); report.engine=Engine.get_version_info().string
	report.window=[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y]
	report.pause_on_focus_loss=game.settings_state.pause_on_focus_loss
	report.before=snapshot()
	report.instrumented=not uninstrumented; report.openings=[]
	for label in ["cabinet","chest"]:
		for attempt in 2:
			reset_windows(); var opened:=Time.get_ticks_usec(); prepare(label); await next_draw()
			report.openings.append({"case":label,"attempt":attempt,"first_present_ms":(Time.get_ticks_usec()-opened)/1000.0,"state":snapshot()})
	if "--openings-only" in OS.get_cmdline_user_args():
		report.status="OPENINGS_ONLY"
		FileAccess.open(directory+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
		quit(); return
	for repeat in repeats:
		for variant in variants:
			if not uninstrumented: game.render_variant=variant
			preload("res://scripts/presentation/moon_theme.gd").styles.clear()
			for label in ["cabinet","cabinet-scroll","chest"]:
				reset_windows(); prepare(label)
				for _frame in 30: await next_draw()
				focus_draws={"focused":0,"unfocused":0}; windows={}
				await measure(label,sample_frames)
				rows.back().variant=variant; rows.back().repeat=repeat
				rows.back().focus_draws=focus_draws.duplicate(); rows.back().windows=windows.duplicate()
				game.message=""; await next_draw()
				if repeat==0: root.get_texture().get_image().save_png(directory+"/%s-%s-%d.png"%[variant,label,repeat])
				FileAccess.open(directory+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	report.after=snapshot(); report.status="COMPLETE"
	report.note="Native fullscreen; fixed seed and real paused storage. CPU instrumentation is explicit; UI-only and flat-ui are diagnostic controls. Focus/window recorded per draw. Openings are recorded before warming storage; frame cases are warm. Screenshots clear the transient footer notice. Short runs are not final 3600-frame x3 acceptance."
	FileAccess.open(directory+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("STORAGE PERF: ",rows.size()," cases; ",directory); quit()

## Записывает фокус и геометрию на каждом настоящем кадре вместе с исходными интервалами.
func _drawn() -> void:
	super._drawn()
	var key:="focused" if DisplayServer.window_is_focused() else "unfocused"
	focus_draws[key]+=1
	var size:=str(DisplayServer.window_get_size()); windows[size]=int(windows.get(size,0))+1
