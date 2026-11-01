extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const WaterMapRegistry := preload("res://scripts/systems/water_map_registry.gd")

var mode := "runtime"
var camera := Vector2.ZERO


## Рисует production-воду или её диагностическую маску при той же камере и том же основании.
func _draw() -> void:
	draw_set_transform(-camera)
	Terrain.draw_base(self, "spring", "clear", true, true, true, true, true, true)
	if mode == "topology":
		_draw_topology()
	else:
		Terrain.draw_underwater_bottom(self, "spring")
		Terrain.draw_surface(self, "spring")
	Terrain.draw_cover(self, "spring", "clear")
	draw_set_transform(Vector2.ZERO)


## Показывает покрытие, глубину и внешний берег из одного снимка без второй геометрии.
func _draw_topology() -> void:
	var snapshot := WaterMapRegistry.visual("overworld")
	for region: Dictionary in snapshot.regions:
		var depth: float = region.depth
		var color := Color(0.20, 0.72, 0.86, lerpf(0.45, 0.82, depth))
		for polygon: PackedVector2Array in region.polygons:
			draw_colored_polygon(polygon, color)
	for span: Dictionary in snapshot.shore_spans:
		var start: Vector2 = span.start
		var finish: Vector2 = span.finish
		draw_line(start, finish, Color(0.98, 0.91, 0.58, 0.94), 4.0)
