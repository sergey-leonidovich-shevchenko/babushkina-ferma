extends RefCounted

const InteriorVisualSystem := preload("res://scripts/systems/interior_visual_system.gd")


## Рисует тематический пол, стены и мебель активного помещения из прозрачного атласа.
static func draw(canvas: Node2D) -> void:
	var data: Dictionary = canvas.BuildingSystem.interior(canvas.current_location)
	if data.is_empty(): return
	var room: Rect2 = data.room
	canvas.draw_rect(room, Color(data.color).darkened(0.18)); canvas.draw_rect(room.grow(-18), Color(data.color).lightened(0.12))
	for y in range(int(room.position.y + 34), int(room.end.y - 20), 42):
		canvas.draw_line(Vector2(room.position.x + 20,y), Vector2(room.end.x - 20,y), Color(0.16,0.10,0.07,0.18), 2)
	canvas.draw_rect(Rect2(room.position + Vector2(18,18), Vector2(room.size.x - 36,44)), Color(data.color).darkened(0.34))
	for prop in InteriorVisualSystem.props(canvas.current_location):
		InteriorVisualSystem.draw(canvas,String(prop.kind),Vector2(prop.position))
	var exit: Vector2 = data.exit
	canvas.draw_rect(Rect2(exit - Vector2(38,18),Vector2(76,36)),Color("39291f")); canvas.draw_string(canvas.UI_FONT,exit+Vector2(-44,39),"E • выход",HORIZONTAL_ALIGNMENT_CENTER,88,13,Color("fff0bd"))
	for link in data.get("links", []): canvas.draw_circle(link.position,34,Color("d6ad52"),false,5)


## Рисует установленный объект тем же профилем, который задаёт его коллизию и F10-границы.
static func draw_prop(canvas: Node2D, kind: String, position: Vector2) -> void:
	InteriorVisualSystem.draw(canvas,kind,position)
