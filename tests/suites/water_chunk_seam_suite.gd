extends "res://tests/suites/suite_base.gd"

const Water := preload("res://scripts/systems/water_topology.gd")


## Запускает адресные сценарии соседнего halo и локальной инвалидизации.
func run() -> void:
	test_chunk_visual_uses_neighbor_halo_without_internal_shore()
	test_chunk_visual_cache_invalidates_only_local_neighbors()


## Сценарий: заполненная река пересекает границу чанков x=15/16 и касается диагонального halo.
## Исходное состояние: каждый снимок владеет только своей половиной воды.
## Ожидаемый результат: маски читают соседнюю группу, а ложного берега на x=384 нет.
func test_chunk_visual_uses_neighbor_halo_without_internal_shore() -> void:
	var plan := Water.new()
	var river := plan.add_body("river")
	plan.add_rect(Rect2(336, 0, 96, 48), river)
	plan.add_rect(Rect2(384, 48, 24, 24), river)
	var left := plan._chunk_visual_snapshot(Vector2i.ZERO)
	var right := plan._chunk_visual_snapshot(Vector2i.RIGHT)
	var left_masks: Dictionary = left.neighbor_masks
	var right_masks: Dictionary = right.neighbor_masks
	var left_diagonals: Dictionary = left.diagonal_masks
	expect(
		(
			left.cells.size() == 4
			and right.cells.size() == 5
			and left.halo.has(Vector2i(16, 0))
			and right.halo.has(Vector2i(15, 0))
		),
		"each group owns its cells once and reads a one-cell cross-chunk halo",
	)
	expect(
		(
			left_masks[Vector2i(15, 0)] & 2
			and right_masks[Vector2i(16, 0)] & 8
			and left_diagonals[Vector2i(15, 1)] & 1
		),
		"cardinal and diagonal masks include water from the neighboring chunk",
	)
	expect(
		left.filled_edges.east == 2 and right.filled_edges.west == 2,
		"filled boundary contacts are explicit on both owners",
	)
	for snapshot: Dictionary in [left, right]:
		for edge: Dictionary in snapshot.shore_edges:
			var start: Vector2 = edge.start
			var finish: Vector2 = edge.finish
			expect(
				not (
					is_equal_approx(start.x, 384.0)
					and is_equal_approx(finish.x, 384.0)
					and minf(start.y, finish.y) < 48.0
				),
				"the chunk boundary never becomes an internal shoreline",
			)


## Сценарий: снимки стыка уже построены, затем меняется далёкая и граничная клетка.
## Исходное состояние: локальный кеш трёх групп без кадровой пересборки.
## Ожидаемый результат: далёкая правка сохраняет стык, граничная инвалидирует обе его стороны.
func test_chunk_visual_cache_invalidates_only_local_neighbors() -> void:
	var plan := Water.new()
	var river := plan.add_body("river")
	plan.add_rect(Rect2(360, 24, 48, 24), river)
	plan.add_rect(Rect2(2400, 2400, 24, 24), river)
	plan._chunk_visual_snapshot(Vector2i.ZERO)
	plan._chunk_visual_snapshot(Vector2i.RIGHT)
	plan._chunk_visual_snapshot(Vector2i(6, 6))
	expect(plan.chunk_visual_builds == 3, "three chunk snapshots build once")
	plan.add_rect(Rect2(2424, 2400, 24, 24), river)
	plan._chunk_visual_snapshot(Vector2i.ZERO)
	plan._chunk_visual_snapshot(Vector2i.RIGHT)
	expect(
		plan.chunk_visual_builds == 3,
		"a distant edit does not rebuild either side of the visible seam",
	)
	plan.erase_rect(Rect2(384, 24, 24, 24))
	plan._chunk_visual_snapshot(Vector2i.ZERO)
	plan._chunk_visual_snapshot(Vector2i.RIGHT)
	expect(
		plan.chunk_visual_builds == 5,
		"editing the boundary invalidates both adjacent visual snapshots exactly once",
	)
