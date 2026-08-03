extends RefCounted

const RIVER_BANK := [
	Vector2(0, 852), Vector2(280, 840), Vector2(560, 872), Vector2(850, 846),
	Vector2(1120, 874), Vector2(1400, 842), Vector2(1670, 868), Vector2(1940, 846),
	Vector2(2200, 866), Vector2(2400, 850),
]
const POND_CENTER := Vector2(650, 700)
const POND_RADII := Vector2(190, 105)
const BRIDGES := [Rect2(1450, 805, 110, 395)]
const PATHS := [
	[Vector2(180,370),Vector2(180,500),Vector2(420,520),Vector2(800,520),Vector2(1030,500),Vector2(1450,500),Vector2(1780,500),Vector2(2060,470),Vector2(2290,430)],
	[Vector2(560,520),Vector2(560,400),Vector2(560,300),Vector2(560,185)],
	[Vector2(1030,500),Vector2(1030,390)],
	[Vector2(1450,500),Vector2(1450,390)],
	[Vector2(1450,520),Vector2(1490,650),Vector2(1505,820)],
	[Vector2(180,500),Vector2(300,650),Vector2(430,790),Vector2(760,820),Vector2(1080,825),Vector2(1505,820)],
	[Vector2(1780,500),Vector2(1870,620),Vector2(2050,700),Vector2(2290,700)],
	[Vector2(650,520),Vector2(650,580)],
]
const WELL_POSITION := Vector2(1160, 650)
const PROP_CELLS := {
	"well":Vector2i(0,0), "bench":Vector2i(1,0), "lamp":Vector2i(2,0), "board":Vector2i(3,0),
	"cart":Vector2i(0,1), "fence":Vector2i(1,1), "gate":Vector2i(2,1), "mill":Vector2i(3,1),
}
const PROP_PLACEMENTS := [
	{"kind":"well","position":WELL_POSITION,"size":Vector2(112,112)},
	{"kind":"bench","position":Vector2(955,585),"size":Vector2(104,72)},
	{"kind":"bench","position":Vector2(1360,585),"size":Vector2(104,72)},
	{"kind":"lamp","position":Vector2(850,505),"size":Vector2(58,112)},
	{"kind":"lamp","position":Vector2(1610,505),"size":Vector2(58,112)},
	{"kind":"board","position":Vector2(1320,445),"size":Vector2(110,104)},
	{"kind":"cart","position":Vector2(890,430),"size":Vector2(112,88)},
	{"kind":"mill","position":Vector2(2130,825),"size":Vector2(270,250)},
]
const SOLID_CIRCLES := [{"center":WELL_POSITION,"radius":42.0}]
const SOLID_RECTS := [Rect2(910, 562, 90, 34), Rect2(1315, 562, 90, 34), Rect2(1275, 407, 90, 48), Rect2(2028, 675, 204, 128)]
const FLOWER_PATCHES := [
	Vector2(310,250),Vector2(340,285),Vector2(760,180),Vector2(820,230),Vector2(930,650),
	Vector2(1030,680),Vector2(1320,700),Vector2(1600,660),Vector2(1880,300),Vector2(2140,340),
]


## Возвращает высоту извилистого северного берега реки для указанной координаты X.
static func river_bank_y(x: float) -> float:
	var bounded_x := clampf(x, RIVER_BANK[0].x, RIVER_BANK[-1].x)
	for index in RIVER_BANK.size() - 1:
		var left: Vector2 = RIVER_BANK[index]
		var right: Vector2 = RIVER_BANK[index + 1]
		if bounded_x <= right.x:
			return lerpf(left.y, right.y, inverse_lerp(left.x, right.x, bounded_x))
	return RIVER_BANK[-1].y


## Проверяет, разрешает ли мост пройти над водой в переданной точке.
static func is_on_bridge(position: Vector2, margin: float = 0.0) -> bool:
	for bridge in BRIDGES:
		if bridge.grow(-18.0 + margin).has_point(position):
			return true
	return false


## Проверяет попадание круглого объекта в реку или фермерский пруд с учётом мостов.
static func is_water(position: Vector2, radius: float) -> bool:
	if position.y + radius > river_bank_y(position.x) and not is_on_bridge(position):
		return true
	var pond_delta := position - POND_CENTER
	return pow(pond_delta.x / (POND_RADII.x + radius), 2.0) + pow(pond_delta.y / (POND_RADII.y + radius), 2.0) < 1.0


## Проверяет столкновение с крупным декором площади, который не является частью зданий.
static func blocks_scenic_prop(position: Vector2, radius: float) -> bool:
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
