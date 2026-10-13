extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
var season := "spring"
var weather := "clear"
var location := "overworld"

## Собирает неизменный деревенский грунт в текстуру только при смене сезона или погоды.
func _draw() -> void:
	if preload("res://scripts/systems/village_region_data.gd").added(location): preload("res://scripts/presentation/village_region_terrain.gd").draw(self,location,season,weather)
	else: Terrain.draw(self,season,weather)
