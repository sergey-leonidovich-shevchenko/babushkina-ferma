extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
var season := "spring"
var weather := "clear"
var location := "overworld"
var base_only := false
var painted_grass := true
var soft_ground_edges := true
var paint_count := 0

## Собирает неизменный деревенский грунт в текстуру только при смене сезона или погоды.
func _draw() -> void:
	paint_count+=1
	if preload("res://scripts/systems/village_region_data.gd").added(location): preload("res://scripts/presentation/village_region_terrain.gd").draw(self,location,season,weather)
	else:
		if base_only: Terrain.draw_base(self,season,weather,painted_grass,soft_ground_edges)
		else:
			Terrain.draw(self,season,weather,painted_grass,soft_ground_edges)
			preload("res://scripts/presentation/village_region_terrain.gd").paths(self,location,soft_ground_edges)
