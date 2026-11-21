extends "res://scripts/game.gd"

var observe_draw := false
var draw_records := []

## Наблюдает настоящий production draw без замены его команд; сохраняемые состояния сравниваются целиком.
func _draw() -> void:
	if not observe_draw:
		super._draw(); return
	var before := SaveSystem.snapshot(self)
	var geometry := {"camera":camera_offset,"player":player,"location":current_location,"pause":menu_state.pause_open}
	super._draw()
	var after := SaveSystem.snapshot(self)
	var geometry_after := {"camera":camera_offset,"player":player,"location":current_location,"pause":menu_state.pause_open}
	draw_records.append({"before":before,"after":after,"equal":before==after,"geometry_equal":geometry==geometry_after,
		"geometry_before":geometry,"geometry_after":geometry_after,
		"process_frame":Engine.get_process_frames(),"queue_after":get_meta("tree_occlusion_frame",{}).get("queue",[]).size()})
