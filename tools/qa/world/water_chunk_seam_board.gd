extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const WaterMapRegistry := preload("res://scripts/systems/water_map_registry.gd")
const WaterTopology := preload("res://scripts/systems/water_topology.gd")
const SEAM_CELL_X := 16
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


## Отрицательный контроль скрывает соседей только через исследуемый стык x=15/16.
func _draw_isolated_negative() -> void:
	var cells := WaterMapRegistry.geometry("overworld").cells()
	var ordered: Array = cells.keys()
	ordered.sort_custom(_cell_before)
	for cell: Vector2i in ordered:
		var visible: Dictionary = cells
		if cell.x == SEAM_CELL_X - 1 or cell.x == SEAM_CELL_X:
			visible = cells.duplicate()
			var across := Vector2i.RIGHT if cell.x == SEAM_CELL_X - 1 else Vector2i.LEFT
			for offset: Vector2i in [across, across + Vector2i.UP, across + Vector2i.DOWN]:
				visible.erase(cell + offset)
		WaterVisualSystem.draw_module(self, cell, visible, animation_frame)


## Стабилизирует painter order независимо от порядка Dictionary.
func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
