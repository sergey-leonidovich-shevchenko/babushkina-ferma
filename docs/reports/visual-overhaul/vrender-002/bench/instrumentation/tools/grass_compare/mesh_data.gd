extends RefCounted

const UV_ROWS := [0.0,0.25,0.5,0.75,490.0/512.0,1.0]
const WIDTH := 438.0*0.09
const HEIGHT := 512.0*0.09
const ROOT_Y := 490.0*0.09
const VERTICES := 18
const INDICES := 60
const AMPLITUDE := 2.4

## Создаёт допустимые корни на земле первой карты собственным RNG, не трогая RNG игры.
static func positions(game: Node, count: int) -> Array:
	var points:=[]
	var solids:Array=game.BuildingSystem.farm_fence_rects().duplicate()
	for id in game.BuildingSystem.buildings_at("overworld"): solids.append_array(game.BuildingSystem.collision_rects(id))
	solids.append(Rect2(game.workbench_position-Vector2(32,20),Vector2(64,44)))
	for tree in game.state.world.tree_nodes:
		if game.TreeSystem.is_solid(tree): solids.append(game.TreeSystem.collision_rect(tree))
	for y in range(560,936,8):
		for x in range(288,1056,8):
			var pos:=Vector2(x+0.25,y+0.25)
			if game.VillageLayoutSystem.overworld_tile(Vector2i(floori(pos.x/24),floori(pos.y/24)))!=game.VillageLayoutSystem.OVERWORLD_TILE_GRASS: continue
			if game.VillageLayoutSystem.is_water(pos,12) or game.VillageLayoutSystem.blocks_scenic_prop(pos,12): continue
			var blocked:=false
			for rect in solids:
				if game.NavigationSystem.circle_intersects_rect(pos,12,rect): blocked=true; break
			if blocked: continue
			points.append(pos)
	var rng:=RandomNumberGenerator.new(); rng.seed=20261020
	for i in range(points.size()-1,0,-1):
		var j:=rng.randi_range(0,i); var swap:Vector2=points[i]; points[i]=points[j]; points[j]=swap
	assert(points.size()>=count,"insufficient admissible grass roots")
	points.resize(count)
	points.sort_custom(func(a: Vector2,b: Vector2)->bool: return a.y<b.y or (a.y==b.y and a.x<b.x))
	return points

## Фиксирует общую восьмибитную фазу для CPU/GPU, независимо от места группировки.
static func phase(position: Vector2) -> float:
	return roundf(fposmod(position.x*0.013+position.y*0.021,TAU)/TAU*255.0)/255.0

## Строит одинаковую сетку 3×6, включая точный ряд корня и неподвижную нижнюю часть PNG.
static func arrays(points: Array, local_origin: Vector2 = Vector2.ZERO) -> Array:
	var vertices:=PackedVector2Array(); var uv:=PackedVector2Array(); var colors:=PackedColorArray(); var indices:=PackedInt32Array()
	for point in points:
		var offset:=vertices.size(); var p:=phase(point)
		for v in UV_ROWS:
			for u in [0.0,0.5,1.0]:
				vertices.append(Vector2(point)-local_origin+Vector2((u-0.5)*WIDTH,v*HEIGHT-ROOT_Y))
				uv.append(Vector2(u,v)); colors.append(Color(p,1,1,1))
		for row in 5:
			for col in 2:
				var a:=offset+row*3+col
				indices.append_array(PackedInt32Array([a,a+1,a+3,a+1,a+4,a+3]))
	var result:=[]; result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX]=vertices; result[Mesh.ARRAY_TEX_UV]=uv; result[Mesh.ARRAY_COLOR]=colors; result[Mesh.ARRAY_INDEX]=indices
	return result

## Вычисляет тот же изгиб по вершинам; UV/индексы/цвета остаются постоянными.
static func deform(data: Array, time: float) -> PackedVector2Array:
	var vertices:PackedVector2Array=data[Mesh.ARRAY_VERTEX].duplicate()
	var colors:PackedColorArray=data[Mesh.ARRAY_COLOR]
	for first in range(0,vertices.size(),VERTICES):
		var sway:=sin(time*1.8+colors[first].r*TAU)*AMPLITUDE
		for row in UV_ROWS.size():
			var weight:=pow(clampf(1.0-UV_ROWS[row]/(490.0/512.0),0.0,1.0),2.0)
			for col in 3: vertices[first+row*3+col].x+=sway*weight
	return vertices

## Добавляет консервативную границу GPU-деформации, сохраняя независимость от кадра ветра.
static func mesh(data: Array, dynamic: bool = false) -> ArrayMesh:
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE if dynamic else 0)
	var bounds:=Rect2(data[Mesh.ARRAY_VERTEX][0],Vector2.ZERO)
	for p in data[Mesh.ARRAY_VERTEX]: bounds=bounds.expand(p)
	bounds=bounds.grow(AMPLITUDE+1.0)
	result.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	return result
