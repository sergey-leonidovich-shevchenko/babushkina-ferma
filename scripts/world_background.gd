extends Node2D

const UI_FONT := preload("res://assets/game/fonts/ui_font.tres")

const WORLD_SIZE := Vector2(2400, 1200)
const RED_MUSHROOMS := preload("res://assets/game/environment/red_mushrooms.png")
const CAVE_CRYSTAL := preload("res://assets/game/environment/cave_crystal.png")
const ROAD_TILE := preload("res://assets/game/tiles/road-brick.png")
const CAVE_FLOOR_TILE := preload("res://assets/game/tiles/cave-floor.png")
const BRIDGES := preload("res://assets/game/environment/bridges.png")
const VILLAGE_PROPS := preload("res://assets/game/environment/village_prop_atlas.png")
const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
const BuildingSystem := preload("res://scripts/systems/building_system.gd")
const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")
const PirateShipRenderer := preload("res://scripts/systems/pirate_ship_renderer.gd")
const VisualAssetSystem := preload("res://scripts/systems/visual_asset_system.gd")

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
	elif location == "pirate_ship": PirateShipRenderer.draw(self)
	elif location == "moon_glade": draw_moon_glade()
	else: draw_adventure_location()

## Отрисовывает редкую ночную локацию, доступную во время Лунного затмения.
func draw_moon_glade() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("24254f"))
	for y in range(150, 1100, 110):
		for x in range(80 + y % 70, 2360, 145):
			draw_circle(Vector2(x, y), 2.5, Color("8171b0"))
	var moon_path := PackedVector2Array([Vector2(220, 430), Vector2(700, 365), Vector2(1140, 595), Vector2(1690, 350), Vector2(2020, 700)])
	draw_polyline(moon_path, Color(0.34, 0.34, 0.62, 0.34), 78.0)
	draw_polyline(moon_path, Color(0.52, 0.48, 0.76, 0.30), 4.0)
	draw_set_transform(Vector2(1370, 900), 0.0, Vector2(1.9, 0.72))
	draw_circle(Vector2.ZERO, 155, Color(0.19, 0.38, 0.58, 0.72))
	draw_circle(Vector2.ZERO, 137, Color(0.35, 0.55, 0.72, 0.26), false, 5.0)
	draw_set_transform(Vector2.ZERO)
	draw_string(UI_FONT, Vector2(80, 100), "ЛУННАЯ ПОЛЯНА", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("e4dbff"))

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
	var names := {"forest":LocaleSystem.location("forest").to_upper(),"rocky":LocaleSystem.location("rocky").to_upper(),"ruins":LocaleSystem.location("ruins").to_upper(),"cursed":LocaleSystem.location("cursed").to_upper(),"glassworks":LocaleSystem.location("glassworks").to_upper()}
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), VisualAssetSystem.background(location))
	for y in range(150, 1100, 120):
		for x in range(70 + (y % 90), 2360, 150):
			draw_circle(Vector2(x, y), 2.5, VisualAssetSystem.background(location).lightened(0.12))
	VisualAssetSystem.draw_biome(self, location)
	draw_string(UI_FONT, Vector2(80, 100), names.get(location, location), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("fff0bd"))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_overworld() -> void:
	# Базовый луг остаётся дешёвым тайловым слоем, поверх которого лежат маршруты и объекты.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("6f9d50"))
	draw_meadow_texture()
	draw_village_water()
	# Связная сеть широких дорог повторяет прогрессию «дом — деревня — приключение».
	for path in VillageLayoutSystem.PATHS:
		draw_village_route(path)
	draw_rect(BuildingSystem.VILLAGE_SQUARE, Color("9e8059"))
	draw_texture_rect(ROAD_TILE, BuildingSystem.VILLAGE_SQUARE.grow(-8), true, Color(1, 1, 1, 0.56))
	# Огород собран в отдельный ухоженный двор с оградой и калиткой к дороге.
	draw_rect(Rect2(382, 190, 340, 290), Color("648e49"))
	draw_fence(BuildingSystem.FARM_YARD_RECT, Vector2(588, 490))
	# Спрайтовый мост остаётся единственным безопасным переходом через южную реку.
	draw_texture_rect_region(BRIDGES, Rect2(1450, 805, 110, 395), Rect2(218, 335, 78, 145))
	draw_village_props()
	# Лавка сбыта стоит на площади и читается как отдельный сервис, а не второй магазин.
	draw_rect(BuildingSystem.SELL_CRATE_RECT, Color("8b5835"))
	for i in 3:
		draw_line(BuildingSystem.SELL_CRATE_RECT.position + Vector2(4, 10 + i * 15), BuildingSystem.SELL_CRATE_RECT.position + Vector2(56, 10 + i * 15), Color("c78d4e"), 4)
	draw_string(UI_FONT, BuildingSystem.SELL_CRATE_POSITION + Vector2(-58, 45), LocaleSystem.ui("sell_sign"), HORIZONTAL_ALIGNMENT_CENTER, 116, 15, Color("293c2f"))
	# Динамические деревья рисует игровой слой: после рубки здесь остаётся видимый пень.
	draw_texture_rect(RED_MUSHROOMS, Rect2(1680,650,72,72), false)


## Заполняет луг редкими детерминированными травинками и цветами без заметной сетки.
func draw_meadow_texture() -> void:
	for y in range(130, 850, 84):
		for x in range(48 + (y * 7) % 73, int(WORLD_SIZE.x), 108):
			var tuft := Vector2(x, y)
			draw_line(tuft + Vector2(-4, 5), tuft, Color("4f7e3d"), 2)
			draw_line(tuft + Vector2(4, 5), tuft, Color("4f7e3d"), 2)
	for patch in VillageLayoutSystem.FLOWER_PATCHES:
		for petal in 5:
			var offset := Vector2((petal % 3 - 1) * 9, (petal / 3) * 9 - 4)
			draw_circle(patch + offset, 3.0, Color("f4c4cf") if petal % 2 == 0 else Color("f2df8b"))
			draw_circle(patch + offset, 1.2, Color("fff2bf"))


## Рисует извилистый берег реки, пруд и спокойные блики отдельным водным слоем.
func draw_village_water() -> void:
	var water_polygon := PackedVector2Array(VillageLayoutSystem.RIVER_BANK)
	water_polygon.append(Vector2(WORLD_SIZE.x, WORLD_SIZE.y))
	water_polygon.append(Vector2(0, WORLD_SIZE.y))
	draw_colored_polygon(water_polygon, Color("3f91aa"))
	draw_polyline(PackedVector2Array(VillageLayoutSystem.RIVER_BANK), Color("d0bd79"), 16.0, true)
	draw_polyline(PackedVector2Array(VillageLayoutSystem.RIVER_BANK), Color("6f9d50"), 6.0, true)
	for x in range(40, int(WORLD_SIZE.x), 92):
		var y := VillageLayoutSystem.river_bank_y(x) + 46 + (x % 4) * 11
		draw_line(Vector2(x, y), Vector2(x + 34, y), Color(0.56, 0.84, 0.86, 0.55), 3)
	draw_set_transform(VillageLayoutSystem.POND_CENTER, 0.0, Vector2(1.8, 1.0))
	draw_circle(Vector2.ZERO, 111, Color("b6a86d"))
	draw_circle(Vector2.ZERO, 105, Color("397f98"))
	draw_circle(Vector2.ZERO, 92, Color("54a3b2"))
	for ripple in [Vector2(-42,-15),Vector2(36,18),Vector2(2,-48)]:
		draw_arc(ripple, 13, 0.2, 2.8, 8, Color(0.70,0.91,0.89,0.62), 2.0)
	draw_set_transform(Vector2.ZERO)


## Рисует криволинейную дорогу с мягким краем и неброскими каменными деталями.
func draw_village_route(points: Array) -> void:
	draw_polyline(PackedVector2Array(points), Color("7f6649"), 108.0, true)
	draw_polyline(PackedVector2Array(points), Color("b39365"), 94.0, true)
	for index in points.size() - 1:
		var start: Vector2 = points[index]
		var finish: Vector2 = points[index + 1]
		var length: float = start.distance_to(finish)
		var stamp_count := maxi(1, floori(length / 52.0))
		for stamp in stamp_count:
			var position: Vector2 = start.lerp(finish, (stamp + 0.5) / float(stamp_count))
			draw_rect(Rect2(position - Vector2(7, 3), Vector2(14, 6)), Color(0.49, 0.39, 0.28, 0.30))


## Расставляет независимые спрайты площади и мельницы из общего атласа четыре на два.
func draw_village_props() -> void:
	var cell_size := Vector2(VILLAGE_PROPS.get_width() / 4.0, VILLAGE_PROPS.get_height() / 2.0)
	for prop in VillageLayoutSystem.PROP_PLACEMENTS:
		var size: Vector2 = prop.size
		var destination := Rect2(prop.position - Vector2(size.x * 0.5, size.y * 0.78), size)
		var source := Rect2(Vector2(VillageLayoutSystem.PROP_CELLS[prop.kind]) * cell_size, cell_size)
		draw_texture_rect_region(VILLAGE_PROPS, destination, source)

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
