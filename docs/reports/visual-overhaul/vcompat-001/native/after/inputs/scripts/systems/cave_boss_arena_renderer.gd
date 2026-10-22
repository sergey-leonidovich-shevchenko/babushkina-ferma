extends RefCounted

const Arena := preload("res://scripts/systems/cave_boss_arena_system.gd")
const Data := preload("res://scripts/systems/cave_boss_arena_data.gd")
const Env := preload("res://scripts/systems/environment_visual_system.gd")
const Light := preload("res://scripts/systems/cave_lighting_system.gd")

## Рисует кешируемый рунический круг и отдельные спрайты колонн с мягкими контактными тенями.
static func draw_background(canvas: Node2D) -> void:
	var ellipse := PackedVector2Array()
	for index in 97: ellipse.append(Data.CENTER+Vector2(cos(index*TAU/96.0)*396,sin(index*TAU/96.0)*240))
	canvas.draw_polyline(ellipse,Color("3a4554"),14.0,true)
	canvas.draw_polyline(ellipse,Color("697a83"),2.0,true)
	for index in 12:
		var angle := index*TAU/12.0
		var position := Data.CENTER+Vector2(cos(angle)*366,sin(angle)*218)
		var rune := PackedVector2Array([position+Vector2(0,-7),position+Vector2(5,0),position+Vector2(0,7),position+Vector2(-5,0),position+Vector2(0,-7)])
		canvas.draw_polyline(rune,Color("799cae"),1.5,true)
	for position in Data.COLUMNS:
		_shadow(canvas,position,Vector2(100,32)); Env.draw(canvas,"ruins_detail",position)
	_shadow(canvas,Data.ALTAR,Vector2(100,32))
	Env.draw(canvas,"moon_altar",Data.ALTAR,Color.WHITE,0.44)

## Показывает три печати до победы и мягкое свечение кристаллов под боевыми предупреждениями.
static func draw_lights(game: Node2D) -> void:
	if game.current_location != Data.LOCATION: return
	var dead := Arena.defeated(game)
	var time: float = game.state.world.cave_boss.clock
	for index in Data.CRYSTALS.size():
		var position: Vector2 = Data.CRYSTALS[index]
		game.draw_texture_rect(Light.soft_disc(),Rect2(position-Vector2(156,108),Vector2(312,216)),false,Color(0.24,0.6,0.85,0.13+0.015*sin(time+index)))
	for offset in [-44,0,44]:
		var position := Vector2(Data.EXIT.x+offset,Data.SEAL.get_center().y)
		if not dead: game.draw_texture_rect(Light.soft_disc(),Rect2(position-Vector2(36,24),Vector2(72,48)),false,Color(0.3,0.7,0.94,0.23))
		var shape := PackedVector2Array([position+Vector2(0,-18),position+Vector2(10,0),position+Vector2(0,18),position+Vector2(-10,0)])
		game.draw_colored_polygon(shape,Color("475b66") if dead else Color("8dd6f1"))
	if not dead: game.draw_line(Vector2(Data.SEAL.position.x,224),Vector2(Data.SEAL.end.x,224),Color(0.45,0.8,0.95,0.32),2.0,true)

## Перекрывает героя видимыми колоннами и алтарём, когда он проходит за их основанием.
static func draw_foreground(game: Node2D) -> void:
	var actor := Rect2(game.player-Vector2(24,72),Vector2(48,86))
	for position in Data.COLUMNS:
		if game.player.y < position.y and Env.visual_rect("ruins_detail",position).intersects(actor): Env.draw(game,"ruins_detail",position)
	if game.player.y < Data.ALTAR.y and Env.visual_rect("moon_altar",Data.ALTAR,0.44).intersects(actor): Env.draw(game,"moon_altar",Data.ALTAR,Color.WHITE,0.44)

## Отделяет модульные спрайты от пола тенями без изменения исходных изображений.
static func _shadow(canvas: Node2D, position: Vector2, size: Vector2) -> void:
	canvas.draw_texture_rect(Light.soft_disc(),Rect2(position-size*0.5,size),false,Color(0.02,0.025,0.04,0.55))
