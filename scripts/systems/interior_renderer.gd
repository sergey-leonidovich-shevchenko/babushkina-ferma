extends RefCounted

const PROPS := {
	"cottage_interior":[{"cell":0,"position":Vector2(340,255),"size":Vector2(150,120)},{"cell":4,"position":Vector2(790,275),"size":Vector2(105,105)}],
	"shop_interior":[{"cell":1,"position":Vector2(576,225),"size":Vector2(210,125)},{"cell":4,"position":Vector2(840,265),"size":Vector2(90,90)}],
	"guild_interior":[{"cell":2,"position":Vector2(576,225),"size":Vector2(200,125)},{"cell":4,"position":Vector2(850,285),"size":Vector2(88,88)}],
	"forge_interior":[{"cell":3,"position":Vector2(576,240),"size":Vector2(180,140)},{"cell":4,"position":Vector2(850,285),"size":Vector2(88,88)}],
}


## Рисует тематический пол, стены и мебель активного помещения из прозрачного атласа.
static func draw(canvas: Node2D) -> void:
	var data: Dictionary = canvas.BuildingSystem.interior(canvas.current_location)
	if data.is_empty(): return
	var room: Rect2 = data.room
	canvas.draw_rect(room, Color(data.color).darkened(0.18)); canvas.draw_rect(room.grow(-18), Color(data.color).lightened(0.12))
	for y in range(int(room.position.y + 34), int(room.end.y - 20), 42):
		canvas.draw_line(Vector2(room.position.x + 20,y), Vector2(room.end.x - 20,y), Color(0.16,0.10,0.07,0.18), 2)
	canvas.draw_rect(Rect2(room.position + Vector2(18,18), Vector2(room.size.x - 36,44)), Color(data.color).darkened(0.34))
	for prop in PROPS.get(canvas.current_location, generic_props(canvas.current_location)):
		var size: Vector2 = prop.size
		canvas.WorldPolishRenderer.draw_cell(canvas, int(prop.cell), 0, Rect2(Vector2(prop.position) - size * 0.5, size))
	var exit: Vector2 = data.exit
	canvas.draw_rect(Rect2(exit - Vector2(38,18),Vector2(76,36)),Color("39291f")); canvas.draw_string(canvas.UI_FONT,exit+Vector2(-44,39),"E • выход",HORIZONTAL_ALIGNMENT_CENTER,88,13,Color("fff0bd"))
	for link in data.get("links", []): canvas.draw_circle(link.position,34,Color("d6ad52"),false,5)


## Создаёт минимальный тематический набор мебели для дополнительных этажей и закрытых зданий.
static func generic_props(location: String) -> Array:
	var seed := posmod(location.hash(), 4)
	return [{"cell":seed,"position":Vector2(410,250),"size":Vector2(140,110)},{"cell":4,"position":Vector2(770,300),"size":Vector2(92,92)}]
