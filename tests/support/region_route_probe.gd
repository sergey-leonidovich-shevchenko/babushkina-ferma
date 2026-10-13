extends RefCounted

const STEP := 24
const DIRECTIONS := [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]

## Обходит реальные проходимые клетки текущей карты с динамическими границами района.
static func reachable(game: Node, start: Vector2) -> Dictionary:
	var size:=Vector2i((game.WorldBoundsSystem.size(game.current_location)/STEP).ceil())
	var first:=Vector2i((start/STEP).round()); var queue:Array[Vector2i]=[first]; var parents:={first:first}; var blocked:={}; var cursor:=0
	while cursor<queue.size():
		var current:=queue[cursor]; cursor+=1
		for direction in DIRECTIONS:
			var cell:Vector2i=current+direction
			if parents.has(cell) or blocked.has(cell) or cell.x<0 or cell.y<0 or cell.x>=size.x or cell.y>=size.y: continue
			if game.NavigationSystem.walkability_reason(game,Vector2(cell*STEP),-1,false)!="walkable": blocked[cell]=true; continue
			parents[cell]=current; queue.append(cell)
	return parents

## Восстанавливает доступный подход к проходу, жителю или растению без постановки героя в его основание.
static func path(parents: Dictionary, target: Vector2, radius: float=60) -> Array[Vector2]:
	var nearest:=Vector2i.ZERO; var distance:=radius; var found:=false
	for cell in parents:
		var length:float=Vector2(cell*STEP).distance_to(target)
		if length<=distance: nearest=cell; distance=length; found=true
	var result:Array[Vector2]=[]
	if not found: return result
	while parents[nearest]!=nearest: result.push_front(Vector2(nearest*STEP)); nearest=parents[nearest]
	result.push_front(Vector2(nearest*STEP)); return result

## Проходит восстановленный путь настоящими малыми физическими шагами, проверяя просветы между клетками.
static func walk(game: Node, points: Array[Vector2]) -> bool:
	if points.is_empty(): return false
	game.player=points[0]
	for point in points.slice(1):
		for _step in 12:
			var motion:Vector2=point-game.player
			if motion.length()<0.1: break
			game.NavigationSystem.move(game,motion.limit_length(2.0))
		if game.player.distance_to(point)>0.1:
			print("REGION ROUTE BLOCK: ",game.current_location," ",game.player," -> ",point," ",game.NavigationSystem.walkability_reason(game,point,-1,false)); return false
	return true
