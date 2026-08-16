extends RefCounted

const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
const TEXTURES := {
	"sack":preload("res://assets/game/world_loot/containers/sack.png"), "trash":preload("res://assets/game/world_loot/containers/trash.png"),
	"chest":preload("res://assets/game/world_loot/containers/chest.png"), "bone_pile":preload("res://assets/game/world_loot/containers/bone_pile.png"),
	"supply_crate":preload("res://assets/game/world_loot/containers/supply_crate.png"), "barrel":preload("res://assets/game/world_loot/containers/barrel.png"),
	"hollow_log":preload("res://assets/game/world_loot/containers/hollow_log.png"), "fairy_cache":preload("res://assets/game/world_loot/containers/fairy_cache.png"),
}
const PROFILES := {
	"sack":{"visual_size":Vector2(72,72),"anchor":"center","collision_size":Vector2(48,24),"collision_offset":Vector2.ZERO},
	"trash":{"visual_size":Vector2(96,72),"anchor":"center","collision_size":Vector2(72,24),"collision_offset":Vector2.ZERO},
	"chest":{"visual_size":Vector2(96,72),"anchor":"center","collision_size":Vector2(72,48),"collision_offset":Vector2.ZERO},
	"bone_pile":{"visual_size":Vector2(96,72),"anchor":"center","collision_size":Vector2(72,24),"collision_offset":Vector2.ZERO},
	"supply_crate":{"visual_size":Vector2(72,72),"anchor":"center","collision_size":Vector2(48,48),"collision_offset":Vector2.ZERO},
	"barrel":{"visual_size":Vector2(72,72),"anchor":"center","collision_size":Vector2(48,48),"collision_offset":Vector2.ZERO},
	"hollow_log":{"visual_size":Vector2(96,72),"anchor":"center","collision_size":Vector2(72,24),"collision_offset":Vector2.ZERO},
	"fairy_cache":{"visual_size":Vector2(72,72),"anchor":"center","collision_size":Vector2(48,48),"collision_offset":Vector2.ZERO},
}


## Преобразует тематический пиратский сундук в общий идентификатор визуального профиля.
static func resolved_kind(kind: String) -> String:
	return "chest" if kind == "pirate_chest" else kind


## Возвращает все зарегистрированные типы мировых контейнеров в стабильном порядке каталога.
static func kinds() -> Array:
	return TEXTURES.keys()


## Возвращает отдельную текстуру контейнера без дробного source-rect.
static func texture(kind: String) -> Texture2D:
	return TEXTURES.get(resolved_kind(kind), TEXTURES.chest) as Texture2D


## Возвращает независимый нормализованный профиль контейнера.
static func profile(kind: String) -> Dictionary:
	return Dictionary(PROFILES.get(resolved_kind(kind), PROFILES.chest)).duplicate(true)


## Возвращает видимую область контейнера через общий пространственный контракт.
static func visual_rect(kind: String, position: Vector2) -> Rect2:
	return WorldVisualProfileSystem.visual_rect_from(profile(kind), position)


## Возвращает физическое основание контейнера через общий пространственный контракт.
static func collision_rect(kind: String, position: Vector2) -> Rect2:
	return WorldVisualProfileSystem.collision_rect_from(profile(kind), position)


## Проверяет текстуры и все профили контейнеров общим валидатором мировой геометрии.
static func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if TEXTURES.size() != 8 or PROFILES.size() != 8:
		errors.append("world_loot: каталог должен содержать восемь контейнеров")
	for kind in PROFILES:
		errors.append_array(WorldVisualProfileSystem.profile_validation_errors("world_loot.%s" % kind, PROFILES[kind]))
		if texture(kind).get_size() != Vector2(PROFILES[kind].visual_size):
			errors.append("world_loot.%s: размер PNG не совпадает с visual_size" % kind)
	return errors
