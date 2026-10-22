extends RefCounted

const INNER_DECK_RECT := Rect2(160, 195, 2090, 790)
const MAST_POSITIONS := [Vector2(850, 520), Vector2(1580, 520)]
const CANNON_RECTS := [Rect2(460, 210, 100, 55), Rect2(1120, 210, 100, 55), Rect2(1810, 210, 100, 55), Rect2(460, 900, 100, 55), Rect2(1120, 900, 100, 55), Rect2(1810, 900, 100, 55)]


## Проверяет, остаётся ли круг героя на палубе и не пересекает ли мачты с пушками.
static func is_walkable(position: Vector2, radius: float) -> bool:
	if not INNER_DECK_RECT.grow(-radius).has_point(position):
		return false
	for mast in MAST_POSITIONS:
		if position.distance_to(mast) < radius + 38.0: return false
	for cannon in CANNON_RECTS:
		if circle_intersects_rect(position, radius, cannon): return false
	return true


## Проверяет пересечение круглого участника боя с прямоугольным объектом корабля.
static func circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) < radius * radius
