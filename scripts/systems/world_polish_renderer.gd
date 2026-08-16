extends RefCounted

const ATLAS := preload("res://assets/game/world_polish/village_polish_atlas.png")
const CELL := Vector2(128, 128)


## Возвращает область одной ячейки строгого атласа 5×4.
static func source(column: int, row: int) -> Rect2:
	return Rect2(Vector2(column, row) * CELL, CELL)


## Рисует одну прозрачную ячейку атласа в указанном мировом прямоугольнике.
static func draw_cell(canvas: Node2D, column: int, row: int, destination: Rect2, modulate: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(ATLAS, destination, source(column, row), modulate)


## Рисует оружие у ведущей руки героя в направлении текущего действия.
static func draw_held_weapon(game: Node2D, kind: String, position: Vector2, direction: Vector2, attack_progress, visual_scale: float = 1.0) -> void:
	var item_kind: String = game.WeaponSystem.item_kind(kind)
	if item_kind.is_empty(): return
	var texture: Texture2D = game.item_texture(item_kind)
	if texture == null: return
	var progress: float = -1.0 if attack_progress is bool and not attack_progress else (0.5 if attack_progress is bool else float(attack_progress))
	var weapon_class: String = game.WeaponSystem.weapon_class(kind)
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
	if progress >= 0.18 and progress <= 0.72 and weapon_class in ["blade", "heavy"]:
		game.draw_arc(position, 37.0 * visual_scale, direction.angle() - 1.0, direction.angle() + 1.0, 18, Color(1.0, 0.82, 0.38, 0.48), 4.0 * visual_scale)
	game.draw_set_transform(center, rotation, Vector2.ONE)
	game.draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
	game.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if progress >= 0.0 and weapon_class == "bow" and progress > 0.42:
		var arrow_start := position + direction * 28.0 * visual_scale
		game.draw_line(arrow_start, arrow_start + direction * 34.0 * visual_scale, Color("fff1b8"), 3.0 * visual_scale)
	if progress >= 0.0 and weapon_class == "staff":
		var orb := position + direction * (42.0 + sin(progress * PI) * 18.0) * visual_scale
		game.draw_circle(orb, (5.0 + sin(progress * PI) * 4.0) * visual_scale, Color(0.35, 0.88, 1.0, 0.78))


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
