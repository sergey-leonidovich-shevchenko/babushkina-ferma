extends RefCounted

const Roots:=preload("res://scripts/presentation/foliage_root_profile.gd")
const ShaderSource:=preload("res://scripts/presentation/foliage_uv.gdshader")
const MAX_BEND:=8.0

## Проверяет целую область конкретного растения; выход за атлас или неверный размер не становятся соседним рисунком.
static func parameters(kind:String,region:Rect2i,atlas_size:Vector2i,mirror_x:bool=false)->Dictionary:
	var data:=Roots.profile(kind)
	if data.is_empty() or region.size!=data.size or not region.has_area() or atlas_size.x<=0 or atlas_size.y<=0:return {}
	if not Rect2i(Vector2i.ZERO,atlas_size).encloses(region):return {}
	return {"kind":kind,"region":region,"atlas_size":atlas_size,"mirror_x":mirror_x,"root":Vector2(data.size.x-data.root.x if mirror_x else data.root.x,data.root.y),"size":data.size}

## Вычисляет ту же выборку центров крайних texel, что и shader; недопустимые локальные UV возвращают явный отказ.
static func atlas_uv(data:Dictionary,local_uv:Vector2)->Vector2:
	if data.is_empty() or not local_uv.is_finite():return Vector2.INF
	var uv:=Vector2(1.0-local_uv.x if data.mirror_x else local_uv.x,local_uv.y)
	var size:=Vector2(data.size);var pixel:=uv*size
	pixel=Vector2(clampf(pixel.x,0.5,size.x-0.5),clampf(pixel.y,0.5,size.y-0.5))
	return (Vector2(data.region.position)+pixel)/Vector2(data.atlas_size)

## Строит локальную сетку с отдельными рядами фиксированного основания и корня, сохраняя пропорции при отражении.
static func mesh_data(kind:String,scale:float,mirror_x:bool=false)->Dictionary:
	var profile:=Roots.profile(kind)
	if profile.is_empty() or not is_finite(scale) or scale<=0.0 or scale>4.0:return {}
	var size:=Vector2(profile.size);var root:=Vector2(size.x-profile.root.x if mirror_x else profile.root.x,profile.root.y)
	var rows:=[0.0,0.25,0.5,0.75,float(profile.lock_y)/size.y,float(profile.root.y)/size.y,1.0];rows.sort()
	var unique:=[]
	for row in rows:
		if unique.is_empty() or not is_equal_approx(unique.back(),row):unique.append(row)
	var vertices:=PackedVector2Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	for v in unique:
		for u in [0.0,0.5,1.0]:
			vertices.append((Vector2(u,v)*size-root)*scale);uv.append(Vector2(u,v))
	for row in range(unique.size()-1):
		for column in 2:
			var a:=row*3+column;indices.append_array(PackedInt32Array([a,a+1,a+3,a+1,a+4,a+3]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	return {"arrays":arrays,"rows":unique,"root":root,"scale":scale,"size":profile.size,"mirror_x":mirror_x}

## Создаёт статичную сетку один раз и расширяет видимую границу на максимально допустимую деформацию.
static func make_mesh(data:Dictionary)->ArrayMesh:
	if data.is_empty():return null
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data.arrays)
	var vertices:PackedVector2Array=data.arrays[Mesh.ARRAY_VERTEX];var bounds:=Rect2(vertices[0],Vector2.ZERO)
	for point in vertices:bounds=bounds.expand(point)
	bounds=bounds.grow(MAX_BEND+1.0);result.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	return result

## Подготавливает отдельный материал региона без глобальных параметров, часов или кеша чужого viewport.
static func make_material(data:Dictionary,atlas:Texture2D,mask:Texture2D)->ShaderMaterial:
	if data.is_empty() or atlas==null or mask==null or Vector2i(atlas.get_size())!=data.atlas_size or Vector2i(mask.get_size())!=data.size:return null
	var result:=ShaderMaterial.new();result.shader=ShaderSource
	result.set_shader_parameter("source_atlas",atlas);result.set_shader_parameter("root_mask",mask)
	result.set_shader_parameter("atlas_size",Vector2(data.atlas_size))
	result.set_shader_parameter("source_rect",Vector4(data.region.position.x,data.region.position.y,data.region.size.x,data.region.size.y))
	result.set_shader_parameter("mirror_x",data.mirror_x);result.set_shader_parameter("bend",Vector2.ZERO)
	var profile:=Roots.profile(data.kind)
	result.set_shader_parameter("lock_v",float(profile.lock_y)/float(profile.size.y));result.set_shader_parameter("top_v",float(profile.top)/float(profile.size.y))
	result.set_shader_parameter("flexible",profile.flexible)
	return result
