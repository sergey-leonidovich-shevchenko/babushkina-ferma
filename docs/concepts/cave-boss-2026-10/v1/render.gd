extends SceneTree

const OUTPUT := "res://docs/concepts/cave-boss-2026-10/v1/"

class ArenaCanvas extends Node2D:
	const Assets := preload("res://scripts/systems/cave_asset_system.gd")
	const Layout := preload("res://scripts/systems/cave_layout_system.gd")
	const Light := preload("res://scripts/systems/cave_lighting_system.gd")
	const Rooms := preload("res://scripts/systems/cave_room_data.gd")
	const Env := preload("res://scripts/systems/environment_visual_system.gd")
	const Hero := preload("res://scripts/systems/hero_visual_system.gd")
	const Boss := preload("res://assets/game/enemies/cave_guardian.png")
	const Water := preload("res://assets/game/locations/overworld/modular/water_material_v1.png")
	const UI_FONT := preload("res://assets/game/fonts/ui_font.tres")
	var variant := "a"
	var state := "windup"
	var overview := true
	var camera := Vector2.ZERO
	var floor := PackedVector2Array()
	var walls: Array = []
	var pools: Array = []
	var props: Array = []
	var boss_position := Vector2(1512,672)
	var hero_position := Vector2(1224,792)
	var seals: Array = []

	## Собирает только проектный макет из производственных спрайтов; игровая карта не меняется.
	func prepare() -> void:
		if variant == "a":
			floor = PackedVector2Array([Vector2(792,216),Vector2(1848,216),Vector2(2112,432),Vector2(2208,816),Vector2(1968,1080),Vector2(864,1080),Vector2(600,888),Vector2(576,504)])
			seals = [Vector2(1128,384),Vector2(1968,648),Vector2(1248,1008)]
		else:
			floor = Rooms.pool_polygon(Rect2(600,240,1608,840))
			boss_position = Vector2(1512,648)
			hero_position = Vector2(1176,768)
			pools = [Rect2(744,288,480,192),Rect2(1776,888,336,144)]
			seals = [Vector2(888,768),Vector2(1896,480),Vector2(1560,1008)]
		for rectangle in [Rect2(504,528,216,192),Rect2(240,408,384,432),Rect2(-120,528,456,192),Rect2(1632,-120,192,408)]:
			var merged := Geometry2D.merge_polygons(floor,Rooms.rectangle_polygon(rectangle))
			assert(merged.size() == 1,"Все части макета должны образовать соединённый зал")
			floor = merged[0]
		var area := 0.0
		for index in floor.size(): area += floor[index].cross(floor[(index+1)%floor.size()])
		if area < 0: floor.reverse()
		Layout._append_walls(walls,floor)
		walls.sort_custom(func(left,right): return left.position.y < right.position.y)
		props = [
			{"kind":"torch","position":Vector2(336,456)}, {"kind":"torch","position":Vector2(336,792)},
			{"kind":"stalagmites","position":Vector2(864,336)}, {"kind":"stalagmites","position":Vector2(2088,744)},
			{"kind":"boulder","position":Vector2(2016,984)}, {"kind":"rubble","position":Vector2(792,984)},
			{"kind":"crystal_fragments","position":Vector2(1920,312)}, {"kind":"crystal_fragments","position":Vector2(1056,1008)},
		]
		if variant == "b":
			props[2].position = Vector2(672,336)
			props[3].position = Vector2(2136,648)
			props[4].position = Vector2(2136,1008)
			props[6].position = Vector2(1968,336)
		for seal in seals: props.append({"kind":"crystal_blue","position":seal})
		if state == "before": hero_position = Vector2(1008,704)
		elif state == "victory": hero_position = Vector2(1608,432)
		if not overview: camera = Vector2(792,336)
		if state == "victory" and not overview: camera = Vector2(1104,0)
		assert(Geometry2D.is_point_in_polygon(hero_position,floor),"Герой находится на полу")
		for prop in props:
			assert(Geometry2D.is_point_in_polygon(prop.position,floor),"Декор стоит на полу")
		for pool in pools:
			assert(not Geometry2D.is_point_in_polygon(hero_position,Rooms.pool_polygon(pool,true)),"Герой стоит на сухом берегу")
			for prop in props: assert(not Geometry2D.is_point_in_polygon(prop.position,Rooms.pool_polygon(pool,true)),"Кристаллы и декор не стоят на воде")

	## Рисует целый зал или кадр масштаба игры с компактной полосой босса.
	func _draw() -> void:
		draw_rect(Rect2(Vector2(-100,-100),Vector2(2700,1600)),Color("111720"))
		draw_set_transform(-camera)
		var uvs := PackedVector2Array()
		for point in floor: uvs.append(point/768.0)
		draw_polygon(floor,PackedColorArray([Color("a7b1cb") if variant == "a" else Color("a2babb")]),uvs,Assets.floor_texture())
		_draw_water()
		_draw_platform()
		for wall in walls: _shadow(wall.position,Vector2(wall.bounds.size.x*1.2,52),0.34)
		for wall in walls: _sprite(wall.kind,wall.position)
		for seal in seals:
			draw_texture_rect(Light.soft_disc(),Rect2(seal-Vector2(156,108),Vector2(312,216)),false,Color(0.23,0.67,1.0,0.22 if state != "victory" else 0.06))
		_shadow(Vector2(936,648),Vector2(96,24),0.4)
		Env.draw(self,"moon_altar",Vector2(936,648),Color.WHITE,0.44)
		for prop in props:
			_shadow(prop.position,Vector2(Assets.profile(prop.kind).visual_size.x,28),0.4)
			_sprite(prop.kind,prop.position)
		for point in ([Vector2(1008,336),Vector2(2016,456),Vector2(840,888),Vector2(1848,984)] if variant == "a" else [Vector2(744,456),Vector2(1944,384),Vector2(720,1008),Vector2(1464,1032)]):
			_shadow(point,Vector2(80,24),0.42)
			Env.draw(self,"ruins_detail",point)
		_draw_exit()
		if state != "victory":
			_draw_attack()
			_shadow(boss_position,Vector2(190,60),0.64)
			draw_texture_rect(Light.soft_disc(),Rect2(boss_position-Vector2(168,210),Vector2(336,336)),false,Color(0.29,0.64,0.91,0.19))
			var tint := Color("a3abb6") if state == "before" else Color.WHITE
			draw_texture_rect(Boss,Rect2(boss_position-Vector2(112,220),Vector2(224,224)),false,tint)
		else:
			_sprite("rubble",boss_position)
			Env.draw(self,"moon_chest",Vector2(1728,360))
		_shadow(hero_position,Vector2(40,12),0.5)
		Hero.draw_pose(self,hero_position,Hero.walk_pose(Vector2.RIGHT,0,false))
		if state == "before":
			_draw_label(Vector2(456,600),"ВХОД В АРЕНУ",15,Color("d5e5e8"))
			_draw_label(boss_position+Vector2(0,52),"Хранитель ещё спит",15,Color("abc4d2"))
		for wall in walls:
			if wall.front: _sprite(wall.kind,wall.position)
		draw_set_transform(Vector2.ZERO)
		_draw_hud()

	## Добавляет свободный каменный круг; руны не служат препятствиями для уклонения.
	func _draw_platform() -> void:
		var center := Vector2(1488,672)
		draw_texture_rect(Light.soft_disc(),Rect2(center-Vector2(492,336),Vector2(984,672)),false,Color(0.13,0.22,0.30,0.52))
		var rim := PackedVector2Array()
		for index in 97: rim.append(center+Vector2(cos(index/96.0*TAU)*396,sin(index/96.0*TAU)*240))
		draw_polyline(rim,Color("3a4554"),14,true)
		draw_polyline(rim,Color("697a83"),2,true)
		for index in 12:
			var angle := index/12.0*TAU
			var point := center+Vector2(cos(angle)*366,sin(angle)*218)
			var color := Color("72a8c1") if state != "victory" else Color("cceae6")
			draw_line(point+Vector2(-6,-6),point+Vector2(0,7),color,2,true)
			draw_line(point+Vector2(0,7),point+Vector2(6,-6),color,2,true)
			draw_line(point-Vector2(6,0),point+Vector2(6,0),color,2,true)
		if variant == "b":
			for point in [Vector2(744,864),Vector2(744,960),Vector2(1968,600)]: _sprite("mushrooms",point)

	## Использует существующий материал воды и реальные береговые контуры проектного варианта.
	func _draw_water() -> void:
		for rectangle in pools:
			var polygon := Rooms.pool_polygon(rectangle,true); var uvs := PackedVector2Array()
			for point in polygon: uvs.append(point/192.0)
			draw_polygon(polygon,PackedColorArray([Color("526f87")]),uvs,Water)
			var shore := polygon.duplicate(); shore.append(shore[0])
			draw_polyline(shore,Color("2c3d47"),12,true)
			draw_polyline(shore,Color(0.41,0.54,0.57,0.5),2,true)

	## Показывает три печати на выходе; после победы остаётся открытый туннель и сундук.
	func _draw_exit() -> void:
		var passage := Vector2(1728,192)
		for index in 3:
			var point := passage+Vector2((index-1)*44,0)
			var active := state != "victory"
			draw_texture_rect(Light.soft_disc(),Rect2(point-Vector2(64,64),Vector2(128,128)),false,Color(0.36,0.78,1.0,0.24 if active else 0.04))
			draw_colored_polygon(PackedVector2Array([point+Vector2(0,-18),point+Vector2(10,0),point+Vector2(0,18),point+Vector2(-10,0)]),Color("8dd6f1") if active else Color("475b66"))
		_draw_label(Vector2(1728,112),"ПРОХОД ОТКРЫТ" if state == "victory" else "ЛУННАЯ ПЕЧАТЬ",14,Color("aec8d9"))

	## Фиксирует опасную область до удара; пустой центр и проходы сохраняют пространство для отхода.
	func _draw_attack() -> void:
		if state == "before": return
		var targets: Array = [Vector2(1368,792)] if state == "windup" else [Vector2(1272,864),Vector2(1776,600)]
		for target in targets:
			var radius := 132.0 if state == "windup" else 96.0
			draw_circle(target,radius,Color(0.90,0.35,0.20,0.13))
			draw_arc(target,radius,0,TAU,96,Color("ed9f72"),3,true)
			draw_arc(target,radius-8,-PI*0.5,PI*1.1,72,Color(1.0,0.72,0.51,0.52),2,true)
			draw_line(target-Vector2(10,0),target+Vector2(10,0),Color("edc3a4"),2,true)
			draw_line(target-Vector2(0,10),target+Vector2(0,10),Color("edc3a4"),2,true)

	## Выводит симметричную короткую полосу босса без портрета героя и постоянной панели заданий.
	func _draw_hud() -> void:
		var width := 2400.0 if overview else 1152.0
		var center := width*0.5
		draw_texture_rect(Light.soft_disc(),Rect2(center-260,-58,520,188),false,Color(0.04,0.08,0.11,0.85))
		if state not in ["before","victory"]:
			_draw_label(Vector2(center,38),"ХРАНИТЕЛЬ ГЛУБИН",20,Color("d9e6ec"))
			var bar := Rect2(center-188,50,376,9)
			draw_rect(bar,Color("233340"))
			draw_rect(Rect2(bar.position,Vector2(bar.size.x*(0.88 if state == "windup" else 0.38),bar.size.y)),Color("7cbed2"))
			_draw_label(Vector2(center,83),"I · КАМЕННЫЙ УДАР" if state == "windup" else "II · КРИСТАЛЬНЫЙ ОБВАЛ",12,Color("9eafb9"))
		else:
			_draw_label(Vector2(center,48),"СЕРДЦЕ ГЛУБИН" if variant == "a" else "ЗАТОПЛЕННОЕ СВЯТИЛИЩЕ",22,Color("d1e3ea"))
			_draw_label(Vector2(center,76),"Хранитель повержен · путь свободен" if state == "victory" else "Лунная печать ждёт пробуждения",13,Color("9eb5c1"))
		if overview:
			_draw_label(Vector2(1200,1300),"A · КРИСТАЛЬНЫЙ ЗАЛ" if variant == "a" else "B · ЗАТОПЛЕННОЕ СВЯТИЛИЩЕ",21,Color("c4d8e2"))
		else:
			draw_rect(Rect2(28,28,154,6),Color("2b3d3f")); draw_rect(Rect2(28,28,139,6),Color("79baa5"))
			draw_rect(Rect2(28,40,112,3),Color("82a4bd")); draw_rect(Rect2(146,40,36,3),Color("b7ac75"))
			draw_rect(Rect2(center-244,603,488,30),Color(0.06,0.09,0.12,0.82))
			_draw_label(Vector2(center,622),"МАКЕТ · существующие спрайты · бой ещё не внедрён",12,Color("b8c6ce"))
			if state == "before": _draw_label(Vector2(center,566),"E · Пробудить Хранителя",16,Color("dce6e8"))

	## Ставит подпись относительно её центра одним игровым шрифтом.
	func _draw_label(point: Vector2, text: String, size: int, color: Color) -> void:
		var length := UI_FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		draw_string(UI_FONT,point-Vector2(length*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

	## Рисует готовый модуль с исходной точкой опоры из каталога.
	func _sprite(kind: String, ground: Vector2) -> void:
		draw_texture_rect(Assets.texture(kind),Assets.destination_rect(kind,ground),false)

	## Добавляет мягкую контактную тень независимо от изображения объекта.
	func _shadow(ground: Vector2, size: Vector2, opacity: float) -> void:
		draw_texture_rect(Light.soft_disc(),Rect2(ground-size*0.5,size),false,Color(0.015,0.02,0.03,opacity))


## Откладывает создание экранов до готовности нативного графического контекста.
func _initialize() -> void:
	capture.call_deferred()


## Сохраняет варианты и состояния одной и той же проектной арены в стандартных игровых масштабах.
func capture() -> void:
	for variant in ["a","b"]:
		await shot(variant,"windup",true)
		for state in ["before","windup","phase2","victory"]: await shot(variant,state,false)
	quit()


## Снимает содержимое макета непосредственно из Godot без изменения основной сцены и сохранений.
func shot(variant: String, state: String, overview: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2400,1350) if overview else Vector2i(1152,648)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := ArenaCanvas.new()
	canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	canvas.variant = variant; canvas.state = state; canvas.overview = overview
	canvas.prepare(); viewport.add_child(canvas)
	for frame in 6: await RenderingServer.frame_post_draw
	var name := "%s-%s.png" % [variant,"overview" if overview else state]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+name))
	print("BOSS CONCEPT: ",name," error=",error)
	viewport.queue_free(); await process_frame
