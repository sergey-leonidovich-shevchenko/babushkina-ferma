extends Node2D

const UI_FONT := preload("res://assets/game/fonts/ui_font.tres")

const WORLD_SIZE := Vector2(2400, 1200)
const GRASS_TILE := preload("res://assets/game/tiles/grass.png")
const GRASS_TILE_VARIANT_1 := preload("res://assets/game/tiles/grass_var_1.png")
const GRASS_TILE_VARIANT_2 := preload("res://assets/game/tiles/grass_var_2.png")
const RED_MUSHROOMS := preload("res://assets/game/environment/red_mushrooms.png")
const CAVE_FLOOR_TILE := preload("res://assets/game/tiles/cave-floor.png")
const FOREST_TREE_GROWTH_ATLAS := preload("res://assets/game/environment/forest_tree_growth_atlas_v1.png")
const VILLAGE_PROPS := preload("res://assets/game/environment/village_prop_atlas_v2.png")
const RESOURCE_ROCK := preload("res://assets/game/resources/rock.png")
const VillageTerrainRenderer := preload("res://scripts/systems/village_terrain_renderer.gd")
const VillageMapPreviewSystem := preload("res://scripts/systems/village_map_preview_system.gd")
const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
const BuildingSystem := preload("res://scripts/systems/building_system.gd")
const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")
const FirstLevelArtSystem := preload("res://scripts/systems/first_level_art_system.gd")
const RoadVisualSystem := preload("res://scripts/systems/road_visual_system.gd")
const WaterVisualSystem := preload("res://scripts/systems/water_visual_system.gd")
const PirateShipRenderer := preload("res://scripts/systems/pirate_ship_renderer.gd")
const VisualAssetSystem := preload("res://scripts/systems/visual_asset_system.gd")
const EnvironmentVisualSystem := preload("res://scripts/systems/environment_visual_system.gd")
const CaveRenderer := preload("res://scripts/systems/cave_renderer.gd")
const DebugPlaygroundSystem := preload("res://scripts/systems/debug_playground_system.gd"); const DebugPlaygroundRenderer := preload("res://scripts/systems/debug_playground_renderer.gd")

const GRASS_VARIANTS := [
	GRASS_TILE,
	GRASS_TILE_VARIANT_1,
	GRASS_TILE_VARIANT_2,
]

var location := "overworld"
var season := "spring"
var weather := "clear"
var terrain_viewport: SubViewport
var terrain_canvas: Node2D
var terrain_ready := false

## Подготавливает узел к работе: создаёт зависимые данные и синхронизирует начальное состояние.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	VillageMapPreviewSystem.warmup()
	if DisplayServer.get_name() != "headless":
		terrain_viewport=SubViewport.new()
		terrain_viewport.size=Vector2i(VillageLayoutSystem.MapData.WORLD_SIZE)
		terrain_viewport.disable_3d=true; terrain_viewport.transparent_bg=true
		terrain_viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		terrain_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		add_child(terrain_viewport)
		terrain_canvas=preload("res://scripts/presentation/village_terrain_canvas.gd").new()
		terrain_canvas.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		terrain_viewport.add_child(terrain_canvas)
		refresh_terrain()

## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
func set_location(value: String) -> void:
	if location != value:
		location = value
		if preload("res://scripts/systems/village_region_data.gd").contains(location): refresh_terrain()
		queue_redraw()

## Синхронизирует сезон и погоду фонового слоя без доступа к изменяемому состоянию игры.
func set_environment(next_season: String, next_weather: String) -> void:
	if season == next_season and weather == next_weather: return
	season = next_season; weather = next_weather; queue_redraw()
	refresh_terrain()

## Инвалидирует только графический кеш земли, оставляя исходные спрайты и коллизии самостоятельными.
func refresh_terrain() -> void:
	if terrain_viewport==null: return
	terrain_ready=false
	terrain_viewport.size=Vector2i(preload("res://scripts/systems/world_bounds_system.gd").size(location))
	terrain_canvas.location=location
	terrain_canvas.season=season; terrain_canvas.weather=weather; terrain_canvas.queue_redraw()
	terrain_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if not RenderingServer.frame_post_draw.is_connected(_terrain_rendered): RenderingServer.frame_post_draw.connect(_terrain_rendered,CONNECT_ONE_SHOT)

## Подменяет готовые команды грунта одним GPU-слоем после реального завершения его отрисовки.
func _terrain_rendered() -> void:
	terrain_ready=true
	if preload("res://scripts/systems/village_region_data.gd").contains(location): queue_redraw()

## Отрисовывает текущее визуальное состояние узла.
func _draw() -> void:
	if BuildingSystem.is_interior(location): draw_interior()
	elif location == "overworld": draw_overworld()
	elif preload("res://scripts/systems/village_region_data.gd").added(location): draw_village_region()
	elif preload("res://scripts/systems/cave_room_data.gd").is_cave(location): draw_cave()
	elif location == "pirate_ship": PirateShipRenderer.draw(self)
	elif location == "moon_glade": draw_moon_glade()
	elif location == DebugPlaygroundSystem.LOCATION: DebugPlaygroundRenderer.draw_background(self)
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

## Рисует только темноту за стенами: само помещение целиком принадлежит интерьерному рендереру.
func draw_interior() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("15191d"))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_adventure_location() -> void:
	var names := {"forest":LocaleSystem.location("forest").to_upper(),"rocky":LocaleSystem.location("rocky").to_upper(),"ruins":LocaleSystem.location("ruins").to_upper(),"cursed":LocaleSystem.location("cursed").to_upper(),"glassworks":LocaleSystem.location("glassworks").to_upper()}
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), EnvironmentVisualSystem.background(location))
	for y in range(150, 1100, 120):
		for x in range(70 + (y % 90), 2360, 150):
			draw_circle(Vector2(x, y), 2.5, EnvironmentVisualSystem.background(location).lightened(0.12))
	EnvironmentVisualSystem.draw_biome(self, location, false)
	draw_string(UI_FONT, Vector2(80, 100), names.get(location, location), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("fff0bd"))

## Отрисовывает соответствующий элемент по текущим данным активной сцены.
func draw_overworld() -> void:
	if terrain_ready and not bool(get_meta("terrain_direct",false)):
		draw_texture_rect(terrain_viewport.get_texture(),Rect2(Vector2.ZERO,VillageLayoutSystem.MapData.WORLD_SIZE),false)
	else: VillageTerrainRenderer.draw(self,season,weather)

## Рисует новую карту деревни из её собственного графического кеша или того же модульного чертежа.
func draw_village_region() -> void:
	if terrain_ready and not bool(get_meta("terrain_direct",false)): draw_texture_rect(terrain_viewport.get_texture(),Rect2(Vector2.ZERO,preload("res://scripts/systems/world_bounds_system.gd").size(location)),false)
	else: preload("res://scripts/presentation/village_region_terrain.gd").draw(self,location,season,weather)


## Выбирает детерминированный вариант травы для старого процедурного режима и тестов палитры.
func _grass_variant(col: int, row: int) -> Texture2D:
	var index: int = abs(col * 31 + row * 17) % GRASS_VARIANTS.size()
	return GRASS_VARIANTS[index]


## Отрисовывает полный тайлмап первой локации, где каждый квадрат получает отдельный спрайт.
func draw_overworld_tile_grid(palette: Dictionary) -> void:
	var tile_size: int = VillageLayoutSystem.OVERWORLD_TILE_SIZE
	var tile_count: Vector2i = VillageLayoutSystem.OVERWORLD_TILE_COUNT
	var road_cells: Dictionary={}; var water_cells: Dictionary={}
	for row in range(tile_count.y):
		for col in range(tile_count.x):
			var cell:=Vector2i(col,row); var type:=VillageLayoutSystem.overworld_tile(cell,season)
			if type==VillageLayoutSystem.OVERWORLD_TILE_ROAD: road_cells[cell]=true
			elif type==VillageLayoutSystem.OVERWORLD_TILE_WATER: water_cells[cell]=true
	var water_animation_frame:=posmod(int(Time.get_ticks_msec()/480),4)
	for row in range(tile_count.y):
		for col in range(tile_count.x):
			var cell:=Vector2i(col,row); var tile_type:=VillageLayoutSystem.overworld_tile(cell,season)
			var destination := Rect2(Vector2(col * tile_size, row * tile_size), Vector2(tile_size, tile_size))
			match tile_type:
				VillageLayoutSystem.OVERWORLD_TILE_GRASS:
					var tint: Color = palette.grass
					var wave: float = fmod((col * 37 + row * 59) * 0.015 + sin((col + row) * 0.2), 1.0)
					tint = tint.lerp(palette.grass_light, clamp(wave, 0.0, 0.25))
					draw_texture_rect(_grass_variant(col, row), destination, false, tint)
				VillageLayoutSystem.OVERWORLD_TILE_ROAD:
					RoadVisualSystem.draw_module(self,RoadVisualSystem.FAMILY_STONE,cell,RoadVisualSystem.neighbor_mask(cell,road_cells),palette.path.darkened(0.1))
				VillageLayoutSystem.OVERWORLD_TILE_FARM:
					draw_texture_rect(CAVE_FLOOR_TILE, destination, true, palette.grass_light.darkened(0.15))
				VillageLayoutSystem.OVERWORLD_TILE_WATER:
					WaterVisualSystem.draw_module(self,cell,water_cells,water_animation_frame,Color(1.0,1.0,1.0,0.92))
				VillageLayoutSystem.OVERWORLD_TILE_STONE:
					draw_texture_rect(CAVE_FLOOR_TILE, destination, false, Color(0.65, 0.66, 0.67, 0.92))
				VillageLayoutSystem.OVERWORLD_TILE_BORDER_ROCK:
					draw_texture_rect(RESOURCE_ROCK, destination, false, Color(1, 1, 1, 0.9))
				_:
					draw_texture_rect(_grass_variant(col, row), destination, false, palette.grass)


## Добавляет лёгкую детализирующую сетку травинок и цветочных пятен, чтобы карта не выглядела плоской.
func draw_meadow_lacing() -> void:
	var seed := 11.37
	for row in range(0, int(WORLD_SIZE.y), 27):
		for col in range(0, int(WORLD_SIZE.x), 31):
			var noise := sin(col * 0.024 + row * 0.031 + seed) * 0.5 + 0.5
			var noise2 := cos(col * 0.041 - row * 0.017 + seed * 1.3) * 0.5 + 0.5
			var pos := Vector2(col + (noise2 - 0.5) * 18.0, row + (noise - 0.5) * 12.0)
			if noise < 0.13 and not VillageLayoutSystem.is_water(pos, 22.0) and not VillageLayoutSystem.is_river_park(pos):
				var shade := Color("4f7e3d").lerp(Color("5f9552"), noise)
				draw_circle(pos, 1.4 + noise2 * 1.5, shade)
				if noise2 < 0.18:
					draw_circle(pos + Vector2(2.5, -3.5), 0.9, Color("efd7a5"))


## Различает кварталы мягкими бордюрами и напольными деталями, не превращая карту в набор прямоугольников.
func draw_village_districts() -> void:
	var palette := VillageLayoutSystem.seasonal_palette(season)
	for district_id in VillageLayoutSystem.DISTRICTS:
		var district: Rect2 = VillageLayoutSystem.DISTRICTS[district_id]
		var tint: Color = palette.grass_light
		if district_id == "market": tint = Color(palette.path).lightened(0.08)
		elif district_id == "guild": tint = Color(palette.grass).darkened(0.07)
		elif district_id == "riverwalk": tint = Color("719a73")
		draw_rect(district.grow(-12), Color(tint, 0.22))
		draw_rect(district.grow(-12), Color(tint).lightened(0.12), false, 3.0)


## Добавляет спокойную жизнь площади: птиц, вывески районов, фонари и сезонные листья.
func draw_village_ambient_life() -> void:
	for spot in VillageLayoutSystem.AMBIENT_SPOTS:
		draw_circle(spot, 4.0, Color("57463d")); draw_line(spot + Vector2(-4,-2), spot + Vector2(-9,-7), Color("57463d"), 2); draw_line(spot + Vector2(4,-2), spot + Vector2(9,-7), Color("57463d"), 2)
	for lamp in VillageLayoutSystem.LANTERNS:
		draw_line(lamp, lamp - Vector2(0,34), Color("594333"), 5); draw_circle(lamp - Vector2(0,39), 8, Color("ffe083") if weather != "rain" else Color("c8d5b4"))
	if season == "autumn":
		for index in 18: draw_circle(Vector2(120 + index * 127, 205 + (index * 83) % 810), 4, Color("cf7545"))
	elif season == "winter":
		for index in 24: draw_circle(Vector2(70 + index * 97, 150 + (index * 61) % 920), 3, Color(0.93,0.97,1.0,0.8))


## Заполняет луг редкими детерминированными травинками и цветами без заметной сетки.
func draw_meadow_texture() -> void:
	for y in range(130, 1140, 84):
		for x in range(48 + (y * 7) % 73, int(WORLD_SIZE.x), 108):
			var tuft := Vector2(x, y)
			draw_line(tuft + Vector2(-4, 5), tuft, Color("4f7e3d"), 2)
			draw_line(tuft + Vector2(4, 5), tuft, Color("4f7e3d"), 2)
	for patch in VillageLayoutSystem.FLOWER_PATCHES:
		for petal in 5:
			var offset := Vector2((petal % 3 - 1) * 9, (petal / 3) * 9 - 4)
			draw_circle(patch + offset, 3.0, Color("f4c4cf") if petal % 2 == 0 else Color("f2df8b"))
			draw_circle(patch + offset, 1.2, Color("fff2bf"))


## Формирует плотную лесную рамку и каменистый угол шахты, как в выбранном концепте локации.
func draw_village_border() -> void:
	for position in VillageLayoutSystem.BORDER_TREES:
		draw_texture_rect_region(FOREST_TREE_GROWTH_ATLAS,Rect2(position-Vector2(96,144),Vector2(192,192)),Rect2(768,0,256,256),Color(0.78,0.94,0.78,0.92))
	for position in VillageLayoutSystem.BORDER_ROCKS:
		draw_texture_rect(RESOURCE_ROCK,Rect2(position-Vector2(36,48),Vector2(72,72)),false,Color("c7c8b5"))


## Рисует извилистый берег реки, пруд и спокойные блики отдельным водным слоем.
func draw_village_water() -> void:
	var upper_bank := PackedVector2Array()
	var lower_bank := PackedVector2Array()
	for point in VillageLayoutSystem.RIVER_CENTER:
		upper_bank.append(point - Vector2(0, VillageLayoutSystem.RIVER_HALF_WIDTH))
		lower_bank.append(point + Vector2(0, VillageLayoutSystem.RIVER_HALF_WIDTH))
	var water_polygon := PackedVector2Array(upper_bank)
	for index in range(lower_bank.size() - 1, -1, -1):
		water_polygon.append(lower_bank[index])
	draw_colored_polygon(water_polygon, Color("3f91aa"))
	draw_polyline(upper_bank, Color("d0bd79"), 12.0, true)
	draw_polyline(lower_bank, Color("d0bd79"), 12.0, true)
	draw_polyline(upper_bank, Color("547f43"), 4.0, true)
	draw_polyline(lower_bank, Color("547f43"), 4.0, true)
	for x in range(40, int(WORLD_SIZE.x), 92):
		var y := VillageLayoutSystem.river_center_y(x) + (x % 3 - 1) * 12
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
	var palette := VillageLayoutSystem.seasonal_palette(season)
	draw_polyline(PackedVector2Array(points), Color("7f6649"), 108.0, true)
	draw_polyline(PackedVector2Array(points), palette.path, 94.0, true)
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
	for prop in VillageLayoutSystem.PROP_PLACEMENTS:
		draw_village_prop(prop)
	for prop in VillageLayoutSystem.SCENIC_PLACEMENTS:
		draw_village_prop(prop)


## Вырезает один объект деревенского атласа; этим же способом собираются крупные ориентиры и мелкий декор.
func draw_village_prop(prop: Dictionary) -> void:
	draw_texture_rect_region(VILLAGE_PROPS,VillageLayoutSystem.prop_rect(prop),VillageLayoutSystem.prop_source_rect(prop.kind))

## Рисует один участок дороги с мягкой окантовкой и приглушённой каменной фактурой.
func draw_village_path(rect: Rect2) -> void:
	draw_rect(rect.grow(6), Color("8e704f"))
	draw_rect(rect, Color("b69062"))
	draw_texture_rect(RoadVisualSystem.texture(RoadVisualSystem.FAMILY_STONE,"cross"),rect.grow(-5),true,Color(1,1,1,0.38))

## Рисует ограду двора, оставляя у указанной точки свободную калитку.
func draw_fence(rect: Rect2, gate: Vector2) -> void:
	var fence_color := Color("7a5537")
	if is_equal_approx(gate.y, rect.position.y):
		draw_line(rect.position, Vector2(gate.x - 32, rect.position.y), fence_color, 7)
		draw_line(Vector2(gate.x + 32, rect.position.y), Vector2(rect.end.x, rect.position.y), fence_color, 7)
	else:
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), fence_color, 7)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), fence_color, 7)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, fence_color, 7)
	if is_equal_approx(gate.y, rect.end.y):
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(gate.x - 32, rect.end.y), fence_color, 7)
		draw_line(Vector2(gate.x + 32, rect.end.y), rect.end, fence_color, 7)
	else:
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, fence_color, 7)

## Собирает пещеру из общего контура, повторяемого пола и отдельных модульных спрайтов.
func draw_cave() -> void:
	CaveRenderer.draw_background(self)
