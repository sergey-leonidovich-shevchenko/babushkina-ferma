extends RefCounted

const MapData := preload("res://scripts/systems/cave_map_data.gd")
const Rooms := preload("res://scripts/systems/cave_room_data.gd")
const Assets := preload("res://scripts/systems/cave_asset_system.gd")
static var _prepared: Dictionary = {}


## Возвращает кешированный полигон именно активной комнаты без перестройки на каждом шаге.
static func floor_polygon(location: String = "cave") -> PackedVector2Array:
	return _prepare(location).floor


## Возвращает модули наружных стен и внутренних скальных перегородок выбранной комнаты.
static func walls(location: String = "cave") -> Array:
	return _prepare(location).walls


## Возвращает подготовленные отрезки наружного контура для точной навигации у скал.
static func segments(location: String = "cave") -> Array:
	return _prepare(location).segments


## Не пускает круг за контур пола и внутрь видимой скальной перегородки.
static func blocks_position(position: Vector2, radius: float, location: String = "cave") -> bool:
	if _blocks_polygon(position,radius,floor_polygon(location),segments(location),false): return true
	for rock in Rooms.ROCKS.get(location, []):
		if _circle_in_rect(position,radius+MapData.WALL_INSET,rock): return true
	return false


## Не позволяет герою или существу наступить в подземную воду; берег совпадает с изображением.
static func blocks_water(position: Vector2, radius: float, location: String) -> bool:
	for pool in _prepare(location).pools:
		if not Rect2(pool.bounds).grow(radius).has_point(position): continue
		if _blocks_polygon(position,radius,pool.polygon,pool.segments,true): return true
	return false


## Проверяет основания крупного декора активной комнаты; маленькие грибы и осыпь проходимы.
static func blocks_decoration(position: Vector2, radius: float, location: String = "cave") -> bool:
	for solid in _prepare(location).decoration_rects:
		if Rect2(solid).grow(radius).has_point(position) and _circle_in_rect(position,radius,solid): return true
	return false


## Переносит лишь позиции в новых скалах или воде, сохраняя здоровье и добычу старого снимка.
static func repair_saved_positions(game: Node) -> void:
	for enemy in game.enemy_nodes:
		if Rooms.is_cave(enemy.location) and (blocks_position(enemy.position,27.0,enemy.location) or blocks_water(enemy.position,27.0,enemy.location)): enemy.position = enemy.home
	for animal in game.wildlife_nodes:
		if Rooms.is_cave(animal.location) and (blocks_position(animal.position,game.PLAYER_RADIUS,animal.location) or blocks_water(animal.position,game.PLAYER_RADIUS,animal.location)):
			animal.position = animal.home; animal.habitat_validated = false
	if Rooms.is_cave(game.current_location):
		var reason: String = game.NavigationSystem.walkability_reason(game,game.player,-1,false)
		if reason in ["boundary","cave_wall","cave_prop","cave_water","cave_seal","resource"]: game.player = safe_start(game.current_location)


## Выбирает свободную точку входящего туннеля, удалённую от обратного триггера на 96 пикселей.
static func safe_start(location: String) -> Vector2:
	if location == "cave": return MapData.START
	var passage: Dictionary = Rooms.passages(location)[0]
	return passage.position + Rooms.INWARD[passage.port] * 96.0


## Готовит геометрию комнаты один раз; переходы повторно используют её без новых узлов сцены.
static func _prepare(location: String) -> Dictionary:
	if _prepared.has(location): return _prepared[location]
	var floor := Rooms.floor_polygon(location)
	var result := {"floor":floor,"walls":[],"segments":_polygon_segments(floor),"pools":[],"decoration_rects":[]}
	if location == "cave_sanctum": result.decoration_rects.append_array(Rooms.Arena.solids())
	for prop in Rooms.decorations(location):
		var solid := Assets.collision_rect(prop.kind,prop.position)
		if solid.has_area(): result.decoration_rects.append(solid)
	_append_walls(result.walls,floor)
	for rock in Rooms.ROCKS.get(location, []):
		var outline := Rooms.rectangle_polygon(rock); outline.reverse()
		_append_walls(result.walls,outline)
	for rectangle in Rooms.POOLS.get(location, []):
		var polygon := Rooms.pool_polygon(rectangle,true)
		result.pools.append({"bounds":rectangle,"polygon":polygon,"segments":_polygon_segments(polygon)})
	result.walls.sort_custom(func(left: Dictionary,right: Dictionary): return left.position.y < right.position.y)
	_prepared[location] = result
	return result


## Собирает стыкующиеся спрайты с готовыми границами для отсечения за пределами камеры.
static func _append_walls(result: Array, polygon: PackedVector2Array) -> void:
	for index in polygon.size():
		var start := polygon[index]; var finish := polygon[(index+1) % polygon.size()]
		var direction := start.direction_to(finish); var inward := Vector2(-direction.y,direction.x)
		var horizontal := absf(direction.x) > absf(direction.y)
		var count := maxi(1,ceili(start.distance_to(finish)/(108.0 if horizontal else 60.0)))
		for part in count:
			var kind := "wall_straight_a" if posmod(index+part,2) == 0 else "wall_straight_b"
			if horizontal and inward.y < 0.0: kind = "wall_rim" if absf(direction.y) < 0.2 else ("corner_left" if direction.x < 0.0 else "corner_right")
			elif not horizontal: kind = "wall_side_right" if inward.x > 0.0 else "wall_side_left"
			var edge := start.lerp(finish,(part+0.5)/float(count))
			var ground := edge+Vector2(0,24)-inward*MapData.WALL_INSET
			result.append({"kind":kind,"position":ground,"edge":edge,"front":inward.y < -0.2,"bounds":Assets.destination_rect(kind,ground)})


## Готовит ограничивающие прямоугольники рёбер для быстрых проверок рядом с контуром.
static func _polygon_segments(polygon: PackedVector2Array) -> Array:
	var result: Array = []
	for index in polygon.size():
		var start := polygon[index]; var finish := polygon[(index+1) % polygon.size()]
		result.append({"start":start,"finish":finish,"bounds":Rect2(start,Vector2.ZERO).expand(finish).grow(MapData.WALL_INSET)})
	return result


## Проверяет круг относительно пола или внутренней непроходимой области по общей геометрии.
static func _blocks_polygon(position: Vector2, radius: float, polygon: PackedVector2Array, edges: Array, inside_blocked: bool) -> bool:
	if Geometry2D.is_point_in_polygon(position,polygon) == inside_blocked: return true
	for edge in edges:
		if not Rect2(edge.bounds).grow(radius).has_point(position): continue
		var closest := Geometry2D.get_closest_point_to_segment(position,edge.start,edge.finish)
		if position.distance_squared_to(closest) < pow(radius+(0.0 if inside_blocked else MapData.WALL_INSET),2): return true
	return false


## Проверяет круг у прямоугольного основания без изменения размеров игрового объекта.
static func _circle_in_rect(position: Vector2, radius: float, rectangle: Rect2) -> bool:
	return position.distance_squared_to(position.clamp(rectangle.position,rectangle.end)) < radius*radius
