extends RefCounted

# Игровой Node2D предоставляет фасад систем; типы его записей проверяются ниже и в Game suites.
@warning_ignore_start("unsafe_property_access", "unsafe_method_access")

const InteriorVisualSystem := preload("res://scripts/systems/interior_visual_system.gd")
const LightQuality := preload("res://scripts/presentation/lighting_quality.gd")
const BasementRenderer := preload("res://scripts/presentation/basement_renderer.gd")
const BasementData := preload("res://scripts/systems/basement_data.gd")
const COTTAGE_TILES := preload("res://assets/game/interiors/grandmother_cottage_tiles_v1.png")
const COTTAGE_FLOOR := preload("res://assets/game/interiors/cottage_floor_seamless_v2.png")
const COTTAGE_FLOOR_SOURCE := Rect2(0, 0, 1254, 1254)
const FLOOR_TILE_WORLD_SIZE := 288.0
const COTTAGE_WALL := Rect2(76, 72, 190, 196)
const COTTAGE_WINDOW := Rect2(375, 366, 194, 201)
const COTTAGE_STONE := Rect2(642, 634, 270, 270)


## Рисует тематический пол, стены и мебель активного помещения из прозрачного атласа.
static func draw(canvas: Node2D) -> void:
	var location: String = canvas.current_location
	var data: Dictionary = canvas.BuildingSystem.interior(location)
	if data.is_empty():
		return
	var player: Vector2 = canvas.player
	var room: Rect2 = data.room
	if location == "cellar_workshop":
		preload("res://scripts/presentation/basement_room_renderer.gd").draw(canvas)
	elif location == "cottage_interior":
		draw_cottage_shell(canvas, room)
	else:
		draw_legacy_shell(canvas, room, data)
	var props := InteriorVisualSystem.props(location)
	# Напольный декор всегда лежит под мебелью и персонажами, а не перекрывает их.
	for prop: Dictionary in props:
		var kind: String = prop.kind
		var position: Vector2 = prop.position
		var direction: int = prop.get("direction", 0)
		if InteriorVisualSystem.collision_rect(kind, position, direction).size == Vector2.ZERO:
			InteriorVisualSystem.draw(canvas, kind, position, Color.WHITE, direction)
	for prop: Dictionary in props:
		var kind: String = prop.kind
		var position: Vector2 = prop.position
		var direction: int = prop.get("direction", 0)
		if InteriorVisualSystem.collision_rect(kind, position, direction).size != Vector2.ZERO:
			if not is_foreground_prop(kind, position, player, direction):
				InteriorVisualSystem.draw(canvas, kind, position, Color.WHITE, direction)
	preload("res://scripts/presentation/alchemy_renderer.gd").draw_station(canvas)
	preload("res://scripts/presentation/furnace_renderer.gd").draw_station(canvas)
	BasementRenderer.fixtures(canvas)
	BasementRenderer.objects(canvas, false)
	var exit: Vector2 = data.exit
	if location == "cottage_interior":
		canvas.draw_texture_rect_region(
			COTTAGE_TILES,
			Rect2(exit - Vector2(46, 20), Vector2(92, 40)),
			COTTAGE_STONE,
			Color("d8b889")
		)
	elif location != "cellar_workshop":
		canvas.draw_rect(Rect2(exit - Vector2(38, 18), Vector2(76, 36)), Color("39291f"))
	for link: Dictionary in data.get("links", []):
		if link.target != "cellar_workshop":
			var position: Vector2 = link.position
			canvas.draw_circle(position, 34, Color("d6ad52"), false, 5)


## Собирает остальные помещения из общих стен и тематического пола в том же масштабе, что дом.
static func draw_legacy_shell(canvas: Node2D, room: Rect2, data: Dictionary) -> void:
	var building: String = data.building
	var stone_floor := building in ["forge", "chapel", "prison", "wizard_tower", "moon_castle"]
	draw_textured_shell(canvas, room, stone_floor)


## Собирает дом бабушки из стеновых тайлов и одного непрерывного паркета без квадратных заплаток.
static func draw_cottage_shell(canvas: Node2D, room: Rect2) -> void:
	draw_textured_shell(canvas, room, false)


## Возвращает напольную область под стеной, оставляя единый 24-пиксельный периметр помещения.
static func floor_rect(room: Rect2) -> Rect2:
	if room == BasementData.ROOM:
		return BasementData.FLOOR
	var inner := room.grow(-24)
	return Rect2(inner.position + Vector2(0, 144), inner.size - Vector2(0, 144))


## Сохраняет масштаб досок; последний фрагмент обрезается по границе пола.
static func floor_tiles(bounds: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source_scale := COTTAGE_FLOOR_SOURCE.size.x / FLOOR_TILE_WORLD_SIZE
	for row in ceili(bounds.size.y / FLOOR_TILE_WORLD_SIZE):
		for column in ceili(bounds.size.x / FLOOR_TILE_WORLD_SIZE):
			var offset := Vector2(column, row) * FLOOR_TILE_WORLD_SIZE
			var size := Vector2(
				minf(FLOOR_TILE_WORLD_SIZE, bounds.size.x - offset.x),
				minf(FLOOR_TILE_WORLD_SIZE, bounds.size.y - offset.y)
			)
			result.append(
				{
					"destination": Rect2(bounds.position + offset, size),
					"source": Rect2(Vector2.ZERO, size * source_scale)
				}
			)
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
		canvas.draw_texture_rect_region(
			COTTAGE_TILES,
			Rect2(inner.position + Vector2(column * 120.0, 0), Vector2(width, 144)),
			source,
			Color("d9d1bf") if stone_floor else Color.WHITE
		)
	var floor := floor_rect(room)
	if stone_floor:
		for row in ceili(floor.size.y / 96.0):
			for column in ceili(floor.size.x / 96.0):
				var offset := Vector2(column, row) * 96.0
				var size := Vector2(
					minf(96.0, floor.size.x - offset.x), minf(96.0, floor.size.y - offset.y)
				)
				canvas.draw_texture_rect_region(
					COTTAGE_TILES,
					Rect2(floor.position + offset, size),
					Rect2(COTTAGE_STONE.position, size * COTTAGE_STONE.size / 96.0),
					Color("a7a197")
				)
	else:
		for tile: Dictionary in floor_tiles(floor):
			var destination: Rect2 = tile.destination
			var source: Rect2 = tile.source
			canvas.draw_texture_rect_region(COTTAGE_FLOOR, destination, source, Color("d2ba96"))
	canvas.draw_rect(
		Rect2(floor.position, Vector2(floor.size.x, 8)), Color(0.10, 0.055, 0.025, 0.32)
	)
	canvas.draw_line(
		floor.position - Vector2(0, 2),
		Vector2(floor.end.x, floor.position.y - 2),
		Color("a46d38"),
		4.0
	)
	canvas.draw_line(
		Vector2(inner.position.x, floor.end.y + 10),
		Vector2(inner.end.x, floor.end.y + 10),
		Color("73502f"),
		5.0
	)
	var light_center := Vector2(
		inner.position.x + mini(columns / 2 * 120.0 + 60.0, inner.size.x - 60.0), floor.position.y
	)
	if LightQuality.decorative_enabled(canvas):
		canvas.draw_colored_polygon(
			PackedVector2Array(
				[
					light_center + Vector2(-35, 0),
					light_center + Vector2(35, 0),
					light_center + Vector2(85, 120),
					light_center + Vector2(-45, 120)
				]
			),
			Color(1.0, 0.91, 0.64, 0.06)
		)


## Рисует установленный объект тем же профилем, который задаёт его коллизию и F10-границы.
static func draw_prop(canvas: Node2D, kind: String, position: Vector2, direction: int = 0) -> void:
	InteriorVisualSystem.draw(canvas, kind, position, Color.WHITE, direction)


## Оставляет ковёр под ногами, а высокую мебель перед находящимся позади героем.
static func is_foreground_prop(
	kind: String, position: Vector2, player: Vector2, direction: int = 0
) -> bool:
	return (
		InteriorVisualSystem.collision_rect(kind, position, direction).size != Vector2.ZERO
		and position.y > player.y
	)


## Завершает интерьер после героя, сохраняя перекрытие мебели и поставленных предметов.
static func draw_foreground(canvas: Node2D) -> void:
	var location: String = canvas.current_location
	if not canvas.BuildingSystem.is_interior(location):
		return
	var player: Vector2 = canvas.player
	BasementRenderer.objects(canvas, true)
	for prop: Dictionary in InteriorVisualSystem.props(location):
		var kind: String = prop.kind
		var position: Vector2 = prop.position
		var direction: int = prop.get("direction", 0)
		if is_foreground_prop(kind, position, player, direction):
			draw_prop(canvas, kind, position, direction)
	if location != "cottage_interior":
		return
	var chest: Vector2 = canvas.StorageSystem.CHEST_POSITION
	if canvas.home_chest_owned and is_foreground_prop("home_chest", chest, player):
		draw_prop(canvas, "home_chest", chest)
	for furniture: Dictionary in canvas.FarmLifeSystem.state(canvas).furniture:
		var kind: String = furniture.kind
		var position: Vector2 = furniture.position
		var direction: int = furniture.get("direction", 0)
		if is_foreground_prop(kind, position, player, direction):
			draw_prop(canvas, kind, position, direction)
