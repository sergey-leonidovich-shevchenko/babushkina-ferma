extends RefCounted

const Field := preload("res://tools/plaza_field.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Meadow := preload("res://scripts/presentation/meadow_ground.gd")

## Компилирует небольшую область площади; непрозрачные полосы объединяются только внутри одного UV-модуля.
static func build(kind: String) -> ArrayMesh:
	var bounds := Map.SQUARE.grow(24.0); var fragments := Field.chips()
	var vertices := PackedVector2Array(); var uv := PackedVector2Array(); var colors := PackedColorArray(); var indices := PackedInt32Array(); var known := {}
	var columns := int(bounds.size.x/Field.STEP); var rows := int(bounds.size.y/Field.STEP)
	var top := _row(bounds.position.y,columns,bounds.position.x,kind,fragments)
	for y in rows:
		var bottom := _row(bounds.position.y+(y+1)*Field.STEP,columns,bounds.position.x,kind,fragments)
		var x := 0
		while x<columns:
			var a: float=top[x]; var b: float=top[x+1]; var c: float=bottom[x+1]; var d: float=bottom[x]
			if maxf(maxf(a,b),maxf(c,d))<=0: x+=1; continue
			var end := x+1; var cell := int(floor((bounds.position.x+x*Field.STEP)/Field.CELL))
			if minf(minf(a,b),minf(c,d))==1.0:
				while end<columns and top[end+1]==1.0 and bottom[end+1]==1.0 and int(floor((bounds.position.x+end*Field.STEP)/Field.CELL))==cell: end+=1
			var corners := [Vector2i(x,y),Vector2i(end,y),Vector2i(end,y+1),Vector2i(x,y+1)]; var alpha := [a,top[end],bottom[end],d]; var quad := []
			for i in 4:
				var key: Vector2i=corners[i]
				if not known.has(key):
					var point := bounds.position+Vector2(key)*Field.STEP
					known[key]=vertices.size(); vertices.append(point); uv.append(Meadow.uv_at(point,Vector2i((point/Field.CELL).floor()))); colors.append(Color(1,1,1,alpha[i]))
				quad.append(known[key])
			indices.append_array(PackedInt32Array([quad[0],quad[1],quad[2],quad[0],quad[2],quad[3]])); x=end
		top=bottom
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.set_meta("mask_spec",{"kind":kind,"step":Field.STEP,"cell_world":Field.CELL,"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"chips":fragments.size(),"vertices":vertices.size(),"indices":indices.size(),"color_independent":true})
	return mesh

## Выбирает альфу по одной общей строке; промежуточные массивы не попадают в игру.
static func _row(y: float, columns: int, start: float, kind: String, fragments: Array) -> PackedFloat32Array:
	var values := PackedFloat32Array(); values.resize(columns+1)
	for x in columns+1: values[x]=Field.coverage(Vector2(start+x*Field.STEP,y),kind,fragments)
	return values
