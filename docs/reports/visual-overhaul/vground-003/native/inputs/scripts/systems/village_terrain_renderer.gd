extends RefCounted

const MapData:=preload("res://scripts/systems/village_map_data.gd")
const GRASS:=preload("res://assets/game/locations/overworld/modular/grass_meadow_tile_v1.png")
const DIRT:=preload("res://assets/game/locations/overworld/modular/dirt_material_v1.png")
const PATH:=preload("res://assets/game/locations/overworld/modular/path_material_v1.png")
const STONE:=preload("res://assets/game/locations/overworld/modular/stone_material_v1.png")
const WATER:=preload("res://assets/game/locations/overworld/modular/water_material_v1.png")
const BRIDGE:=preload("res://assets/game/locations/overworld/modular/bridge_modular_v1.png")
const FenceRenderer:=preload("res://scripts/systems/fence_renderer.gd")
const Ambient:=preload("res://scripts/systems/village_ambient_renderer.gd")
static var _fence_sources:Dictionary={}

## Сохраняет прежний полный проход для прямого рендера и обратимого контроля разделённых слоёв.
static func draw(canvas:Node2D,season:String,weather:String,painted_grass:bool=false,soft_edges:bool=false)->void:
	draw_base(canvas,season,weather,painted_grass,soft_edges)
	draw_surface(canvas,season)
	draw_cover(canvas,season,weather)

## Вычисляет прежний сезонный тон неподвижных материалов без изменения состояния игры.
static func ground_tint(season:String,weather:String)->Color:
	var tint:=Color.WHITE
	if season=="autumn": tint=Color("e9c99d")
	elif season=="winter": tint=Color("b9cec9")
	elif season=="summer": tint=Color("dce2bd")
	if weather in ["rain","storm"]: tint*=Color("c3d6dc")
	return tint

## Собирает только неподвижную землю и берега; вода и движущиеся растения сюда не входят.
static func draw_base(canvas:Node2D,season:String,weather:String,painted_grass:bool=false,soft_edges:bool=false)->void:
	var tint:=ground_tint(season,weather)
	if painted_grass: preload("res://scripts/presentation/meadow_ground.gd").draw(canvas,MapData.WORLD_SIZE,tint)
	else: canvas.draw_texture_rect(GRASS,Rect2(Vector2.ZERO,MapData.WORLD_SIZE),true,tint)
	_draw_paths(canvas,soft_edges)
	_draw_plaza(canvas)
	_draw_garden(canvas)
	draw_banks(canvas)

## Оставляет ограды, неподвижные цветы и мосты над водой в прежнем порядке команд.
static func draw_cover(canvas:Node2D,season:String,weather:String)->void:
	var tint:=ground_tint(season,weather)
	_draw_fences(canvas,tint)
	for flower in MapData.FLOWERS:
		if season!="winter": Ambient.draw_cell(canvas,"flowers",flower,Color(0.92,0.95,0.84,0.88))
	for bridge in MapData.BRIDGES:
		_draw_bridge(canvas,bridge)

## Рисует повторяемый материал в полигоне, сохраняя одну мировую UV-сетку для соседних участков.
static func material(canvas:Node2D,points:PackedVector2Array,texture:Texture2D,tint:Color=Color.WHITE)->void:
	var uvs:=PackedVector2Array()
	for point in points: uvs.append(point/texture.get_size())
	canvas.draw_polygon(points,PackedColorArray([tint]),uvs,texture)

## Создаёт скруглённую геометрию отрезка той же ширины, что и функция типа поверхности.
static func capsule(start:Vector2,finish:Vector2,radius:float)->PackedVector2Array:
	var angle:=start.angle_to_point(finish); var points:=PackedVector2Array()
	for index in 13:
		var phase:=angle-PI*0.5+PI*float(index)/12.0
		points.append(finish+Vector2.from_angle(phase)*radius)
	for index in 13:
		var phase:=angle+PI*0.5+PI*float(index)/12.0
		points.append(start+Vector2.from_angle(phase)*radius)
	return points

## Рисует единую мягкую маску либо совместимые старые два прохода без изменения чертежа.
static func _draw_paths(canvas:Node2D,soft_edges:bool=false)->void:
	if soft_edges:
		preload("res://scripts/presentation/ground_edge_masks.gd").draw(canvas,PATH)
		return
	for path in MapData.routes():
		for index in path.size()-1: canvas.draw_colored_polygon(capsule(path[index],path[index+1],MapData.PATH_HALF_WIDTH+1.5),Color("8b8950"))
	for path in MapData.routes():
		for index in path.size()-1: material(canvas,capsule(path[index],path[index+1],MapData.PATH_HALF_WIDTH),PATH)

## Отделяет небольшую торговую площадь камнем, не превращая весь центр в большой пустой прямоугольник.
static func _draw_plaza(canvas:Node2D)->void:
	var center:=MapData.SQUARE.get_center()
	var points:=PackedVector2Array()
	for index in 40:
		var angle:=TAU*float(index)/40.0
		points.append(center+Vector2(cos(angle),sin(angle))*MapData.SQUARE.size*0.5)
	material(canvas,points,STONE,Color("d6c5a1"))

## Обозначает подготовленный огород мягким земляным участком: пустая клетка остаётся доступной для мотыги.
static func _draw_garden(canvas:Node2D)->void:
	var rect:=Rect2(Vector2(MapData.FARM_ORIGIN),Vector2(288,240))
	material(canvas,PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),DIRT,Color("aa9168"))
	for row in 5:
		var start:=rect.position+Vector2(8,24+row*48)
		canvas.draw_line(start,start+Vector2(272,0),Color(0.36,0.26,0.13,0.30),3)

## Рисует берега и прозрачный рисунок воды по навигационным полигонам, а не по независимой картинке.
static func draw_water(canvas:Node2D,season:String)->void:
	draw_banks(canvas)
	draw_surface(canvas,season)

## Оформляет неподвижную кромку отдельно от поверхности и будущих водных материалов.
static func draw_banks(canvas:Node2D)->void:
	for points in [MapData.river_polygon(10.0),MapData.pond_polygon(10.0)]: canvas.draw_colored_polygon(points,Color("626934"))
	for points in [MapData.river_polygon(5.0),MapData.pond_polygon(5.0)]: canvas.draw_colored_polygon(points,Color("bead71"))

## Рисует поверхность воды самостоятельным CanvasItem без запекания в UPDATE_ONCE.
static func draw_surface(canvas:Node2D,season:String,clipped:bool=false)->void:
	var tint:=Color("b3d6da") if season=="winter" else Color("d2e7eb")
	for points in surface_polygons(clipped): material(canvas,points,WATER,tint)

## Ограничивает самостоятельную поверхность теми же границами, которыми раньше отсекал её viewport.
static func surface_polygons(clipped:bool=false)->Array:
	var polygons:=[MapData.river_polygon(),MapData.pond_polygon()]
	if not clipped: return polygons
	var frame:=PackedVector2Array([Vector2.ZERO,Vector2(MapData.WORLD_SIZE.x,0),MapData.WORLD_SIZE,Vector2(0,MapData.WORLD_SIZE.y)])
	var result:=[]
	for points in polygons: result.append_array(Geometry2D.intersect_polygons(points,frame))
	return result

## Вырезает только геометрию водоёма в прозрачность специальным blend-disabled материалом.
static func draw_cutouts(canvas:Node2D)->void:
	for points in [MapData.river_polygon(),MapData.pond_polygon()]: canvas.draw_colored_polygon(points,Color.WHITE)

## Ставит каждую секцию ограды строго в ту же клетку, которая блокирует движение, оставляя широкие проёмы.
static func _draw_fences(canvas:Node2D,tint:Color)->void:
	for span in MapData.FENCE_SPANS:
		var vertical:bool=span.size.y>span.size.x
		for y in range(span.position.y,span.end.y):
			for x in range(span.position.x,span.end.x):
				var rect:=Rect2(Vector2(x,y)*MapData.CELL,Vector2(24,24))
				var source:=fence_source(2 if vertical else 1)
				# Высокая рейка видна на уровне пояса, но её основание остаётся в той же клетке24×24.
				var size:=Vector2(24,32)
				canvas.draw_texture_rect_region(FenceRenderer.ATLAS,Rect2(rect.position-Vector2(0,8),size),source,tint)

## Убирает прозрачные поля внутри ячейки ограды, чтобы соседние торцы касались, а не оставляли щели.
static func fence_source(column:int)->Rect2:
	if not _fence_sources.has(column):
		var source:=FenceRenderer.source(0,column)
		var image:=FenceRenderer.ATLAS.get_image()
		if image.is_compressed(): image.decompress()
		var bounds:=image.get_region(Rect2i(source)).get_used_rect()
		_fence_sources[column]=Rect2(source.position+Vector2(bounds.position),Vector2(bounds.size))
	return _fence_sources[column]

## Кладёт самостоятельный PNG 144×216 поверх русла; открытый настил занимает центральные 96×192 пикселя.
static func _draw_bridge(canvas:Node2D,bridge:Rect2)->void:
	canvas.draw_texture_rect(BRIDGE,Rect2(bridge.get_center()-Vector2(72,108),Vector2(144,216)),false)
