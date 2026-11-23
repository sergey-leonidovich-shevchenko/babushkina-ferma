extends RefCounted

const Version := preload("res://scripts/presentation/visual_version.gd")
const META := &"lighting_quality"
const STANDARD := &"standard"
const LOW := &"low"
const OFF := &"off"
const LOW_ALPHA := 0.65
const LOCATIONS: Array[String] = ["overworld", "cottage_interior"]


## Неизвестное значение сохраняет обычный рисунок вместо случайного выключения света.
static func normalize(value: Variant) -> StringName:
	if value is String or value is StringName:
		if value == LOW:
			return LOW
		if value == OFF:
			return OFF
	return STANDARD


## Наследует профиль ближайшего canvas, ограничивая изменение первой картой и существующим домом.
static func profile(canvas: Node) -> StringName:
	var owner := canvas
	var selected: Variant = STANDARD
	var found := false
	while owner != null:
		if not found and owner.has_meta(META):
			selected = owner.get_meta(META)
			found = true
		var location: Variant = owner.get("current_location")
		if location is String:
			if location == "overworld" and not Version.enabled(owner):
				return STANDARD
			return normalize(selected) if location in LOCATIONS else STANDARD
		owner = owner.get_parent()
	return normalize(selected)


## Меняет только временные метаданные владельца и обновляет оба его рисующих слоя.
static func set_profile(canvas: CanvasItem, value: Variant) -> void:
	var selected := normalize(value)
	canvas.set_meta(META, selected)
	canvas.queue_redraw()
	var background := canvas.get_node_or_null("WorldBackground") as CanvasItem
	if background != null:
		background.queue_redraw()


## Сохраняет форму календарной кривой; low меняет только alpha, off пропускает затемнение.
static func tint(canvas: Node, color: Color) -> Color:
	var selected := profile(canvas)
	if selected == OFF:
		return Color.TRANSPARENT
	if selected == LOW:
		color.a *= LOW_ALPHA
	return color


## Оставляет декоративные световые проходы только обычному профилю, сохраняя сами объекты.
static func decorative_enabled(canvas: Node) -> bool:
	return profile(canvas) == STANDARD
