extends Node2D

const UI_FONT := preload("res://assets/game/fonts/ui_font.tres")

const WORLD_SIZE := Vector2(2400, 1200)
const FOREST_TREE := preload("res://assets/game/environment/forest_tree.png")
const RED_MUSHROOMS := preload("res://assets/game/environment/red_mushrooms.png")
const CAVE_CRYSTAL := preload("res://assets/game/environment/cave_crystal.png")
const ROAD_TILE := preload("res://assets/game/tiles/road-brick.png")
const CAVE_FLOOR_TILE := preload("res://assets/game/tiles/cave-floor.png")
const BRIDGES := preload("res://assets/game/environment/bridges.png")
const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
const BuildingSystem := preload("res://scripts/systems/building_system.gd")

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
	if BuildingSystem.is_interior(location): draw_interior()
	elif location == "overworld": draw_overworld()
	elif location == "cave": draw_cave()
	else: draw_adventure_location()

## Отрисовывает пол, стены и название отдельной интерьерной локации.
func draw_interior() -> void:
	var data: Dictionary = BuildingSystem.interior(location)
	var room: Rect2 = data.room
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("16191b"))
	draw_rect(room.grow(18), Color("302d2d"))
	draw_rect(room, data.color)
	for y in range(int(room.position.y), int(room.end.y), 48):
		for x in range(int(room.position.x), int(room.end.x), 48):
			var checker := int(x / 48 + y / 48) % 2
			draw_rect(Rect2(x + 2, y + 2, 44, 44), Color(data.color).lightened(0.06 if checker == 0 else 0.0), false, 1)
	draw_string(UI_FONT, room.position + Vector2(28, 46), LocaleSystem.location(location).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, room.size.x - 56, 24, Color("fff0bd"))

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
	# Спокойный луг служит фоном, а редкие кластеры не создают визуальный шум.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("79a957"))
	for y in range(145, 850, 118):
		for x in range(64 + (y % 83), int(WORLD_SIZE.x), 154):
			var tuft := Vector2(x, y)
			draw_line(tuft + Vector2(-5, 6), tuft, Color("5f8d47"), 2)
			draw_line(tuft + Vector2(5, 6), tuft, Color("5f8d47"), 2)
			if (x + y) % 5 == 0:
				draw_circle(tuft - Vector2(0, 3), 2.5, Color("f4d277"))
	# Общая сеть дорожек связывает двор, площадь, пруд, мост и восточную окраину.
	draw_village_path(BuildingSystem.VILLAGE_MAIN_PATH)
	draw_village_path(Rect2(135, 330, 90, 170))
	draw_village_path(Rect2(555, 185, 92, 315))
	draw_village_path(Rect2(985, 330, 90, 220))
	draw_village_path(Rect2(1405, 330, 90, 530))
	draw_village_path(Rect2(610, 510, 92, 220))
	draw_rect(BuildingSystem.VILLAGE_SQUARE, Color("a9865e"))
	draw_texture_rect(ROAD_TILE, BuildingSystem.VILLAGE_SQUARE.grow(-8), true, Color(1, 1, 1, 0.48))
	# Огород собран в отдельный ухоженный двор с оградой и калиткой к дороге.
	draw_rect(Rect2(382, 190, 340, 290), Color("668f49"))
	draw_fence(BuildingSystem.FARM_YARD_RECT, Vector2(588, 490))
	draw_rect(Rect2(0, 860, WORLD_SIZE.x, 340), Color("4f9fb0"))
	for x in range(0, int(WORLD_SIZE.x), 70): draw_line(Vector2(x, 900), Vector2(x + 34, 900), Color("83c9c5"), 3)
	# Пруд возле фермы и спрайтовый мост через южную реку.
	draw_set_transform(Vector2(650, 700), 0.0, Vector2(1.8, 1.0))
	draw_circle(Vector2.ZERO, 105, Color("3f899c"))
	draw_circle(Vector2.ZERO, 92, Color("58a8b4"))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect_region(BRIDGES, Rect2(1450, 805, 110, 395), Rect2(218, 335, 78, 145))
	# Лавка сбыта стоит на площади и читается как отдельный сервис, а не второй магазин.
	draw_rect(BuildingSystem.SELL_CRATE_RECT, Color("8b5835"))
	for i in 3:
		draw_line(BuildingSystem.SELL_CRATE_RECT.position + Vector2(4, 10 + i * 15), BuildingSystem.SELL_CRATE_RECT.position + Vector2(56, 10 + i * 15), Color("c78d4e"), 4)
	draw_string(UI_FONT, BuildingSystem.SELL_CRATE_POSITION + Vector2(-58, 45), LocaleSystem.ui("sell_sign"), HORIZONTAL_ALIGNMENT_CENTER, 116, 15, Color("293c2f"))
	# Динамические деревья рисует игровой слой: после рубки здесь остаётся видимый пень.
	draw_texture_rect(RED_MUSHROOMS, Rect2(1680,650,72,72), false)

## Рисует один участок дороги с мягкой окантовкой и приглушённой каменной фактурой.
func draw_village_path(rect: Rect2) -> void:
	draw_rect(rect.grow(6), Color("8e704f"))
	draw_rect(rect, Color("b69062"))
	draw_texture_rect(ROAD_TILE, rect.grow(-5), true, Color(1, 1, 1, 0.38))

## Рисует ограду двора, оставляя у указанной точки свободную калитку.
func draw_fence(rect: Rect2, gate: Vector2) -> void:
	var fence_color := Color("7a5537")
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), fence_color, 7)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), fence_color, 7)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, fence_color, 7)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(gate.x - 32, rect.end.y), fence_color, 7)
	draw_line(Vector2(gate.x + 32, rect.end.y), rect.end, fence_color, 7)

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
