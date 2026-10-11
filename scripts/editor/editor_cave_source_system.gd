extends RefCounted

const Assets := preload("res://scripts/systems/cave_asset_system.gd")


## Передаёт редактору тот же размер, нижнюю опору и основание, что используют пещерные объекты в игре.
static func profile(path: String) -> Dictionary:
	if not path.begins_with("res://assets/game/locations/cave/modular/"): return {}
	if path == Assets.floor_texture().resource_path:
		return {"category": "terrain", "anchor": "tile", "layer": "ground", "collision": false, "display_size": Vector2(24,24), "surface_kind": "stone"}
	for kind in Assets.CATALOG:
		if Assets.texture(kind).resource_path != path: continue
		var data := Assets.profile(kind)
		return {"category": "decor", "anchor": "bottom", "layer": "objects", "slice_size": 0, "frame_count": 1, "sliced": false, "display_size": data.visual_size, "collision": Vector2(data.collision_size) != Vector2.ZERO, "collision_size": data.collision_size, "collision_offset": Vector2(data.collision_offset) + Vector2(0, data.visual_size.y * 0.5)}
	return {}
