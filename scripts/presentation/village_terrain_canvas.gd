extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
var season := "spring"
var weather := "clear"

## Собирает неизменный деревенский грунт в текстуру только при смене сезона или погоды.
func _draw() -> void:
	Terrain.draw(self,season,weather)
