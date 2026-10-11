extends RefCounted

const WildlifeVisuals := preload("res://scripts/systems/wildlife_visual_system.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
const HERO_WALK := "res://assets/game/characters/hero_v3/walk_master.png"
const HERO_HOE := "res://assets/game/characters/hero_v3/hoe_master.png"
const GRANDMOTHER := "res://assets/game/characters/grandmother_v2/walk_master.png"
const GrandmotherVisual := preload("res://scripts/systems/grandmother_visual_system.gd")
const ANIMAL_MASTERS := ["fox_walk_4dir_v2.png", "bat_flight_4dir_v2.png", "lizard_walk_4dir_v2.png"]


## Явно отмечает неровные мастер-листы, которым запрещена автоматическая нарезка по 128 или 222 пикселя.
static func handles(path: String) -> bool:
	return path in [HERO_WALK, HERO_HOE, GRANDMOTHER] or path.get_file() in ANIMAL_MASTERS


## Возвращает истинный первый кадр и мировой масштаб, не превращая весь лист в один декоративный объект.
static func profile(path: String) -> Dictionary:
	if path == GRANDMOTHER:
		var frame := GrandmotherVisual.pose(Vector2.DOWN, 0.0, false)
		var source: Rect2 = frame.source
		return {"source_rect":source, "display_size":source.size*GrandmotherVisual.DRAW_SCALE, "slice_size":0, "frame_count":1, "sliced":true, "unique_key":"npc:grandmother", "name":"Бабушка · новый облик", "collision":false}
	if path in [HERO_WALK, HERO_HOE]:
		var source := Rect2(336, 0, 300, 300) if path == HERO_WALK else Rect2(96, 29, 184, 261)
		return {"source_rect": source, "display_size": source.size * 0.32, "slice_size": 0, "frame_count": 1, "sliced": true, "unique_key": "hero:player", "runtime_role": "spawn", "name": "Герой · точка появления", "entity_template": true, "collision": false}
	if path.get_file() not in ANIMAL_MASTERS: return {}
	var kind := "fox" if path.get_file() == ANIMAL_MASTERS[0] else ("bat" if path.get_file() == ANIMAL_MASTERS[1] else "lizard")
	var areas := {"fox": Rect2i(0, 0, 328, 350), "bat": Rect2i(0, 0, 314, 305), "lizard": Rect2i(0, 0, 332, 334)}
	var texture := Matte.clean_texture(WildlifeVisuals.NEW_SHEETS[kind])
	var source := Rect2(WildlifeVisuals.visible_bounds(texture, areas[kind]))
	return {"source_rect": source, "display_size": source.size * (0.23 if kind == "bat" else 0.245), "slice_size": 0, "frame_count": 1, "sliced": true}


## Предлагает явные единичные шаблоны героя и бабушки; их полные мастер-листы нельзя случайно поставить на карту.
static func template_paths(root: String) -> Array[String]:
	var result: Array[String] = []
	for path in [HERO_WALK, GRANDMOTHER]:
		if path.begins_with(root.trim_suffix("/") + "/") and ResourceLoader.exists(path): result.append(path)
	return result


## Использует одинаковое удаление внешнего matte у миниатюры, кисти и настоящего персонажа.
static func texture(path: String, original: Texture2D) -> Texture2D:
	if path == GRANDMOTHER: return GrandmotherVisual.texture()
	return Matte.clean_texture(original) if handles(path) else original
