extends RefCounted

const Data := preload("res://scripts/systems/house_furniture_data.gd")
const Visual := preload("res://scripts/systems/farm_life_visual_system.gd")

## Проверяет виды мебели и конечный целый ракурс до применения сохранения к живой игре.
static func valid_records(records: Array) -> bool:
	for item in records:
		if String(item.kind) not in Data.KINDS: return false
		var direction:float=float(item.get("direction",0))
		if not is_finite(direction) or direction!=floorf(direction) or direction<0 or direction>3: return false
	return true

## Возвращает габарит занимаемых клеток; ковёр занимает место на полу, но не создаёт стену.
static func size(kind: String, direction: int=0) -> Vector2:
	var profile:=Visual.profile(kind,direction)
	return profile.visual if profile.collision==Vector2.ZERO else profile.collision

## Привязывает левую и нижнюю границы основания к клеткам, включая нечётную ширину мебели.
static func snap(kind: String, position: Vector2, direction: int=0) -> Vector2:
	var width:=size(kind,direction).x
	return Vector2(roundf((position.x-width/2)/Data.GRID)*Data.GRID+width/2,roundf(position.y/Data.GRID)*Data.GRID)

## Рассчитывает занимаемый прямоугольник из направления и нижней центральной опоры.
static func rect(kind: String, position: Vector2, direction: int=0) -> Rect2:
	var bounds:=size(kind,direction)
	return Rect2(position-Vector2(bounds.x/2,bounds.y),bounds)

## Выбирает клетку перед героем по ближайшей главной оси его движения.
static func candidate(game: Node) -> Dictionary:
	var value:Dictionary=game.FarmLifeSystem.state(game)
	var kind:String=Data.KINDS[clampi(int(value.build_index),0,Data.KINDS.size()-1)]
	var facing:Vector2=game.facing
	facing=Vector2(signf(facing.x),0) if absf(facing.x)>absf(facing.y) else Vector2(0,signf(facing.y))
	if facing==Vector2.ZERO: facing=Vector2.DOWN
	var direction:=posmod(int(value.get("build_direction",0)),4)
	return {"kind":kind,"position":snap(kind,game.player+facing*72,direction),"direction":direction}

## Проверяет весь footprint, границы пола, мебель и подходы к постоянным услугам дома.
static func fits(game: Node, item: Dictionary, placed: Array) -> bool:
	var bounds:=rect(item.kind,item.position,int(item.get("direction",0)))
	if not Data.FLOOR.encloses(bounds): return false
	if Visual.profile(item.kind).collision==Vector2.ZERO: return true
	for solid in game.InteriorVisualSystem.collision_rects("cottage_interior"):
		if bounds.intersects(solid): return false
	if bounds.intersects(Data.STAIR_RECT) or bounds.intersects(Rect2(528,480,96,48)): return false
	if bounds.intersects(game.InteriorVisualSystem.collision_rect("home_chest",Data.CHEST_POSITION)): return false
	for point in [Data.CABINET_POINT,Data.BED_POINT,Data.KITCHEN_POINT,Data.ALCHEMY_POINT,Data.POTTERY_POINT,Vector2(828,516),Vector2(900,504)]:
		if bounds.intersects(Rect2(point-Vector2(24,24),Vector2(48,48))): return false
	for other in placed:
		var collision:=Visual.collision_rect(other.kind,other.position,int(other.get("direction",0)))
		if collision.size!=Vector2.ZERO and bounds.intersects(collision): return false
	return true

## Кэширует проверку кадра размещения, чтобы сетка не проверяла одинаковые препятствия повторно.
static func can_place(game: Node, item: Dictionary) -> bool:
	var placed:Array=game.FarmLifeSystem.state(game).furniture
	var key:=str(hash([item,placed,game.home_chest_owned]))
	var cache:Dictionary=game.get_meta("house_furniture_placement",{})
	if cache.get("key","")!=key:
		var allowed:=fits(game,item,placed)
		if allowed and Visual.profile(item.kind).collision!=Vector2.ZERO: allowed=services_reachable(game,placed+[item])
		game.set_meta("house_furniture_placement",{"key":key,"allowed":allowed})
	return bool(game.get_meta("house_furniture_placement").allowed) and not Visual.circle_intersects_rect(game.player,game.PLAYER_RADIUS,Visual.collision_rect(item.kind,item.position,int(item.direction)))

## Проверяет физический путь от двери ко всем услугам, чтобы новая мебель не создавала перегородку.
static func services_reachable(game: Node, placed: Array) -> bool:
	var solids:Array=game.InteriorVisualSystem.collision_rects("cottage_interior")
	if game.home_chest_owned: solids.append(game.InteriorVisualSystem.collision_rect("home_chest",Data.CHEST_POSITION))
	for item in placed:
		var collision:=Visual.collision_rect(item.kind,item.position,int(item.get("direction",0)))
		if collision.size!=Vector2.ZERO: solids.append(collision)
	var free:Dictionary={}
	for y in range(300,528,Data.GRID):
		for x in range(180,984,Data.GRID):
			var point:=Vector2(x,y)
			if solids.any(func(solid): return Visual.circle_intersects_rect(point,game.PLAYER_RADIUS,solid)): continue
			free[point]=true
	var queue:Array[Vector2]=[]; var seen:Dictionary={}
	for point in free:
		if point.distance_to(Vector2(576,504))<=24: queue.append(point); seen[point]=true
	var cursor:=0
	while cursor<queue.size():
		var point:=queue[cursor]; cursor+=1
		for offset in [Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT]:
			var neighbor:Vector2=point+offset*Data.GRID
			if free.has(neighbor) and not seen.has(neighbor): seen[neighbor]=true; queue.append(neighbor)
	for target in [Data.CABINET_POINT,Data.BED_POINT,Data.KITCHEN_POINT,Data.ALCHEMY_POINT,Data.POTTERY_POINT,Vector2(816,514),Vector2(900,504)]:
		if not queue.any(func(point): return point.distance_to(target)<=24): return false
	return true

## Находит ближайший допустимый набор клеток для старого предмета без потери его направления.
static func nearest(game: Node, item: Dictionary, placed: Array) -> Vector2:
	var snapped:=snap(item.kind,item.position,int(item.get("direction",0)))
	var trial:=item.duplicate(); trial.position=snapped
	if fits(game,trial,placed): return snapped
	var best:=Vector2.INF; var distance:=INF
	for y in range(int(Data.FLOOR.position.y)+Data.GRID,int(Data.FLOOR.end.y)+1,Data.GRID):
		for x in range(int(Data.FLOOR.position.x),int(Data.FLOOR.end.x),Data.GRID):
			var point:=snap(item.kind,Vector2(x,y),int(item.get("direction",0)))
			var next_distance:=point.distance_squared_to(item.position)
			if next_distance>=distance: continue
			trial.position=point
			if fits(game,trial,placed): best=point; distance=next_distance
	return best

## Переносит старую мебель на сетку; если места нет, возвращает целый предмет в рюкзак.
static func migrate(game: Node) -> void:
	var value:Dictionary=game.FarmLifeSystem.state(game); var restored:Array=[]
	for record in value.furniture:
		var item:Dictionary=record.duplicate(true)
		item.direction=posmod(int(item.get("direction",0)),4)
		var position:=nearest(game,item,restored)
		if position==Vector2.INF: game.change_inventory_count(item.kind,1); continue
		item.position=position; restored.append(item)
	value.furniture=restored; value.furniture_grid_version=1
	if game.current_location!="cottage_interior" or game.NavigationSystem.is_walkable(game,game.player): return
	var best:=Vector2(576,504); var distance:=INF
	for y in range(300,528,Data.GRID):
		for x in range(180,984,Data.GRID):
			var point:=Vector2(x,y); var next_distance:=point.distance_squared_to(game.player)
			if next_distance<distance and game.NavigationSystem.is_walkable(game,point): best=point; distance=next_distance
	game.player=best
