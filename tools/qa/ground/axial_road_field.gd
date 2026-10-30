extends RefCounted

const Shared := preload("res://tools/qa/ground/ground_edge_field.gd")
const STEP := Shared.STEP
const FEATHER := Shared.FEATHER
const PERIOD := Shared.PERIOD
const CORNER := 4.0

## Сохраняет те же осевые отрезки без диагональных ветвей или новых связей между маршрутами.
static func segments(paths: Array) -> Array:
	return Shared.segments(paths)

## Ограничивает неровность материалом края; она не добавляется к центрам путей или правилам движения.
static func roughness(point: Vector2) -> float:
	return Shared.roughness(point)

## Заменяет полукруглые окончания осевыми прямоугольниками с малым скруглением внутри прежнего AABB.
static func coverage(point: Vector2, edges: Array, radius: float=36.0) -> float:
	var nearest := INF
	var rounding := minf(CORNER,radius)
	for edge: Vector4 in edges:
		var centre := Vector2(edge.x+edge.z,edge.y+edge.w)*0.5
		var half_size := Vector2(edge.z-edge.x,edge.w-edge.y)*0.5+Vector2.ONE*(radius-rounding)
		var delta := (point-centre).abs()-half_size
		var distance := delta.max(Vector2.ZERO).length()+minf(maxf(delta.x,delta.y),0.0)-rounding
		nearest=minf(nearest,distance)
	if nearest>FEATHER+1.5: return 0.0
	if nearest< -FEATHER-1.5: return 1.0
	return 1.0-smoothstep(-FEATHER,FEATHER,nearest+roughness(point))
