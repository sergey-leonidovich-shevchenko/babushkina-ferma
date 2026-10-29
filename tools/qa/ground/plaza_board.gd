extends Node2D

const Plaza := preload("res://scripts/presentation/plaza_ground.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
var kind := "after"
var season := "spring"

## Показывает повтор материала и контакт площади при неизменных положении, масштабе и грунте.
func _draw() -> void:
	if kind in ["repeat","repeat-before"]:
		if kind=="repeat": draw_mesh(Meadow.mesh(Vector2(960,960)),Plaza.texture())
		else: draw_texture_rect(Terrain.STONE,Rect2(0,0,960,960),true,Color("d6c5a1"))
		return
	draw_set_transform(Vector2(-960,-288))
	if kind=="mask": draw_mesh(Plaza.STONE,null)
	elif kind=="recolor": draw_mesh(Plaza.STONE,Plaza.texture(Plaza.DIRT))
	else: Terrain.draw_base(self,season,"clear",true,true,true,true,kind=="after")
