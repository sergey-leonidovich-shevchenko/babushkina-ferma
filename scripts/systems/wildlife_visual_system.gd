extends RefCounted

const SpriteMatte := preload("res://scripts/systems/sprite_matte_system.gd")
const FOX := preload("res://assets/game/wildlife/directional/fox_walk_4dir_v2.png")
const BAT := preload("res://assets/game/wildlife/directional/bat_flight_4dir_v2.png")
const LIZARD := preload("res://assets/game/wildlife/directional/lizard_walk_4dir_v2.png")
const NEW_SHEETS := {"fox": FOX, "bat": BAT, "lizard": LIZARD}
const ROWS := [0, 2, 4, 6]
static var _bounds: Dictionary = {}
const Prepared := preload("res://scripts/presentation/prepared_pixel_cache.gd")


## Прогревает текстуры и источники до начала игры, исключая тяжёлую обработку при первой встрече с животным.
static func warmup(game: Node) -> void:
	for kind in game.WildlifeSystem.TYPES:
		for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]:
			for frame in 4:
				frame_packet(game, {"kind": kind, "position": Vector2.ZERO, "direction": direction, "animation": frame / 9.0, "moving": true, "visual_state": "flee"})


## Выбирает одну из четырёх читаемых сторон без косых кадров с другой анатомией и масштабом.
static func direction_index(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y): return 1 if direction.x < 0.0 else 3
	return 2 if direction.y < 0.0 else 0


## Выбирает согласованные фазы; ошибочные уменьшенные столбцы не попадают ни в шаг, ни в реакцию на удар.
static func frame_column(kind: String, direction: int, state: String, time: float, moving: bool) -> int:
	if state == "death" and not NEW_SHEETS.has(kind): return 5
	if kind == "bat" and state not in ["hurt", "death", "attack"]: return int(time * 9.0) % 4
	if not moving or state in ["hurt", "attack", "death", "idle"]: return 0
	var phase := int(time * (9.0 if state == "flee" else 6.0)) % 4
	if NEW_SHEETS.has(kind): return phase
	if kind == "boar": return [0, 1, 0, 1][phase]
	return [0, 1, 2, 1][phase]


## Строит источник и размер с неизменным коэффициентом пикселей; кадры не растягиваются по отдельности.
static func frame_packet(game: Node, animal: Dictionary) -> Dictionary:
	var kind: String = animal.kind
	var direction := direction_index(animal.direction)
	var state: String = animal.get("visual_state", "idle")
	var column := frame_column(kind, direction, state, float(animal.animation), bool(animal.get("moving", false)))
	var texture: Texture2D = NEW_SHEETS.get(kind, game.WILDLIFE_ACTION_SHEETS[kind])
	texture = SpriteMatte.clean_texture(texture)
	var area:=frame_area(kind,direction,column)
	var pixel_scale:=0.245 if kind in ["fox","lizard"] else (0.23 if kind=="bat" else 0.75)
	var flip:bool=kind=="boar" and direction==3
	var source := visible_bounds(texture, area)
	var size := Vector2(source.size) * pixel_scale
	var position: Vector2 = animal.position.round()
	var destination := Rect2(position - Vector2(size.x * 0.5, size.y), size)
	if kind == "bat": destination.position.y -= 16.0
	if state == "attack": destination.position += Vector2(animal.direction).normalized() * sin(clampf(1.0 - float(animal.get("state_timer", 0.0)) / 0.34, 0.0, 1.0) * PI) * 4.0
	if flip: destination.position.x += destination.size.x; destination.size.x *= -1.0
	var tint := Color(1.0, 0.69, 0.61) if state == "hurt" else Color.WHITE
	if state == "death": tint.a = clampf(float(animal.get("state_timer", 0.0)) / 0.6, 0.0, 1.0)
	return {"texture": texture, "source": Rect2(source), "destination": destination, "scale": pixel_scale, "tint": tint, "direction": direction, "column": column}


## Даёт сборщику и игре одну прежнюю целочисленную область каждого нарисованного кадра.
static func frame_area(kind: String, direction: int, column: int) -> Rect2i:
	if kind == "fox":
		var rows := [0, 350, 565, 896, 1199]
		return Rect2i(column * 328, rows[direction], 328, rows[direction + 1] - rows[direction])
	elif kind == "bat":
		var rows := [0, 305, 600, 900, 1254]
		var columns := [0, 314, 628, 941, 1254]
		return Rect2i(columns[column], rows[direction], columns[column + 1] - columns[column], rows[direction + 1] - rows[direction])
	elif kind == "lizard":
		var rows := [0, 334, 575, 920, 1224]
		var columns := [0, 332, 658, 976, 1285]
		return Rect2i(columns[column], rows[direction], columns[column + 1] - columns[column], rows[direction + 1] - rows[direction])
	else:
		var row: int = ROWS[direction]
		if kind == "boar" and direction == 3: row = 2
		return Rect2i(column * 128 + 5, row * 128 + 5, 118, 114)


## Кэширует видимые границы источника только для выравнивания опоры, игнорируя почти прозрачный мусор генератора.
static func visible_bounds(texture: Texture2D, area: Rect2i) -> Rect2i:
	var key := "%s:%s" % [texture.get_rid().get_id(), area]
	if _bounds.has(key): return _bounds[key]
	var prepared:=Prepared.bounds(texture,area)
	var result:=prepared if prepared.has_area() else measure_visible_bounds(texture.get_image(),area)
	_bounds[key]=result
	return result


## Воспроизводит прежний порог альфы и опору кадра для сборки и независимой проверки подготовленных областей.
static func measure_visible_bounds(image: Image, area: Rect2i) -> Rect2i:
	var minimum := area.end
	var maximum := area.position
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if image.get_pixel(x, y).a < 0.25: continue
			minimum = minimum.min(Vector2i(x, y)); maximum = maximum.max(Vector2i(x + 1, y + 1))
	var result := Rect2i(minimum, maximum - minimum) if maximum.x > minimum.x and maximum.y > minimum.y else area
	return result


## Рисует зверей с тёмной контактной тенью, спокойным получением урона и исчезновением побеждённой цели.
static func draw(game: Node2D) -> void:
	for animal in game.wildlife_nodes:
		if animal.location != game.current_location: continue
		if not animal.alive and float(animal.get("state_timer", 0.0)) <= 0.0: continue
		var packet := frame_packet(game, animal)
		var position: Vector2 = animal.position.round()
		var shadow := Color(0.10, 0.09, 0.06, 0.24 * float(packet.tint.a))
		draw_contact_shadow(game, position + Vector2(0, 2), shadow)
		game.draw_texture_rect_region(packet.texture, packet.destination, packet.source, packet.tint)
		var hp_max := int(game.WildlifeSystem.TYPES[animal.kind].hp)
		if animal.alive and int(animal.hp) < hp_max:
			var bar := Rect2(Vector2(position.x - 22.0, float(packet.destination.position.y) - 8.0), Vector2(44, 4))
			game.draw_rect(bar, Color("35291f")); game.draw_rect(Rect2(bar.position + Vector2.ONE, Vector2(42.0 * animal.hp / hp_max, 2)), Color("c65e4e"))


## Рисует плоскую овальную тень под лапами, не меняя мировой transform основного renderer.
static func draw_contact_shadow(game: Node2D, position: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in 16: points.append(position + Vector2(cos(TAU * index / 16.0) * 18.0, sin(TAU * index / 16.0) * 5.0))
	game.draw_colored_polygon(points, tint)
