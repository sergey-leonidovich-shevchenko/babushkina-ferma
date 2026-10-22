extends RefCounted

const CELL_SIZE := 128.0
const DYNAMIC_HALF_EXTENT := 256.0
static var _groups: Dictionary = {}
static var build_count := 0


## Проверяет только близкие неизменные основания, сохраняя точный круг и живое условие открытия двери.
static func blocks(game: Node, category: String, position: Vector2, radius: float) -> bool:
	var group := geometry(game, category)
	for index in candidates(group, position, radius):
		var entry: Dictionary = group.entries[index]
		if not game.NavigationSystem.circle_intersects_rect(position, radius, entry.rect): continue
		if entry.has("door") and game.BuildingSystem.can_enter(game, String(entry.door)): continue
		return true
	return false


## Один раз индексирует геометрию констант; редактируемый уровень и живые объекты в этот кэш не входят.
static func geometry(game: Node, category: String) -> Dictionary:
	var key := "%s:%s" % [category, game.current_location]
	if _groups.has(key): return _groups[key]
	var group := {"entries": [], "buckets": {}}
	if category == "building":
		for building_id in game.BuildingSystem.buildings_at(game.current_location):
			for rect in game.BuildingSystem.collision_rects(building_id): append(group, {"rect": rect})
			append(group, {"rect": game.BuildingSystem.door_rect(building_id), "door": building_id})
	elif category == "scenic" and game.current_location == "overworld":
		for point in game.VillageLayoutSystem.BORDER_TREES:
			append(group, {"rect": game.WorldVisualProfileSystem.collision_rect("tree_adult", point + Vector2(0, 48))})
		for prop in game.VillageLayoutSystem.PROP_PLACEMENTS:
			var rect: Rect2 = game.VillageLayoutSystem.prop_collision_rect(prop)
			if rect.has_area(): append(group, {"rect": rect})
		for rect in game.VillageLayoutSystem.MASTER_SOLID_RECTS: append(group, {"rect": rect})
	elif category == "farm_fence" and game.current_location == "overworld":
		for rect in game.BuildingSystem.farm_fence_rects(): append(group, {"rect": rect})
	_groups[key] = group
	build_count += 1
	return group


## Раскладывает каждый прямоугольник во все пересекаемые пространственные ячейки без изменения его формы.
static func append(group: Dictionary, entry: Dictionary) -> void:
	var index: int = group.entries.size()
	group.entries.append(entry)
	var rect: Rect2 = entry.rect
	for y in range(floori(rect.position.y / CELL_SIZE), floori(rect.end.y / CELL_SIZE) + 1):
		for x in range(floori(rect.position.x / CELL_SIZE), floori(rect.end.x / CELL_SIZE) + 1):
			var key := Vector2i(x, y)
			if not group.buckets.has(key): group.buckets[key] = []
			group.buckets[key].append(index)


## Возвращает только основания около круга, включая соседнюю ячейку у края и исключая дубли.
static func candidates(group: Dictionary, position: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	for y in range(floori((position.y - radius) / CELL_SIZE), floori((position.y + radius) / CELL_SIZE) + 1):
		for x in range(floori((position.x - radius) / CELL_SIZE), floori((position.x + radius) / CELL_SIZE) + 1):
			for index in group.buckets.get(Vector2i(x, y), []):
				if index not in result: result.append(index)
	return result


## Отсекает заведомо далёкий живой объект до сборки его профиля; запас проверяется по всем семействам тестом.
static func near_dynamic(position: Vector2, anchor: Vector2, radius: float) -> bool:
	var delta := (position - anchor).abs()
	return delta.x <= DYNAMIC_HALF_EXTENT + radius and delta.y <= DYNAMIC_HALF_EXTENT + radius
