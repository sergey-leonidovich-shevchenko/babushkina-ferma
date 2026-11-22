extends "res://tools/qa/world/lighting/inventory_game.gd"

var hidden_target := ""
var bad_hud := false


## Обычный корень использует production renderer; порча HUD существует только как контроль.
func _draw() -> void:
	super._draw()
	if bad_hud and not hud_only:
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.05, 0.08, 0.12, 0.45))


## Убирает только прежний проход врагов для пары видимости; AI и полный save не меняются.
func draw_enemy_nodes_and_gate() -> void:
	if hidden_target != "enemy":
		super.draw_enemy_nodes_and_gate()


## Контроль без ресурсного прохода не удаляет жилу из настоящего игрового состояния.
func draw_resource_nodes() -> void:
	if hidden_target != "resource":
		super.draw_resource_nodes()
