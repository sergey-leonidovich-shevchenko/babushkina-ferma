extends Node2D

var size := Vector2.ZERO

## Очищает только ограниченную родительским scissor область, включая прежнюю альфу водных вырезов.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color.TRANSPARENT)
