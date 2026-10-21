extends RefCounted

const REVISION := 5
const HOME_SIZE := Vector2(2400,1368)
const HOME_RIVER := [Vector2(0,288),Vector2(576,288),Vector2(576,456),Vector2(1032,456),Vector2(1032,960),Vector2(2400,960)]
const HOME_HALF_WIDTH := 48
const HOME_POND := Vector2(1848,888)
const HOME_POND_RECTS := [Rect2(1752,816,192,144),Rect2(1728,840,240,96)]
const HOME_BRIDGES := [Rect2(816,360,96,192),Rect2(1560,864,96,192)]
const VILLAGE_WATER := Rect2(936,120,144,1032)
const VILLAGE_BRIDGES := [Rect2(912,432,192,96),Rect2(912,816,192,96)]
const CAVE_POOLS := {"cave_lake":[Rect2(648,432,768,240),Rect2(1656,720,264,144)]}
const MOON_RECTS := [Rect2(1104,816,528,168),Rect2(1152,792,432,216)]
const PROFILE_KINDS := {"overworld":"river+pond","village_river":"river","cave_lake":"cave_pools","moon_glade":"decorative_moon_pool","pirate_ship":"sea_backdrop"}

## Даёт одинаковые осевые составляющие озера рендеру и физике, оставляя небольшие уступы у углов.
static func stepped_pool(rect: Rect2) -> Array[Rect2]:
	return [Rect2(rect.position+Vector2(24,0),rect.size-Vector2(48,0)),Rect2(rect.position+Vector2(0,24),rect.size-Vector2(0,48))]

## Возвращает полосу каждой осевой ветви; расширение используется только для старого статического берега.
static func river_rects(extra_width: float=0.0) -> Array[Rect2]:
	var result: Array[Rect2]=[]; var half:=HOME_HALF_WIDTH+extra_width
	for index in range(1,HOME_RIVER.size()):
		var start: Vector2=HOME_RIVER[index-1]; var finish: Vector2=HOME_RIVER[index]
		var low:=Vector2(minf(start.x,finish.x),minf(start.y,finish.y))-Vector2.ONE*half
		var high:=Vector2(maxf(start.x,finish.x),maxf(start.y,finish.y))+Vector2.ONE*half
		result.append(Rect2(low,high-low))
	return result
