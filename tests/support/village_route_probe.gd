extends RefCounted

const STEP:=12
const SIZE:=Vector2i(200,100)
const DIRECTIONS:=[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]

## Строит связанную область именно через действующую навигацию игры, включая мебель, воду, заборы и деревья.
static func reachable(game:Node,start:Vector2)->Dictionary:
	var first:=Vector2i((start/STEP).round()); var queue:Array[Vector2i]=[first]
	var parents:={first:first}; var blocked:={}; var cursor:=0
	while cursor<queue.size():
		var current:=queue[cursor]; cursor+=1
		for direction in DIRECTIONS:
			var cell:Vector2i=current+direction
			if parents.has(cell) or blocked.has(cell) or cell.x<0 or cell.y<0 or cell.x>=SIZE.x or cell.y>=SIZE.y: continue
			if game.NavigationSystem.walkability_reason(game,Vector2(cell*STEP),-1,false)!="walkable": blocked[cell]=true; continue
			parents[cell]=current; queue.append(cell)
	return parents

## Восстанавливает маршрут до ближайшего доступного подхода, не ставя персонажа внутрь интерактивного объекта.
static func path_to(parents:Dictionary,target:Vector2,range_limit:float=60.0)->Array[Vector2]:
	var nearest:=Vector2i.ZERO; var distance:=range_limit; var found:=false
	for cell in parents:
		var candidate:float=Vector2(cell*STEP).distance_to(target)
		if candidate<=distance: nearest=cell; distance=candidate; found=true
	var path:Array[Vector2]=[]
	if not found: return path
	while parents[nearest]!=nearest:
		path.push_front(Vector2(nearest*STEP)); nearest=parents[nearest]
	path.push_front(Vector2(nearest*STEP))
	return path

## Проходит каждый найденный сегмент малыми физическими шагами, выявляя стены между узлами сетки.
static func walk(game:Node,path:Array[Vector2])->bool:
	if path.is_empty(): return false
	game.player=path[0]
	for target in path.slice(1):
		for _step in 8:
			var motion:Vector2=target-game.player
			if motion.length()<0.1: break
			game.NavigationSystem.move(game,motion.limit_length(3.0))
		if game.player.distance_to(target)>0.1: return false
	return true
