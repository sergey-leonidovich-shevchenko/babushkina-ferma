extends RefCounted

const VIEWPORT_SIZE := Vector2(1152, 648)


## Возвращает мировую область экрана между постоянной верхней панелью и быстрыми слотами.
static func playfield_rect(game: Node) -> Rect2:
	var top: float = game.HudLayoutSystem.HUD_RESERVED_RECT.end.y
	var bottom: float = game.HudLayoutSystem.HOTBAR_RESERVED_RECT.position.y
	return Rect2(0, top, VIEWPORT_SIZE.x, bottom - top)


## Удерживает маленькую комнату в центре свободного экрана, а по большим залам и улицам следует за героем.
static func target_offset(game: Node) -> Vector2:
	if game.BuildingSystem.is_interior(game.current_location):
		var room: Rect2 = game.BuildingSystem.interior(game.current_location).room
		var playfield := playfield_rect(game)
		return Vector2(
			_room_axis(game.player.x, room.position.x, room.end.x, playfield.position.x, playfield.end.x, VIEWPORT_SIZE.x),
			_room_axis(game.player.y, room.position.y, room.end.y, playfield.position.y, playfield.end.y, VIEWPORT_SIZE.y)
		).round()
	return Vector2(
		clampf(game.player.x - VIEWPORT_SIZE.x * 0.5, 0.0, game.WORLD_SIZE.x - VIEWPORT_SIZE.x),
		clampf(game.player.y - VIEWPORT_SIZE.y * 0.5, 0.0, game.WORLD_SIZE.y - VIEWPORT_SIZE.y)
	).round()


## Центрирует помещающуюся комнату по одной оси и ограничивает прокрутку большого зала его стенами.
static func _room_axis(player: float, room_start: float, room_end: float, screen_start: float, screen_end: float, viewport_extent: float) -> float:
	var screen_center := (screen_start + screen_end) * 0.5
	if room_end - room_start <= viewport_extent:
		return (room_start + room_end) * 0.5 - screen_center
	return clampf(player - screen_center, room_start - screen_start, room_end - screen_end)
