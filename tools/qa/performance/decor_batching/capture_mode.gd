extends RefCounted

const Candidate := preload("res://tools/qa/performance/decor_batching/candidate_cover.gd")
const Background := preload("res://scripts/world_background.gd")
const VARIANTS := ["baseline", "one_batch", "spatial_batches"]


## Устанавливает вариант только в тестовой сцене и оставляет штатный кеш владельцем слоя.
static func install(background: Background, variant: String) -> void:
	if variant != "baseline":
		var cover := background.cover_layer
		cover.set_script(Candidate)
		var candidate := cover as Candidate
		candidate.prepare(variant == "spatial_batches")
	background.refresh_terrain()


## Сохраняет счётчики реальных обновлений независимо от частоты кадров окна.
static func terrain(background: Background) -> Dictionary:
	var revision := background.terrain_revision
	return {
		"requests": background.terrain_requests,
		"revision": revision.revision,
		"full_paints": revision.full_paints,
		"local_paints": revision.local_paints,
		"last_completed": region(revision.last_completed),
	}


static func region(rect: Rect2) -> Array:
	return [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)]


static func preset(background: Background) -> Dictionary:
	return {
		"ground_split": background.ground_split,
		"local_terrain_updates": background.local_terrain_updates,
		"painted_grass": background.painted_grass,
		"soft_ground_edges": background.soft_ground_edges,
		"rectangular_roads": background.rectangular_roads,
		"joined_roads": background.joined_roads,
		"split_bridge_rails": background.split_bridge_rails,
		"water_bottom_trim_decks": background.water_layer.trim_decks,
		"water_surface_trim_decks": background.water_surface.trim_decks,
		"window_mode": DisplayServer.window_get_mode(),
	}


static func installed(background: Background, variant: String) -> bool:
	if variant == "baseline":
		return not background.cover_layer is Candidate
	var expected := 1 if variant == "one_batch" else 10
	return batch_count(background) == expected


## Считает реальные MultiMesh-узлы, установленные в тестовой сцене.
static func batch_count(background: Background) -> int:
	var cover := background.cover_layer
	return cover.get_child_count() if cover is Candidate else 0
