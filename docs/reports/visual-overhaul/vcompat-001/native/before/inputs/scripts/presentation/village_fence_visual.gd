extends RefCounted

const Resources:=preload("res://scripts/systems/visual_resource_catalog.gd")
const MapData:=preload("res://scripts/systems/village_map_data.gd")
const Visibility:=preload("res://scripts/systems/world_visibility_system.gd")
static var _farm:Dictionary={}

## Разрешает три самостоятельные части без поворота или квадратной растяжки.
static func texture(part:String)->Texture2D:
	return Resources.sampled_texture("part.village_fence_"+part,"south")

## Возвращает осевые полусвязи для всех шестнадцати соседств клетки.
static func arms(mask:int)->Array[Vector2]:
	var result:Array[Vector2]=[]
	for pair in [[1,Vector2.UP],[2,Vector2.RIGHT],[4,Vector2.DOWN],[8,Vector2.LEFT]]:
		if mask&int(pair[0]):result.append(pair[1]*12.0)
	return result

## Обрезает подотрезок постоянной плотности; не вписывает исходник в другую пропорцию.
static func rail(canvas:CanvasItem,a:Vector2,b:Vector2,tint:Color=Color.WHITE)->void:
	var horizontal:=is_equal_approx(a.y,b.y);var tex:=texture("rail" if horizontal else "depth")
	if tex==null:return
	var length:=absf(b.x-a.x) if horizontal else absf(b.y-a.y)
	if length<=0.0:return
	var origin:=Vector2(minf(a.x,b.x),a.y-25) if horizontal else Vector2(a.x-3.5,minf(a.y,b.y)-25)
	var size:=Vector2(length,16) if horizontal else Vector2(7,length)
	# Only the end of the wide rail is sampled: the middle brace is not tiled into every half-cell.
	canvas.draw_texture_rect_region(tex,Rect2(origin,size),Rect2(Vector2(8,8),size*4),tint)

## Ставит нижнюю плоскость столба в мировую точку, сохраняя единый масштаб 0.25.
static func post(canvas:CanvasItem,ground:Vector2,tint:Color=Color.WHITE)->void:
	var tex:=texture("post")
	if tex==null:return
	var size:=tex.get_size()*0.25
	canvas.draw_texture_rect(tex,Rect2(ground-Vector2(size.x*0.5,size.y-2),size),false,tint)

## Собирает угол, прямую, тройник или конец из тех же осевых деталей.
static func draw_section(canvas:CanvasItem,ground:Vector2,mask:int,tint:Color=Color.WHITE)->void:
	for end in arms(mask):rail(canvas,ground,ground+end,tint)
	post(canvas,ground,tint)

## Оставляет двухклеточную открытую калитку свободной; створка складывается вдоль оси у петли.
static func draw_gate(canvas:CanvasItem,center:Vector2,orientation:int,opened:bool,tint:Color=Color.WHITE)->void:
	var axis:=Vector2.RIGHT if orientation==0 else Vector2.DOWN
	var hinge:=center-axis*26;var latch:=center+axis*26
	var end:=hinge+(Vector2.UP if orientation==0 else Vector2.LEFT)*48 if opened else latch
	for index in 4:
		rail(canvas,hinge.lerp(end,index/4.0),hinge.lerp(end,(index+1)/4.0),tint)
	post(canvas,hinge,tint);post(canvas,latch,tint)

## Кеширует только неизменные клетки периметра, не игровые сохранения или сетку всей карты.
static func farm_cells()->Dictionary:
	if not _farm.is_empty():return _farm
	for span in MapData.FENCE_SPANS:
		for y in range(span.position.y,span.end.y):
			for x in range(span.position.x,span.end.x):_farm[Vector2i(x,y)]=true
	return _farm

## Вычисляет соединения по настоящему множеству твёрдых клеток, включая общие углы.
static func farm_mask(cell:Vector2i)->int:
	var mask:=0
	for entry in [[Vector2i.UP,1],[Vector2i.RIGHT,2],[Vector2i.DOWN,4],[Vector2i.LEFT,8]]:
		if farm_cells().has(cell+entry[0]):mask|=entry[1]
	return mask

## Рисует периметр по глубине вне кеша земли; два прежних прохода не закрываются створкой.
static func draw_farm(game:Node2D,foreground:bool)->void:
	var visible:=Visibility.visible_rect(game);var tint:Color=game.FenceRenderer.climate_color(game)
	for cell in farm_cells():
		var ground:=Vector2(cell)*24+Vector2(12,12)
		if (ground.y>game.player.y)!=foreground:continue
		if visible.intersects(Rect2(ground-Vector2(28,40),Vector2(56,56))):draw_section(game,ground,farm_mask(cell),tint)

## Ставит секции загонов по узлам 24 px, сохраняя исходные тонкие физические стенки и разрывы.
static func draw_wall(game:Node2D,wall:Rect2,foreground:bool)->void:
	var vertical:=wall.size.y>wall.size.x
	var a:=Vector2(roundf(wall.get_center().x/24)*24,roundf(wall.position.y/24)*24) if vertical else Vector2(roundf(wall.position.x/24)*24,roundf(wall.get_center().y/24)*24)
	var b:=Vector2(a.x,roundf(wall.end.y/24)*24) if vertical else Vector2(roundf(wall.end.x/24)*24,a.y)
	var count:=maxi(1,roundi(a.distance_to(b)/24));var tint:Color=game.FenceRenderer.climate_color(game)
	for index in count:
		var from:=a.lerp(b,index/float(count));var to:=a.lerp(b,(index+1)/float(count))
		if ((from.y+to.y)*0.5>game.player.y)!=foreground:continue
		rail(game,from,to,tint);post(game,from,tint)
		if index==count-1:post(game,to,tint)
