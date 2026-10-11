extends RefCounted

const HeroActionSystem := preload("res://scripts/systems/hero_action_system.gd")
const SpriteMatteSystem := preload("res://scripts/systems/sprite_matte_system.gd")
const WALK_MASTER := preload("res://assets/game/characters/hero_v3/walk_master.png")
const HOE_MASTER := preload("res://assets/game/characters/hero_v3/hoe_master.png")
const DRAW_SCALE := 0.32
const WALK_COLUMNS := [44, 336, 628, 920]
const WALK_BASELINES := [289, 291, 291, 289]
const FRAME_SIZE := Vector2(300, 300)
const WALK_FPS := 8.0
const HOE_BOUNDS := [
	[Rect2(104,37,168,245), Rect2(418,22,108,261), Rect2(661,96,172,209), Rect2(941,36,166,245)],
	[Rect2(107,348,169,235), Rect2(403,315,118,270), Rect2(622,399,227,197), Rect2(937,343,168,239)],
	[Rect2(148,636,165,238), Rect2(428,606,111,268), Rect2(684,686,226,202), Rect2(983,634,166,240)],
	[Rect2(151,922,170,234), Rect2(425,889,103,272), Rect2(684,939,147,212), Rect2(994,922,165,234)],
]
const HOE_FEET := [
	[Vector2(216,282), Vector2(467,283), Vector2(765,282), Vector2(1052,281)],
	[Vector2(217,583), Vector2(454,585), Vector2(785,581), Vector2(1046,582)],
	[Vector2(204,874), Vector2(488,874), Vector2(746,871), Vector2(1042,874)],
	[Vector2(206,1156), Vector2(479,1159), Vector2(744,1151), Vector2(1047,1156)],
]


## Преобразует направление в четыре фактические строки нового листа: вниз, влево, вправо, вверх.
static func direction_row(direction: Vector2) -> int:
	var cardinal := HeroActionSystem.cardinal(direction)
	return [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP].find(cardinal)


## Возвращает измеренный кадр, не деля весь мастер на дробные одинаковые ячейки.
static func source_rect(direction: Vector2, time: float, moving: bool) -> Rect2:
	var frame := int(maxf(time, 0.0) * WALK_FPS) % 4 if moving else 1
	return Rect2(WALK_COLUMNS[frame], direction_row(direction) * 300, FRAME_SIZE.x, FRAME_SIZE.y)


## Описывает кадр и постоянную точку стоп без подгонки масштаба под размер каждой отдельной позы.
static func walk_pose(direction: Vector2, time: float, moving: bool) -> Dictionary:
	var row := direction_row(direction)
	return {"texture":WALK_MASTER, "source":source_rect(direction, time, moving), "pivot":Vector2(150, WALK_BASELINES[row]), "scale":DRAW_SCALE}


## Выбирает настоящий нарисованный замах мотыги; точка между ботинками измерена отдельно от выступающего инструмента.
static func hoe_pose(direction: Vector2, progress_value: float) -> Dictionary:
	var row := direction_row(direction)
	var frame := HeroActionSystem.frame(progress_value)
	var source: Rect2 = HOE_BOUNDS[row][frame].grow(8)
	return {"texture":HOE_MASTER, "source":source, "pivot":Vector2(HOE_FEET[row][frame]) - source.position, "scale":DRAW_SCALE}


## Строит мировой прямоугольник от точки стоп, совпадающей с физической позицией героя.
static func destination(ground: Vector2, frame: Dictionary) -> Rect2:
	var scale_value := float(frame.scale)
	return Rect2(ground - Vector2(frame.pivot) * scale_value, Rect2(frame.source).size * scale_value)


## Рисует только тело героя; смена ракурса и анимации никогда не масштабирует физический мир.
static func draw_actor(game: Node2D, ground: Vector2, direction: Vector2, moving: bool, tint: Color) -> void:
	var pose := current_pose(game, direction, moving)
	var action := HeroActionSystem.pose(game)
	game.DirectionalCharacterSystem.draw_soft_shadow(game, ground, Vector2(15, 5))
	if not action.is_empty() and action.action != "hoe" and direction == Vector2.UP: draw_tool(game, ground, action)
	draw_pose(game, ground, pose, tint)
	if not action.is_empty() and action.action != "hoe" and direction != Vector2.UP: draw_tool(game, ground, action)


## Даёт отрисовке и инспектору один источник текущей позы и её фактических границ.
static func current_pose(game: Node, direction: Vector2, moving: bool) -> Dictionary:
	var action := HeroActionSystem.pose(game)
	if String(action.get("action", "")) == "hoe": return hoe_pose(action.direction, HeroActionSystem.progress(game))
	return walk_pose(direction, game.PlayerSystem.visual_animation_time(game, moving), moving)


## Привязывает остальные инструменты к рукам и сохранённому ракурсу, не рисуя дубликат тела отдельным эффектом.
static func draw_tool(game: Node2D, ground: Vector2, action: Dictionary) -> void:
	var item := String({"mine":"pickaxe", "chop":"axe", "water":"water", "plant":"seeds", "fish_cast":"fishing_rod"}.get(action.action, "hand"))
	var texture: Texture2D = game.item_texture(item)
	if texture == null: return
	var direction: Vector2 = action.direction
	var progress_value := HeroActionSystem.progress(game)
	var lift := sin(smoothstep(0.0, 0.43, progress_value) * PI) * 16.0
	var hand := ground + Vector2(direction.x * 15.0, -30.0 - lift) + Vector2(0, direction.y * 7.0)
	var rotation := direction.angle() + PI * 0.25
	if item in ["pickaxe", "axe"]: rotation += lerpf(-1.6, 0.45, smoothstep(0.18, 0.66, progress_value))
	elif item in ["water", "seeds", "hand"]: rotation = -0.3 if direction.x < 0.0 else 0.3
	var world: Vector2 = game.PresentationSystem.world_offset(game)
	game.draw_set_transform(world + hand, rotation, Vector2.ONE)
	game.draw_texture_rect(texture, Rect2(-10, -30, 36, 36), false)
	game.draw_set_transform(world, 0.0, Vector2.ONE)


## Выводит один production-кадр с локальной очисткой служебного края и общей геометрией preview/runtime.
static func draw_pose(canvas: CanvasItem, ground: Vector2, frame: Dictionary, tint: Color = Color.WHITE) -> void:
	var texture := SpriteMatteSystem.clean_texture(frame.texture)
	canvas.draw_texture_rect_region(texture, destination(ground, frame), frame.source, tint)


## Рисует новый реальный облик в HUD и окне персонажа с сохранением пропорций, без старых восьминаправленных скинов.
static func draw_portrait(canvas: CanvasItem, rect: Rect2, bust: bool = false) -> void:
	var source := Rect2(428, 32, 134, 162) if bust else source_rect(Vector2.DOWN, 0.0, false)
	var scale_value := minf(rect.size.x / source.size.x, rect.size.y / source.size.y)
	var size := source.size * scale_value
	canvas.draw_texture_rect_region(SpriteMatteSystem.clean_texture(WALK_MASTER), Rect2(rect.get_center() - size * 0.5, size), source)


## Проверяет четыре направления и безопасные границы измеренных источников, а не только размер PNG.
static func profiles_are_valid() -> bool:
	var bounds := Rect2(Vector2.ZERO, WALK_MASTER.get_size())
	for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		for frame in 4:
			if not bounds.encloses(source_rect(direction, frame / WALK_FPS, true)): return false
			if not Rect2(Vector2.ZERO, HOE_MASTER.get_size()).encloses(Rect2(HOE_BOUNDS[direction_row(direction)][frame]).grow(8)): return false
	return WALK_MASTER.get_size() == Vector2(1254, 1254) and HOE_MASTER.get_size() == Vector2(1281, 1228)


## Подготавливает опциональную очистку двух мастер-листов до начала управляемого игрового кадра.
static func warmup() -> void:
	SpriteMatteSystem.clean_texture(WALK_MASTER)
	SpriteMatteSystem.clean_texture(HOE_MASTER)
