extends RefCounted

const Data := preload("res://scripts/systems/basement_data.gd")

## Переводит мировую точку в клетку общей непрерывной сетки пола.
static func cell(position: Vector2) -> Vector2i:
	return Vector2i(((position-Data.FLOOR.position)/Data.GRID).floor())

## Возвращает центр клетки, одинаковый для размещения, навигации и рабочего подхода.
static func center(value: Vector2i) -> Vector2:
	return Data.FLOOR.position+(Vector2(value)+Vector2(0.5,0.5))*Data.GRID

## Меняет размер прямоугольной опоры при повороте на четверть оборота.
static func dimensions(kind: String, direction: int) -> Vector2i:
	var value:Vector2i=Data.STATIONS[kind].size
	return Vector2i(value.y,value.x) if posmod(direction,2)==1 else value

## Возвращает честную опору станка или строительной кучи по сохранённым целым координатам.
static func rect(object: Dictionary) -> Rect2:
	return Rect2(Data.FLOOR.position+Vector2(object.x,object.y)*Data.GRID,Vector2(dimensions(object.kind,object.direction))*Data.GRID)

## Находит единственную точку работы в двух клетках перед выбранной лицевой стороной.
static func approach_cell(object: Dictionary) -> Vector2i:
	var size:=dimensions(object.kind,object.direction); var origin:=Vector2i(object.x,object.y)
	match int(object.direction):
		0: return origin+Vector2i(size.x/2,size.y+1)
		1: return origin+Vector2i(-2,size.y/2)
		2: return origin+Vector2i(size.x/2,-2)
	return origin+Vector2i(size.x+1,size.y/2)

## Возвращает прямоугольники занятых оснований, не зависящие от стадии строительства или высоты рисунка.
static func rectangles(objects: Array) -> Array[Rect2]:
	var result:Array[Rect2]=[]
	for object in objects: result.append(rect(object))
	return result

## Считает клетку проходимой для героя с настоящим радиусом восемнадцать пикселей и не блокирует касание краёв.
static func walkable(point: Vector2, obstacles: Array[Rect2], radius: float=18) -> bool:
	if point.x<Data.FLOOR.position.x+radius or point.x>Data.FLOOR.end.x-radius or point.y<Data.FLOOR.position.y+radius or point.y>Data.FLOOR.end.y-radius: return false
	for bounds in obstacles:
		var nearest:=Vector2(clampf(point.x,bounds.position.x,bounds.end.x),clampf(point.y,bounds.position.y,bounds.end.y))
		if point.distance_squared_to(nearest)<radius*radius-0.001: return false
	return true

## Находит проходы на подрешётке 12 px с настоящим радиусом героя, включая свободные коридоры шириной 48 px.
static func reachable(obstacles: Array[Rect2], targets: Array=[]) -> Dictionary:
	var pending:={}
	for target in targets: pending[target]=true
	var occupied:={}; var blocked_centers:={}
	for bounds in obstacles:
		var begin:=cell(bounds.position+Vector2(0.01,0.01)); var end:=cell(bounds.end-Vector2(0.01,0.01))
		for y in range(begin.y-1,end.y+2):
			for x in range(begin.x-1,end.x+2): blocked_centers[Vector2i(x,y)]=true
		for y in range(begin.y*2-1,(end.y+1)*2+1):
			for x in range(begin.x*2-1,(end.x+1)*2+1): occupied[Vector2i(x,y)]=true
	var start:=Vector2i(((Data.SPAWN-Data.FLOOR.position)/12).floor()); var seen:={start:true}; var queue:Array[Vector2i]=[start]; var cursor:=0; var result:={}
	while cursor<queue.size():
		var current:=queue[cursor]; cursor+=1; var original:=Vector2i(current.x/2,current.y/2)
		if not blocked_centers.has(original):
			result[original]=true; pending.erase(original)
			if not targets.is_empty() and pending.is_empty(): return result
		for direction in Data.DIRECTIONS:
			var next:Vector2i=current+direction
			if seen.has(next) or occupied.has(next) or next.x<1 or next.y<1 or next.x>=183 or next.y>=101: continue
			seen[next]=true; queue.append(next)
	return result

## Проверяет сохранённый набор одним обходом занятых клеток и одним поиском связности, без квадратичных пересчётов маршрута.
static func valid_set(objects: Array) -> bool:
	var occupied:={}; var obstacles:=rectangles(objects)
	for item in objects:
		var bounds:=rect(item)
		if not Data.FLOOR.encloses(bounds) or bounds.intersects(Data.STAIRS) or bounds.grow(18).has_point(Data.BOARD) or bounds.grow(18).has_point(Data.SPAWN): return false
		var origin:=Vector2i(item.x,item.y); var size:=dimensions(item.kind,item.direction)
		for y in range(origin.y,origin.y+size.y):
			for x in range(origin.x,origin.x+size.x):
				var value:=Vector2i(x,y)
				if occupied.has(value): return false
				occupied[value]=true
	var targets:Array=[cell(Data.BOARD)]
	for item in objects: targets.append(approach_cell(item))
	var visited:=reachable(obstacles,targets)
	if not visited.has(cell(Data.BOARD)): return false
	var approaches:={}
	for item in objects:
		if not visited.has(approach_cell(item)): return false
		if approaches.has(approach_cell(item)): return false
		approaches[approach_cell(item)]=true
	return true

## Проверяет расположение, рабочую сторону, лестницу и связность всех рабочих мест до списания ресурсов.
static func reason(objects: Array, candidate: Dictionary, player: Vector2=Vector2.INF) -> String:
	if not Data.STATIONS.has(candidate.get("kind","")) or int(candidate.get("direction",-1)) not in range(4): return "basement_invalid"
	var bounds:=rect(candidate)
	if not Data.FLOOR.encloses(bounds): return "basement_wall"
	if bounds.intersects(Data.STAIRS) or bounds.grow(18).has_point(Data.BOARD) or bounds.grow(18).has_point(Data.SPAWN): return "basement_reserved"
	if player!=Vector2.INF and not walkable(player,[bounds]): return "basement_player"
	var obstacles:=rectangles(objects)
	for obstacle in obstacles:
		if bounds.intersects(obstacle): return "basement_occupied"
	obstacles.append(bounds)
	var approach:=approach_cell(candidate)
	if not walkable(center(approach),obstacles): return "basement_approach"
	var targets:Array=[cell(Data.BOARD),approach]
	for object in objects: targets.append(approach_cell(object))
	var visited:=reachable(obstacles,targets)
	if not visited.has(cell(Data.BOARD)): return "basement_route"
	if not visited.has(approach): return "basement_approach"
	for object in objects:
		if approach_cell(object)==approach: return "basement_approach"
		if not visited.has(approach_cell(object)): return "basement_route"
	return ""

## Красит отдельную клетку предварительного основания, сохраняя красные пересечения вместо целого красного силуэта.
static func cell_blocked(objects: Array, value: Vector2i) -> bool:
	var bounds:=Rect2(center(value)-Vector2(12,12),Vector2(24,24))
	if not Data.FLOOR.encloses(bounds) or bounds.intersects(Data.STAIRS): return true
	for object in objects:
		if rect(object).intersects(bounds): return true
	return false
