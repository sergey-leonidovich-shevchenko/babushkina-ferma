extends "res://tools/render_order_game.gd"

var query_roots:=false
var root_records:=[]
var root_origin:=Vector2(1944,648)

## Читает реальные корни непосредственно внутри настоящего draw; наблюдатель не подменяет игровой рисунок.
func _draw()->void:
	if query_roots and observe_draw:
		var before:=SaveSystem.snapshot(self);var children:=get_child_count();var metadata:=get_meta_list();var anchors:=[]
		for kind in VillageAmbientRenderer.CELLS:
			var anchor:Vector2=VillageAmbientRenderer.root_anchor(kind,root_origin)
			anchors.append({"kind":kind,"world":[anchor.x,anchor.y]})
		root_records.append({"frame":Engine.get_process_frames(),"anchors":anchors,"pure":before==SaveSystem.snapshot(self) and children==get_child_count() and metadata==get_meta_list()})
	super._draw()
