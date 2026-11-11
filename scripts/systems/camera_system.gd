extends RefCounted

const VIEWPORT_SIZE := Vector2(1152, 648)
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const HudLayoutSystem := preload("res://scripts/systems/hud_layout_system.gd")
const BuildingSystem := preload("res://scripts/systems/building_system.gd")
const WorldBoundsSystem := preload("res://scripts/systems/world_bounds_system.gd")


## Возвращает мировую область между верхней панелью и быстрыми слотами.
static func playfield_rect(_game: Node) -> Rect2:
	var top: float = HudLayoutSystem.HUD_RESERVED_RECT.end.y
	var bottom: float = HudLayoutSystem.HOTBAR_RESERVED_RECT.position.y
	return Rect2(0, top, VIEWPORT_SIZE.x, bottom - top)


## Удерживает маленькую комнату в центре свободного экрана.
## По большим залам и улицам следует за героем.
static func target_offset(game: Node) -> Vector2:
	var player: Variant = game.get("player")
	if player is Vector2:
		var position: Vector2 = player
		return offset_for_position(game, position)
	return Vector2.ZERO


## Применяет прежние границы камеры к общей отображаемой опоре.
## Физическая позиция не изменяется.
static func offset_for_position(game: Node, ground: Vector2) -> Vector2:
	var offset: Vector2
	var location := _location(game)
	if BuildingSystem.is_interior(location):
		var interior := BuildingSystem.interior(location)
		var room_value: Variant = interior.get("room")
		if not room_value is Rect2:
			return Vector2.ZERO
		var room: Rect2 = room_value
		var playfield := playfield_rect(game)
		offset = Vector2(
			_room_axis(
				ground.x,
				room.position.x,
				room.end.x,
				playfield.position.x,
				playfield.end.x,
				VIEWPORT_SIZE.x
			),
			_room_axis(
				ground.y,
				room.position.y,
				room.end.y,
				playfield.position.y,
				playfield.end.y,
				VIEWPORT_SIZE.y
			)
		)
	else:
		var bounds: Vector2 = WorldBoundsSystem.size(location)
		var field := WorldProjection.field_size(game)
		offset = Vector2(
			clampf(ground.x - field.x * 0.5, 0.0, maxf(0.0, bounds.x - field.x)),
			clampf(ground.y - field.y * 0.5, 0.0, maxf(0.0, bounds.y - field.y))
		)
	# Опора героя и смещение фона используют ту же дробную проекцию.
	return offset


## Центрирует помещающуюся комнату по одной оси.
## Прокрутку большого зала ограничивает его стенами.
static func _room_axis(
	player: float,
	room_start: float,
	room_end: float,
	screen_start: float,
	screen_end: float,
	viewport_extent: float
) -> float:
	var screen_center := (screen_start + screen_end) * 0.5
	if room_end - room_start <= viewport_extent:
		return (room_start + room_end) * 0.5 - screen_center
	return clampf(player - screen_center, room_start - screen_start, room_end - screen_end)


## Перемещает ручную камеру редактора с прежним полем 100%.
## Сразу синхронизирует фон.
static func pan_editor(game: Node, motion: Vector2) -> void:
	var value: Variant = game.get("camera_offset")
	if not value is Vector2:
		return
	var offset: Vector2 = value
	var bounds: Vector2 = WorldBoundsSystem.size(_location(game))
	offset.x = clampf(offset.x + motion.x, 0.0, bounds.x - VIEWPORT_SIZE.x)
	offset.y = clampf(offset.y + motion.y, 0.0, bounds.y - VIEWPORT_SIZE.y)
	game.set("camera_offset", offset)
	WorldProjection.sync_background(game)


## Читает строковый идентификатор карты без небезопасного преобразования Variant.
static func _location(game: Node) -> String:
	var value: Variant = game.get("current_location")
	return value if value is String else ""
