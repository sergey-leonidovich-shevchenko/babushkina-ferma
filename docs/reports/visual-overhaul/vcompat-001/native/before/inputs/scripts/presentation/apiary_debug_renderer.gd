extends RefCounted

const Apiary := preload("res://scripts/systems/apiary_system.gd")

## Показывает те же основания и южные точки, которые фактически проверяет навигация пасеки.
static func draw(game: Node2D) -> void:
	if game.current_location=="overworld":
		for index in Apiary.Data.SITES.size():
			if Apiary.state(game).hives[index].level>0: game.draw_rect(Apiary.Data.base(Apiary.Data.SITES[index]),Color("ee5360"),false,2)
			game.draw_circle(Apiary.Data.SITES[index]+Vector2(0,48),4,Color("45df78"))
	for entry in Apiary.Data.WILD:
		if entry.location==game.current_location: game.draw_rect(Apiary.Data.base(entry.position),Color("ee5360"),false,2); game.draw_circle(entry.position+Vector2(0,48),4,Color("45df78"))
