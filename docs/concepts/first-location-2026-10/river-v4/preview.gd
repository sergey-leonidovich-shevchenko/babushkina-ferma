extends SceneTree

const OUT := "res://docs/concepts/first-location-2026-10/river-v4/"
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const MapData := preload("res://scripts/systems/village_map_data.gd")

class RoadMask extends Node2D:
	var routes: Array = []
	var organic: bool = true
	var radius: float = 24.0

	## Собирает белую маску всех маршрутов одним слоем, чтобы пересечения не темнели от наложения.
	func _draw() -> void:
		for route in routes:
			var points: PackedVector2Array = route
			for i in points.size()-1:
				var middle := (points[i]+points[i+1])*0.5
				var width := radius
				if organic:
					width += sin(middle.x*0.057+middle.y*0.021)*1.5+sin(middle.y*0.11)*0.7
				draw_colored_polygon(Terrain.capsule(points[i],points[i+1],width),Color.WHITE)

class SpriteScene extends Node2D:
	var data: Dictionary
	var textures: Dictionary = {}
	var surfaces: Dictionary = {}
	var objects: Array = []
	var stage: int = 0
	var road_mask: Texture2D

	## Загружает независимые объекты и покрытия макета без запуска игровой симуляции или сохранений.
	func prepare(value: Dictionary) -> void:
		data = value
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		for id in data.assets:
			textures[id] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(data.assets[id].path)))
		for id in data.terrain_assets:
			surfaces[id] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(data.terrain_assets[id])))
		objects = data.objects.duplicate(true)
		objects.sort_custom(func(a,b): return float(a.anchor[1]) < float(b.anchor[1]) if not is_equal_approx(float(a.anchor[1]),float(b.anchor[1])) else a.asset == "railing_beam" and b.asset != "railing_beam")

	## Разделяет траву, единый дорожный материал и верхние объекты на три последовательных слоя.
	func _draw() -> void:
		var bounds := Rect2(Vector2.ZERO,Vector2(data.world_size[0],data.world_size[1]))
		if stage == 3 or stage == 4:
			_soft_patch(bounds.get_center(),bounds.size*0.47,Color("c4c284") if stage == 3 else Color("496d38"),0.32 if stage == 3 else 0.30)
			return
		if stage == 0:
			_material(_rect_points(bounds),Color("879961"),surfaces.grass,0.72,768.0)
			for patch in data.grass_patches:
				_soft_patch(Vector2(patch[0],patch[1]),Vector2(patch[2],patch[3]),Color("496d38"),0.30)
			for patch in data.clearings:
				_soft_patch(Vector2(patch[0],patch[1]),Vector2(patch[2],patch[3]),Color("c4c284"),0.32)
			return
		if stage == 1:
			draw_texture_rect(road_mask, bounds, false)
			return
		_material(_ellipse(Vector2(1310,727),Vector2(224,140)),Color("9a987c"),surfaces.stone,0.48)
		_draw_farm()
		var river := _smooth(_points(data.river))
		draw_colored_polygon(_ribbon(river,62),Color("657b42"))
		draw_colored_polygon(_ribbon(river,52),Color("b5a779"))
		_material(_ribbon(river,46),Color("39717a"),surfaces.water,0.18)
		for object in objects:
			if object.asset == "lilies": _draw_object(object)
		for bridge in data.bridges:
			draw_texture_rect(surfaces.bridge,Rect2(Vector2(bridge[0],bridge[1])-Vector2(72,108),Vector2(144,216)),false)
		_draw_fences()
		for object in objects:
			if object.asset != "lilies": _draw_object(object)

	## Повторяет материал в общей мировой UV-сетке, сохраняя независимый от разрешения масштаб рисунка.
	func _material(points: PackedVector2Array, color: Color, texture: Texture2D, opacity: float, period: float = 0.0) -> void:
		draw_colored_polygon(points,color)
		var uv := PackedVector2Array()
		for point in points: uv.append(point/period if period>0.0 else point/texture.get_size())
		draw_polygon(points,PackedColorArray([Color(1,1,1,opacity)]),uv,texture)

	## Даёт полянам и более густой траве широкую мягкую границу вместо заметных одноцветных островков.
	func _soft_patch(center: Vector2, radius: Vector2, color: Color, strength: float) -> void:
		for ring in 24:
			var factor := lerpf(1.0,0.72,float(ring)/23.0)
			var tint := color
			tint.a = strength/24.0
			draw_colored_polygon(_grass_patch(center,radius*factor),tint)

	## Переиспользует существующие растения, огородную землю и простые рядки рядом с домом.
	func _draw_farm() -> void:
		var rect := Rect2(144,816,288,240)
		_material(_rect_points(rect),Color("70553d"),surfaces.dirt,0.20)
		for row in 5:
			draw_line(Vector2(156,840+row*48),Vector2(420,840+row*48),Color("624833"),9,true)
			for column in 6:
				if row>=3 and column>=3: continue
				draw_texture_rect_region(textures.crop,Rect2(150+column*44,808+row*48,48,48),Rect2(192 if row%2==0 else 288,0,96,96))

	## Сохраняет отдельные секции ограды и прежние проходы на сетке 24 пикселя.
	func _draw_fences() -> void:
		for span in MapData.FENCE_SPANS:
			var vertical: bool = span.size.y>span.size.x
			for y in range(span.position.y,span.end.y):
				for x in range(span.position.x,span.end.x):
					draw_texture_rect_region(textures.fence,Rect2(x*24,y*24-8,24,32),Terrain.fence_source(2 if vertical else 1))

	## Ставит отдельный спрайт по опорной точке без привязки к нарисованному фону.
	func _draw_object(object: Dictionary) -> void:
		var id: String = object.asset
		if id == "railing_beam":
			var start := Vector2(object.from[0],object.from[1])-Vector2(0,float(object.elevation))
			var finish := Vector2(object.to[0],object.to[1])-Vector2(0,float(object.elevation))
			draw_set_transform(start,start.angle_to_point(finish),Vector2.ONE)
			draw_texture_rect(textures[id],Rect2(-2,-3.5,start.distance_to(finish)+4,7),false)
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
			return
		var profile: Dictionary = data.assets[id]
		var size := Vector2(profile.draw_size[0],profile.draw_size[1])*float(object.get("scale",1.0))
		var anchor := Vector2(object.anchor[0],object.anchor[1])
		var destination := Rect2(anchor-Vector2(size.x*0.5,size.y),size)
		var color := Color(String(object.get("tint","ffffff")))
		if profile.has("source"):
			var source: Array = profile.source
			draw_texture_rect_region(textures[id],destination,Rect2(source[0],source[1],source[2],source[3]),color)
		else: draw_texture_rect(textures[id],destination,false,color)

	## Возвращает углы прямоугольника как полигон материала.
	func _rect_points(rect: Rect2) -> PackedVector2Array:
		return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

	## Переводит явные координаты из JSON в полилинию поверхности.
	func _points(values: Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for value in values: result.append(Vector2(value[0],value[1]))
		return result

	## Скругляет общие маршруты дорог и реки, сохраняя входы к домам и мостам.
	func _smooth(points: PackedVector2Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for i in points.size()-1:
			var a := points[maxi(0,i-1)]; var b := points[i]; var c := points[i+1]; var d := points[mini(i+2,points.size()-1)]
			for step in 12:
				var t := float(step)/12.0
				result.append(0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
		result.append(points[-1])
		return result

	## Строит постоянную ширину берегов от той же центральной линии.
	func _ribbon(points: PackedVector2Array, radius: float) -> PackedVector2Array:
		var left := PackedVector2Array(); var right := PackedVector2Array()
		for i in points.size():
			var tangent := points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
			var normal := tangent.normalized().orthogonal()*radius
			left.append(points[i]+normal); right.append(points[i]-normal)
		right.reverse(); left.append_array(right)
		return left

	## Создаёт замкнутую овальную область площади.
	func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
		var result := PackedVector2Array()
		for i in 48: result.append(center+Vector2.from_angle(float(i)*TAU/48.0)*radius)
		return result

	## Делает спокойный нерегулярный контур луговой растительности без крупных блоков цвета.
	func _grass_patch(center: Vector2, radius: Vector2) -> PackedVector2Array:
		var result := PackedVector2Array()
		for i in 96:
			var phase := float(i)*TAU/96.0
			var variation := 1.0+sin(phase*3.0+center.x*0.01)*0.10+cos(phase*5.0)*0.04
			result.append(center+Vector2.from_angle(phase)*radius*variation)
		return result

## Запускает автономный визуальный макет после создания корневого viewport.
func _initialize() -> void:
	_run.call_deferred()

## Рендерит соединённые дороги в отдельную альфа-маску с одинаковой обработкой всех развилок.
func _make_road_mask(routes: Array, size: Vector2i, scale_factor: float, organic: bool) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var layer := RoadMask.new()
	layer.routes = routes; layer.organic = organic; layer.scale = Vector2.ONE*scale_factor
	viewport.add_child(layer)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var result := ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free(); await process_frame
	return result

## Назначает один земляной материал и масштаб мягкой кромки всему дорожному слою.
func _road_material(earth: Texture2D, world_size: Vector2, period: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string(OUT+"road.gdshader")
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("earth",earth)
	result.set_shader_parameter("world_size",world_size)
	result.set_shader_parameter("texture_period",period)
	return result

## Сохраняет шесть прозрачных дорожных модулей с одинаковыми портами на границах клеток.
func _save_road_modules(earth: Texture2D) -> void:
	var corner := PackedVector2Array([Vector2(48,-96),Vector2(48,24)])
	for i in 17:
		corner.append(Vector2(72,24)+Vector2.from_angle(PI-float(i)*PI*0.5/16.0)*24)
	corner.append(Vector2(192,48))
	var horizontal := PackedVector2Array([Vector2(-96,48),Vector2(192,48)])
	var vertical := PackedVector2Array([Vector2(48,-96),Vector2(48,192)])
	var north := PackedVector2Array([Vector2(48,-96),Vector2(48,48)])
	var definitions := {"horizontal":[horizontal],"vertical":[vertical],"corner":[corner],"junction_t":[horizontal,north],"cross":[horizontal,vertical],"end":[north]}
	for id in definitions:
		var mask: Texture2D = await _make_road_mask(definitions[id],Vector2i(384,384),4.0,false)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(384,384); viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var sprite := Sprite2D.new()
		sprite.texture = mask; sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.material = _road_material(earth,Vector2(96,96),96.0)
		viewport.add_child(sprite)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var error := _save_straight_alpha(viewport.get_texture().get_image(),OUT+"roads/"+id+".png")
		print("ROAD MODULE %s: %s"%[id,error])
		viewport.queue_free(); await process_frame

## Сохраняет прозрачные пятна поляны и густой травы для свободного размещения поверх любого материала.
func _save_patches() -> void:
	for entry in [[3,"clearing"],[4,"grass_dense"]]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512,384); viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var layer := SpriteScene.new()
		layer.data = {"world_size":[512,384]}; layer.stage = entry[0]
		viewport.add_child(layer)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var error := _save_straight_alpha(viewport.get_texture().get_image(),OUT+"overlays/"+entry[1]+".png")
		print("GRASS OVERLAY %s: %s"%[entry[1],error])
		viewport.queue_free(); await process_frame

## Переводит предумноженный альфа-канал viewport в обычный PNG, чтобы кромки не темнели при повторном использовании.
func _save_straight_alpha(image: Image, path: String) -> Error:
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			if color.a>0.0 and color.a<1.0:
				image.set_pixel(x,y,Color(minf(color.r/color.a,1.0),minf(color.g/color.a,1.0),minf(color.b/color.a,1.0),color.a))
	return image.save_png(ProjectSettings.globalize_path(path))

## Собирает тот же набор модулей в нативных кадрах 1080p и 4K без изменения игровой локации.
func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout.json"))
	var helper := SpriteScene.new()
	var routes: Array = []
	for route in data.paths: routes.append(helper._smooth(helper._points(route)))
	var mask: Texture2D = await _make_road_mask(routes,Vector2i(4800,2700),2.0,true)
	var earth := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(data.terrain_assets.path)))
	for entry in [[Vector2i(1920,1080),"scene-1080p.png"],[Vector2i(3840,2160),"scene-4k.png"]]:
		var viewport := SubViewport.new()
		viewport.size = entry[0]
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var container := Node2D.new()
		container.scale = Vector2(entry[0])/Vector2(data.world_size[0],data.world_size[1])
		viewport.add_child(container)
		for index in 3:
			var layer := SpriteScene.new()
			layer.prepare(data); layer.stage = index
			if index == 1:
				layer.road_mask = mask
				layer.material = _road_material(earth,Vector2(2400,1350),288.0)
			container.add_child(layer)
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+entry[1]))
		print("TERRAIN PREVIEW %s: %s"%[entry[1],error])
		viewport.queue_free(); await process_frame
	await _save_road_modules(earth)
	await _save_patches()
	helper.free()
	quit()
