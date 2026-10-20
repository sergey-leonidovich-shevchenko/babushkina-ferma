extends RefCounted

const VIEWPORT_SIZE := Vector2(1152, 648)
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")


## Возвращает мировую область экрана между постоянной верхней панелью и быстрыми слотами.
static func playfield_rect(game: Node) -> Rect2:
	var top: float = game.HudLayoutSystem.HUD_RESERVED_RECT.end.y
	var bottom: float = game.HudLayoutSystem.HOTBAR_RESERVED_RECT.position.y
	return Rect2(0, top, VIEWPORT_SIZE.x, bottom - top)


## Удерживает маленькую комнату в центре свободного экрана, а по большим залам и улицам следует за героем.
static func target_offset(game: Node) -> Vector2:
	return offset_for_position(game, game.player)


## Применяет прежние границы камеры к общей отображаемой опоре, не изменяя физическую позицию.
static func offset_for_position(game: Node, ground: Vector2) -> Vector2:
	var offset: Vector2
	if game.BuildingSystem.is_interior(game.current_location):
		var room: Rect2 = game.BuildingSystem.interior(game.current_location).room
		var playfield := playfield_rect(game)
		offset = Vector2(
			_room_axis(ground.x, room.position.x, room.end.x, playfield.position.x, playfield.end.x, VIEWPORT_SIZE.x),
			_room_axis(ground.y, room.position.y, room.end.y, playfield.position.y, playfield.end.y, VIEWPORT_SIZE.y)
		)
	else:
		var bounds: Vector2 = game.WorldBoundsSystem.size(game.current_location)
		var field := WorldProjection.field_size(game)
		offset = Vector2(
			clampf(ground.x - field.x * 0.5, 0.0, maxf(0.0,bounds.x - field.x)),
			clampf(ground.y - field.y * 0.5, 0.0, maxf(0.0,bounds.y - field.y))
		)
	# Опора героя и смещение фона используют ту же дробную проекцию.
	return offset


## Центрирует помещающуюся комнату по одной оси и ограничивает прокрутку большого зала его стенами.
static func _room_axis(player: float, room_start: float, room_end: float, screen_start: float, screen_end: float, viewport_extent: float) -> float:
	var screen_center := (screen_start + screen_end) * 0.5
	if room_end - room_start <= viewport_extent:
		return (room_start + room_end) * 0.5 - screen_center
	return clampf(player - screen_center, room_start - screen_start, room_end - screen_end)


## Перемещает только ручную камеру редактора с его прежним полем 100% и сразу синхронизирует фон.
static func pan_editor(game: Node, motion: Vector2) -> void:
	var bounds:Vector2=game.WorldBoundsSystem.size(game.current_location)
	game.camera_offset.x=clampf(game.camera_offset.x+motion.x,0.0,bounds.x-VIEWPORT_SIZE.x)
	game.camera_offset.y=clampf(game.camera_offset.y+motion.y,0.0,bounds.y-VIEWPORT_SIZE.y)
	WorldProjection.sync_background(game)
