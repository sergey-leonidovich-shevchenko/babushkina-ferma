extends RefCounted

const Field := preload("res://tools/qa/ground/axial_road_field.gd")

## Делит единое покрытие на непересекающиеся клетки двух прежних слоёв без повторной альфы в стыке.
static func build(main_paths: Array, upper_paths: Array, size: Vector2, radius: float=36.0) -> Dictionary:
	var main_edges := Field.segments(main_paths); var upper_edges := Field.segments(upper_paths)
	var columns := int(ceil(size.x/Field.STEP)); var rows := int(ceil(size.y/Field.STEP))
	var stores := [_store(),_store()]; var counts := [0,0]
	var top := _row(0.0,columns,size,main_edges,upper_edges,radius)
	for y in rows:
		var bottom := _row(minf((y+1)*Field.STEP,size.y),columns,size,main_edges,upper_edges,radius)
		var x := 0
		while x<columns:
			var a: float=top[0][x]; var b: float=top[0][x+1]; var c: float=bottom[0][x+1]; var d: float=bottom[0][x]
			if maxf(maxf(a,b),maxf(c,d))==0.0: x+=1; continue
			var owner := _owner(top[1],bottom[1],x)
			var end := x+1
			if minf(minf(a,b),minf(c,d))==1.0:
				while end<columns and top[0][end+1]==1.0 and bottom[0][end+1]==1.0 and _owner(top[1],bottom[1],end)==owner: end+=1
			counts[owner]+=end-x
			_quad(stores[owner],x,end,y,size,[a,top[0][end],bottom[0][end],d]); x=end
		top=bottom
	var result := {}
	for owner in 2:
		var data: Dictionary=stores[owner]; var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=data.vertices; arrays[Mesh.ARRAY_TEX_UV]=data.uv; arrays[Mesh.ARRAY_COLOR]=data.colors; arrays[Mesh.ARRAY_INDEX]=data.indices
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.set_meta("mask_spec",{"step":Field.STEP,"feather":Field.FEATHER,"period_world":Field.PERIOD,"size":[size.x,size.y],"radius":radius,"corner":Field.CORNER,"color_independent":true,"shape":"axial-union-partition","owner":owner,"occupied_cells":counts[owner],"vertices":data.vertices.size(),"indices":data.indices.size()})
		result["main" if owner==0 else "connectors"]=mesh
	return result

## Создаёт независимый накопитель геометрии одного слоя; в игре он уже не нужен.
static func _store() -> Dictionary:
	return {"vertices":PackedVector2Array(),"uv":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array(),"known":{}}

## Отдаёт всю клетку верхнему проходу, если в ней есть поддержка выходной дорожки; общая кромка не дробится альфой.
static func _owner(top: PackedFloat32Array, bottom: PackedFloat32Array, x: int) -> int:
	return 1 if maxf(maxf(top[x],top[x+1]),maxf(bottom[x],bottom[x+1]))>0.0 else 0

## Добавляет непересекающийся прямоугольник с непрерывными мировыми UV и общими значениями покрытия.
static func _quad(data: Dictionary, start: int, end: int, y: int, size: Vector2, alpha: Array) -> void:
	var corners := [Vector2i(start,y),Vector2i(end,y),Vector2i(end,y+1),Vector2i(start,y+1)]; var quad := []
	for i in 4:
		var key: Vector2i=corners[i]
		if not data.known.has(key):
			var point := (Vector2(key)*Field.STEP).min(size)
			data.known[key]=data.vertices.size(); data.vertices.append(point); data.uv.append(point/Field.PERIOD); data.colors.append(Color(1,1,1,alpha[i]))
		quad.append(data.known[key])
	data.indices.append_array(PackedInt32Array([quad[0],quad[1],quad[2],quad[0],quad[2],quad[3]]))

## Вычисляет объединение обеих групп по одной функции расстояния, сохраняя отдельную область владения верхнего слоя.
static func _row(y: float, columns: int, size: Vector2, main_edges: Array, upper_edges: Array, radius: float) -> Array:
	var active := []; var upper := []
	for edge: Vector4 in main_edges:
		if y>=edge.y-radius-6.0 and y<=edge.w+radius+6.0: active.append(edge)
	for edge: Vector4 in upper_edges:
		if y>=edge.y-radius-6.0 and y<=edge.w+radius+6.0: active.append(edge); upper.append(edge)
	var coverage := PackedFloat32Array(); coverage.resize(columns+1)
	var ownership := PackedFloat32Array(); ownership.resize(columns+1)
	if active.is_empty(): return [coverage,ownership]
	for x in columns+1:
		var point := Vector2(minf(x*Field.STEP,size.x),y)
		coverage[x]=Field.coverage(point,active,radius)
		if not upper.is_empty(): ownership[x]=Field.coverage(point,upper,radius)
	return [coverage,ownership]
