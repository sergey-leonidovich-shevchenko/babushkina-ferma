extends RefCounted

const RIVER_CENTER := [
	Vector2(260, 80), Vector2(330, 300), Vector2(500, 500), Vector2(700, 650),
	Vector2(980, 740), Vector2(1250, 760), Vector2(1550, 825), Vector2(1800, 920),
	Vector2(2050, 1050), Vector2(2400, 1160),
]
const RIVER_HALF_WIDTH := 58.0
const POND_CENTER := Vector2(1560, 850)
const POND_RADII := Vector2(150, 82)
const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
const BRIDGE_SIZE := WorldVisualProfileSystem.PROFILES.bridge.visual_size
const BRIDGES := [Rect2(592, 444, 96, 192), Rect2(1352, 714, 96, 192)]
const BRIDGE_RENDER_OFFSETS := [Vector2.ZERO, Vector2.ZERO]
const BRIDGE_RENDER_SIZES := [BRIDGE_SIZE, BRIDGE_SIZE]
const DISTRICTS := {
	"homestead":Rect2(38, 690, 720, 490), "farm":Rect2(38, 830, 420, 350),
	"market":Rect2(1120, 250, 560, 350), "guild":Rect2(1780, 120, 500, 430),
	"riverwalk":Rect2(720, 610, 980, 300), "east_grove":Rect2(1760, 320, 620, 760),
}
const DISTRICT_LABELS := {"homestead":"УСАДЬБА","farm":"ФЕРМА","market":"РЫНОК","guild":"ГИЛЬДИЯ","riverwalk":"НАБЕРЕЖНАЯ","east_grove":"ВОСТОЧНАЯ РОЩА"}
const PATHS := [
	[Vector2(420,790),Vector2(520,710),Vector2(640,610),Vector2(650,500),Vector2(840,430),Vector2(1120,440),Vector2(1480,390),Vector2(1740,420),Vector2(2110,250)],
	[Vector2(240,1090),Vector2(250,880),Vector2(420,790)],
	[Vector2(1480,520),Vector2(1480,390)],
	[Vector2(1740,420),Vector2(1920,540),Vector2(2110,250)],
	[Vector2(1120,440),Vector2(920,300),Vector2(760,210),Vector2(620,170),Vector2(480,180)],
	[Vector2(1120,440),Vector2(1430,270),Vector2(1730,150)],
	[Vector2(1480,520),Vector2(1540,690),Vector2(1400,810),Vector2(1720,900),Vector2(2020,1010),Vector2(2260,1080)],
	[Vector2(1400,810),Vector2(1560,850)],
	[Vector2(1120,440),Vector2(1050,390)],
]
const WELL_POSITION := Vector2(1050, 390)
const PROP_CELLS := {
	"well":Vector2i(0,0), "bench":Vector2i(1,0), "lamp":Vector2i(2,0), "board":Vector2i(3,0),
	"cart":Vector2i(0,1), "fence":Vector2i(1,1), "gate":Vector2i(2,1), "mill":Vector2i(3,1),
}
const PROP_PROFILES := {"well":"village_well","bench":"village_bench","lamp":"village_lamp","board":"village_board","cart":"village_cart","fence":"village_fence","gate":"village_gate","mill":"village_mill"}
const PROP_ATLAS_CELL := Vector2(512,512)
const PROP_PLACEMENTS := [
	{"kind":"well","position":WELL_POSITION,"solid":true},
	{"kind":"bench","position":Vector2(1030,585)},
	{"kind":"bench","position":Vector2(1450,585)},
	{"kind":"lamp","position":Vector2(875,535)},
	{"kind":"lamp","position":Vector2(1640,535)},
	{"kind":"board","position":Vector2(1335,460)},
	{"kind":"cart","position":Vector2(915,455),"solid":true},
	{"kind":"mill","position":Vector2(2010,745),"solid":true},
]
# Небольшой неколлизионный декор уплотняет видимый кадр между ключевыми объектами, не создавая невидимых стен.
const SCENIC_PLACEMENTS := [
	{"kind":"bench","position":Vector2(520,430)},
	{"kind":"lamp","position":Vector2(690,520)},
	{"kind":"fence","position":Vector2(470,1010)},
	{"kind":"fence","position":Vector2(545,1010)},
	{"kind":"gate","position":Vector2(625,1010)},
	{"kind":"cart","position":Vector2(1120,720)},
	{"kind":"bench","position":Vector2(1515,435)},
	{"kind":"lamp","position":Vector2(1780,475)},
	{"kind":"board","position":Vector2(1910,860)},
	{"kind":"fence","position":Vector2(2160,930)},
]
const MASTER_SOLID_RECTS := [
	Rect2(250,120,230,260), Rect2(730,120,260,230), Rect2(1490,120,380,105),
	Rect2(2240,120,160,780), Rect2(1760,570,250,150), Rect2(1970,890,250,190),
]
const FLOWER_PATCHES := [
	Vector2(290,820),Vector2(420,780),Vector2(900,680),Vector2(1040,740),Vector2(1320,760),
	Vector2(1600,790),Vector2(1880,420),Vector2(2140,390),Vector2(930,310),Vector2(1520,290),
	Vector2(360,430),Vector2(560,560),Vector2(760,430),Vector2(1160,320),Vector2(1370,650),
	Vector2(1680,430),Vector2(1960,520),Vector2(2210,560),Vector2(1850,920),Vector2(1180,980),
]
const SpatialGridSystem := preload("res://scripts/systems/spatial_grid_system.gd")
const OVERWORLD_TILE_SIZE := SpatialGridSystem.BASE_CELL
const OVERWORLD_TILE_COUNT := Vector2i(100, 50)
const OVERWORLD_TILE_GRASS := 0
const OVERWORLD_TILE_ROAD := 1
const OVERWORLD_TILE_FARM := 2
const OVERWORLD_TILE_WATER := 3
const OVERWORLD_TILE_STONE := 4
const OVERWORLD_TILE_BORDER_ROCK := 5

## Возвращает координаты ячейки сетки (0-based) для центра тайла.
static func tile_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * OVERWORLD_TILE_SIZE + Vector2(OVERWORLD_TILE_SIZE * 0.5, OVERWORLD_TILE_SIZE * 0.5)


## Возвращает видимый прямоугольник деревенского объекта с общей линией земли.
static func prop_rect(prop: Dictionary) -> Rect2:
	return WorldVisualProfileSystem.visual_rect(String(PROP_PROFILES[prop.kind]),Vector2(prop.position)+Vector2(0,24))


## Возвращает одну из восьми целых ячеек нормализованного деревенского атласа.
static func prop_source_rect(kind: String) -> Rect2:
	return Rect2(Vector2(PROP_CELLS[kind])*PROP_ATLAS_CELL,PROP_ATLAS_CELL)


## Возвращает основание только действительно твёрдого размещения, не превращая мелкий декор в стены.
static func prop_collision_rect(prop: Dictionary) -> Rect2:
	if not bool(prop.get("solid",false)): return Rect2()
	return WorldVisualProfileSystem.collision_rect(String(PROP_PROFILES[prop.kind]),Vector2(prop.position)+Vector2(0,24))

## Возвращает тип тайла по позиции ячейки, учитывая сезон и особенности ландшафта.
static func overworld_tile(cell: Vector2i, season: String = "spring") -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= OVERWORLD_TILE_COUNT.x or cell.y >= OVERWORLD_TILE_COUNT.y:
		return OVERWORLD_TILE_GRASS
	var position := tile_center(cell)
	var seasonal_bonus := season == "winter"
	if is_water(position, 0.0):
		return OVERWORLD_TILE_STONE if seasonal_bonus else OVERWORLD_TILE_WATER
	if is_road_or_path(position):
		return OVERWORLD_TILE_ROAD
	if is_farm_zone(position):
		return OVERWORLD_TILE_FARM
	if is_border_rock(position) and seasonal_bonus:
		return OVERWORLD_TILE_BORDER_ROCK
	if is_border_zone(cell):
		return OVERWORLD_TILE_BORDER_ROCK
	return OVERWORLD_TILE_GRASS

## Проверяет, попала ли точка в воду или пруд, но игнорирует мосты как ходовые точки.
static func is_river_park(position: Vector2) -> bool:
	var has_bridge := is_on_bridge(position, OVERWORLD_TILE_SIZE * 0.2)
	return ((absf(position.y - river_center_y(position.x)) < RIVER_HALF_WIDTH + 5.0) and not has_bridge)

## Проверяет, принадлежит ли область позиции зоне внутренней фермы.
static func is_farm_zone(position: Vector2) -> bool:
	var farm_zone := Rect2(490, 805, 360, 315)
	var gate := Vector2(540, 905)
	return farm_zone.has_point(position) and not farm_zone.intersects(Rect2(gate - Vector2(40, 0), Vector2(90, 20)))

## Возвращает, нужно ли рисовать бордюрный камень в зависимости от координаты.
static func is_border_zone(cell: Vector2i) -> bool:
	return cell.x < 2 or cell.x > OVERWORLD_TILE_COUNT.x - 3 or cell.y < 2 or cell.y > OVERWORLD_TILE_COUNT.y - 3

## Возвращает признак участка, который должен выглядеть как дорога/тропа.
static func is_road_or_path(position: Vector2) -> bool:
	for path in PATHS:
		for index in path.size() - 1:
			if distance_to_segment(position, path[index], path[index + 1]) <= 34.0:
				return true
	return false

## Возвращает бордюры и каменистую кромку вдоль карты.
static func is_border_rock(position: Vector2) -> bool:
	var margin := 34.0
	if position.x < margin or position.x > 2400.0 - margin:
		return true
	if position.y < 170.0 or position.y > 1160.0:
		return true
	return false

const LANTERNS := [Vector2(805,535),Vector2(1050,620),Vector2(1450,620),Vector2(1790,555),Vector2(1790,825)]
const AMBIENT_SPOTS := [Vector2(1010,430),Vector2(1130,565),Vector2(1390,555),Vector2(1570,440),Vector2(910,760),Vector2(1650,790)]
const BORDER_TREES := [Vector2(60,175),Vector2(190,155),Vector2(330,170),Vector2(520,145),Vector2(700,165),Vector2(1710,155),Vector2(1870,145),Vector2(2040,165),Vector2(2210,145),Vector2(2350,175),Vector2(65,390),Vector2(2335,430),Vector2(70,850),Vector2(2325,890)]
const BORDER_ROCKS := [Vector2(70,245),Vector2(120,220),Vector2(175,205),Vector2(225,230),Vector2(95,300)]


## Возвращает район, содержащий мировую точку, либо пустую строку вне деревенских кварталов.
static func district_at(position: Vector2) -> String:
	for district_id in DISTRICTS:
		if DISTRICTS[district_id].has_point(position): return district_id
	return ""


## Возвращает сезонную палитру земли, тропы и растительности первой локации.
static func seasonal_palette(season: String) -> Dictionary:
	return {
		"spring":{"grass":Color("6f9d50"),"grass_light":Color("88ae5d"),"path":Color("b79a6d"),"leaf":Color("6f9d50")},
		"summer":{"grass":Color("649348"),"grass_light":Color("7fa650"),"path":Color("b99a68"),"leaf":Color("4f843e")},
		"autumn":{"grass":Color("819451"),"grass_light":Color("a6a65b"),"path":Color("ad8058"),"leaf":Color("b86c3f")},
		"winter":{"grass":Color("aab9aa"),"grass_light":Color("cbd4c9"),"path":Color("a99d8c"),"leaf":Color("75887c")},
	}.get(season, {})


## Возвращает высоту центральной линии извилистой реки для указанной координаты X.
static func river_center_y(x: float) -> float:
	var bounded_x := clampf(x, RIVER_CENTER[0].x, RIVER_CENTER[-1].x)
	for index in RIVER_CENTER.size() - 1:
		var left: Vector2 = RIVER_CENTER[index]
		var right: Vector2 = RIVER_CENTER[index + 1]
		if bounded_x <= right.x:
			return lerpf(left.y, right.y, inverse_lerp(left.x, right.x, bounded_x))
	return RIVER_CENTER[-1].y


## Проверяет, разрешает ли мост пройти над водой в переданной точке.
static func is_on_bridge(position: Vector2, margin: float = 0.0) -> bool:
	for bridge_index in BRIDGES.size():
		if bridge_navigation_rect(bridge_index).grow(margin).has_point(position):
			return true
	return false


## Возвращает непрерывную полосу прохода, которая точно совпадает с утверждённым прямоугольником настила.
static func bridge_navigation_rect(index: int) -> Rect2:
	return BRIDGES[index % BRIDGES.size()]


## Возвращает центр ближайшего моста к позиции; полезно для одной и той же
## подсказки «перейди по мосту», даже если в сцене несколько переходов.
static func nearest_bridge_center(position: Vector2) -> Vector2:
	var nearest_center: Vector2 = BRIDGES[0].get_center()
	var nearest_distance: float = nearest_center.distance_to(position)
	for index in range(1, BRIDGES.size()):
		var candidate_center: Vector2 = BRIDGES[index].get_center()
		var candidate_distance: float = position.distance_to(candidate_center)
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			nearest_center = candidate_center
	return nearest_center


## Возвращает дополнительный визуальный сдвиг рендера моста относительно коллизионного прямоугольника.
static func bridge_sprite_offset(index: int) -> Vector2:
	if BRIDGE_RENDER_OFFSETS.is_empty():
		return Vector2.ZERO
	return BRIDGE_RENDER_OFFSETS[index % BRIDGE_RENDER_OFFSETS.size()]


## Возвращает фактический прямоугольник рендера каждого моста, учитывая его размер на спрайте и сдвиг.
static func bridge_render_rect(bridge_index: int) -> Rect2:
	var source_size: Vector2 = BRIDGE_RENDER_SIZES[bridge_index % BRIDGE_RENDER_SIZES.size()]
	var rect: Rect2 = BRIDGES[bridge_index]
	var centered_position: Vector2 = rect.position + (rect.size - source_size) * 0.5
	return Rect2(centered_position + bridge_sprite_offset(bridge_index), source_size)


## Проверяет попадание круглого объекта в реку или фермерский пруд с учётом мостов.
static func is_water(position: Vector2, radius: float) -> bool:
	# Мост перекрывает и русло, и расширение пруда: раньше пруд повторно
	# блокировал вторую половину большого моста даже внутри разрешённой полосы.
	if is_on_bridge(position): return false
	if absf(position.y - river_center_y(position.x)) < RIVER_HALF_WIDTH + radius:
		return true
	var pond_delta := position - POND_CENTER
	return pow(pond_delta.x / (POND_RADII.x + radius), 2.0) + pow(pond_delta.y / (POND_RADII.y + radius), 2.0) < 1.0


## Проверяет столкновение с крупным декором площади, который не является частью зданий.
static func blocks_scenic_prop(position: Vector2, radius: float) -> bool:
	for prop in PROP_PLACEMENTS:
		var prop_collision:Rect2=prop_collision_rect(prop)
		if prop_collision.has_area():
			var prop_closest:=Vector2(clampf(position.x,prop_collision.position.x,prop_collision.end.x),clampf(position.y,prop_collision.position.y,prop_collision.end.y))
			if position.distance_squared_to(prop_closest)<radius*radius: return true
	for rect in MASTER_SOLID_RECTS:
		var closest := Vector2(clampf(position.x, rect.position.x, rect.end.x), clampf(position.y, rect.position.y, rect.end.y))
		if position.distance_squared_to(closest) < radius * radius:
			return true
	return false


## Возвращает минимальное расстояние от точки до одного отрезка маршрута.
static func distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


## Проверяет, связан ли ориентир с читаемой дорожной сетью в заданном радиусе.
static func path_reaches(point: Vector2, margin: float = 70.0) -> bool:
	for path in PATHS:
		for index in path.size() - 1:
			if distance_to_segment(point, path[index], path[index + 1]) <= margin:
				return true
	return false
