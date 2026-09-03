extends RefCounted

const InteriorVisualSystem := preload("res://scripts/systems/interior_visual_system.gd")
const COTTAGE_TILES := preload("res://assets/game/interiors/grandmother_cottage_tiles_v1.png")
const COTTAGE_FLOORS := [Rect2(640,330,274,274),Rect2(944,330,274,274),Rect2(32,632,274,274),Rect2(335,632,274,274)]
const COTTAGE_WALL := Rect2(76,72,190,196)
const COTTAGE_WINDOW := Rect2(375,366,194,201)
const COTTAGE_STONE := Rect2(642,634,270,270)


## Рисует тематический пол, стены и мебель активного помещения из прозрачного атласа.
static func draw(canvas: Node2D) -> void:
	var data: Dictionary = canvas.BuildingSystem.interior(canvas.current_location)
	if data.is_empty(): return
	var room: Rect2 = data.room
	if canvas.current_location=="cottage_interior": draw_cottage_shell(canvas,room)
	else: draw_legacy_shell(canvas,room,data)
	var props:=InteriorVisualSystem.props(canvas.current_location)
	# Напольный декор всегда лежит под мебелью и персонажами, а не перекрывает их.
	for prop in props:
		if InteriorVisualSystem.collision_rect(String(prop.kind),Vector2(prop.position)).size==Vector2.ZERO:
			InteriorVisualSystem.draw(canvas,String(prop.kind),Vector2(prop.position))
	for prop in props:
		if InteriorVisualSystem.collision_rect(String(prop.kind),Vector2(prop.position)).size!=Vector2.ZERO:
			InteriorVisualSystem.draw(canvas,String(prop.kind),Vector2(prop.position))
	var exit: Vector2 = data.exit
	if canvas.current_location=="cottage_interior":
		canvas.draw_texture_rect_region(COTTAGE_TILES,Rect2(exit-Vector2(46,20),Vector2(92,40)),COTTAGE_STONE,Color("d8b889"))
	else:
		canvas.draw_rect(Rect2(exit-Vector2(38,18),Vector2(76,36)),Color("39291f"))
	for link in data.get("links", []): canvas.draw_circle(link.position,34,Color("d6ad52"),false,5)


## Рисует прежний нейтральный каркас дополнительных помещений, пока для них не подготовлены отдельные тайлсеты.
static func draw_legacy_shell(canvas:Node2D,room:Rect2,data:Dictionary)->void:
	canvas.draw_rect(room, Color(data.color).darkened(0.18)); canvas.draw_rect(room.grow(-18), Color(data.color).lightened(0.12))
	for y in range(int(room.position.y + 34), int(room.end.y - 20), 42):
		canvas.draw_line(Vector2(room.position.x + 20,y), Vector2(room.end.x - 20,y), Color(0.16,0.10,0.07,0.18), 2)
	canvas.draw_rect(Rect2(room.position + Vector2(18,18), Vector2(room.size.x - 36,44)), Color(data.color).darkened(0.34))


## Собирает дом бабушки из повторяемых деревянных, стеновых и оконных спрайтов без плоской заливки пола.
static func draw_cottage_shell(canvas:Node2D,room:Rect2)->void:
	canvas.draw_rect(room.grow(14),Color(0.02,0.016,0.014,0.82)); canvas.draw_rect(room,Color("402718"))
	var inner:=room.grow(-24); var wall_height:=144.0; var wall_width:=120.0
	for column in 7:
		var source:=COTTAGE_WINDOW if column==3 else COTTAGE_WALL
		canvas.draw_texture_rect_region(COTTAGE_TILES,Rect2(inner.position+Vector2(column*wall_width,0),Vector2(wall_width,wall_height)),source)
	var floor_top:=inner.position.y+wall_height
	for row in 2:
		for column in 7:
			var source:Rect2=COTTAGE_FLOORS[posmod(row*3+column,COTTAGE_FLOORS.size())]
			canvas.draw_texture_rect_region(COTTAGE_TILES,Rect2(Vector2(inner.position.x+column*wall_width,floor_top+row*120),Vector2(120,120)),source)
	canvas.draw_rect(Rect2(inner.position+Vector2(0,wall_height-5),Vector2(inner.size.x,10)),Color("6f3c1c")); canvas.draw_line(inner.position+Vector2(0,wall_height),inner.position+Vector2(inner.size.x,wall_height),Color("e3a852"),2)


## Рисует установленный объект тем же профилем, который задаёт его коллизию и F10-границы.
static func draw_prop(canvas: Node2D, kind: String, position: Vector2) -> void:
	InteriorVisualSystem.draw(canvas,kind,position)
