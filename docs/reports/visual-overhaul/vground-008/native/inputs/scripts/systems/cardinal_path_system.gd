extends RefCounted

## Добавляет прямоугольный поворот между диагональными точками, сохраняя начало, конец и порядок маршрута.
static func routes(paths:Array) -> Array:
	var result:Array=[]
	for raw in paths:
		if raw.is_empty(): continue
		var path:Array[Vector2]=[Vector2(raw[0])]
		for index in range(1,raw.size()):
			var before:Vector2=path[-1]; var after:=Vector2(raw[index]); var delta:=after-before
			if not is_zero_approx(delta.x) and not is_zero_approx(delta.y):
				path.append(Vector2(after.x,before.y) if absf(delta.x)>=absf(delta.y) else Vector2(before.x,after.y))
			if path[-1]!=after: path.append(after)
		result.append(path)
	return result
