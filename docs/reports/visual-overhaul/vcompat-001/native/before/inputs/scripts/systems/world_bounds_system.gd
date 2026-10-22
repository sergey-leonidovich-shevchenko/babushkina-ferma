extends RefCounted

const Village := preload("res://scripts/systems/village_map_data.gd")
const DEFAULT_SIZE := Vector2(2400,1200)

## Возвращает размер активной карты, не расширяя пещеры и другие локации вслед за деревней.
static func size(location: String) -> Vector2:
	if location=="cellar_workshop": return Vector2(2400,1560)
	if preload("res://scripts/systems/village_region_data.gd").added(location): return preload("res://scripts/systems/village_region_data.gd").SIZE
	return Village.WORLD_SIZE if location=="overworld" else DEFAULT_SIZE
