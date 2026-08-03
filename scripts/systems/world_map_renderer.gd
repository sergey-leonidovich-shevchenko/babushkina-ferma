extends RefCounted

const WINDOW := Rect2(92, 62, 968, 524)


## Рисует стилизованную карту открытых регионов, текущее положение и сюжетную цель.
static func draw(game: Node2D) -> void:
	if not game.world_map_open: return
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.0, 0.0, 0.0, 0.66))
	game.InterfaceRenderer.panel(game, WINDOW, Color(0.035, 0.065, 0.06, 0.98))
	game.draw_rect(Rect2(118, 112, 916, 418), Color("29483f"), true)
	game.draw_circle(Vector2(680, 300), 215, Color("31584c")); game.draw_circle(Vector2(248, 285), 145, Color("426b4e"))
	for connection in game.WorldMapSystem.CONNECTIONS:
		var start: Vector2 = game.WorldMapSystem.LOCATIONS[connection[0]]
		var finish: Vector2 = game.WorldMapSystem.LOCATIONS[connection[1]]
		game.draw_line(start, finish, Color("a98b5f"), 5.0, true)
	var current: String = game.WorldMapSystem.current_region(game)
	var objective: String = game.WorldMapSystem.objective_region(game)
	for location in game.WorldMapSystem.LOCATIONS:
		var position: Vector2 = game.WorldMapSystem.LOCATIONS[location]
		var discovered: bool = location in game.state.world.estate.discovered
		var color := Color("efc766") if location == current else (Color("d4825b") if location == objective else (Color("8fcf9e") if discovered else Color("52615b")))
		game.draw_circle(position, 17.0, Color("172822")); game.draw_circle(position, 12.0, color)
		var label: String = game.WorldSystem.name(location) if discovered else game.LocaleSystem.ui("map_unknown")
		game.draw_string(game.UI_FONT, position + Vector2(-76, 35), label, HORIZONTAL_ALIGNMENT_CENTER, 152, 13, Color("f8f1dc"))
	game.draw_string(game.UI_FONT, Vector2(122, 94), game.LocaleSystem.ui("world_map"), HORIZONTAL_ALIGNMENT_LEFT, 600, 24, Color("efc766"))
	game.draw_string(game.UI_FONT, Vector2(670, 92), game.LocaleSystem.ui("map_legend"), HORIZONTAL_ALIGNMENT_RIGHT, 350, 13, Color("b9c8b8"))
	game.draw_string(game.UI_FONT, Vector2(320, 565), game.LocaleSystem.ui("map_close"), HORIZONTAL_ALIGNMENT_CENTER, 512, 14, Color("b9c8b8"))
