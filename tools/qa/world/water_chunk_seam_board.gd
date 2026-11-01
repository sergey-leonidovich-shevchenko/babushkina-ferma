extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const WaterMapRegistry := preload("res://scripts/systems/water_map_registry.gd")
const WaterTopology := preload("res://scripts/systems/water_topology.gd")
const WaterVisualSystem := preload("res://scripts/systems/water_visual_system.gd")

var mode := "chunk-safe"
var camera := Vector2.ZERO
var animation_frame := 1


## Рисует одинаковое окружение и меняет только способ классификации модульной воды.
func _draw() -> void:
	Terrain.draw_base(self, "spring", "clear", true, true, true, true, true, true)
	match mode:
		"global":
			_draw_global()
		"isolated-negative":
			_draw_isolated_negative()
		_:
			_draw_chunk_safe()
	Terrain.draw_cover(self, "spring", "clear")
	draw_set_transform(Vector2.ZERO)


## Классифицирует каждую клетку по полному каноническому плану — эталон результата.
func _draw_global() -> void:
	var cells := WaterMapRegistry.geometry("overworld").cells()
	var ordered: Array = cells.keys()
	ordered.sort_custom(_cell_before)
	for cell: Vector2i in ordered:
		WaterVisualSystem.draw_module(self, cell, cells, animation_frame)


## Рисует клетку ровно один раз её владельцем, но читает соседние маски из общего halo.
func _draw_chunk_safe() -> void:
	var plan: WaterTopology = WaterMapRegistry.geometry("overworld")
	var chunks: Dictionary = plan._chunks_snapshot()
	var keys: Array = chunks.keys()
	keys.sort_custom(_cell_before)
	for key: Vector2i in keys:
		var snapshot := WaterMapRegistry.visual_chunk("overworld", key)
		for cell: Vector2i in snapshot.cells:
			WaterVisualSystem.draw_chunk_module(self, cell, snapshot, animation_frame)


## Отрицательный контроль намеренно не видит соседний чанк и потому создаёт ложный берег.
func _draw_isolated_negative() -> void:
	var plan: WaterTopology = WaterMapRegistry.geometry("overworld")
	var chunks: Dictionary = plan._chunks_snapshot()
	var keys: Array = chunks.keys()
	keys.sort_custom(_cell_before)
	for key: Vector2i in keys:
		var local := {}
		for cell: Vector2i in plan.chunk_cells(key):
			local[cell] = true
		for cell: Vector2i in plan.chunk_cells(key):
			WaterVisualSystem.draw_module(self, cell, local, animation_frame)


## Стабилизирует painter order независимо от порядка Dictionary.
func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
