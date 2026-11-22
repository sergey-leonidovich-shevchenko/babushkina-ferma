extends "res://scripts/game.gd"

var draws := 0


## Считает реальные вызовы исходного игрового renderer, не подменяя ни одного draw.
func _draw() -> void:
	draws += 1
	super._draw()
