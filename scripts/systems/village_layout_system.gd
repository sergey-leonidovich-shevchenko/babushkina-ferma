extends RefCounted

const RIVER_CENTER := [
	Vector2(0, 640), Vector2(260, 665), Vector2(520, 635), Vector2(800, 665),
	Vector2(1080, 690), Vector2(1350, 675), Vector2(1600, 705), Vector2(1840, 665),
	Vector2(2140, 645), Vector2(2400, 620),
]
const RIVER_HALF_WIDTH := 37.0
const POND_CENTER := Vector2(1550, 965)
const POND_RADII := Vector2(185, 108)
const BRIDGES := [Rect2(755, 575, 100, 190), Rect2(1740, 585, 100, 190)]
const DISTRICTS := {
	"homestead":Rect2(120, 760, 760, 390), "farm":Rect2(470, 790, 410, 350),
	"market":Rect2(850, 255, 390, 350), "guild":Rect2(1240, 255, 430, 350),
	"riverwalk":Rect2(830, 610, 880, 250), "east_grove":Rect2(1710, 240, 620, 760),
}
const DISTRICT_LABELS := {"homestead":"УСАДЬБА","farm":"ФЕРМА","market":"РЫНОК","guild":"ГИЛЬДИЯ","riverwalk":"НАБЕРЕЖНАЯ","east_grove":"ВОСТОЧНАЯ РОЩА"}
const PATHS := [
	[Vector2(330,950),Vector2(430,900),Vector2(670,820),Vector2(805,745),Vector2(805,610),Vector2(940,555),Vector2(1200,515),Vector2(1450,515),Vector2(1650,530)],
	[Vector2(670,1085),Vector2(670,820)],
	[Vector2(1050,515),Vector2(1050,370)],
	[Vector2(1450,515),Vector2(1450,370)],
	[Vector2(1200,515),Vector2(930,420),Vector2(650,350),Vector2(390,315),Vector2(180,280)],
	[Vector2(1450,515),Vector2(1650,530),Vector2(1790,610),Vector2(1790,740),Vector2(1990,695),Vector2(2200,760)],
	[Vector2(1790,740),Vector2(1660,825),Vector2(1550,825)],
	[Vector2(1200,515),Vector2(1240,560)],
]
const WELL_POSITION := Vector2(1240, 545)
const PROP_CELLS := {
	"well":Vector2i(0,0), "bench":Vector2i(1,0), "lamp":Vector2i(2,0), "board":Vector2i(3,0),
	"cart":Vector2i(0,1), "fence":Vector2i(1,1), "gate":Vector2i(2,1), "mill":Vector2i(3,1),
}
const PROP_PLACEMENTS := [
	{"kind":"well","position":WELL_POSITION,"size":Vector2(112,112)},
	{"kind":"bench","position":Vector2(1030,585),"size":Vector2(104,72)},
	{"kind":"bench","position":Vector2(1450,585),"size":Vector2(104,72)},
	{"kind":"lamp","position":Vector2(875,535),"size":Vector2(58,112)},
	{"kind":"lamp","position":Vector2(1640,535),"size":Vector2(58,112)},
	{"kind":"board","position":Vector2(1335,460),"size":Vector2(110,104)},
	{"kind":"cart","position":Vector2(915,455),"size":Vector2(112,88)},
	{"kind":"mill","position":Vector2(2010,745),"size":Vector2(270,250)},
]
# Небольшой неколлизионный декор уплотняет видимый кадр между ключевыми объектами, не создавая невидимых стен.
const SCENIC_PLACEMENTS := [
	{"kind":"bench","position":Vector2(520,430),"size":Vector2(78,54)},
	{"kind":"lamp","position":Vector2(690,520),"size":Vector2(44,86)},
	{"kind":"fence","position":Vector2(470,1010),"size":Vector2(72,58)},
	{"kind":"fence","position":Vector2(545,1010),"size":Vector2(72,58)},
	{"kind":"gate","position":Vector2(625,1010),"size":Vector2(78,62)},
	{"kind":"cart","position":Vector2(1120,720),"size":Vector2(84,66)},
	{"kind":"bench","position":Vector2(1515,435),"size":Vector2(78,54)},
	{"kind":"lamp","position":Vector2(1780,475),"size":Vector2(44,86)},
	{"kind":"board","position":Vector2(1910,860),"size":Vector2(82,78)},
	{"kind":"fence","position":Vector2(2160,930),"size":Vector2(72,58)},
]
const SOLID_CIRCLES := [{"center":WELL_POSITION,"radius":42.0}]
const SOLID_RECTS := [Rect2(985, 562, 90, 34), Rect2(1405, 562, 90, 34), Rect2(1290, 422, 90, 48), Rect2(1908, 595, 204, 128)]
const FLOWER_PATCHES := [
	Vector2(290,820),Vector2(420,780),Vector2(900,680),Vector2(1040,740),Vector2(1320,760),
	Vector2(1600,790),Vector2(1880,420),Vector2(2140,390),Vector2(930,310),Vector2(1520,290),
	Vector2(360,430),Vector2(560,560),Vector2(760,430),Vector2(1160,320),Vector2(1370,650),
	Vector2(1680,430),Vector2(1960,520),Vector2(2210,560),Vector2(1850,920),Vector2(1180,980),
]
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
	for bridge in BRIDGES:
		if bridge.grow(-18.0 + margin).has_point(position):
			return true
	return false


## Проверяет попадание круглого объекта в реку или фермерский пруд с учётом мостов.
static func is_water(position: Vector2, radius: float) -> bool:
	if absf(position.y - river_center_y(position.x)) < RIVER_HALF_WIDTH + radius and not is_on_bridge(position):
		return true
	var pond_delta := position - POND_CENTER
	return pow(pond_delta.x / (POND_RADII.x + radius), 2.0) + pow(pond_delta.y / (POND_RADII.y + radius), 2.0) < 1.0


## Проверяет столкновение с крупным декором площади, который не является частью зданий.
static func blocks_scenic_prop(position: Vector2, radius: float) -> bool:
	for tree in BORDER_TREES:
		if position.distance_to(tree + Vector2(0,28)) < radius + 34.0: return true
	for rock in BORDER_ROCKS:
		if position.distance_to(rock) < radius + 12.0: return true
	for circle in SOLID_CIRCLES:
		if position.distance_to(circle.center) < radius + float(circle.radius):
			return true
	for rect in SOLID_RECTS:
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
