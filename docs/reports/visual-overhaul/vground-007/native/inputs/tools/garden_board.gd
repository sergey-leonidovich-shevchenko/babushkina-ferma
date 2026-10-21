extends Node2D

const Soil := preload("res://scripts/presentation/garden_soil.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const Legacy := preload("res://scripts/systems/farm_visual_system.gd")
var kind := "after"
var season := "spring"

## Сравнивает настоящие материалы: нетронутая, сухая и влажная земля при одном игровом масштабе.
func _draw() -> void:
	Soil.warmup()
	for state in 3:
		draw_set_transform(Vector2(24+state*304,48)-Soil.FARM.position)
		if kind in ["mask","recolor"]:
			draw_mesh(Soil._base,null,Transform2D.IDENTITY,Color.WHITE if kind=="mask" else Color("6f9cc1"))
			continue
		if kind=="before": Terrain._draw_garden(self)
		else: Soil.draw_base(self)
		if state==0: continue
		var plots:={}
		for cell: Vector2i in Soil._plots: plots[cell]={"tilled":true,"planted":false,"watered":state==2}
		for cell: Vector2i in Soil._plots:
			var rect:=Rect2(Soil.FARM.position+Vector2(cell)*48.0,Vector2(48,48))
			var plot: Dictionary=plots[cell]
			if kind=="before": Legacy.draw_soil(self,rect,plot)
			else: Soil.draw_plot(self,rect,plot,plots)
	draw_set_transform(Vector2.ZERO)
