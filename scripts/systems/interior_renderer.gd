extends RefCounted

const InteriorVisualSystem := preload("res://scripts/systems/interior_visual_system.gd")
const COTTAGE_TILES := preload("res://assets/game/interiors/grandmother_cottage_tiles_v1.png")
const COTTAGE_FLOOR := preload("res://assets/game/interiors/cottage_floor_seamless_v2.png")
const COTTAGE_FLOOR_SOURCE := Rect2(0,0,1254,1254)
const FLOOR_TILE_WORLD_SIZE := 288.0
const COTTAGE_WALL := Rect2(76,72,190,196)
const COTTAGE_WINDOW := Rect2(375,366,194,201)
const COTTAGE_STONE := Rect2(642,634,270,270)


## Рисует тематический пол, стены и мебель активного помещения из прозрачного атласа.
static func draw(canvas: Node2D) -> void:
	var data: Dictionary = canvas.BuildingSystem.interior(canvas.current_location)
	if data.is_empty(): return
	var room: Rect2 = data.room
	if canvas.current_location=="cottage_interior": draw_cottage_shell(canvas,room)
	else: draw_legacy_shell(canvas,room,data)
	var props:=InteriorVisualSystem.props(canvas.current_location)
	# Напольный декор всегда лежит под мебелью и персонажами, а не перекрывает их.
	for prop in props:
		if InteriorVisualSystem.collision_rect(String(prop.kind),Vector2(prop.position)).size==Vector2.ZERO:
			InteriorVisualSystem.draw(canvas,String(prop.kind),Vector2(prop.position))
	for prop in props:
		if InteriorVisualSystem.collision_rect(String(prop.kind),Vector2(prop.position)).size!=Vector2.ZERO:
			if not is_foreground_prop(String(prop.kind), Vector2(prop.position), canvas.player):
				InteriorVisualSystem.draw(canvas,String(prop.kind),Vector2(prop.position))
	preload("res://scripts/presentation/alchemy_renderer.gd").draw_station(canvas)
	preload("res://scripts/presentation/furnace_renderer.gd").draw_station(canvas)
	var exit: Vector2 = data.exit
	if canvas.current_location=="cottage_interior":
		canvas.draw_texture_rect_region(COTTAGE_TILES,Rect2(exit-Vector2(46,20),Vector2(92,40)),COTTAGE_STONE,Color("d8b889"))
	else:
		canvas.draw_rect(Rect2(exit-Vector2(38,18),Vector2(76,36)),Color("39291f"))
	for link in data.get("links", []): canvas.draw_circle(link.position,34,Color("d6ad52"),false,5)


## Собирает остальные помещения из общих стен и тематического пола в том же масштабе, что дом.
static func draw_legacy_shell(canvas:Node2D,room:Rect2,data:Dictionary)->void:
	var stone_floor := String(data.building) in ["forge", "chapel", "prison", "wizard_tower", "moon_castle"]
	draw_textured_shell(canvas, room, stone_floor)


## Собирает дом бабушки из стеновых тайлов и одного непрерывного паркета без квадратных заплаток.
static func draw_cottage_shell(canvas:Node2D,room:Rect2)->void:
	draw_textured_shell(canvas, room, false)


## Возвращает напольную область под стеной, оставляя единый 24-пиксельный периметр помещения.
static func floor_rect(room: Rect2) -> Rect2:
	var inner := room.grow(-24)
	return Rect2(inner.position + Vector2(0, 144), inner.size - Vector2(0, 144))


## Нарезает покрытие с неизменным масштабом досок; последний фрагмент обрезается, а не растягивается.
static func floor_tiles(bounds: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source_scale := COTTAGE_FLOOR_SOURCE.size.x / FLOOR_TILE_WORLD_SIZE
	for row in ceili(bounds.size.y / FLOOR_TILE_WORLD_SIZE):
		for column in ceili(bounds.size.x / FLOOR_TILE_WORLD_SIZE):
			var offset := Vector2(column, row) * FLOOR_TILE_WORLD_SIZE
			var size := Vector2(minf(FLOOR_TILE_WORLD_SIZE, bounds.size.x - offset.x), minf(FLOOR_TILE_WORLD_SIZE, bounds.size.y - offset.y))
			result.append({"destination": Rect2(bounds.position + offset, size), "source": Rect2(Vector2.ZERO, size * source_scale)})
	return result


## Рисует законченную комнату с мелкими досками или камнем, плинтусами и мягким светом окна.
static func draw_textured_shell(canvas: Node2D, room: Rect2, stone_floor: bool) -> void:
	canvas.draw_rect(room.grow(12), Color(0.02, 0.018, 0.016, 0.76))
	canvas.draw_rect(room, Color("3e2a1e"))
	var inner := room.grow(-24)
	var columns := ceili(inner.size.x / 120.0)
	for column in columns:
		var source := COTTAGE_WINDOW if column == columns / 2 else COTTAGE_WALL
		var width := minf(120.0, inner.size.x - column * 120.0)
		source.size.x *= width / 120.0
		canvas.draw_texture_rect_region(COTTAGE_TILES, Rect2(inner.position + Vector2(column * 120.0, 0), Vector2(width, 144)), source, Color("d9d1bf") if stone_floor else Color.WHITE)
	var floor := floor_rect(room)
	if stone_floor:
		for row in ceili(floor.size.y / 96.0):
			for column in ceili(floor.size.x / 96.0):
				var offset := Vector2(column, row) * 96.0
				var size := Vector2(minf(96.0, floor.size.x - offset.x), minf(96.0, floor.size.y - offset.y))
				canvas.draw_texture_rect_region(COTTAGE_TILES, Rect2(floor.position + offset, size), Rect2(COTTAGE_STONE.position, size * COTTAGE_STONE.size / 96.0), Color("a7a197"))
	else:
		for tile in floor_tiles(floor):
			canvas.draw_texture_rect_region(COTTAGE_FLOOR, tile.destination, tile.source, Color("d2ba96"))
	canvas.draw_rect(Rect2(floor.position, Vector2(floor.size.x, 8)), Color(0.10, 0.055, 0.025, 0.32))
	canvas.draw_line(floor.position - Vector2(0, 2), Vector2(floor.end.x, floor.position.y - 2), Color("a46d38"), 4.0)
	canvas.draw_line(Vector2(inner.position.x, floor.end.y + 10), Vector2(inner.end.x, floor.end.y + 10), Color("73502f"), 5.0)
	var light_center := Vector2(inner.position.x + mini(columns / 2 * 120.0 + 60.0, inner.size.x - 60.0), floor.position.y)
	canvas.draw_colored_polygon(PackedVector2Array([light_center + Vector2(-35, 0), light_center + Vector2(35, 0), light_center + Vector2(85, 120), light_center + Vector2(-45, 120)]), Color(1.0, 0.91, 0.64, 0.06))


## Рисует установленный объект тем же профилем, который задаёт его коллизию и F10-границы.
static func draw_prop(canvas: Node2D, kind: String, position: Vector2) -> void:
	InteriorVisualSystem.draw(canvas,kind,position)


## Определяет глубину по нижней точке мебели: ковёр остаётся под ногами, высокая мебель перекрывает героя позади.
static func is_foreground_prop(kind: String, position: Vector2, player: Vector2) -> bool:
	return InteriorVisualSystem.collision_rect(kind, position).size != Vector2.ZERO and position.y > player.y


## Завершает интерьер после отрисовки героя, сохраняя честное перекрытие мебели, сундука и поставленных предметов.
static func draw_foreground(canvas: Node2D) -> void:
	if not canvas.BuildingSystem.is_interior(canvas.current_location): return
	for prop in InteriorVisualSystem.props(canvas.current_location):
		if is_foreground_prop(String(prop.kind), Vector2(prop.position), canvas.player):
			draw_prop(canvas, String(prop.kind), Vector2(prop.position))
	if canvas.current_location != "cottage_interior": return
	if canvas.home_chest_owned and is_foreground_prop("home_chest", canvas.StorageSystem.CHEST_POSITION, canvas.player):
		draw_prop(canvas, "home_chest", canvas.StorageSystem.CHEST_POSITION)
	for furniture in canvas.FarmLifeSystem.state(canvas).furniture:
		if is_foreground_prop(String(furniture.kind), Vector2(furniture.position), canvas.player):
			draw_prop(canvas, String(furniture.kind), Vector2(furniture.position))
