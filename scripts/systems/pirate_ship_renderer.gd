extends RefCounted

const PirateShipSystem := preload("res://scripts/systems/pirate_ship_system.gd")


## Рисует море, деревянную палубу, борта, мачты, канаты, пушки и пиратский флаг.
static func draw(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(2400, 1200)), Color("173c56"))
	for y in range(85, 1160, 95):
		for x in range(30 + y % 110, 2380, 150):
			canvas.draw_arc(Vector2(x, y), 26, 0.15, PI - 0.15, 10, Color(0.35, 0.72, 0.78, 0.42), 3)
	var hull := PackedVector2Array([Vector2(80,590),Vector2(155,125),Vector2(2150,125),Vector2(2320,590),Vector2(2150,1055),Vector2(155,1055)])
	canvas.draw_colored_polygon(hull, Color("3c211c"))
	var deck := PackedVector2Array([Vector2(130,590),Vector2(205,170),Vector2(2100,170),Vector2(2265,590),Vector2(2100,1010),Vector2(205,1010)])
	canvas.draw_colored_polygon(deck, Color("a86d3f"))
	for y in range(205, 1000, 46): canvas.draw_line(Vector2(190, y), Vector2(2140, y), Color(0.34, 0.18, 0.12, 0.58), 3)
	for x in range(250, 2160, 120): canvas.draw_line(Vector2(x, 185), Vector2(x, 995), Color(0.78, 0.52, 0.30, 0.35), 2)
	canvas.draw_polyline(deck, Color("d09a5f"), 9)
	for mast in PirateShipSystem.MAST_POSITIONS:
		canvas.draw_circle(mast, 40, Color("38231c")); canvas.draw_circle(mast, 29, Color("775035"))
		canvas.draw_line(mast + Vector2(0,-25), mast + Vector2(0,-280), Color("4a2e21"), 18)
		canvas.draw_line(mast + Vector2(-155,-210), mast + Vector2(155,-210), Color("4a2e21"), 12)
		canvas.draw_colored_polygon(PackedVector2Array([mast+Vector2(-145,-200),mast+Vector2(140,-200),mast+Vector2(95,-80),mast+Vector2(-110,-80)]), Color("d8c69d"))
	for cannon in PirateShipSystem.CANNON_RECTS:
		canvas.draw_rect(cannon, Color("4b3529")); canvas.draw_rect(cannon.grow(-11), Color("20282c")); canvas.draw_circle(cannon.position + Vector2(18, cannon.size.y), 9, Color("171a1b")); canvas.draw_circle(cannon.end - Vector2(18, 0), 9, Color("171a1b"))
	canvas.draw_line(Vector2(2070, 520), Vector2(2070, 270), Color("4a2e21"), 14)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(2070,280),Vector2(2220,320),Vector2(2070,380)]), Color("17191d"))
	canvas.draw_circle(Vector2(2120,330), 14, Color("e9e2c9")); canvas.draw_line(Vector2(2106,316),Vector2(2134,344),Color("e9e2c9"),5); canvas.draw_line(Vector2(2134,316),Vector2(2106,344),Color("e9e2c9"),5)
	canvas.draw_string(canvas.UI_FONT, Vector2(210, 115), canvas.LocaleSystem.location("pirate_ship").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("f3d58a"))
