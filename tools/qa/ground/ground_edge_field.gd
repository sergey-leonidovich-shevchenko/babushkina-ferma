extends RefCounted

const STEP := 2
const FEATHER := 4.5
const PERIOD := 384.0

## Готовит только осевые отрезки существующего чертежа; текстура и её цвет в маску не входят.
static func segments(paths: Array) -> Array:
	var result := []
	for path in paths:
		for i in range(1,path.size()):
			var a: Vector2=path[i-1]; var b: Vector2=path[i]
			assert(a.x==b.x or a.y==b.y,"Only cardinal ground routes")
			result.append(Vector4(minf(a.x,b.x),minf(a.y,b.y),maxf(a.x,b.x),maxf(a.y,b.y)))
	return result

## Смешивает короткие гладкие волны по мировой координате без случайного состояния или времени.
static func roughness(point: Vector2) -> float:
	return sin(point.x*.29+sin(point.y*.17))*0.9+sin(point.y*.41+point.x*.13)*0.55

## Вычисляет единое покрытие объединения дорожек: Т-стык не накладывает несколько прозрачных рамок.
static func coverage(point: Vector2, edges: Array, radius: float=36.0) -> float:
	var nearest := INF
	for edge: Vector4 in edges:
		var x := point.x-clampf(point.x,edge.x,edge.z)
		var y := point.y-clampf(point.y,edge.y,edge.w)
		nearest=minf(nearest,x*x+y*y)
	var distance := sqrt(nearest)-radius
	if distance>FEATHER+1.5: return 0.0
	if distance< -FEATHER-1.5: return 1.0
	return 1.0-smoothstep(-FEATHER,FEATHER,distance+roughness(point))
