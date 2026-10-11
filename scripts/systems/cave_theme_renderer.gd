extends RefCounted

const Rooms := preload("res://scripts/systems/cave_room_data.gd")
const Assets := preload("res://scripts/systems/cave_asset_system.gd")
const Lighting := preload("res://scripts/systems/cave_lighting_system.gd")
const EnvVisual :=  preload("res://scripts/systems/environment_visual_system.gd")
const Water := preload("res://assets/game/locations/overworld/modular/water_material_v1.png")
const GRASS_BEDS := [Rect2(384,336,456,192),Rect2(1488,744,480,144),Rect2(1200,720,240,120)]
const FUNGAL_BEDS := [Rect2(384,384,360,144),Rect2(384,744,360,144),Rect2(1536,336,384,120),Rect2(1536,744,432,144)]
static var _clusters: Dictionary = {}


## Рисует тематические поверхности и детали один раз в кешируемом фоне выбранной комнаты.
static func draw_background(canvas: Node2D, location: String) -> void:
	if location == "cave_fungal":
		for bed in FUNGAL_BEDS:
			canvas.draw_texture_rect(Lighting.soft_disc(),bed.grow(48),false,Color(0.16,0.34,0.19,0.24))
		for index in clusters(location).size():
			var ground: Vector2 = clusters(location)[index]
			var rect := Assets.Profiles.visual_rect("cave_fungal_canopy",ground) if index % 4 == 0 else Assets.destination_rect("mushrooms",ground)
			canvas.draw_texture_rect(Assets.texture("mushrooms"),rect,false)
	elif location == "cave_moon":
		for bed in GRASS_BEDS:
			canvas.draw_texture_rect(Lighting.soft_disc(),bed.grow(48),false,Color(0.14,0.35,0.47,0.28))
		for ground in clusters(location): _draw_lunar_grass(canvas,ground)
		for ground in [Vector2(480,384),Vector2(1800,864)]: EnvVisual.draw(canvas,"moon_flower",ground)
	elif location == "cave_lake":
		for rectangle in Rooms.POOLS[location]:
			var polygon := Rooms.pool_polygon(rectangle,true); var uvs := PackedVector2Array()
			for point in polygon: uvs.append(point/192.0)
			canvas.draw_polygon(polygon,PackedColorArray([Color("537e99")]),uvs,Water)
			var shore := polygon.duplicate(); shore.append(shore[0])
			canvas.draw_polyline(shore,Color("303c44"),10.0,true); canvas.draw_polyline(shore,Color(0.34,0.43,0.44,0.6),2.0,true)
	elif location == "cave_mine": _draw_rails(canvas)
	elif location == "cave_sanctum":
		for ground in [Vector2(528,480),Vector2(1728,480),Vector2(528,840),Vector2(1944,792)]: EnvVisual.draw(canvas,"ruins_detail",ground)


## Возвращает одинаковые при каждом входе кластеры растительности, сохраняя свободные проходы.
static func clusters(location: String) -> Array:
	if _clusters.has(location): return _clusters[location]
	var result: Array = []
	var beds: Array = GRASS_BEDS if location == "cave_moon" else (FUNGAL_BEDS if location == "cave_fungal" else [])
	var rng := RandomNumberGenerator.new(); rng.seed = 20261011+location.hash()
	for bed in beds:
		for index in int(bed.get_area()/(2600.0 if location == "cave_moon" else 3800.0)):
			var angle := rng.randf_range(0,TAU); var radius := sqrt(rng.randf())
			result.append(bed.get_center()+Vector2(cos(angle),sin(angle))*bed.size*0.44*radius)
	_clusters[location] = result
	return result


## Рисует мягкое дыхание травы, грибницы и блики воды отдельным динамическим слоем.
static func draw_lights(game: Node2D, visible: Rect2, time: float) -> void:
	var location: String = game.current_location
	var beds: Array = GRASS_BEDS if location == "cave_moon" else (FUNGAL_BEDS if location == "cave_fungal" else Rooms.POOLS.get(location,[]))
	var tint := Color(0.32,0.65,1.0,0.10) if location == "cave_moon" else Color(0.28,0.85,0.62,0.08)
	for index in beds.size():
		var bed: Rect2 = beds[index]; var rect := bed.grow(36)
		if not visible.intersects(rect): continue
		var color := tint; color.a *= 0.85+0.15*sin(time*1.2+index)
		game.draw_texture_rect(Lighting.soft_disc(),rect,false,color)
		if location == "cave_lake":
			for ripple in 3:
				var point := bed.position+Vector2(bed.size.x*(ripple+1)/4.0,bed.size.y*0.5)
				game.draw_arc(point,12+fmod(time*8+ripple*13,28),0.2,2.8,16,Color(0.60,0.88,0.94,0.12),1.5,true)


## Рисует небольшой модуль лунной травы из тонких изогнутых стеблей с холодными светлыми кончиками.
static func _draw_lunar_grass(canvas: Node2D, ground: Vector2) -> void:
	for blade in 8:
		var variation := int(ground.x*3+ground.y)+blade*17
		var height := 22.0+posmod(variation,23); var lean := float(posmod(variation*7,43)-21)
		var base := ground+Vector2(float(posmod(variation,17)-8),0); var mid := base+Vector2(lean*0.3,-height*0.52)
		var tip := base+Vector2(lean,-height)
		var leaf := PackedVector2Array([base-Vector2(2,0),mid-Vector2(3,0),tip,mid+Vector2(3,0),base+Vector2(2,0)])
		canvas.draw_polygon(leaf,PackedColorArray([Color("486579"),Color("86b8c5"),Color("d3edf5"),Color("92c5d2"),Color("486579")]))


## Добавляет извилистые рельсы и деревянные шпалы в шахту, не закрывая коридор невидимыми коллизиями.
static func _draw_rails(canvas: Node2D) -> void:
	var track := [Vector2(408,600),Vector2(1776,600),Vector2(1776,840)]
	for index in range(track.size()-1):
		var start: Vector2 = track[index]; var finish: Vector2 = track[index+1]
		var normal := start.direction_to(finish).orthogonal()
		for tie in int(start.distance_to(finish)/48.0)+1:
			var point := start.lerp(finish,tie/float(maxi(1,int(start.distance_to(finish)/48.0))))
			canvas.draw_line(point-normal*30,point+normal*30,Color("6f5540"),8.0)
		for offset in [-18.0,18.0]:
			canvas.draw_line(start+normal*offset,finish+normal*offset,Color("353d45"),7.0)
			canvas.draw_line(start+normal*offset,finish+normal*offset,Color("9ca4a6"),2.0)
