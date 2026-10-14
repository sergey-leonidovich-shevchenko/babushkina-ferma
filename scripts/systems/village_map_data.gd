extends RefCounted

## Единственный чертёж деревни: мировые пиксели, шаг сетки 24, координата объектов — линия земли.
const REVISION := 4
const CELL := 24
const WORLD_SIZE := Vector2(2400,1368)
const START := Vector2(432,672)
const FARM_ORIGIN := Vector2i(144,816)
const COTTAGE_DOOR := Vector2(360,552)
const COTTAGE_EXIT := Vector2(360,648)
const SHOP_DOOR := Vector2(1320,504)
const GUILD_DOOR := Vector2(1776,480)
const GRANDMOTHER := Vector2(552,648)
const WORKBENCH := Vector2(648,960)
const CAVE_ENTRANCE := Vector2(744,216)
const FOREST_GATE := Vector2(2256,816)
const SHOP_STALL := Vector2(1416,576)
const SELL_CRATE := Vector2(1512,576)
const WELL := Vector2(1296,672)
const SQUARE := Rect2(1104,552,480,264)
const FARM_YARD := Rect2(96,768,456,336)
const FARM_ANIMALS := {"hen":Vector2(852,996),"cow":Vector2(792,1224),"sheep":Vector2(852,1160)}
const FARM_TROUGH := Vector2(888,1128)
const FENCE_SPANS := [Rect2i(4,32,4,1),Rect2i(12,32,11,1),Rect2i(4,33,1,13),Rect2i(22,33,1,5),Rect2i(22,42,1,4),Rect2i(5,45,17,1)]
const GATE_SPANS := [Rect2i(8,32,4,1),Rect2i(22,38,1,4)]
const RIVER := [Vector2(0,264),Vector2(600,336),Vector2(864,456),Vector2(960,600),Vector2(1176,888),Vector2(1560,960),Vector2(2400,1032)]
const RIVER_HALF_WIDTH := 48.0
const POND := Vector2(1848,888)
const POND_RADII := Vector2(120,72)
const BRIDGES := [Rect2(816,360,96,192),Rect2(1560,864,96,192)]
const PATH_HALF_WIDTH := 36.0
const PATHS := [
	[Vector2(360,552),Vector2(360,672),Vector2(648,672),Vector2(864,552),Vector2(864,360),Vector2(960,360),Vector2(960,528),Vector2(1128,528),Vector2(1128,744),Vector2(1320,744),Vector2(1608,720),Vector2(1776,600),Vector2(1776,480)],
	[Vector2(1320,504),Vector2(1320,576),Vector2(1416,624),Vector2(1512,624),Vector2(1608,720)],
	[Vector2(360,672),Vector2(240,768),Vector2(240,792)],
	[Vector2(648,672),Vector2(648,864),Vector2(576,912),Vector2(576,984),Vector2(504,984)],
	[Vector2(648,864),Vector2(744,864),Vector2(744,1080),Vector2(1248,1080),Vector2(1608,1080),Vector2(1608,864),Vector2(1608,720)],
	[Vector2(1608,720),Vector2(1824,744),Vector2(2016,744),Vector2(2256,816)],
	[Vector2(864,360),Vector2(840,264),Vector2(744,216)],
	[Vector2(1776,600),Vector2(1896,696),Vector2(1944,792)],
	[Vector2(888,864),Vector2(960,936),Vector2(960,1248)],
]
const DISTRICTS := {"homestead":Rect2(96,360,648,744),"farm":FARM_YARD,"market":SQUARE,"guild":Rect2(1584,216,384,480),"riverwalk":Rect2(912,792,1032,288),"east_grove":Rect2(1968,432,384,528)}
const TREES := [Vector2(2064,336),Vector2(2088,456),Vector2(2280,432),Vector2(1968,528),Vector2(2088,888),Vector2(2256,936),Vector2(2304,648),Vector2(1968,936)]
const BORDER_TREES := [Vector2(72,168),Vector2(240,144),Vector2(480,144),Vector2(1032,192),Vector2(1152,168),Vector2(1488,144),Vector2(2016,216),Vector2(2184,216),Vector2(2352,240),Vector2(72,576),Vector2(72,720),Vector2(2352,552),Vector2(2352,888)]
const FLOWERS := [Vector2(192,600),Vector2(504,576),Vector2(696,624),Vector2(792,588),Vector2(960,360),Vector2(1032,552),Vector2(1128,720),Vector2(1560,528),Vector2(1680,552),Vector2(1800,672),Vector2(1992,648),Vector2(2160,792),Vector2(600,1080),Vector2(1392,1224)]
const NPCS := {"miron":Vector2(1728,600),"agafya":Vector2(1152,600),"varvara":Vector2(1776,816),"gavrila":Vector2(1512,720),"dunya":Vector2(1440,672)}
const FORAGE := {0:Vector2(2160,600),1:Vector2(2064,840),2:Vector2(1608,1272),3:Vector2(744,744),7:Vector2(432,1032),10:Vector2(624,1320),11:Vector2(1128,1320),12:Vector2(1392,1272)}
const RESOURCES := {0:Vector2(696,288),1:Vector2(936,216)}
const EVENTS := {"market":Vector2(1128,720),"festival":Vector2(1416,768),"traveler":Vector2(1632,600),"raid":Vector2(2040,816)}
const REPAIR := Vector2(1704,864)
const SEASONAL_TREE := Vector2(1056,456)
static var _routes:Array=[]

## Возвращает прямые дорожные ветви по сетке без диагоналей и скрытого сглаживания поворотов.
static func routes()->Array:
	if not _routes.is_empty(): return _routes
	_routes=preload("res://scripts/systems/cardinal_path_system.gd").routes(PATHS)
	return _routes

## Возвращает точки берегового контура из той же оси и ширины, которые использует навигация.
static func river_polygon(extra_width:float=0.0)->PackedVector2Array:
	var points:=PackedVector2Array()
	for point in RIVER: points.append(point-Vector2(0,RIVER_HALF_WIDTH+extra_width))
	for index in range(RIVER.size()-1,-1,-1): points.append(RIVER[index]+Vector2(0,RIVER_HALF_WIDTH+extra_width))
	return points

## Строит один непрерывный овал пруда; одинаковый центр и радиусы используются в коллизиях.
static func pond_polygon(extra_width:float=0.0)->PackedVector2Array:
	var points:=PackedVector2Array()
	for index in 48:
		var angle:=TAU*float(index)/48.0
		points.append(POND+Vector2(cos(angle),sin(angle))*(POND_RADII+Vector2.ONE*extra_width))
	return points
