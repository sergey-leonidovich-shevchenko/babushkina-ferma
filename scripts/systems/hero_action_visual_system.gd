extends RefCounted

const ROOT := "res://assets/game/characters/hero_v3/actions_v2/"
const Actions := preload("res://scripts/systems/hero_action_system.gd")
const TOOLS := {"mine":"pickaxe","chop":"axe","water":"watering","fish_cast":"fishing"}
const WEAPONS := {"war_hammer":"hammer","moon_staff":"staff","axe":"axe"}
static var _catalog: Dictionary = {}
static var _textures: Dictionary = {}

## Читает измеренные ботинки и независимые кадры инструментов без загрузки больших исходников.
static func catalog() -> Dictionary:
	if _catalog.is_empty(): _catalog = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"frames.json"))
	return _catalog

## Кэширует готовый прозрачный кадр в его экранном размере.
static func frame_texture(kind: String, index: int) -> Texture2D:
	var key := kind+":"+str(index)
	if not _textures.has(key): _textures[key] = load(ROOT+catalog()[kind].frames[index].sprite)
	return _textures[key]

## Разделяет подготовку, замах, контакт или выпуск магии и спокойное возвращение инструмента.
static func frame(progress: float, kind: String) -> int:
	if progress < 0.18: return 0
	if progress < (0.62 if kind == "staff" else 0.43): return 1
	if progress < (0.78 if kind == "staff" else 0.72): return 2
	return 3

## Возвращает полное тело с реальной опорой ботинок, включая выступающий ниже стоп инструмент.
static func pose(kind: String, direction: Vector2, progress: float) -> Dictionary:
	var row := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP].find(Actions.cardinal(direction))
	var column := frame(progress,kind)
	var index := row*4+column
	var value: Dictionary = catalog()[kind].frames[index]
	var sprite := frame_texture(kind,index)
	return {"texture":sprite,"source":Rect2(Vector2.ZERO,sprite.get_size()),"pivot":Vector2(value.draw_pivot[0],value.draw_pivot[1]),"scale":1.0,"kind":kind,"frame":column,"preserve_alpha":true,"full_body_action":true}

## Сообщает рендереру, что атакующее оружие уже нарисовано в руках героя.
static func combat_active(game: Node) -> bool:
	return game.WeaponSystem.attack_progress(game) >= 0.0 and WEAPONS.has(game.player_attack_weapon)

## Выбирает снимок направления удара либо успешного действия инструмента, сохраняя приоритет боя.
static func current_pose(game: Node) -> Dictionary:
	if combat_active(game): return pose(WEAPONS[game.player_attack_weapon],game.get_meta("attack_visual_direction",Actions.cardinal(game.facing)),game.WeaponSystem.attack_progress(game))
	if game.WeaponSystem.attack_progress(game) >= 0.0: return {}
	var fishing_phase := String(game.state.fishing.phase)
	var fishing_direction: Vector2 = game.get_meta("fish_visual_direction",Actions.cardinal(game.facing))
	if fishing_phase == "charging": return pose("fishing",fishing_direction,0.3)
	var action := Actions.pose(game)
	var kind := String(TOOLS.get(action.get("action",""),""))
	if not kind.is_empty(): return pose(kind,action.direction,Actions.progress(game))
	if fishing_phase in ["waiting","bite","minigame"]: return pose("fishing",fishing_direction,0.95)
	return {}

## Загружает малые игровые кадры до первого замаха, оставляя мастер-листы в документации.
static func warmup() -> void:
	for kind in catalog():
		for index in 16: frame_texture(kind,index)

## Привязывает настоящую леску к измеренному концу удочки в спокойной позе ожидания поклёвки.
static func fishing_line_origin(game: Node) -> Vector2:
	var direction: Vector2 = game.get_meta("fish_visual_direction",Actions.cardinal(game.facing))
	var row := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP].find(Actions.cardinal(direction))
	var entry: Dictionary = catalog().fishing.frames[row*4+3]
	return game.player+Vector2(entry.draw_tip[0],entry.draw_tip[1])-Vector2(entry.draw_pivot[0],entry.draw_pivot[1])
