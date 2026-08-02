extends Node2D

const WORLD_SIZE := Vector2(2400, 1200)
const PLANT_SHEET := preload("res://assets/game/environment/farm_plants.png")
const FOREST_TREE := preload("res://assets/game/environment/forest_tree.png")
const RED_MUSHROOMS := preload("res://assets/game/environment/red_mushrooms.png")
const CAVE_CRYSTAL := preload("res://assets/game/environment/cave_crystal.png")

var location := "overworld"

func set_location(value: String) -> void:
	if location != value:
		location = value
		queue_redraw()

func _draw() -> void:
	if location == "cave": draw_cave()
	else: draw_overworld()

func draw_overworld() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("7fad5c"))
	for y in range(150, int(WORLD_SIZE.y), 190):
		for x in range(70 + (y % 140), int(WORLD_SIZE.x), 210):
			draw_circle(Vector2(x, y), 3.0, Color("99bd6a"))
	draw_rect(Rect2(0, 860, WORLD_SIZE.x, 340), Color("4f9fb0"))
	for x in range(0, int(WORLD_SIZE.x), 70): draw_line(Vector2(x, 900), Vector2(x + 34, 900), Color("83c9c5"), 3)
	# Дом, лавка и ящик продажи.
	draw_rect(Rect2(54, 130, 190, 150), Color("e5c478"))
	draw_colored_polygon(PackedVector2Array([Vector2(38,145), Vector2(149,72), Vector2(260,145)]), Color("9c5338"))
	draw_rect(Rect2(128, 216, 43, 64), Color("6b4328"))
	draw_string(ThemeDB.fallback_font, Vector2(66, 308), "ДОМ • сон [N]", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	draw_rect(Rect2(910, 194, 128, 98), Color("f3d88e"))
	draw_rect(Rect2(895, 175, 158, 30), Color("d66b45"))
	draw_string(ThemeDB.fallback_font, Vector2(913, 238), "СЕМЕНА", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("55382b"))
	draw_string(ThemeDB.fallback_font, Vector2(905, 320), "Лавка [B]", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	draw_texture_rect_region(PLANT_SHEET, Rect2(270, 126, 290, 90), Rect2(94, 0, 290, 90))
	draw_rect(Rect2(790, 392, 60, 54), Color("9c633b"))
	for i in 3: draw_line(Vector2(794, 402 + i * 15), Vector2(846, 402 + i * 15), Color("d09755"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(753, 473), "Продажа [E]", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# Дорога и лес рисуются один раз и затем только сдвигаются transform-ом.
	draw_rect(Rect2(1030, 360, 1370, 150), Color("b68b5c"))
	for x in range(1080, 2380, 110): draw_circle(Vector2(x, 430), 6, Color("94704f"))
	var trees := [Vector2(1210,190), Vector2(1430,250), Vector2(1740,170), Vector2(1990,290), Vector2(2240,180), Vector2(1320,680), Vector2(1880,720), Vector2(2210,650)]
	for tree in trees: draw_texture_rect(FOREST_TREE, Rect2(tree - Vector2(96,128), Vector2(192,192)), false)
	draw_texture_rect(RED_MUSHROOMS, Rect2(1380,570,72,72), false)

func draw_cave() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("18232c"))
	for y in range(100, int(WORLD_SIZE.y), 230):
		for x in range(80, int(WORLD_SIZE.x), 260): draw_circle(Vector2(x + (y % 160), y), 4, Color("34434b"))
	draw_circle(Vector2(180,430), 54, Color("0e151a"))
	draw_circle(Vector2(180,430), 40, Color("b1e4d5"), false, 5)
	var crystals := [Vector2(480,250), Vector2(720,600), Vector2(1040,300), Vector2(1380,720), Vector2(1720,280), Vector2(2050,620)]
	for crystal in crystals:
		draw_texture_rect(CAVE_CRYSTAL, Rect2(crystal - Vector2(32,32), Vector2(64,64)), false)
		draw_circle(crystal, 42, Color(0.35,0.95,0.85,0.12))
	draw_string(ThemeDB.fallback_font, Vector2(90,100), "КРИСТАЛЬНАЯ ПЕЩЕРА", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("9ce9dd"))
