extends RefCounted

const SpatialGridSystem := preload("res://scripts/systems/spatial_grid_system.gd")
const BASE_CELL := SpatialGridSystem.BASE_CELL
const VALID_ANCHORS := ["top_left", "center", "bottom_center", "ground_center"]
const PROFILES := {
	"terrain": {"visual_size": Vector2(24, 24), "anchor": "top_left", "collision_size": Vector2.ZERO, "collision_offset": Vector2.ZERO},
	"farm_plot": {"visual_size": Vector2(48, 48), "anchor": "center", "collision_size": Vector2.ZERO, "collision_offset": Vector2.ZERO},
	"bridge": {"visual_size": Vector2(96, 192), "anchor": "center", "collision_size": Vector2(96, 192), "collision_offset": Vector2.ZERO},
	"tree_stump": {"visual_size": Vector2(72, 72), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"tree_sapling": {"visual_size": Vector2(72, 72), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"tree_young": {"visual_size": Vector2(120, 120), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"tree_flowering": {"visual_size": Vector2(168, 168), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"tree_adult": {"visual_size": Vector2(192, 192), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"resource_node": {"visual_size": Vector2(72, 72), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"cave_cluster": {"visual_size": Vector2(120, 96), "anchor": "center", "collision_size": Vector2(96, 72), "collision_offset": Vector2.ZERO},
	"cave_rock": {"visual_size": Vector2(48, 48), "anchor": "bottom_center", "collision_size": Vector2.ZERO, "collision_offset": Vector2.ZERO},
	"cave_crystal": {"visual_size": Vector2(72, 72), "anchor": "bottom_center", "collision_size": Vector2.ZERO, "collision_offset": Vector2.ZERO},
	"forage_patch": {"visual_size": Vector2(48, 48), "anchor": "bottom_center", "collision_size": Vector2(24, 24), "collision_offset": Vector2(0, -24)},
	"forage_crop": {"visual_size": Vector2(72, 72), "anchor": "bottom_center", "collision_size": Vector2(24, 24), "collision_offset": Vector2(0, -24)},
	"forage_tree": {"visual_size": Vector2(120, 120), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"village_ambient": {"visual_size": Vector2(72, 72), "anchor": "bottom_center", "collision_size": Vector2.ZERO, "collision_offset": Vector2.ZERO},
	"village_well": {"visual_size": Vector2(120, 120), "anchor": "bottom_center", "collision_size": Vector2(72, 48), "collision_offset": Vector2(0, -24)},
	"village_bench": {"visual_size": Vector2(96, 72), "anchor": "bottom_center", "collision_size": Vector2(72, 24), "collision_offset": Vector2(0, -12)},
	"village_lamp": {"visual_size": Vector2(48, 120), "anchor": "bottom_center", "collision_size": Vector2(24, 24), "collision_offset": Vector2(0, -12)},
	"village_board": {"visual_size": Vector2(120, 96), "anchor": "bottom_center", "collision_size": Vector2(72, 24), "collision_offset": Vector2(0, -12)},
	"village_cart": {"visual_size": Vector2(120, 96), "anchor": "bottom_center", "collision_size": Vector2(96, 48), "collision_offset": Vector2(0, -24)},
	"village_fence": {"visual_size": Vector2(72, 72), "anchor": "bottom_center", "collision_size": Vector2(48, 24), "collision_offset": Vector2(0, -12)},
	"village_gate": {"visual_size": Vector2(96, 72), "anchor": "bottom_center", "collision_size": Vector2(72, 24), "collision_offset": Vector2(0, -12)},
	"village_mill": {"visual_size": Vector2(288, 240), "anchor": "bottom_center", "collision_size": Vector2(192, 72), "collision_offset": Vector2(0, -36)},
	"fence_section": {"visual_size": Vector2(48, 48), "anchor": "center", "collision_size": Vector2(24, 24), "collision_offset": Vector2.ZERO},
	"fence_gate": {"visual_size": Vector2(72, 72), "anchor": "center", "collision_size": Vector2(48, 24), "collision_offset": Vector2.ZERO},
	"hero": {"visual_size": Vector2(72, 96), "anchor": "bottom_center", "collision_size": Vector2(48, 24), "collision_offset": Vector2(0, -12)},
	"resident": {"visual_size": Vector2(96, 96), "anchor": "bottom_center", "collision_size": Vector2(48, 24), "collision_offset": Vector2(0, -12)},
	"animal": {"visual_size": Vector2(96, 96), "anchor": "bottom_center", "collision_size": Vector2(48, 24), "collision_offset": Vector2(0, -12)},
	"enemy_common": {"visual_size": Vector2(96, 96), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"enemy_veteran": {"visual_size": Vector2(120, 120), "anchor": "bottom_center", "collision_size": Vector2(48, 48), "collision_offset": Vector2(0, -24)},
	"enemy_elite": {"visual_size": Vector2(144, 144), "anchor": "bottom_center", "collision_size": Vector2(72, 48), "collision_offset": Vector2(0, -24)},
	"story_slime": {"visual_size": Vector2(72, 72), "anchor": "ground_center", "anchor_ratio": 0.72, "collision_size": Vector2(48, 24), "collision_offset": Vector2(0, -12)},
}


## Возвращает независимую копию визуального профиля, чтобы renderer не мог изменить общий стандарт.
static func profile(profile_id: String) -> Dictionary:
	return Dictionary(PROFILES.get(profile_id, {})).duplicate(true)


## Возвращает утверждённый размер изображения либо нулевой размер для неизвестного семейства.
static func visual_size(profile_id: String) -> Vector2:
	return Vector2(PROFILES.get(profile_id, {}).get("visual_size", Vector2.ZERO))


## Строит мировой прямоугольник изображения относительно заявленной точки привязки.
static func visual_rect(profile_id: String, anchor_position: Vector2) -> Rect2:
	return visual_rect_from(profile(profile_id), anchor_position)


## Строит прямоугольник коллизии из того же профиля и той же мировой точки привязки.
static func collision_rect(profile_id: String, anchor_position: Vector2) -> Rect2:
	return collision_rect_from(profile(profile_id), anchor_position)


## Нормализует профиль подсистемы к общим ключам размеров, привязки и коллизии.
static func normalized_profile(data: Dictionary, visual_key: String = "visual_size", collision_key: String = "collision_size", default_anchor: String = "bottom_center") -> Dictionary:
	return {
		"visual_size":Vector2(data.get(visual_key, Vector2.ZERO)),
		"anchor":String(data.get("anchor", default_anchor)),
		"anchor_ratio":float(data.get("anchor_ratio", data.get("pivot_y", 1.0))),
		"collision_size":Vector2(data.get(collision_key, Vector2.ZERO)),
		"collision_offset":Vector2(data.get("collision_offset", Vector2.ZERO)),
	}


## Строит видимый мировой прямоугольник для любого нормализованного профиля.
static func visual_rect_from(data: Dictionary, anchor_position: Vector2) -> Rect2:
	var size := Vector2(data.get("visual_size", Vector2.ZERO))
	match String(data.get("anchor", "top_left")):
		"center": return Rect2(anchor_position - size * 0.5, size)
		"bottom_center": return Rect2(anchor_position - Vector2(size.x * 0.5, size.y), size)
		"ground_center": return Rect2(anchor_position - size * Vector2(0.5, float(data.get("anchor_ratio", 1.0))), size)
		_: return Rect2(anchor_position, size)


## Строит физическое основание для любого нормализованного профиля.
static func collision_rect_from(data: Dictionary, anchor_position: Vector2) -> Rect2:
	var size := Vector2(data.get("collision_size", Vector2.ZERO))
	var center := anchor_position + Vector2(data.get("collision_offset", Vector2.ZERO))
	return Rect2(center - size * 0.5, size)


## Проверяет один нормализованный профиль и возвращает точные нарушения пространственного контракта.
static func profile_validation_errors(profile_id: String, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var size := Vector2(data.get("visual_size", Vector2.ZERO))
	var collision := Vector2(data.get("collision_size", Vector2.ZERO))
	if size.x <= 0 or size.y <= 0 or fmod(size.x, BASE_CELL) != 0 or fmod(size.y, BASE_CELL) != 0:
		errors.append("%s: visual_size не кратен %d" % [profile_id, BASE_CELL])
	if not VALID_ANCHORS.has(String(data.get("anchor", ""))):
		errors.append("%s: неизвестная точка привязки" % profile_id)
	if collision.x < 0 or collision.y < 0 or fmod(collision.x, BASE_CELL) != 0 or fmod(collision.y, BASE_CELL) != 0:
		errors.append("%s: collision_size не кратен %d" % [profile_id, BASE_CELL])
	return errors


## Проверяет кратность размеров базовой сетке, допустимые anchors и непротиворечивость коллизий.
static func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	for profile_id in PROFILES:
		errors.append_array(profile_validation_errors(profile_id, PROFILES[profile_id]))
	return errors
