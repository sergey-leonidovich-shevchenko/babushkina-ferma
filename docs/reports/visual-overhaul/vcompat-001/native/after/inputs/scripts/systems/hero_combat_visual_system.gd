extends RefCounted

const ROOT := "res://assets/game/characters/hero_v3/combat_v1/"
const Actions := preload("res://scripts/systems/hero_action_system.gd")
static var _frames: Dictionary = {}
static var _textures: Dictionary = {}

## Читает измеренные границы и стопы реальных фаз тела без деления нерегулярного мастера на сетку.
static func catalog() -> Dictionary:
	if _frames.is_empty(): _frames = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"frames.json"))
	return _frames

## Повторно использует исходный RGBA-мастер, сохраняя рисунок и прозрачность генерации.
static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind): _textures[kind] = load(ROOT+kind+".png")
	return _textures[kind]

## Загружает только нарезанный кадр; большие мастер-листы остаются исходниками и не занимают память обычного боя.
static func frame_texture(kind: String, index: int) -> Texture2D:
	var key := kind+":"+str(index)
	if not _textures.has(key): _textures[key] = load(ROOT+catalog()[kind].frames[index].sprite)
	return _textures[key]

## Выделяет классы с нарисованными фазами, чтобы поверх них не появлялся второй предмет в руке.
static func active(game: Node) -> bool:
	return game.WeaponSystem.attack_progress(game) >= 0 and game.player_attack_weapon in ["forest_sword","iron_spear","bow"]

## Удерживает подготовку, полный замах, контакт и возвращение в стойку на временной шкале оружия.
static func frame(progress: float, kind: String) -> int:
	if progress < 0.18: return 0
	if progress < (0.62 if kind == "bow" else 0.43): return 1
	if progress < (0.78 if kind == "bow" else 0.72): return 2
	return 3

## Собирает один кадр относительно измеренной точки стоп; два боковых кадра лука исправлены отдельным рисунком.
static func pose(kind: String, direction: Vector2, progress: float) -> Dictionary:
	var row := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP].find(Actions.cardinal(direction))
	var column := frame(progress,kind)
	var key := kind
	var flip := false
	var index := row*4+column
	if kind == "bow" and row in [1,2] and column >= 2:
		key = "bow-contact"; index = column-2; flip = row == 1
	var value: Dictionary = catalog()[key].frames[index]
	var sprite := frame_texture(key,index)
	var source := Rect2(Vector2.ZERO,sprite.get_size())
	var pivot := Vector2(value.draw_pivot[0],value.draw_pivot[1])
	if flip: pivot.x = source.size.x-pivot.x
	return {"texture":sprite,"source":source,"pivot":pivot,"scale":float(value.draw_scale),"flip":flip,"kind":kind,"frame":column,"preserve_alpha":true}

## Возвращает кадр удара по сохранённому ракурсу даже после поворота или смены экипировки.
static func current_pose(game: Node) -> Dictionary:
	if not active(game): return {}
	return pose(game.WeaponSystem.weapon_class(game.player_attack_weapon),game.get_meta("attack_visual_direction",Actions.cardinal(game.facing)),game.WeaponSystem.attack_progress(game))

## Прогревает прозрачные листы заранее, чтобы первый удар не запускал обработку matte в боевом кадре.
static func warmup() -> void:
	for key in catalog():
		for index in catalog()[key].frames.size(): frame_texture(key,index)
