extends RefCounted

const Data := preload("res://scripts/systems/basement_data.gd")
const Art := preload("res://scripts/presentation/basement_visual_system.gd")
const FLOOR := preload("res://assets/game/basement/floor_a.png")

## Собирает большую кирпичную мастерскую из повторяемого пола и независимых стен, балок, фонарей и лестницы.
static func draw(game: Node2D) -> void:
	var visible:=Rect2(game.camera_offset,Vector2(1152,648)).grow(192)
	game.draw_rect(Data.ROOM.grow(12),Color("171511")); game.draw_rect(Data.ROOM,Color("503322"))
	for y in range(0,ceili(Data.FLOOR.size.y/288.0)):
		for x in range(0,ceili(Data.FLOOR.size.x/288.0)):
			var origin:=Data.FLOOR.position+Vector2(x,y)*288
			var size:=Vector2(minf(288,Data.FLOOR.end.x-origin.x),minf(288,Data.FLOOR.end.y-origin.y)); var rect:=Rect2(origin,size)
			if visible.intersects(rect): game.draw_texture_rect_region(FLOOR,rect,Rect2(Vector2.ZERO,size*FLOOR.get_size()/288),Color("c1b49e"))
	for index in ceili(Data.FLOOR.size.x/216):
		var rect:=Rect2(96+index*216,72,minf(216,Data.FLOOR.end.x-96-index*216),168)
		if visible.intersects(rect): game.draw_texture_rect_region(Art.SHELL.wall,rect,Rect2(Vector2.ZERO,Vector2(Art.SHELL.wall.get_width()*rect.size.x/216,Art.SHELL.wall.get_height())))
	for side in [48.0,2304.0]:
		for y in range(240,1464,144):
			var rect:=Rect2(side,y,48,144)
			if visible.intersects(rect): game.draw_texture_rect_region(Art.SHELL.wall,rect,Rect2(140,24,48,180),Color("b49a7a"))
		for y in range(384,1465,384): sprite(game,"post",Rect2(side,y-96,48,120))
	sprite(game,"corner_left",Rect2(48,72,96,168)); sprite(game,"corner_right",Rect2(2256,72,96,168))
	for x in [312,960,1608,2256]: sprite(game,"lantern",Rect2(x-36,126,72,108))
	game.draw_rect(Rect2(96,236,2208,8),Color(0.10,0.06,0.03,0.30))
	game.draw_rect(Rect2(48,1464,2304,48),Color("382a20")); game.draw_line(Vector2(96,1464),Vector2(2304,1464),Color("96734c"),5)

## Вписывает полный самостоятельный ресурс в модульную область, не искажая его пропорции.
static func sprite(game: Node2D, kind: String, bounds: Rect2) -> void:
	if not bounds.intersects(Rect2(game.camera_offset,Vector2(1152,648)).grow(192)): return
	var texture:Texture2D=Art.SHELL[kind]; var size:=texture.get_size()*minf(bounds.size.x/texture.get_width(),bounds.size.y/texture.get_height())
	game.draw_texture_rect(texture,Rect2(bounds.get_center()-size/2,size),false)
