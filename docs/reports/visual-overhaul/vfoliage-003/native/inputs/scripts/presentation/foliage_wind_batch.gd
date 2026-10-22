extends RefCounted

const UV:=preload("res://scripts/presentation/foliage_uv.gd")
const Roots:=preload("res://scripts/presentation/foliage_root_profile.gd")
const ShaderSource:=preload("res://scripts/presentation/foliage_wind.gdshader")
const SLOT:=96
const PAD:=12
const COLUMNS:=4
const CAPACITY:=64
const AMPLITUDE:=1.35

## Вычисляет пространственную фазу из мировой опоры, не трогая игровой или глобальный RNG.
static func phase(anchor:Vector2)->float:
	return fposmod(anchor.x*0.017+anchor.y*0.031,TAU)

## Даёт независимый CPU-эталон ограниченного горизонтального изгиба с нулевой вертикальной составляющей.
static func bend(seconds:float,anchor:Vector2)->Vector2:
	if not is_finite(seconds) or not anchor.is_finite():return Vector2.ZERO
	var value:=phase(anchor)
	return Vector2(AMPLITUDE*(0.78*sin(seconds*0.95+value)+0.22*sin(seconds*1.61+value*1.7)),0)

## Размещает полную область с запасом на изгиб; соседние слоты не соприкасаются даже на предельной амплитуде.
static func slot(index:int)->Rect2:
	return Rect2(Vector2(index%COLUMNS,index/COLUMNS)*SLOT,Vector2.ONE*SLOT)

## Создаёт максимум одну группу на вид, с общей геометрией и отдельной фазой каждого экземпляра.
static func build(rows:Array,atlas:Texture2D,scale:int)->Dictionary:
	if rows.is_empty() or rows.size()>CAPACITY or atlas==null or scale<1 or scale>4:return {}
	var viewport:=SubViewport.new();viewport.name="WindAtlas";viewport.disable_3d=true;viewport.transparent_bg=true
	viewport.size=Vector2i(COLUMNS*SLOT,ceili(float(rows.size())/COLUMNS)*SLOT)*scale
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var groups:={};var nodes:=[]
	for index in rows.size():
		var row:Dictionary=rows[index]
		if not groups.has(row.kind):groups[row.kind]=[]
		groups[row.kind].append(index)
	for kind in groups:
		var profile:=Roots.profile(kind)
		if profile.is_empty() or not profile.flexible:viewport.free();return {}
		var indices:Array=groups[kind];var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_2D;multi.use_custom_data=true
		multi.mesh=UV.make_mesh(UV.mesh_data(kind,72.0/profile.size.x));multi.instance_count=indices.size()
		for instance in indices.size():
			var index:int=indices[instance];var origin:=slot(index).position+Vector2.ONE*PAD+Vector2(profile.root)*72.0/Vector2(profile.size)
			multi.set_instance_transform_2d(instance,Transform2D(0,Vector2.ONE*scale,0,origin*scale))
			multi.set_instance_custom_data(instance,Color(phase(rows[index].anchor),0,0,0))
		var material:=ShaderMaterial.new();material.shader=ShaderSource
		material.set_shader_parameter("source_atlas",atlas);material.set_shader_parameter("atlas_size",atlas.get_size())
		var region:Rect2=rows[indices[0]].source
		material.set_shader_parameter("source_rect",Vector4(region.position.x,region.position.y,region.size.x,region.size.y))
		material.set_shader_parameter("lock_v",float(profile.lock_y)/profile.size.y);material.set_shader_parameter("top_v",float(profile.top)/profile.size.y)
		var node:=MultiMeshInstance2D.new();node.name=String(kind);node.multimesh=multi;node.material=material;viewport.add_child(node);nodes.append(node)
	return {"viewport":viewport,"groups":nodes,"scale":scale,"rows":rows}
