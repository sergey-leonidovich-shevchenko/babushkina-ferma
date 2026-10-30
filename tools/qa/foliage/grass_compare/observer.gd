extends Node

const FIELDS := ["usec","interval_ms","update_ms","engine_frame_ms","draw_calls","static_bytes","texture_bytes","wind_time","camera_x","camera_y","focused","window_x","window_y","modal"]
const CAPACITY := 12000
var controller: SceneTree
var warm := 0
var count := 0
var previous := 0
var start := 0
var finished := false
var values := PackedFloat64Array()
var errors := []

## Заранее резервирует raw-память до прогрева, не записывая CSV в измеряемом интервале.
func _ready() -> void:
	process_priority=100; values.resize(CAPACITY*FIELDS.size())

## Наблюдает автоматические callbacks только собственного визуального эффекта, не игровые FPS.
func _process(_delta: float) -> void:
	if finished: return
	var now:=Time.get_ticks_usec(); warm+=1
	if warm<=120: previous=now; start=now; return
	if count==0: controller.started_utc=Time.get_unix_time_from_system()
	var g:Node=controller.game; var field:Node=controller.field; var win:=DisplayServer.window_get_size()
	var modal:bool=g.GameLoop.modal_active(g) or g.GameLoop.gameplay_window_open(g)
	var focus:=DisplayServer.window_is_focused(); var camera:Vector2=g.camera_offset
	var row:=[now,float(now-previous)/1000.0,field.update_usec/1000.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.MEMORY_STATIC),
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),field.wind_time,camera.x,camera.y,1 if focus else 0,win.x,win.y,1 if modal else 0]
	for i in FIELDS.size(): values[count*FIELDS.size()+i]=float(row[i])
	count+=1; previous=now
	if not focus or win!=Vector2i(1152,648) or modal or camera.distance_to(Vector2(120.25,430.25))>0.001: errors.append("focus/window/modal/camera changed")
	if g.is_processing() or g.is_physics_processing(): errors.append("game simulation unexpectedly enabled")
	if count>=CAPACITY: errors.append("sample capacity reached")
	if now-start>=controller.seconds*1000000 or not errors.is_empty():
		finished=true; controller._finish_bench.call_deferred()
