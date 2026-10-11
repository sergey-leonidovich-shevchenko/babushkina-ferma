extends RefCounted

const LOCATION := "cave_sanctum"
const ALTAR := Vector2(936,648)
const BOSS := Vector2(1512,672)
const CENTER := Vector2(1488,672)
const EXIT := Vector2(1728,192)
const CHEST := Vector2(1728,360)
const SEAL := Rect2(1632,208,192,32)
const COLUMNS := [Vector2(1008,336),Vector2(2016,456),Vector2(840,888),Vector2(1848,984)]
const CRYSTALS := [Vector2(1128,384),Vector2(1968,648),Vector2(1248,1008)]
const PROPS := [
	{"kind":"torch","position":Vector2(336,456)}, {"kind":"torch","position":Vector2(336,792)},
	{"kind":"stalagmites","position":Vector2(864,336)}, {"kind":"stalagmites","position":Vector2(2088,744)},
	{"kind":"boulder","position":Vector2(2016,984)}, {"kind":"rubble","position":Vector2(792,984)},
	{"kind":"crystal_fragments","position":Vector2(1920,312)}, {"kind":"crystal_fragments","position":Vector2(1056,1008)},
	{"kind":"crystal_blue","position":Vector2(1128,384)}, {"kind":"crystal_blue","position":Vector2(1968,648)},
	{"kind":"crystal_blue","position":Vector2(1248,1008)},
]
static var _floor := PackedVector2Array()
static var _solids: Array[Rect2] = []

## Соединяет просторный зал, тёплый предбанник и два туннеля выбранного варианта А.
static func floor_polygon() -> PackedVector2Array:
	if not _floor.is_empty(): return _floor
	_floor = PackedVector2Array([Vector2(792,216),Vector2(1848,216),Vector2(2112,432),Vector2(2208,816),Vector2(1968,1080),Vector2(864,1080),Vector2(600,888),Vector2(576,504)])
	for rectangle in [Rect2(504,528,216,192),Rect2(240,408,384,432),Rect2(-120,528,456,192),Rect2(1632,-120,192,408)]:
		var p: Vector2 = rectangle.position; var e: Vector2 = rectangle.end
		var merged := Geometry2D.merge_polygons(_floor,PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)]))
		assert(merged.size()==1,"Пол арены должен оставаться связным")
		_floor = merged[0]
	var area := 0.0
	for index in _floor.size(): area += _floor[index].cross(_floor[(index+1)%_floor.size()])
	if area < 0.0: _floor.reverse()
	return _floor

## Возвращает небольшие видимые основания алтаря и колонн, оставляя рунический круг проходимым.
static func solids() -> Array[Rect2]:
	if _solids.is_empty():
		_solids.append(Rect2(ALTAR-Vector2(21.12,21.12),Vector2(42.24,21.12)))
		for position in COLUMNS: _solids.append(Rect2(position-Vector2(24,24),Vector2(48,24)))
	return _solids
