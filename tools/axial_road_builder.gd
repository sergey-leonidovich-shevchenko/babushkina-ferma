extends RefCounted

const Field := preload("res://tools/axial_road_field.gd")

## Компилирует альфа-маску в один mesh: крупные непрозрачные полосы и мелкая сетка только на кромке.
static func build(paths: Array, size: Vector2, radius: float=36.0) -> ArrayMesh:
	var edges := Field.segments(paths)
	var vertices := PackedVector2Array(); var uv := PackedVector2Array(); var colors := PackedColorArray(); var indices := PackedInt32Array(); var known := {}
	var columns := int(ceil(size.x/Field.STEP)); var rows := int(ceil(size.y/Field.STEP))
	var top := _row(0.0,columns,size,edges,radius)
	for y in rows:
		var bottom := _row(minf((y+1)*Field.STEP,size.y),columns,size,edges,radius)
		var x := 0
		while x<columns:
			var a: float=top[x]; var b: float=top[x+1]; var c: float=bottom[x+1]; var d: float=bottom[x]
			if maxf(maxf(a,b),maxf(c,d))==0.0: x+=1; continue
			var end := x+1
			if minf(minf(a,b),minf(c,d))==1.0:
				while end<columns and top[end+1]==1.0 and bottom[end+1]==1.0: end+=1
			var corners := [Vector2i(x,y),Vector2i(end,y),Vector2i(end,y+1),Vector2i(x,y+1)]
			var alpha := [a,top[end],bottom[end],d]; var quad := []
			for i in 4:
				var key: Vector2i=corners[i]
				if not known.has(key):
					var point := (Vector2(key)*Field.STEP).min(size)
					known[key]=vertices.size(); vertices.append(point); uv.append(point/Field.PERIOD); colors.append(Color(1,1,1,alpha[i]))
				quad.append(known[key])
			indices.append_array(PackedInt32Array([quad[0],quad[1],quad[2],quad[0],quad[2],quad[3]])); x=end
		top=bottom
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.set_meta("mask_spec",{"step":Field.STEP,"feather":Field.FEATHER,"period_world":Field.PERIOD,"size":[size.x,size.y],"radius":radius,"color_independent":true,"vertices":vertices.size(),"indices":indices.size()})
	return result

## Отбрасывает далёкие от строки отрезки до выборки поля; массивы нужны только офлайн-компилятору.
static func _row(y: float, columns: int, size: Vector2, edges: Array, radius: float) -> PackedFloat32Array:
	var active := []
	for edge: Vector4 in edges:
		if y>=edge.y-radius-6.0 and y<=edge.w+radius+6.0: active.append(edge)
	var result := PackedFloat32Array(); result.resize(columns+1)
	if active.is_empty(): return result
	for x in columns+1: result[x]=Field.coverage(Vector2(minf(x*Field.STEP,size.x),y),active,radius)
	return result
