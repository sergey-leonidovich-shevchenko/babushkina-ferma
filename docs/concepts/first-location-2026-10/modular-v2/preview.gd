extends SceneTree

const OUT := "res://docs/concepts/first-location-2026-10/modular-v2/"
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const MapData := preload("res://scripts/systems/village_map_data.gd")

class SpriteScene extends Node2D:
	var data: Dictionary
	var textures: Dictionary = {}
	var objects: Array = []

	## Загружает только перечисленные в макете отдельные ресурсы без запуска игровой симуляции.
	func prepare(value: Dictionary) -> void:
		data=value
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		for id in data.assets:
			var path: String=data.assets[id].path
			var img:=Image.load_from_file(ProjectSettings.globalize_path(path))
			if img==null: push_error("Нет спрайта: "+path); continue
			textures[id]=ImageTexture.create_from_image(img)
		objects=data.objects.duplicate(true)
		objects.sort_custom(func(a,b):return float(a.anchor[1])<float(b.anchor[1]))

	## Рисует повторяемые покрытия и независимые объекты с общей линией земли и сортировкой по глубине.
	func _draw() -> void:
		var bounds:=Rect2(Vector2.ZERO,Vector2(data.world_size[0],data.world_size[1]))
		draw_rect(bounds,Color("879465"))
		draw_texture_rect(Terrain.GRASS,bounds,true,Color(1,1,1,0.10))
		for patch in data.grass_patches:
			_material(_grass_patch(Vector2(patch[0],patch[1]),Vector2(patch[2],patch[3])),Color("849161"),Terrain.GRASS,0.10)
		for route in data.paths:
			var line:=_smooth(_points(route))
			for i in line.size()-1: _material(Terrain.capsule(line[i],line[i+1],24),Color("bba77b"),Terrain.PATH,0.25)
		_material(_ellipse(Vector2(1310,727),Vector2(224,140)),Color("9a987c"),Terrain.STONE,0.48)
		_draw_farm()
		var river:=_smooth(_points(data.river))
		draw_colored_polygon(_ribbon(river,62),Color("707b4d"))
		draw_colored_polygon(_ribbon(river,52),Color("b5a779"))
		_material(_ribbon(river,46),Color("39717a"),Terrain.WATER,0.18)
		for bridge in data.bridges:
			draw_texture_rect(Terrain.BRIDGE,Rect2(Vector2(bridge[0],bridge[1])-Vector2(72,108),Vector2(144,216)),false)
		_draw_fences()
		for object in objects: _draw_object(object)

	## Накладывает существующую повторяемую текстуру с низкой контрастностью вместо шумной цельной иллюстрации.
	func _material(points: PackedVector2Array, color: Color, texture: Texture2D, opacity: float) -> void:
		draw_colored_polygon(points,color)
		var uv:=PackedVector2Array()
		for point in points: uv.append(point/texture.get_size())
		draw_polygon(points,PackedColorArray([Color(1,1,1,opacity)]),uv,texture)

	## Собирает огород из общей земли и повторяемых независимых растений из существующего атласа.
	func _draw_farm() -> void:
		var rect:=Rect2(144,816,288,240)
		_material(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),Color("70553d"),Terrain.DIRT,0.20)
		for row in 5:
			draw_line(Vector2(156,840+row*48),Vector2(420,840+row*48),Color("624833"),9,true)
			for column in 6:
				if row>=3 and column>=3: continue
				var tex: Texture2D=textures.crop
				draw_texture_rect_region(tex,Rect2(150+column*44,808+row*48,48,48),Rect2(192 if row%2==0 else 288,0,96,96))

	## Ставит прежние секции ограды в ту же сетку 24 пикселя, сохраняя проёмы для прохода.
	func _draw_fences() -> void:
		for span in MapData.FENCE_SPANS:
			var vertical: bool=span.size.y>span.size.x
			for y in range(span.position.y,span.end.y):
				for x in range(span.position.x,span.end.x):
					draw_texture_rect_region(textures.fence,Rect2(x*24,y*24-8,24,32),Terrain.fence_source(2 if vertical else 1))

	## Размещает отдельный спрайт или ячейку старого атласа; декоративные поля не определяют опору.
	func _draw_object(object: Dictionary) -> void:
		var id: String=object.asset
		if not textures.has(id): return
		var profile: Dictionary=data.assets[id]
		var size:=Vector2(profile.draw_size[0],profile.draw_size[1])*float(object.get("scale",1.0))
		var anchor:=Vector2(object.anchor[0],object.anchor[1])
		var destination:=Rect2(anchor-Vector2(size.x*0.5,size.y),size)
		var color:=Color(String(object.get("tint","ffffff")))
		if profile.has("source"):
			var source: Array=profile.source
			draw_texture_rect_region(textures[id],destination,Rect2(source[0],source[1],source[2],source[3]),color)
		else: draw_texture_rect(textures[id],destination,false,color)

	## Переводит явные координаты JSON в единую полилинию поверхности.
	func _points(values: Array) -> PackedVector2Array:
		var result:=PackedVector2Array()
		for value in values: result.append(Vector2(value[0],value[1]))
		return result

	## Скругляет маршрут для простой читаемой дороги и естественного берега без отдельного фонового рисунка.
	func _smooth(points: PackedVector2Array) -> PackedVector2Array:
		var result:=PackedVector2Array()
		for i in points.size()-1:
			var a:=points[maxi(0,i-1)]; var b:=points[i]; var c:=points[i+1]; var d:=points[mini(i+2,points.size()-1)]
			for step in 8:
				var t:=float(step)/8.0
				result.append(0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
		result.append(points[-1]); return result

	## Строит обе кромки русла из той же центральной линии с постоянной локальной шириной.
	func _ribbon(points: PackedVector2Array, radius: float) -> PackedVector2Array:
		var left:=PackedVector2Array(); var right:=PackedVector2Array()
		for i in points.size():
			var tangent:=points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
			var normal:=tangent.normalized().orthogonal()*radius
			left.append(points[i]+normal); right.append(points[i]-normal)
		right.reverse(); left.append_array(right); return left

	## Возвращает замкнутую форму общего материала для площади и тихих вариаций травы.
	func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
		var result:=PackedVector2Array()
		for i in 48: result.append(center+Vector2.from_angle(float(i)*TAU/48.0)*radius)
		return result

	## Делает контур тихого травяного пятна нерегулярным, сохраняя простой общий материал.
	func _grass_patch(center: Vector2, radius: Vector2) -> PackedVector2Array:
		var result:=PackedVector2Array()
		for i in 64:
			var phase:=float(i)*TAU/64.0
			var variation:=1.0+sin(phase*3.0+center.x*0.01)*0.10+cos(phase*5.0)*0.04
			result.append(center+Vector2.from_angle(phase)*radius*variation)
		return result

## Запускает автономный макет после создания движком viewport без загрузки пользовательского сохранения.
func _initialize() -> void:
	_run.call_deferred()

## Снимает тот же набор отдельных спрайтов в двух разрешениях через независимый рендер каждого кадра.
func _run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout.json"))
	for entry in [[Vector2i(1920,1080),"scene-1080p.png"],[Vector2i(3840,2160),"scene-4k.png"]]:
		var viewport:=SubViewport.new()
		viewport.size=entry[0]; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var scene:=SpriteScene.new(); scene.prepare(data)
		scene.scale=Vector2(entry[0])/Vector2(data.world_size[0],data.world_size[1])
		viewport.add_child(scene)
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		var error:=viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+entry[1]))
		print("MODULAR PREVIEW %s: %s"%[entry[1],error])
		viewport.queue_free(); await process_frame
	quit()
