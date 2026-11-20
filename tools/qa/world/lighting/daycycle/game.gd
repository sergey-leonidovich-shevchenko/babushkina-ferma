extends "res://tools/qa/world/lighting/inventory_game.gd"

var bad_hud := false
var hidden_target := ""


## Обычный кадр проходит настоящий production draw; ошибка HUD — явный отрицательный контроль.
func _draw() -> void:
	super._draw()
	if bad_hud and not hud_only:
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.08, 0.10, 0.22, 0.32))


## Нативная пара без героя выделяет его фактические пиксели, не меняя game/save.
func draw_player() -> void:
	if hidden_target != "hero":
		super.draw_player()


## Используется прежний renderer угрозы; QA не добавляет новую механику в production.
func draw_hazards() -> void:
	if hidden_target != "threat":
		super.draw_hazards()
