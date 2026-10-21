extends RefCounted

const Facing := preload("res://scripts/systems/furniture_facing_system.gd")
const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const Profile := preload("res://assets/game/locations/overworld/benches/profile.json")
const Legacy := preload("res://assets/game/locations/overworld/modular/prop_bench_v1.png")
static var _shadows := {}

## Разрешает только три самостоятельных ракурса с одной плотностью мировых пикселей.
static func view(direction: int=0) -> Dictionary:
	return Resources.describe("prop.village_bench",Facing.NAMES[Facing.visible(direction)])

## Сохраняет измеренную опору и пропорции без растяжения PNG до прежнего квадратного габарита.
static func destination(ground: Vector2, direction: int=0) -> Rect2:
	return Resources.destination(view(direction),ground)

## Возвращает четыре настоящие точки контакта из паспорта без чтения пикселей во время игры.
static func contacts(ground: Vector2, direction: int=0) -> PackedVector2Array:
	var data:Dictionary=Profile.data.views[Facing.NAMES[Facing.visible(direction)]];var result:=PackedVector2Array()
	for p in data.contacts:result.append(ground+(Vector2(p[0],p[1])-Vector2(data.anchor[0],data.anchor[1]))*0.25)
	return result

## Задаёт единственный свободный подход со стороны сиденья, не добавляя механику сидения.
static func approach(ground: Vector2, direction: int=0) -> Vector2:
	return ground+{0:Vector2(0,32),1:Vector2(-40,-20),3:Vector2(40,-20)}[Facing.visible(direction)]

## Рисует новую лавочку; потеря адресного ресурса сохраняет старый независимый спрайт.
static func draw(canvas: CanvasItem, ground: Vector2, direction: int=0) -> void:
	var texture:Texture2D=Resources.sampled_texture("prop.village_bench",Facing.NAMES[Facing.visible(direction)])
	if texture==null:canvas.draw_texture_rect(Legacy,Rect2(ground-Vector2(48,72),Vector2(96,72)),false)
	else:canvas.draw_texture_rect(texture,destination(ground,direction),false)

## Рисует один кешированный мягкий mesh под четырьмя ножками до героя, отдельно от PNG.
static func draw_shadow(canvas: CanvasItem, ground: Vector2, direction: int=0) -> void:
	canvas.draw_mesh(shadow(direction),null,Transform2D(0.0,ground))

## Строит маленькую общую геометрию один раз для каждого направления; покадровых изображений нет.
static func shadow(direction: int=0) -> ArrayMesh:
	var side:=Facing.visible(direction)
	if _shadows.has(side):return _shadows[side]
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	for foot in contacts(Vector2.ZERO,side):
		for pass_id in 2:
			var center:Vector2=foot+Vector2(4,2) if pass_id==0 else foot
			var radius:=Vector2(7,2.8) if pass_id==0 else Vector2(3.2,1.8)
			var opacity:=0.10 if pass_id==0 else 0.23
			for segment in 16:
				var a:=Vector2.from_angle(TAU*segment/16.0)*radius;var b:=Vector2.from_angle(TAU*(segment+1)/16.0)*radius
				for p in [center,center+a,center+b]:vertices.append(Vector3(p.x,p.y,0))
				colors.append(Color(0.16,0.12,0.08,opacity));colors.append(Color(0.16,0.12,0.08,0));colors.append(Color(0.16,0.12,0.08,0))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);_shadows[side]=mesh;return mesh
