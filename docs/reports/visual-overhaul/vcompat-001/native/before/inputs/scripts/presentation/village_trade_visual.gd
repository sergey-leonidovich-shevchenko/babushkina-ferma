extends RefCounted

const Facing:=preload("res://scripts/systems/furniture_facing_system.gd")
const Resources:=preload("res://scripts/systems/visual_resource_catalog.gd")
const Profile:=preload("res://assets/game/locations/overworld/trade/profile.json")
const Legacy:=preload("res://scripts/systems/world_loot_visual_system.gd")
const Visibility:=preload("res://scripts/systems/world_visibility_system.gd")
const PARTS:=[{"kind":"stall","ground":Vector2(1152,720),"scale":1.0},{"kind":"crate","ground":Vector2(1104,720),"scale":1.0},{"kind":"barrel","ground":Vector2(1200,720),"scale":1.0},{"kind":"sack","ground":Vector2(1176,720),"scale":0.5}]
static var _shadows:={}

## Разрешает три вида; круглые немаркированные бочка и мешок явно используют общий рисунок.
static func view(kind:String,direction:int=0)->Dictionary:
	return Resources.describe("prop.village_trade_"+kind,Facing.NAMES[Facing.visible(direction)])

## Совмещает опору с землёй и меняет размер экземпляра равномерно по двум осям.
static func destination(kind:String,ground:Vector2,direction:int=0,instance_scale:float=1.0)->Rect2:
	var rect:=Resources.destination(view(kind,direction),Vector2.ZERO)
	return Rect2(ground+rect.position*instance_scale,rect.size*instance_scale)

## Возвращает измеренные контакты видимых стоек или нижнего основания без чтения PNG в кадре.
static func contacts(kind:String,ground:Vector2,direction:int=0)->PackedVector2Array:
	var data:Dictionary=Profile.data.props[kind].views[Facing.NAMES[Facing.visible(direction)]];var result:=PackedVector2Array()
	for p in data.contacts:result.append(ground+(Vector2(p[0],p[1])-Vector2(data.anchor[0],data.anchor[1]))*0.25)
	return result

## Показывает одну рабочую сторону прилавка; направление предмета не создаёт новую механику.
static func approach(_kind:String,ground:Vector2,direction:int=0)->Vector2:
	return ground+{0:Vector2(0,48),1:Vector2(-48,0),3:Vector2(48,0)}[Facing.visible(direction)]

## Рисует отдельный живописный ресурс с адресным прежним запасным вариантом.
static func draw(canvas:CanvasItem,kind:String,ground:Vector2,direction:int=0,instance_scale:float=1.0,tint:Color=Color.WHITE)->void:
	var texture:Texture2D=Resources.sampled_texture("prop.village_trade_"+kind,Facing.NAMES[Facing.visible(direction)])
	if texture!=null:canvas.draw_texture_rect(texture,destination(kind,ground,direction,instance_scale),false,tint)
	elif kind!="stall":canvas.draw_texture_rect(Legacy.texture("supply_crate" if kind=="crate" else kind),Rect2(ground-Vector2(36,72)*instance_scale,Vector2(72,72)*instance_scale),false,tint)

## Рисует кешированную мягкую контактную тень отдельно от текстуры предмета.
static func draw_shadow(canvas:CanvasItem,kind:String,ground:Vector2,direction:int=0,instance_scale:float=1.0,tint:Color=Color.WHITE)->void:
	canvas.draw_mesh(shadow(kind,direction),null,Transform2D(0.0,Vector2(instance_scale,instance_scale),0.0,ground),tint)

## Создаёт не более восьми общих маленьких мешей; нейтральные виды разделяют один кеш.
static func shadow(kind:String,direction:int=0)->ArrayMesh:
	var side:int=0 if kind in ["barrel","sack"] else Facing.visible(direction);var key:=kind+str(side)
	if _shadows.has(key):return _shadows[key]
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	for foot in contacts(kind,Vector2.ZERO,side):
		var radius:=Vector2(7,2) if kind=="stall" else (Vector2(20,4) if kind=="sack" else Vector2(10,2.5))
		for pass_id in 2:
			var center:Vector2=foot+Vector2(3,2) if pass_id==0 else foot
			var r:Vector2=radius*1.3 if pass_id==0 else radius;var opacity:=0.07 if pass_id==0 else 0.16
			for segment in 20:
				var a:=Vector2.from_angle(TAU*segment/20.0)*r;var b:=Vector2.from_angle(TAU*(segment+1)/20.0)*r
				for p in [center,center+a,center+b]:vertices.append(Vector3(p.x,p.y,0))
				colors.append(Color(0.16,0.12,0.08,opacity));colors.append(Color(0.16,0.12,0.08,0));colors.append(Color(0.16,0.12,0.08,0))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);_shadows[key]=mesh;return mesh

## Проверяет принадлежность нового мешка только первой карте; коллизии и содержимое остаются прежними.
static func painted_sack(container:Dictionary)->bool:
	return container.location=="overworld" and container.kind=="sack" and Resources.sampled_texture("prop.village_trade_sack","south")!=null

## Делит существующие мешки по ногам героя; открытие оставляет прежние альфу и подпись.
static func draw_sacks(game:Node2D,foreground:bool=false)->void:
	if game.current_location!="overworld":return
	var visible:=Visibility.visible_rect(game)
	for container in game.world_loot_nodes:
		if not painted_sack(container):continue
		var ground:Vector2=Vector2(container.position).round()+Vector2(0,12)
		if not visible.intersects(destination("sack",ground).grow(12),true):continue
		var tint:=Color(1,1,1,0.38 if container.opened else 1.0)
		if not foreground:draw_shadow(game,"sack",ground,0,1.0,tint)
		if (game.AnimationRenderer.player_ground(game).y<ground.y-8)==foreground:draw(game,"sack",ground,0,1.0,tint)

## Раскладывает прежнюю ярмарку на четыре модуля на суше без новых коллизий и переноса её услуги.
static func draw_market(game:Node2D,foreground:bool=false)->void:
	if game.current_location!="overworld" or game.state.world.estate.event!="market":return
	if Resources.sampled_texture("prop.village_trade_stall","south")==null:
		if not foreground:game.WorldPolishRenderer.draw_cell(game,0,1,Rect2(Vector2(1056,648),Vector2(144,144)))
		return
	var visible:=Visibility.visible_rect(game)
	for part in PARTS:
		if not visible.intersects(destination(part.kind,part.ground,0,part.scale).grow(12),true):continue
		if not foreground:draw_shadow(game,part.kind,part.ground,0,part.scale)
		if (game.AnimationRenderer.player_ground(game).y<part.ground.y-8)==foreground:draw(game,part.kind,part.ground,0,part.scale)
