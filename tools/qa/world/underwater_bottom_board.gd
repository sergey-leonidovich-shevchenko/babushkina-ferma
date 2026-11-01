extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")

var mode := "after"
var camera := Vector2.ZERO
var season := "spring"
var weather := "clear"


## Рисует прежнюю и новую воду на одном production-чертёже без запуска игровой сцены.
func _draw() -> void:
	draw_set_transform(-camera)
	Terrain.draw_base(self, season, weather, true, true, true, true, true, true)
	if mode == "before":
		var tint := Color("b3d6da") if season == "winter" else Color("d2e7eb")
		for points: PackedVector2Array in Terrain.surface_polygons():
			Terrain.material(self, points, Terrain.WATER, tint)
	elif mode == "bottom":
		Terrain.draw_underwater_bottom(self, season, weather)
	else:
		Terrain.draw_underwater_bottom(self, season, weather)
		Terrain.draw_surface(self, season, false, weather)
	Terrain.draw_cover(self, season, weather)
	draw_set_transform(Vector2.ZERO)
