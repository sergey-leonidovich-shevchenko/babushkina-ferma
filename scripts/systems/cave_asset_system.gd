extends RefCounted

const Profiles := preload("res://scripts/systems/world_visual_profile_system.gd")
const FLOOR := preload("res://assets/game/locations/cave/modular/floor_v1.png")
const CATALOG := {
	"wall_straight_a": {"profile": "cave_wall", "texture": preload("res://assets/game/locations/cave/modular/wall_straight_a_v1.png")},
	"wall_straight_b": {"profile": "cave_wall", "texture": preload("res://assets/game/locations/cave/modular/wall_straight_b_v1.png")},
	"wall_side_right": {"profile": "cave_side_wall", "texture": preload("res://assets/game/locations/cave/modular/wall_side_right_v1.png")},
	"wall_side_left": {"profile": "cave_side_wall", "texture": preload("res://assets/game/locations/cave/modular/wall_side_left_v1.png")},
	"wall_rim": {"profile": "cave_rim", "texture": preload("res://assets/game/locations/cave/modular/wall_rim_v1.png")},
	"corner_left": {"profile": "cave_corner", "texture": preload("res://assets/game/locations/cave/modular/corner_left_v1.png")},
	"corner_right": {"profile": "cave_corner", "texture": preload("res://assets/game/locations/cave/modular/corner_right_v1.png")},
	"corner_inner": {"profile": "cave_corner", "texture": preload("res://assets/game/locations/cave/modular/corner_inner_v1.png")},
	"wall_end": {"profile": "cave_corner", "texture": preload("res://assets/game/locations/cave/modular/wall_end_v1.png")},
	"entrance": {"profile": "cave_door", "texture": preload("res://assets/game/locations/cave/modular/entrance_v1.png")},
	"crystal_blue": {"profile": "cave_vein", "texture": preload("res://assets/game/locations/cave/modular/crystal_blue_v1.png")},
	"crystal_green": {"profile": "cave_vein", "texture": preload("res://assets/game/locations/cave/modular/crystal_green_v1.png")},
	"crystal_red": {"profile": "cave_vein", "texture": preload("res://assets/game/locations/cave/modular/crystal_red_v1.png")},
	"ore_metal": {"profile": "cave_vein", "texture": preload("res://assets/game/locations/cave/modular/ore_metal_v1.png")},
	"boulder": {"profile": "cave_boulder", "texture": preload("res://assets/game/locations/cave/modular/boulder_v1.png")},
	"stalagmites": {"profile": "cave_stalagmite", "texture": preload("res://assets/game/locations/cave/modular/stalagmites_v1.png")},
	"rubble": {"profile": "cave_rubble", "texture": preload("res://assets/game/locations/cave/modular/rubble_v1.png")},
	"mushrooms": {"profile": "cave_mushroom", "texture": preload("res://assets/game/locations/cave/modular/mushrooms_v1.png")},
	"torch": {"profile": "cave_torch", "texture": preload("res://assets/game/locations/cave/modular/torch_v1.png")},
	"crystal_fragments": {"profile": "cave_fragments", "texture": preload("res://assets/game/locations/cave/modular/crystal_fragments_v1.png")},
}
const RESOURCE_ART := {"stone": "boulder", "crystal": "crystal_blue", "green_crystal": "crystal_green", "red_crystal": "crystal_red", "metal": "ore_metal"}


## Возвращает самостоятельный прозрачный спрайт из согласованного набора пещеры.
static func texture(kind: String) -> Texture2D:
	return CATALOG.get(kind, {}).get("texture") as Texture2D


## Возвращает спокойное повторяемое покрытие пола без запечённых стен и объектов.
static func floor_texture() -> Texture2D:
	return FLOOR


## Возвращает общий пространственный профиль выбранного элемента без локальных размеров в renderer.
static func profile(kind: String) -> Dictionary:
	return Profiles.profile(String(CATALOG.get(kind, {}).get("profile", "")))


## Строит прямоугольник спрайта относительно его нижней опоры на земле.
static func destination_rect(kind: String, ground: Vector2) -> Rect2:
	return Profiles.visual_rect_from(profile(kind), ground)


## Строит основание элемента из того же каталога, который использует его изображение.
static func collision_rect(kind: String, ground: Vector2) -> Rect2:
	return Profiles.collision_rect_from(profile(kind), ground)


## Сопоставляет добываемый материал отдельному рисунку жилы без перекрашивания одного кристалла.
static func resource_art(kind: String) -> String:
	return String(RESOURCE_ART.get(kind, "boulder"))


## Проверяет разрешение, прозрачность и модульную геометрию каждого независимого PNG.
static func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	for kind in CATALOG:
		var data := profile(kind)
		errors.append_array(Profiles.profile_validation_errors(kind, data))
		var sprite := texture(kind)
		if sprite == null or sprite.get_size() != Vector2(data.visual_size) * 2.0:
			errors.append("%s: размер PNG не соответствует двойному размеру профиля" % kind)
	return errors
