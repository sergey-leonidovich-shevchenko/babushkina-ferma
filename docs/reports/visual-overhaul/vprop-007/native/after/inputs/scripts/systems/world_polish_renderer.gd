extends RefCounted

const ATLAS := preload("res://assets/game/world_polish/village_polish_atlas.png")
const CELL := Vector2(128, 128)
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
static var _event_cells: Dictionary = {}


## Возвращает область одной ячейки строгого атласа 5×4.
static func source(column: int, row: int) -> Rect2:
	return Rect2(Vector2(column, row) * CELL, CELL)


## Рисует одну прозрачную ячейку атласа в указанном мировом прямоугольнике.
static func draw_cell(canvas: Node2D, column: int, row: int, destination: Rect2, modulate: Color = Color.WHITE) -> void:
	if row==1 and column in [0,1,2]:
		canvas.draw_texture_rect(event_texture(column),destination,false,modulate); return
	canvas.draw_texture_rect_region(ATLAS, destination, source(column, row), modulate)

## Очищает только внешние служебные края ярмарки, праздничного стола и телеги, сохраняя исходный атлас и эффекты.
static func event_texture(column: int) -> Texture2D:
	if not _event_cells.has(column):
		var image := ATLAS.get_image().get_region(Rect2i(source(column,1)))
		_event_cells[column]=ImageTexture.create_from_image(Matte.clean_image(image,true))
	return _event_cells[column]

## Подготавливает три малые текстуры событий до первого игрового кадра.
static func warmup_events() -> void:
	for column in 3: event_texture(column)


## Рисует оружие у ведущей руки только во время атаки, не оставляя предмет рядом с обычной ходьбой.
static func draw_held_weapon(game: Node2D, kind: String, position: Vector2, direction: Vector2, attack_progress, visual_scale: float = 1.0) -> void:
	var progress: float = -1.0 if attack_progress is bool and not attack_progress else (0.5 if attack_progress is bool else float(attack_progress))
	if progress<0.0: return
	var item_kind: String = game.WeaponSystem.item_kind(kind)
	if item_kind.is_empty(): return
	var texture: Texture2D = game.item_texture(item_kind)
	if texture == null: return
	var weapon_class: String = game.WeaponSystem.weapon_class(kind)
	var projection:=preload("res://scripts/systems/world_projection_system.gd")
	var pose := held_weapon_pose(position, direction, weapon_class, progress, visual_scale)
	if progress >= 0.18 and progress <= 0.72 and weapon_class in ["blade", "heavy"]:
		game.draw_arc(position, 37.0 * visual_scale, direction.angle() - 1.0, direction.angle() + 1.0, 18, Color(1.0, 0.82, 0.38, 0.48), 4.0 * visual_scale)
	game.draw_set_transform_matrix(projection.transform(game,pose.transform))
	game.draw_texture_rect(texture, pose.destination, false)
	projection.apply(game)
	if progress >= 0.0 and weapon_class == "bow" and progress > 0.42:
		var arrow_start := position + direction * 28.0 * visual_scale
		game.draw_line(arrow_start, arrow_start + direction * 34.0 * visual_scale, Color("fff1b8"), 3.0 * visual_scale)
	if progress >= 0.0 and weapon_class == "staff":
		var orb := position + direction * (42.0 + sin(progress * PI) * 18.0) * visual_scale
		game.draw_circle(orb, (5.0 + sin(progress * PI) * 4.0) * visual_scale, Color(0.35, 0.88, 1.0, 0.78))


## Рассчитывает позу оружия в том же экранном пространстве, что и герой, при любом смещении камеры.
static func held_weapon_pose(position: Vector2, direction: Vector2, weapon_class: String, progress: float, visual_scale: float = 1.0, world_offset: Vector2 = Vector2.ZERO) -> Dictionary:
	var base_angle: float = direction.angle() + PI * 0.25
	var reach: float = 25.0
	var rotation: float = base_angle
	if progress >= 0.0:
		match weapon_class:
			"blade":
				rotation = base_angle + lerpf(-1.35, 1.15, smoothstep(0.08, 0.72, progress))
				reach += sin(progress * PI) * 11.0
			"heavy":
				rotation = base_angle + lerpf(-1.75, 0.65, smoothstep(0.12, 0.68, progress))
				reach += sin(progress * PI) * 8.0
			"spear": reach += sin(clampf(progress / 0.55, 0.0, 1.0) * PI) * 27.0
			"bow": reach += 3.0
			"staff":
				rotation += sin(progress * TAU) * 0.22
				reach += sin(progress * PI) * 8.0
	var center: Vector2 = position + direction.normalized() * reach * visual_scale + Vector2(0, -4) * visual_scale
	var size: Vector2 = Vector2(48, 48) * visual_scale
	if weapon_class in ["spear", "staff"]: size = Vector2(56, 56) * visual_scale
	return {"transform": Transform2D(rotation, center + world_offset), "destination": Rect2(-size * 0.5, size)}


## Рассчитывает экранный прямоугольник предмета в руке с учётом общего визуального масштаба героя.
static func held_weapon_destination(position: Vector2, direction: Vector2, attacking: bool, visual_scale: float = 1.0) -> Rect2:
	var side := -1.0 if direction.x < -0.1 else 1.0
	var item_size := Vector2(48, 48) * visual_scale
	var offset := Vector2(22.0 * side, -3.0) * visual_scale + (direction * 7.0 * visual_scale if attacking else Vector2.ZERO)
	return Rect2(position + offset - item_size * 0.5, item_size)


## Рисует короткую тематическую частицу нового набора без изменения игрового состояния.
static func draw_effect(canvas: Node2D, kind: String, position: Vector2, alpha: float = 1.0) -> void:
	var column: int = int({"dust":0,"leaves":1,"splash":2,"stone":3,"wood":4}.get(kind, 0))
	draw_cell(canvas,column,3,Rect2(position-Vector2(36,36),Vector2(72,72)),Color(1,1,1,alpha))
