extends RefCounted

const MapData := preload("res://scripts/systems/cave_map_data.gd")
const Assets := preload("res://scripts/systems/cave_asset_system.gd")
static var _walls: Array[Dictionary] = []
static var _segments: Array[Dictionary] = []
static var _polygon := PackedVector2Array(MapData.FLOOR)


## Возвращает подготовленный полигон пола без нового преобразования массива на каждом шаге навигации.
static func floor_polygon() -> PackedVector2Array:
	return _polygon


## Собирает контур и его основания один раз; кадры используют готовый набор модульных стен.
static func walls() -> Array[Dictionary]:
	if not _walls.is_empty(): return _walls
	for index in MapData.FLOOR.size():
		var start: Vector2 = MapData.FLOOR[index]
		var finish: Vector2 = MapData.FLOOR[(index + 1) % MapData.FLOOR.size()]
		var direction := start.direction_to(finish)
		var inward := Vector2(-direction.y, direction.x)
		var horizontal := absf(direction.x) > absf(direction.y)
		var count := maxi(1, ceili(start.distance_to(finish) / (108.0 if horizontal else 60.0)))
		for part in count:
			var kind := "wall_straight_a" if posmod(index + part, 2) == 0 else "wall_straight_b"
			if horizontal and inward.y < 0.0:
				kind = "wall_rim" if absf(direction.y) < 0.2 else ("corner_left" if direction.x < 0.0 else "corner_right")
			elif not horizontal: kind = "wall_side_right" if inward.x > 0.0 else "wall_side_left"
			var edge := start.lerp(finish, (part + 0.5) / float(count))
			var ground := edge + Vector2(0, 24) - inward * MapData.WALL_INSET
			_walls.append({"kind": kind, "position": ground, "edge": edge, "front": inward.y < -0.2})
	_walls.sort_custom(func(left: Dictionary, right: Dictionary): return left.position.y < right.position.y)
	return _walls


## Кеширует отрезки скального контура для быстрых точных проверок основания рядом со стеной.
static func segments() -> Array[Dictionary]:
	if not _segments.is_empty(): return _segments
	for index in MapData.FLOOR.size():
		var start: Vector2 = MapData.FLOOR[index]
		var finish: Vector2 = MapData.FLOOR[(index + 1) % MapData.FLOOR.size()]
		_segments.append({"start": start, "finish": finish, "bounds": Rect2(start, Vector2.ZERO).expand(finish).grow(MapData.WALL_INSET)})
	return _segments


## Не пускает круг за видимый контур, оставляя небольшой запас для выступающих оснований скал.
static func blocks_position(position: Vector2, radius: float) -> bool:
	if not Geometry2D.is_point_in_polygon(position, _polygon): return true
	for segment in segments():
		if not Rect2(segment.bounds).grow(radius).has_point(position): continue
		var closest := Geometry2D.get_closest_point_to_segment(position, segment.start, segment.finish)
		if position.distance_squared_to(closest) < pow(radius + MapData.WALL_INSET, 2): return true
	return false


## Проверяет только основания крупного декора; мелкие грибы и камни не перекрывают проходы.
static func blocks_decoration(position: Vector2, radius: float) -> bool:
	for prop in MapData.DECORATIONS:
		var solid := Assets.collision_rect(prop.kind, prop.position)
		if not solid.has_area(): continue
		var closest := position.clamp(solid.position, solid.end)
		if closest.distance_squared_to(position) < radius * radius: return true
	return false


## Переносит лишь оказавшиеся в новых скалах позиции старого сохранения, сохраняя добычу и состояние существ.
static func repair_saved_positions(game: Node) -> void:
	for enemy in game.enemy_nodes:
		if enemy.location == "cave" and blocks_position(enemy.position, 27.0): enemy.position = enemy.home
	for animal in game.wildlife_nodes:
		if animal.location == "cave" and blocks_position(animal.position, game.PLAYER_RADIUS):
			animal.position = animal.home; animal.habitat_validated = false
	if game.current_location == "cave":
		var reason: String = game.NavigationSystem.walkability_reason(game, game.player, -1, false)
		if reason in ["boundary", "cave_wall", "cave_prop", "resource"]: game.player = MapData.START
