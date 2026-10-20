extends RefCounted

const UiScale := preload("res://scripts/systems/ui_scale_system.gd")
const EDGE_MARGIN := 24.0


## Возвращает фактическую область камеры в мировых координатах с запасом для краёв спрайтов и тряски.
static func visible_rect(game: Node2D) -> Rect2:
	var viewport := game.get_viewport_rect() if game.is_inside_tree() else Rect2(Vector2.ZERO, UiScale.DESIGN_SIZE)
	if viewport.size == Vector2.ZERO: viewport = Rect2(Vector2.ZERO, UiScale.DESIGN_SIZE)
	return preload("res://scripts/systems/world_projection_system.gd").screen_rect_to_world(game,viewport).grow(EDGE_MARGIN)
