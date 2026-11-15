extends RefCounted

const Layout := preload("res://scripts/systems/village_layout_system.gd")
const TEXTURE := preload("res://assets/game/locations/overworld/modular/bridge_modular_v1.png")
const DECK := Rect2(24, 0, 96, 216)
const RAILS := [Rect2(0, 0, 24, 216), Rect2(120, 0, 24, 216)]
const RAIL_HEIGHT := 24.0
const SOUTH_POST_FOOT := 214.0


## Оставляет настил в неподвижной земле и сохраняет исходный целый спрайт для просмотра без героя.
static func draw_ground(canvas: Node2D, separate_rails: bool) -> void:
	for index in Layout.BRIDGES.size():
		var bridge := Layout.bridge_render_rect(index)
		if separate_rails:
			_draw_region(canvas, bridge.position, DECK)
		else:
			canvas.draw_texture_rect(TEXTURE, bridge, false)


## Рисует полосы перил по обе стороны прохода до или после тела героя.
static func draw_rails(canvas: Node2D, view: Rect2, foot: Vector2, foreground: bool) -> void:
	for index in Layout.BRIDGES.size():
		var bridge := Layout.bridge_render_rect(index)
		if not view.intersects(bridge):
			continue
		var depth := _foreground_start(bridge, Layout.bridge_navigation_rect(index), foot)
		var top := depth if foreground else 0.0
		var bottom := bridge.size.y if foreground else depth
		if top >= bottom:
			continue
		for rail: Rect2 in RAILS:
			_draw_region(
				canvas, bridge.position, Rect2(rail.position.x, top, rail.size.x, bottom - top)
			)


## Сравнивает опору героя с перилами. Перед южными опорами герой уже рисуется поверх моста.
static func _foreground_start(bridge: Rect2, passage: Rect2, foot: Vector2) -> float:
	var local_y := foot.y - bridge.position.y
	if foot.x < passage.position.x or foot.x >= passage.end.x or local_y > SOUTH_POST_FOOT:
		return bridge.size.y
	return clampf(floorf(local_y - RAIL_HEIGHT), 0.0, bridge.size.y)


## Использует то же положение и ту же UV-сетку для непересекающихся областей исходной текстуры.
static func _draw_region(canvas: Node2D, origin: Vector2, source: Rect2) -> void:
	canvas.draw_texture_rect_region(TEXTURE, Rect2(origin + source.position, source.size), source)
