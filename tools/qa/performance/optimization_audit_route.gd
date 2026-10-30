extends "res://tools/qa/performance/runtime_frame_review.gd"

var audit_focused:=0
var audit_unfocused:=0
var audit_windows:Dictionary={}

## Отделяет весь маршрутный аудит, включая настройки, от пользовательских слотов игры.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Optimization-Audit-20261014")
	super._initialize()

## Дополняет старый прогрев пустых циклов настоящими кадрами и дожидается применения режима окна.
func _start() -> void:
	if DisplayServer.get_name()=="headless": print("AUDIT REJECTED: native renderer required"); quit(2); return
	super._start()
	if game==null: return
	started=false
	for _frame in 120:
		game.queue_redraw()
		await RenderingServer.frame_post_draw
	game.set_meta("cpu_samples",{})
	draw_intervals_ms=[]; previous_draw_usec=0; previous_frame_usec=Time.get_ticks_usec()
	started=true

## Помечает дополнительные условия измерения, не выдавая пустые циклы за кадры или тестовые слоты за слоты игрока.
func _finish() -> void:
	super._finish()
	var directory:="res://docs/reports"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): directory=argument.trim_prefix("--report-dir=")
	var pattern:="native_frames_%s.json"
	if profile_town: pattern="native_profile_town_%s_short.json" if profile_short else "native_profile_town_%s.json"
	var path:=directory.path_join(pattern%("f10" if game.DebugOverlaySystem.active(game) else "normal"))
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	data.audit_real_draw_warmup=120; data.audit_profile="Codex-Optimization-Audit-20261014"
	data.audit_instrumented="--cpu-sections" in OS.get_cmdline_user_args()
	data.audit_focus_draws={"focused":audit_focused,"unfocused":audit_unfocused}; data.audit_windows=audit_windows
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")

## Проверяет фокус и реальный размер во время каждого кадра, а не только в конце процесса.
func _record_drawn_frame() -> void:
	super._record_drawn_frame()
	if not started or frames<=WARMUP_FRAMES: return
	if DisplayServer.window_is_focused(): audit_focused+=1
	else: audit_unfocused+=1
	var key:=str(DisplayServer.window_get_size())
	audit_windows[key]=int(audit_windows.get(key,0))+1
