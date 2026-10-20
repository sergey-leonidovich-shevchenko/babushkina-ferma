extends RefCounted

const Apiary := preload("res://scripts/systems/apiary_system.gd")
const TEXTURES := {
	"hive_1":preload("res://assets/game/apiary/hive_1.tres"),
	"hive_2":preload("res://assets/game/apiary/hive_2.tres"),
	"hive_3":preload("res://assets/game/apiary/hive_3.tres"),
	"wild_hive":preload("res://assets/game/apiary/wild_hive.tres"),
	"bees":preload("res://assets/game/apiary/bees.tres"),
	"honeycomb":preload("res://assets/game/apiary/honeycomb.tres"),
	"beeswax":preload("res://assets/game/apiary/beeswax.tres"),
	"pollen":preload("res://assets/game/apiary/pollen.tres"),
	"propolis":preload("res://assets/game/apiary/propolis.tres"),
}

## Совмещает нижнюю опору силуэта с общим основанием, сохраняя пропорции и ширину трёх уровней.
static func destination(kind: String, position: Vector2) -> Rect2:
	var texture:AtlasTexture=TEXTURES[kind]; var size:=texture.get_size()
	size*=minf(96.0/size.x,144.0/size.y) if kind.begins_with("hive_") else minf(72.0/size.x,96.0/size.y)
	return Rect2(position+Vector2(-size.x/2,24-size.y),size)

## Выводит выбранную ступень в окне без игровых декораций и больших пустых полей атласа.
static func draw_preview(game: Node2D, level: int, bounds: Rect2) -> void:
	var texture:AtlasTexture=TEXTURES["hive_"+str(maxi(1,level))]; var size:=texture.get_size()*minf(bounds.size.x/texture.get_width(),bounds.size.y/texture.get_height())
	game.draw_texture_rect(texture,Rect2(bounds.get_center()-size/2,size),false,Color(1,1,1,0.4 if level==0 else 1))

## Рисует маленькие самостоятельные пчелиные ресурсы тем же атласом, что и сырьё пасеки.
static func item_texture(kind: String) -> AtlasTexture:
	return TEXTURES.get(kind)

## Делит ульи по глубине героя и привязывает полёт пчёл к игровому времени, которое стоит на паузе.
static func draw_world(game: Node2D, foreground: bool) -> void:
	var entries:Array=[]
	if game.current_location=="overworld":
		for index in Apiary.Data.SITES.size():
			var item:Dictionary=Apiary.state(game).hives[index]
			entries.append({"position":Apiary.Data.SITES[index],"kind":"hive_"+str(item.level),"empty":item.level==0,"bees":item.colonized})
	for wild in Apiary.Data.WILD:
		if wild.location==game.current_location: entries.append({"position":wild.position,"kind":"wild_hive","empty":false,"bees":true})
	for item in entries:
		var position:Vector2=item.position
		if (position.y+24>game.player.y)!=foreground or not preload("res://scripts/systems/world_projection_system.gd").view_rect(game).grow(144).has_point(position): continue
		if item.empty:
			game.draw_rect(Apiary.Data.base(position),Color(0.7,0.64,0.39,0.16)); game.draw_rect(Apiary.Data.base(position),Color(0.7,0.64,0.39,0.35),false,1); continue
		var bounds:=destination(item.kind,position)
		game.draw_circle(position+Vector2(0,15),25,Color(0.1,0.065,0.025,0.15))
		game.draw_texture_rect(TEXTURES[item.kind],bounds,false)
		if not item.bees: continue
		var phase:float=game.game_minutes*0.5
		for index in 3:
			var offset:=Vector2(cos(phase+index*2.1)*30,sin(phase*1.3+index)*12-35)
			game.draw_texture_rect(TEXTURES.bees,Rect2(position+offset-Vector2(4,4),Vector2(8,8)),false)
