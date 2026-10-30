extends "res://tools/qa/world/post_motion_game.gd"
var depth_records:=[]

## Записывает только наблюдаемые реальные dispatch растения вокруг production draw.
func _draw()->void:
	if not observe_draw:super._draw();return
	set_meta("plant_depth_trace",[])
	super._draw()
	var state:Dictionary=get_meta("tree_occlusion_frame",{})
	depth_records.append({"frame":Engine.get_process_frames(),"trace":get_meta("plant_depth_trace",[]).duplicate(true),"queue_after":state.get("queue",[]).size(),"hero_ground":state.get("hero_ground",Vector2.INF)})
