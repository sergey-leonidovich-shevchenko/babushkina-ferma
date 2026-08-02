extends Node2D

const UI_FONT := preload("res://assets/game/fonts/ui_font.tres")

const WORLD_SIZE := Vector2(2400, 1200)
const PLANT_SHEET := preload("res://assets/game/environment/farm_plants.png")
const FOREST_TREE := preload("res://assets/game/environment/forest_tree.png")
const RED_MUSHROOMS := preload("res://assets/game/environment/red_mushrooms.png")
const CAVE_CRYSTAL := preload("res://assets/game/environment/cave_crystal.png")
const GRASS_TILE := preload("res://assets/game/tiles/grass.png")
const ROAD_TILE := preload("res://assets/game/tiles/road-brick.png")
const CAVE_FLOOR_TILE := preload("res://assets/game/tiles/cave-floor.png")
const BRIDGES := preload("res://assets/game/environment/bridges.png")
const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

var location := "overworld"

## Подготавливает узел к работе: создаёт зависимые данные и синхронизирует начальное состояние.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
func set_location(value: String) -> void:
	if location != value:
		location = value
		queue_redraw()

## Отрисовывает текущее визуальное состояние узла.
func _draw() -> void:
	if location == "overworld": draw_overworld()
	elif location == "cave": draw_cave()
	else: draw_adventure_location()

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_adventure_location() -> void:
	var colors := {"forest":Color("315c3c"),"rocky":Color("6f6a5b"),"ruins":Color("665849"),"cursed":Color("3e304b"),"glassworks":Color("6f493b")}
	var names := {"forest":LocaleSystem.location("forest").to_upper(),"rocky":LocaleSystem.location("rocky").to_upper(),"ruins":LocaleSystem.location("ruins").to_upper(),"cursed":LocaleSystem.location("cursed").to_upper(),"glassworks":LocaleSystem.location("glassworks").to_upper()}
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), colors.get(location, Color("48624a")))
	for y in range(140, 1100, 180):
		for x in range(100 + (y % 120), 2300, 220):
			if location == "forest": draw_texture_rect(FOREST_TREE, Rect2(x - 45, y - 70, 90, 90), false)
			elif location in ["rocky","ruins"]: draw_circle(Vector2(x,y), 28, Color("8f8875"))
			elif location == "cursed": draw_circle(Vector2(x,y), 8, Color("8d6aa0"))
			else: draw_rect(Rect2(x - 20,y - 35,40,70), Color("b86f4d"))
	draw_string(UI_FONT, Vector2(80, 100), names.get(location, location), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("fff0bd"))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_overworld() -> void:
	# Один повторяющийся графический тайл вместо одноцветного пола и тысяч команд отрисовки.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("6f9d50"))
	draw_texture_rect(GRASS_TILE, Rect2(Vector2.ZERO, WORLD_SIZE), true)
	draw_rect(Rect2(0, 860, WORLD_SIZE.x, 340), Color("4f9fb0"))
	for x in range(0, int(WORLD_SIZE.x), 70): draw_line(Vector2(x, 900), Vector2(x + 34, 900), Color("83c9c5"), 3)
	# Пруд возле фермы и спрайтовый мост через южную реку.
	draw_set_transform(Vector2(650, 700), 0.0, Vector2(1.8, 1.0))
	draw_circle(Vector2.ZERO, 105, Color("3f899c"))
	draw_circle(Vector2.ZERO, 92, Color("58a8b4"))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect_region(BRIDGES, Rect2(1450, 805, 110, 395), Rect2(218, 335, 78, 145))
	# Дом, лавка и ящик продажи.
	draw_rect(Rect2(54, 130, 190, 150), Color("e5c478"))
	draw_colored_polygon(PackedVector2Array([Vector2(38,145), Vector2(149,72), Vector2(260,145)]), Color("9c5338"))
	draw_rect(Rect2(128, 216, 43, 64), Color("6b4328"))
	draw_string(UI_FONT, Vector2(66, 308), LocaleSystem.ui("home"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	draw_rect(Rect2(910, 194, 128, 98), Color("f3d88e"))
	draw_rect(Rect2(895, 175, 158, 30), Color("d66b45"))
	draw_string(UI_FONT, Vector2(913, 238), LocaleSystem.ui("seeds_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("55382b"))
	draw_string(UI_FONT, Vector2(905, 320), LocaleSystem.ui("shop_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	draw_texture_rect_region(PLANT_SHEET, Rect2(270, 126, 290, 90), Rect2(94, 0, 290, 90))
	draw_rect(Rect2(790, 392, 60, 54), Color("9c633b"))
	for i in 3: draw_line(Vector2(794, 402 + i * 15), Vector2(846, 402 + i * 15), Color("d09755"), 4)
	draw_string(UI_FONT, Vector2(753, 473), LocaleSystem.ui("sell_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# Дорога и лес рисуются один раз и затем только сдвигаются преобразованием узла.
	draw_rect(Rect2(1030, 360, 1370, 150), Color("b68b5c"))
	draw_texture_rect(ROAD_TILE, Rect2(1030, 360, 1370, 150), true)
	var trees := [Vector2(1210,190), Vector2(1430,250), Vector2(1740,170), Vector2(1990,290), Vector2(2240,180), Vector2(1320,680), Vector2(1880,720), Vector2(2210,650)]
	for tree in trees: draw_texture_rect(FOREST_TREE, Rect2(tree - Vector2(96,128), Vector2(192,192)), false)
	draw_texture_rect(RED_MUSHROOMS, Rect2(1380,570,72,72), false)

## Отрисовывает пещеры по текущему состоянию игры.
func draw_cave() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("18232c"))
	draw_texture_rect(CAVE_FLOOR_TILE, Rect2(Vector2.ZERO, WORLD_SIZE), true, Color(0.72, 0.78, 0.8, 1.0))
	draw_circle(Vector2(180,430), 54, Color("0e151a"))
	draw_circle(Vector2(180,430), 40, Color("b1e4d5"), false, 5)
	var crystals := [Vector2(480,250), Vector2(720,600), Vector2(1040,300), Vector2(1380,720), Vector2(1720,280), Vector2(2050,620)]
	for crystal in crystals:
		draw_texture_rect(CAVE_CRYSTAL, Rect2(crystal - Vector2(32,32), Vector2(64,64)), false)
		draw_circle(crystal, 42, Color(0.35,0.95,0.85,0.12))
	draw_string(UI_FONT, Vector2(90,100), LocaleSystem.location("cave").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("9ce9dd"))
