extends "res://tools/render_order_game.gd"
var pass_records:=[]

## Снимает фактический маршрут выбранного прохода вокруг обычного production draw, не меняя код рисования.
func _draw()->void:
	if not observe_draw:super._draw();return
	set_meta("pilot_object_pass_trace",[])
	var own_material:=material;var inherited:=use_parent_material
	super._draw()
	var count:=0;var builds:=0
	if ResourceLoader.exists("res://scripts/presentation/pilot_object_pass.gd"):
		var pass_code=load("res://scripts/presentation/pilot_object_pass.gd");count=pass_code._packets.size();builds=pass_code._builds
	pass_records.append({"frame":Engine.get_process_frames(),"trace":get_meta("pilot_object_pass_trace",[]).duplicate(true),"cache_count":count,"cache_builds":builds,"material_equal":material==own_material,"inherit_equal":use_parent_material==inherited})
