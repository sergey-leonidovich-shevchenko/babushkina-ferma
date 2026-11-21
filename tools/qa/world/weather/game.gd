extends "res://scripts/game.gd"

var weather_only := false
var draw_count := 0


## Наблюдает production draw; отдельный режим изолирует тот же AtmosphereRenderer.
func _draw() -> void:
	draw_count += 1
	if weather_only:
		AtmosphereRenderer.draw(self)
	else:
		super._draw()
