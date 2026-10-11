extends RefCounted

const Entrance := preload("res://scripts/systems/cave_map_data.gd")
const IDS := ["cave", "cave_fungal", "cave_moon", "cave_lake", "cave_mine", "cave_sanctum"]
const PORTS := {"left": Vector2(192,600), "right": Vector2(2208,600), "top": Vector2(1200,192), "bottom": Vector2(1200,1056), "deep": Entrance.DEEP_GATE}
const INWARD := {"left": Vector2.RIGHT, "right": Vector2.LEFT, "top": Vector2.DOWN, "bottom": Vector2.UP, "deep": Vector2.DOWN}
const LINKS := {
	"cave": {"deep": ["cave_fungal", "left"]},
	"cave_fungal": {"left": ["cave", "deep"], "right": ["cave_moon", "left"], "top": ["cave_mine", "bottom"]},
	"cave_moon": {"left": ["cave_fungal", "right"], "bottom": ["cave_lake", "top"]},
	"cave_lake": {"top": ["cave_moon", "bottom"], "left": ["cave_mine", "right"], "right": ["cave_sanctum", "left"]},
	"cave_mine": {"bottom": ["cave_fungal", "top"], "right": ["cave_lake", "left"]},
	"cave_sanctum": {"left": ["cave_lake", "right"]},
}
const PATHS := {
	"cave_fungal": [Rect2(288,288,624,624), Rect2(864,528,552,168), Rect2(1368,240,744,720), Rect2(-120,504,456,192), Rect2(2064,504,456,192), Rect2(1104,-120,192,720)],
	"cave_moon": [Rect2(288,240,696,384), Rect2(936,480,576,192), Rect2(1440,480,672,480), Rect2(1104,624,624,336), Rect2(-120,504,456,192), Rect2(1104,888,192,360)],
	"cave_lake": [Rect2(288,288,1824,672), Rect2(-120,504,456,192), Rect2(2064,504,456,192), Rect2(1104,-120,192,456)],
	"cave_mine": [Rect2(288,288,624,384), Rect2(864,528,696,168), Rect2(1512,288,600,672), Rect2(528,624,528,336), Rect2(1008,816,288,144), Rect2(1104,888,192,360), Rect2(2064,504,456,192)],
	"cave_sanctum": [Rect2(288,288,1824,672), Rect2(-120,504,456,192), Rect2(1920,-120,192,456)],
}
const ROCKS := {"cave_sanctum": [Rect2(1128,480,192,216)]}
const POOLS := {"cave_lake": [Rect2(648,432,768,240), Rect2(1656,720,264,144)]}
const COLORS := {"cave": Color.WHITE, "cave_fungal": Color("abbda3"), "cave_moon": Color("a6b2d5"), "cave_lake": Color("a6c0c7"), "cave_mine": Color("c1ad94"), "cave_sanctum": Color("b3a4c4")}
static var _floors: Dictionary = {}
static var _decor: Dictionary = {}


## Определяет все подземные комнаты без добавления их в линейный маршрут наземных биомов.
static func is_cave(location: String) -> bool:
	return location in IDS


## Возвращает проходы активной комнаты с обратной дверью и безопасной точкой появления.
static func passages(location: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for port in LINKS.get(location, {}):
		var target: Array = LINKS[location][port]
		result.append({"port": port, "position": PORTS[port], "target": target[0], "arrival": target[1], "spawn": PORTS[target[1]] + INWARD[target[1]] * 96.0})
	return result


## Собирает соединённые залы и узкие коридоры в единственный кешированный полигон пола.
static func floor_polygon(location: String) -> PackedVector2Array:
	if location == "cave": return PackedVector2Array(Entrance.FLOOR)
	if _floors.has(location): return _floors[location]
	var floor := PackedVector2Array()
	for rectangle in PATHS.get(location, []):
		var piece := pool_polygon(rectangle) if minf(rectangle.size.x,rectangle.size.y) > 216 else rectangle_polygon(rectangle)
		if floor.is_empty(): floor = piece
		else:
			var merged := Geometry2D.merge_polygons(floor, piece)
			if merged.size() == 1: floor = merged[0]
			else:
				push_error("Несоединённый зал пещеры: %s" % location)
				return PackedVector2Array()
	var signed_area := 0.0
	for index in floor.size(): signed_area += floor[index].cross(floor[(index + 1) % floor.size()])
	if signed_area < 0.0: floor.reverse()
	_floors[location] = floor
	return floor


## Строит прямоугольный контур скальной перегородки с предсказуемым направлением обхода.
static func rectangle_polygon(rectangle: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)])


## Срезает углы подземного водоёма; его изображение и навигация используют один контур берега.
static func pool_polygon(rectangle: Rect2, organic: bool = false) -> PackedVector2Array:
	if organic:
		var outline := PackedVector2Array()
		for point in [Vector2(0.06,0.36),Vector2(0.13,0.12),Vector2(0.34,0.04),Vector2(0.5,0.14),Vector2(0.68,0.05),Vector2(0.89,0.16),Vector2(1,0.44),Vector2(0.95,0.72),Vector2(0.8,0.95),Vector2(0.58,1),Vector2(0.36,0.88),Vector2(0.15,0.96),Vector2(0,0.72)]: outline.append(rectangle.position+point*rectangle.size)
		return outline
	var p := rectangle.position; var e := rectangle.end; var bevel := 48.0
	return PackedVector2Array([p + Vector2(bevel,0), Vector2(e.x-bevel,p.y), Vector2(e.x,p.y+bevel), e-Vector2(0,bevel), e-Vector2(bevel,0), Vector2(p.x+bevel,e.y), Vector2(p.x,e.y-bevel), p+Vector2(0,bevel)])


## Размещает тематические скальные детали вне главных проходов; схемы создаются один раз.
static func decorations(location: String) -> Array:
	if location == "cave": return Entrance.DECORATIONS
	if _decor.has(location): return _decor[location]
	var result: Array = []
	var points := [Vector2(384,360), Vector2(768,336), Vector2(432,840), Vector2(1848,360), Vector2(1992,864)]
	for point in points:
		if Geometry2D.is_point_in_polygon(point, floor_polygon(location)): result.append({"kind": "rubble", "position": point})
	if location == "cave_fungal":
		for point in [Vector2(384,456),Vector2(528,408),Vector2(744,768),Vector2(480,816),Vector2(1632,336),Vector2(1920,432),Vector2(1680,864),Vector2(1920,840)]:
			result.append({"kind": "mushrooms", "position": point})
	elif location == "cave_mine":
		for point in [Vector2(768,408),Vector2(600,888),Vector2(1704,360),Vector2(1920,864)]: result.append({"kind":"torch", "position":point})
	elif location == "cave_moon":
		for point in [Vector2(432,360),Vector2(840,528),Vector2(1560,792),Vector2(1944,864)]: result.append({"kind":"crystal_fragments", "position":point})
	_decor[location] = result
	return result


## Разрешает внешний выход только в глубоком святилище, чтобы комнаты образовывали исследуемый лабиринт.
static func has_world_exit(location: String) -> bool:
	return location == "cave_sanctum"
