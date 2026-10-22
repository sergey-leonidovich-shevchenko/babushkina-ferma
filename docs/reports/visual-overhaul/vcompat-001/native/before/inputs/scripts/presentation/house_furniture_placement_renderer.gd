extends RefCounted

const Layout := preload("res://scripts/systems/house_furniture_layout_system.gd")

## Показывает единую сетку дома, целый ракурс предмета и цвет реальной проверки пересечений.
static func draw(game: Node2D) -> void:
	if game.current_location!="cottage_interior" or not bool(game.FarmLifeSystem.state(game).build_mode): return
	var floor:=Layout.Data.FLOOR
	for x in range(int(floor.position.x),int(floor.end.x)+1,Layout.Data.GRID): game.draw_line(Vector2(x,floor.position.y),Vector2(x,floor.end.y),Color(0.95,0.86,0.65,0.15),1)
	for y in range(int(floor.position.y),int(floor.end.y)+1,Layout.Data.GRID): game.draw_line(Vector2(floor.position.x,y),Vector2(floor.end.x,y),Color(0.95,0.86,0.65,0.15),1)
	var item:=Layout.candidate(game); var bounds:=Layout.rect(item.kind,item.position,int(item.direction))
	var tint:=Color(0.55,0.84,0.44,0.35) if Layout.can_place(game,item) else Color(0.92,0.30,0.25,0.42)
	game.draw_rect(bounds,tint); game.draw_rect(bounds,Color(tint,0.9),false,2)
	game.FarmLifeVisualSystem.draw(game,item.kind,item.position,Color(1,1,1,0.55),int(item.direction))
