extends RefCounted

const Boss := preload("res://scripts/systems/cave_boss_system.gd")
const Data := preload("res://scripts/systems/cave_boss_data.gd")
const Art := preload("res://scripts/systems/cave_boss_art_system.gd")
const Light := preload("res://scripts/systems/cave_lighting_system.gd")
const Moon := preload("res://scripts/presentation/moon_theme.gd")
const Rooms := preload("res://scripts/systems/cave_room_data.gd")

## Рисует предупреждения на земле под существами, сохраняя совпадение рисунка с зоной контакта.
static func draw_ground(game: Node2D) -> void:
	if game.current_location != Data.LOCATION: return
	var state: Dictionary = game.state.world.cave_boss
	if not state.active: return
	for area in state.zones:
		var age: float = float(state.attack.elapsed) - float(area.trigger)
		var lifetime := 1.0 if area.shape in ["ring","crystal"] else 0.45
		if age > lifetime: continue
		var color := Color("f2be76") if age < 0.0 else Color("ed755e")
		var fill := color; fill.a = 0.12 if age < 0.0 else 0.24
		var origin: Vector2 = area.position
		match area.shape:
			"circle", "crystal":
				game.draw_circle(origin,float(area.radius),fill)
				game.draw_circle(origin,float(area.radius),color,false,2.0,true)
				if age < 0.0: game.draw_arc(origin,float(area.radius)-6.0,-PI/2.0,-PI/2.0+TAU*clampf(float(state.attack.elapsed)/float(area.trigger),0,1),40,color,2.0,true)
			"cone":
				var polygon := PackedVector2Array([origin])
				var direction := origin.direction_to(area.end)
				for index in 25: polygon.append(origin + direction.rotated(-float(area.radius)+float(area.radius)*2.0*index/24.0)*origin.distance_to(area.end))
				draw_area(game,polygon,fill,color)
			"line", "charge":
				var normal := origin.direction_to(area.end).orthogonal() * float(area.radius)
				var polygon := PackedVector2Array([origin+normal,Vector2(area.end)+normal,Vector2(area.end)-normal,origin-normal])
				draw_area(game,polygon,fill,color)
			"ring":
				var radius := 110.0 + maxf(0.0,age) * 250.0
				draw_ring(game,origin,110.0,Color(0.4,0.8,0.8,0.12),2.0)
				draw_ring(game,origin,360.0,Color(0.95,0.7,0.4,0.25),2.0)
				draw_ring(game,origin,radius,color,22.0 if age >= 0.0 else 2.0)
	for minion in state.minions:
		if minion.alive and float(minion.emerge) > 0.0: game.draw_circle(minion.position,32.0,Color(0.55,0.8,0.65,0.35),false,2.0,true)
		if minion.alive and float(minion.fly_windup) > 0.0:
			game.draw_line(minion.position,minion.fly_target,Color(0.72,0.86,0.32,0.55),2.0,true)

## Обрезает заполненную опасную область по полу, чтобы предупреждение не рисовалось за стенами.
static func draw_area(game: Node2D, polygon: PackedVector2Array, fill: Color, edge: Color) -> void:
	for piece in Geometry2D.intersect_polygons(polygon,Rooms.floor_polygon(Data.LOCATION)):
		game.draw_colored_polygon(piece,fill)
		var border: PackedVector2Array = piece.duplicate(); border.append(border[0])
		game.draw_polyline(border,edge,2.0,true)

## Рисует видимые дуги лунной волны только внутри пещерного пола.
static func draw_ring(game: Node2D, origin: Vector2, radius: float, color: Color, width: float) -> void:
	var curve := PackedVector2Array()
	for index in 65: curve.append(origin + Vector2.from_angle(index*TAU/64.0)*radius)
	for piece in Geometry2D.intersect_polyline_with_polygon(curve,Rooms.floor_polygon(Data.LOCATION)):
		if piece.size() >= 2: game.draw_polyline(piece,color,width,true)

## Рисует отдельные анимации босса, призванных существ и эффектов из настоящих атласов.
static func draw_actors(game: Node2D) -> void:
	if game.current_location != Data.LOCATION: return
	var index := Boss.index(game)
	if index < 0: return
	var state: Dictionary = game.state.world.cave_boss
	var boss: Dictionary = game.enemy_nodes[index]
	if boss.alive:
		var color: Color = [Color("72d2cf"),Color("a3abea"),Color("df99c1")][int(state.phase)-1]
		game.draw_texture_rect(Light.soft_disc(),Rect2(boss.position-Vector2(105,75),Vector2(210,150)),false,Color(color,0.16 if state.active else 0.04))
		shadow(game,boss.position,100.0)
		var row := 0; var column := 3
		if float(state.summoning) > 0.0: row = 3; column = clampi(floori((1.2-float(state.summoning))/0.3),0,3)
		elif not state.attack.is_empty():
			var config: Dictionary = Data.ATTACKS[state.attack.id]
			row = int(config.row)
			var elapsed := float(state.attack.elapsed)
			column = 0 if elapsed < float(config.windup)*0.65 else (1 if elapsed < float(config.windup) else (2 if elapsed < float(config.windup)+0.3 else 3))
		Art.draw(game,"guardian",row,column,boss.position,200.0,false,Color("a3abb6") if not state.active else (Color(1,0.92,0.94) if int(state.phase)==3 else Color.WHITE))
	var sorted: Array = state.minions.duplicate()
	sorted.sort_custom(func(a,b): return Vector2(a.position).y < Vector2(b.position).y)
	for minion in sorted: draw_minion(game,minion,float(state.clock))
	for effect in state.effects:
		var column := clampi(floori(float(effect.time)/0.65*Art.count("effects",int(effect.row))),0,Art.count("effects",int(effect.row))-1)
		Art.draw(game,"effects",int(effect.row),column,effect.position,float(effect.size),true)
	for area in state.zones:
		if area.shape != "crystal" or state.attack.is_empty(): continue
		var age := float(state.attack.elapsed)-float(area.trigger)
		if age >= 0.0 and age <= 1.0: Art.draw(game,"effects",1,mini(3,floori(age*5.0)),area.position,105.0)
	for shot in state.projectiles:
		if shot.kind == "fly": Art.draw(game,"flyers",0,posmod(floori(float(shot.age)*14.0),4),shot.position,24.0,true)
		else: Art.draw(game,"effects",3 if shot.kind == "amber" else 1,0,shot.position,30.0,true)

## Добавляет мягкую контактную тень, не запечённую в кадры персонажа.
static func shadow(game: Node2D, position: Vector2, width: float) -> void:
	game.draw_texture_rect(Light.soft_disc(),Rect2(position-Vector2(width/2.0,12),Vector2(width,24)),false,Color(0.02,0.02,0.05,0.7))

## Выбирает кадры появления, ходьбы, атаки и смерти; мухи зомби летают независимо от тела.
static func draw_minion(game: Node2D, minion: Dictionary, time: float) -> void:
	shadow(game,minion.position,48.0)
	var row := 1; var column := posmod(floori(float(minion.age)*7.0),4) if minion.moving else 3
	if not minion.alive: row = 3; column = clampi(floori(float(minion.death)*4.0),0,3)
	elif float(minion.emerge) > 0.0: row = 0; column = clampi(floori((1.25-float(minion.emerge))/1.25*4.0),0,3)
	elif float(minion.attack) > 0.0: row = 2; column = clampi(floori((0.5-float(minion.attack))*8.0),0,3)
	elif float(minion.fly_windup) > 0.0: row = 2; column = clampi(floori((0.65-float(minion.fly_windup))/0.65*4.0),0,3)
	var position: Vector2 = minion.position
	if minion.kind == "vampire" and float(minion.emerge) > 0.65: position.y -= float(minion.emerge)*45.0
	Art.draw(game,String(minion.kind),row,column,position,88.0)
	if minion.alive and float(minion.emerge) <= 0.0:
		game.draw_rect(Rect2(position+Vector2(-18,-94),Vector2(36,3)),Color("332938"))
		game.draw_rect(Rect2(position+Vector2(-18,-94),Vector2(36.0*int(minion.hp)/int(Boss.Minions.TYPES[minion.kind].hp),3)),Color("88b887"))
	if minion.kind == "zombie" and minion.alive and float(minion.emerge) <= 0.0:
		for index in 3:
			var angle := time*2.4 + index*TAU/3.0
			var offset := Vector2(cos(angle)*27.0,-40.0+sin(angle)*15.0)
			Art.draw(game,"flyers",0,posmod(floori(time*13.0)+index,4),position+offset,14.0,true)

## Рисует прикреплённую муху поверх героя, пока продолжается эффект укусов.
static func draw_front(game: Node2D) -> void:
	if game.current_location != Data.LOCATION: return
	var state: Dictionary = game.state.world.cave_boss
	if float(state.fly_timer) > 0.0:
		var offset := Vector2(cos(float(state.clock)*5.0)*18.0,-45.0+sin(float(state.clock)*5.0)*12.0)
		Art.draw(game,"flyers",0,posmod(floori(float(state.clock)*14.0),4),game.player+offset,17.0,true)

## Выводит компактный индикатор здоровья с порогами стадий и подписью текущей атаки.
static func draw_ui(game: Node2D) -> void:
	if game.current_location != Data.LOCATION: return
	var state: Dictionary = game.state.world.cave_boss
	if not state.active and float(state.victory) <= 0.0: return
	var index := Boss.index(game)
	if index < 0: return
	var width := minf(420.0,game.get_viewport_rect().size.x*0.45)
	var origin := Vector2((game.get_viewport_rect().size.x-width)/2.0,24.0)
	var title: String = game.LocaleSystem.entity("cave_guardian") + " · " + Data.word(game,"stage",[int(state.phase)])
	if float(state.victory) > 0.0: title = Data.word(game,"victory")
	Moon.panel(game,Rect2(origin-Vector2(12,10),Vector2(width+24,64)),Color("18232b"),Color("7a9295"),9)
	game.draw_string(game.UI_FONT,origin+Vector2(0,5),title,HORIZONTAL_ALIGNMENT_CENTER,width,15,Color("ece0c5"))
	game.draw_rect(Rect2(origin+Vector2(0,14),Vector2(width,9)),Color("322936"))
	var hp := clampf(float(game.enemy_nodes[index].hp)/Data.MAX_HP,0.0,1.0)
	game.draw_rect(Rect2(origin+Vector2(0,14),Vector2(width*hp,9)),[Color("81bab5"),Color("a6a0d6"),Color("d28fa7")][int(state.phase)-1])
	for threshold in [1.0/3.0,2.0/3.0]: game.draw_line(origin+Vector2(width*threshold,14),origin+Vector2(width*threshold,23),Color("18232b"),2.0)
	var label := ""
	if not state.attack.is_empty(): label = Data.word(game,String(state.attack.id))
	elif float(state.summoning) > 0.0: label = Data.word(game,"summon")
	if float(state.fly_timer) > 0.0: label += (" · " if not label.is_empty() else "") + Data.word(game,"flies",[float(state.fly_timer)])
	game.draw_string(game.UI_FONT,origin+Vector2(0,38),label,HORIZONTAL_ALIGNMENT_CENTER,width,13,Color("d7c2a0"))
