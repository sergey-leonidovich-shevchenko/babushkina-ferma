extends RefCounted

const Scenario := preload("res://tests/helpers/foliage_pause_scenario.gd")
const Wind := Scenario.Wind
const Navigation := preload("res://scripts/systems/navigation_system.gd")
const DT := 1.0 / 120.0
const FRAMES := 72
const TRAVEL := 126.0
const MAX_CONTACT := 4.36
const MAX_WIND := 1.35


## Выбирает настоящие проходимые маршруты по фиксированному порядку, не перемещая декор и коллизии.
static func routes(game: Node) -> Array:
	var rows := Wind.placements()
	var candidates := [
		{"id": "left", "row": 0, "direction": Vector2.LEFT, "start": Vector2(rows[0].rect.end.x + 38 + 480, rows[0].anchor.y)},
		{"id": "right", "row": 4, "direction": Vector2.RIGHT, "start": Vector2(rows[4].rect.position.x - 960 - 38 + 480, rows[4].anchor.y)},
		{"id": "top", "row": 6, "direction": Vector2.UP, "start": Vector2(rows[6].anchor.x, rows[6].rect.end.y + 38 + 270)},
		{"id": "bottom", "row": 7, "direction": Vector2.DOWN, "start": Vector2(rows[7].anchor.x, rows[7].rect.position.y - 540 - 38 + 270)},
		{"id": "chunk", "row": 6, "direction": Vector2.RIGHT, "start": rows[6].anchor + Vector2(-63, 0)}
	]
	var result := []
	for candidate in candidates:
		if candidate.id != "chunk":
			candidate["camera_only"] = true
			candidate["camera_start"] = candidate.start - Vector2(480, 270)
			if candidate.direction.x == 0: candidate.camera_start.x = clampf(candidate.camera_start.x, 0, 1440)
			else: candidate.camera_start.y = clampf(candidate.camera_start.y, 0, 828)
			candidate.start = rows[6].anchor + Vector2(-12, 0)
			result.append(candidate)
			continue
		var normal: Vector2 = candidate.direction.orthogonal()
		var chosen := {}
		for offset in [0, 48, -48, 96, -96, 144, -144, 192, -192]:
			var start: Vector2 = candidate.start + normal * offset
			if clear_path(game, start, candidate.direction):
				chosen = candidate.duplicate()
				chosen.start = start
				chosen["offset"] = offset
				break
		if chosen.is_empty():
			push_warning("No walkable route: " + candidate.id)
			return []
		result.append(chosen)
	# Герой проходит вдоль видимой кроны, а не сквозь твёрдый ствол куста.
	for index in game.food_nodes.size():
		var item: Dictionary = game.food_nodes[index]
		if str(item.get("location", "overworld")) != "overworld" or str(item.get("kind", "")) != "berries": continue
		var root: Vector2 = item.position + Vector2(0, 24)
		for direction in [Vector2.DOWN, Vector2.RIGHT]:
			for side in [-24, 24, -36, 36, -42, 42]:
				var start: Vector2 = root + direction.orthogonal() * side - direction * 63
				if clear_path(game, start, direction):
					result.append({"id": "bush", "row": 6, "direction": direction, "start": start, "bush_index": index, "bush_root": root})
					return result
	return []


## Проверяет каждый обычный шаг героя, включая препятствия и границы карты; обход коллизий не применяется.
static func clear_path(game: Node, start: Vector2, direction: Vector2) -> bool:
	for index in FRAMES + 1:
		if Navigation.walkability_reason(game, start + direction * TRAVEL * index / FRAMES, -1, true, false) != "walkable": return false
	return true


## Начинает воспроизводимый маршрут настоящей сценой, камерой120% и обычной скоростью210.
static func place(game: Node, route: Dictionary) -> void:
	game.clear_movement_keys()
	game.player = route.start
	game.facing = route.direction
	game.update_camera()
	if route.get("camera_only", false): game.camera_offset = route.camera_start
	Scenario.Pose.reset(game)
	Wind.update(game)


## Держит штатное направление; physics/process исполняются контролируемо, это не аппаратный ввод или FPS.
static func advance(game: Node, direction: Vector2) -> void:
	game.clear_movement_keys()
	game.move_left_held = direction.x < 0
	game.move_right_held = direction.x > 0
	game.move_up_held = direction.y < 0
	game.move_down_held = direction.y > 0
	Scenario.step(game, DT)


## Ограничивает любой изгиб по неравенству треугольника, независимо от времени и квантования INSTANCE_CUSTOM.
static func swept_rect(row: Dictionary) -> Rect2:
	return row.rect.grow_individual(MAX_WIND + MAX_CONTACT, MAX_CONTACT, MAX_WIND + MAX_CONTACT, MAX_CONTACT)


## Экспортирует только числовую геометрию для независимого читателя, а не строковые Vector2.
static func pack(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Rect2: return {"position": pack(value.position), "size": pack(value.size)}
	if value is AABB: return {"position": [value.position.x, value.position.y, value.position.z], "size": [value.size.x, value.size.y, value.size.z]}
	if value is Dictionary:
		var result := {}
		for key in value: result[str(key)] = pack(value[key])
		return result
	if value is Array or value is PackedVector2Array:
		var result := []
		for item in value: result.append(pack(item))
		return result
	return value
