extends RefCounted

const Data := preload("res://scripts/systems/village_region_data.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const Ambient := preload("res://scripts/systems/village_ambient_renderer.gd")
const PLOTS := [Rect2(336,552,240,120),Rect2(336,744,240,120),Rect2(1392,360,240,120)]

## Собирает землю каждого района из тех же независимых материалов, что используются на ферме.
static func draw(canvas: Node2D, location: String, season: String, weather: String) -> void:
	var tint:Color={"spring":Color.WHITE,"summer":Color("e4e3bc"),"autumn":Color("e9c99d"),"winter":Color("b9cec9")}.get(season,Color.WHITE)
	if weather in ["rain","storm"]: tint*=Color("c3d6dc")
	canvas.draw_texture_rect(Terrain.GRASS,Rect2(Vector2.ZERO,Data.SIZE),true,tint)
	paths(canvas,location)
	if location=="village_market": rectangle(canvas,Rect2(648,432,768,360),Terrain.STONE,Color("ded7be"))
	elif location=="village_workyard": rectangle(canvas,Rect2(672,480,768,432),Terrain.DIRT,Color("c3a77a"))
	elif location=="village_garden":
		for plot in PLOTS: rectangle(canvas,plot,Terrain.DIRT,Color("b59d70"))
	elif location=="village_river": water(canvas,tint)
	if location=="village_workyard": paths(canvas,location)
	for y in range(360,1080,168):
		for x in range(288,1800,192):
			var seed:=posmod(x*13+y*7+location.hash(),997)
			if seed%3==0: continue
			var point:=Vector2(x+seed%97-48,y+(seed/7)%79-39)
			if not flower_patch(location,point): continue
			if season!="winter": Ambient.draw_cell(canvas,"flowers",point,Color(0.90,0.94,0.82,0.65))

## Оставляет цветочные островки только на свободной траве, вне дорог, дворов и лекарственных грядок.
static func flower_patch(location: String, point: Vector2) -> bool:
	if Data.water_blocks(location,point,36): return false
	if location=="village_market" and Rect2(648,432,768,360).grow(36).has_point(point): return false
	if location=="village_workyard" and Rect2(672,480,768,432).grow(36).has_point(point): return false
	if location=="village_garden" and PLOTS.any(func(plot): return plot.grow(36).has_point(point)): return false
	for path in Data.routes(location):
		for index in range(1,path.size()):
			if Geometry2D.get_closest_point_to_segment(point,path[index-1],path[index]).distance_to(point)<72: return false
	return true

## Рисует дорожные ветви и повороты по индивидуальному чертежу района.
static func paths(canvas: Node2D, location: String, soft_edges: bool=false, rectangular: bool=false, joined: bool=false) -> void:
	if location=="overworld" and soft_edges:
		preload("res://scripts/presentation/ground_edge_masks.gd").draw(canvas,Terrain.PATH,true,Color("ddc79e"),rectangular,joined)
		return
	for path in Data.routes(location):
		for index in range(1,path.size()): Terrain.material(canvas,Terrain.capsule(path[index-1],path[index],36),Terrain.PATH,Color("ddc79e"))

## Укладывает повторяемый материал в единый прямоугольный участок без большой фоновой картинки.
static func rectangle(canvas: Node2D, rect: Rect2, texture: Texture2D, tint: Color) -> void:
	Terrain.material(canvas,PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),texture,tint)

## Рисует вертикальную реку и повёрнутые деревянные мосты с совпадающими физическими настилами.
static func water(canvas: Node2D, tint: Color) -> void:
	rectangle(canvas,Data.WATER.grow(10),Terrain.DIRT,Color("bbaa75"))
	rectangle(canvas,Data.WATER,Terrain.WATER,tint)
	for span in Data.RAILS:
		for y in range(int(span.position.y),int(span.end.y),24): canvas.draw_texture_rect_region(Terrain.FenceRenderer.ATLAS,Rect2(span.position.x,y-8,24,32),Terrain.fence_source(2),tint)
	for bridge in Data.BRIDGES:
		canvas.draw_set_transform(bridge.get_center(),PI/2)
		canvas.draw_texture_rect(Terrain.BRIDGE,Rect2(-72,-108,144,216),false,tint)
		canvas.draw_set_transform(Vector2.ZERO)
