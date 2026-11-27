extends SceneTree

const FlowerGroups := preload("res://tools/qa/performance/decor_batching/flower_groups.gd")
const CandidateCover := preload("res://tools/qa/performance/decor_batching/candidate_cover.gd")
const CASES := {
	"full_rebuild": Rect2(0, 0, 2400, 1368),
	"flower_crossing_cell": Rect2(468, 528, 24, 72),
	"three_flowers": Rect2(480, 520, 384, 144),
	"empty_patch": Rect2(2088, 1200, 144, 96),
	"home_view": Rect2(0, 402, 960, 540),
	"west_bridge_view": Rect2(384, 186, 960, 540),
	"village_square_view": Rect2(648, 474, 960, 540),
	"east_view": Rect2(1440, 385, 960, 540),
	"north_view": Rect2(648, 0, 960, 540),
}


## Проверяет геометрию существующих цветов без экземпляра игрового мира.
func _initialize() -> void:
	var full := FlowerGroups.build(false)
	var grouped := FlowerGroups.build(true)
	if not _batches_match(full, false) or not _batches_match(grouped, true):
		push_error("Prepared MultiMesh geometry differs from the flower group plan")
		quit(2)
		return
	var rects: Array[Rect2] = full[0].rects
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				push_error("Static flowers overlap and need their original draw order")
				quit(2)
				return
	var report := {"scope": "offline_geometry", "branches": {}}
	for label: String in CASES:
		var clip: Rect2 = CASES[label]
		var original := FlowerGroups.counts(full, clip)
		var spatial := FlowerGroups.counts(grouped, clip)
		if original.visible != spatial.visible:
			push_error("Grouped geometry omitted a flower in " + label)
			quit(2)
			return
		report.branches[label] = {"one_batch": original, "spatial_batches": spatial}
	print(JSON.stringify(report))
	quit()


## Проверяет назначенную текстуру, число экземпляров и фазу узла на реальном ресурсе Godot.
static func _batches_match(groups: Array[Dictionary], spatial: bool) -> bool:
	var layer := CandidateCover.new()
	layer.prepare(spatial)
	var matches := layer.get_child_count() == groups.size()
	for index in layer.get_child_count():
		var batch := layer.get_child(index) as MultiMeshInstance2D
		var group: Dictionary = groups[index]
		var rects: Array[Rect2] = group.rects
		matches = (
			matches
			and batch != null
			and batch.show_behind_parent
			and batch.texture == FlowerGroups.Ambient.ATLAS
			and batch.multimesh.instance_count == rects.size()
		)
	layer.free()
	return matches
