extends RefCounted

const Facing := preload("res://scripts/systems/furniture_facing_system.gd")
const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const Profile := preload("res://assets/game/locations/overworld/boards/profile.json")
const WorldProfile := preload("res://scripts/systems/world_visual_profile_system.gd")
const Legacy := {"board":preload("res://assets/game/locations/overworld/modular/prop_board_v1.png"),"sign":preload("res://assets/game/locations/overworld/modular/prop_board_v1.png")}
const Regions:=preload("res://scripts/systems/village_region_data.gd")
const Visibility:=preload("res://scripts/systems/world_visibility_system.gd")
static var _shadows := {}

## Выбирает один из трёх самостоятельных видов, сохраняя прежний alias заднего направления.
static func view(kind: String, direction: int=0) -> Dictionary:
	return Resources.describe("prop.village_"+kind,Facing.NAMES[Facing.visible(direction)])

## Совмещает измеренную опору столбов с миром без вписывания или растяжения спрайта.
static func destination(kind: String, ground: Vector2, direction: int=0) -> Rect2:
	return Resources.destination(view(kind,direction),ground)

## Возвращает проекции опор; дальняя боковая стойка доски явно помечена как скрытая.
static func contacts(kind: String, ground: Vector2, direction: int=0) -> PackedVector2Array:
	var data:Dictionary=Profile.data.props[kind].views[Facing.NAMES[Facing.visible(direction)]];var result:=PackedVector2Array()
	for p in data.contacts:result.append(ground+(Vector2(p.point[0],p.point[1])-Vector2(data.anchor[0],data.anchor[1]))*0.25)
	return result

## Задаёт одну наглядную рабочую сторону для QA; существующие взаимодействия и коллизии не меняются.
static func approach(kind: String, ground: Vector2, direction: int=0) -> Vector2:
	var side:=Facing.visible(direction)
	return ground+{0:Vector2(0,48),1:Vector2(-48,0),3:Vector2(48,0)}[side]

## Рисует адресный живописный PNG с linear-фильтром либо прежний самостоятельный ресурс.
static func draw(canvas: CanvasItem, kind: String, ground: Vector2, direction: int=0) -> void:
	var texture:Texture2D=Resources.sampled_texture("prop.village_"+kind,Facing.NAMES[Facing.visible(direction)])
	if texture==null:canvas.draw_texture_rect(Legacy[kind],WorldProfile.visual_rect("village_board",ground),false)
	else:canvas.draw_texture_rect(texture,destination(kind,ground,direction),false)

## Отделяет контактную тень от рисунка и всегда выводит её до героя.
static func draw_shadow(canvas: CanvasItem, kind: String, ground: Vector2, direction: int=0) -> void:
	canvas.draw_mesh(shadow(kind,direction),null,Transform2D(0.0,ground))

## Кеширует шесть маленьких мешей; во время кадров нет PNG-readback, viewport или новой геометрии.
static func shadow(kind: String, direction: int=0) -> ArrayMesh:
	var side:=Facing.visible(direction);var key:=kind+str(side)
	if _shadows.has(key):return _shadows[key]
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	for foot in contacts(kind,Vector2.ZERO,side):
		for pass_id in 2:
			var base:=foot
			var center:Vector2=base+Vector2(4,2) if pass_id==0 else base
			var radius:=Vector2(4,1.8) if kind=="board" else Vector2(3,1.5)
			if pass_id==0:radius+=Vector2(4,1)
			var opacity:=0.07 if pass_id==0 else 0.15
			for segment in 20:
				var a:=Vector2.from_angle(TAU*segment/20.0)*radius;var b:=Vector2.from_angle(TAU*(segment+1)/20.0)*radius
				for p in [center,center+a,center+b]:vertices.append(Vector3(p.x,p.y,0))
				colors.append(Color(0.16,0.12,0.08,opacity));colors.append(Color(0.16,0.12,0.08,0));colors.append(Color(0.16,0.12,0.08,0))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);_shadows[key]=mesh;return mesh

## Привязывает основание указателя к клетке24, оставляя исходную точку перехода неизменной.
static func sign_ground(link:Dictionary)->Vector2:
	return Vector2(link.position)-Vector2(0,24)

## Рисует только три прежних указателя первой карты; текст и переходы принадлежат прежнему владельцу.
static func draw_signs(game:Node2D,foreground:bool)->void:
	if game.current_location!="overworld":return
	var visible:=Visibility.visible_rect(game)
	for link in Regions.passages("overworld"):
		var ground:=sign_ground(link)
		if not visible.intersects(destination("sign",ground).grow(12),true):continue
		if not foreground:draw_shadow(game,"sign",ground)
		if (game.AnimationRenderer.player_ground(game).y<ground.y-8)!=foreground:continue
		draw(game,"sign",ground)
