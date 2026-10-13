extends RefCounted

const UiScale := preload("res://scripts/systems/ui_scale_system.gd")
const EDGE_MARGIN := 24.0


## Возвращает фактическую область камеры в мировых координатах с запасом для краёв спрайтов и тряски.
static func visible_rect(game: Node2D) -> Rect2:
	var viewport := game.get_viewport_rect() if game.is_inside_tree() else Rect2(Vector2.ZERO, UiScale.DESIGN_SIZE)
	if viewport.size == Vector2.ZERO: viewport = Rect2(Vector2.ZERO, UiScale.DESIGN_SIZE)
	var shake: Vector2 = game.AdventurePolishSystem.shake_offset(game)
	return Rect2(viewport.position + game.camera_offset - shake, viewport.size).grow(EDGE_MARGIN)
