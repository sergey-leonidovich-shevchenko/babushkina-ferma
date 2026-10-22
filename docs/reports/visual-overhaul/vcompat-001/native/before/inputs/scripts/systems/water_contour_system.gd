extends RefCounted

const Data := preload("res://scripts/systems/water_layout_data.gd")
static var _home_cache: Dictionary = {}

## Собирает контур встроенной простой реки из того же осевого плана; маски островов принадлежат клеточному renderer.
static func home_river(extra_width: float=0.0) -> PackedVector2Array:
	return _home("river",extra_width)

## Собирает ступенчатый пруд из общих участков вместо независимого эллипса.
static func home_pond(extra_width: float=0.0) -> PackedVector2Array:
	return _home("pond",extra_width)

## Объединяет небольшое число пересекающихся осевых прямоугольников без загрузки изображений.
static func merge_rects(rectangles: Array) -> Array:
	var contours: Array=[]
	for rect in rectangles:
		var rectangle: Rect2=rect
		var polygon := PackedVector2Array([rectangle.position,Vector2(rectangle.end.x,rectangle.position.y),rectangle.end,Vector2(rectangle.position.x,rectangle.end.y)])
		var index:=0
		while index<contours.size():
			var merged:=Geometry2D.merge_polygons(contours[index],polygon)
			if merged.size()==1: polygon=merged[0]; contours.remove_at(index); index=0
			else: index+=1
		contours.append(polygon)
	return contours

## Кеширует только три фиксированные ширины старого renderer, не накапливая произвольные числовые ключи.
static func _home(kind: String, extra_width: float) -> PackedVector2Array:
	var key:="%s:%s"%[kind,extra_width]
	if _home_cache.has(key): return _home_cache[key]
	var rectangles: Array=[]
	if kind=="river": rectangles=Data.river_rects(extra_width)
	else:
		for rect in Data.HOME_POND_RECTS: rectangles.append(Rect2(rect).grow(extra_width))
	var contours:=merge_rects(rectangles)
	assert(contours.size()==1,"Встроенный водоём должен иметь один простой контур")
	var result: PackedVector2Array=contours[0] if contours.size()==1 else PackedVector2Array()
	if extra_width in [0.0,5.0,10.0]: _home_cache[key]=result
	return result
