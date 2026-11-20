extends RefCounted

const OFF := &"qa_light_inventory_off"


## Переключатель принадлежит рисующему canvas, поэтому не переносится в соседний viewport.
static func _enabled(canvas: CanvasItem, owner: String, bounds: Rect2) -> bool:
	if canvas.has_method("record_light_call"):
		canvas.call("record_light_call", owner, bounds)
	return not is_off(canvas)


## Метаданные проверяются по типу до преобразования, включая строгий semantic gate.
static func is_off(canvas: CanvasItem) -> bool:
	var value: Variant = canvas.get_meta(OFF, false)
	if value is not bool:
		return false
	var flag: bool = value
	return flag


## Сохраняет ровно прежний экранный прямоугольник общего затемнения.
static func rect(owner: String, canvas: CanvasItem, bounds: Rect2, color: Color) -> void:
	if _enabled(canvas, owner, bounds):
		canvas.draw_rect(bounds, color)


## Не подменяет геометрию и материал фонаря; выключает лишь его отдельный draw.
static func mesh(
	owner: String,
	canvas: CanvasItem,
	shape: Mesh,
	texture: Texture2D = null,
	transform: Transform2D = Transform2D.IDENTITY,
	modulate: Color = Color.WHITE
) -> void:
	var box := shape.get_aabb()
	var bounds := (
		transform * Rect2(Vector2(box.position.x, box.position.y), Vector2(box.size.x, box.size.y))
	)
	if _enabled(canvas, owner, bounds):
		canvas.draw_mesh(shape, texture, transform, modulate)


## Оставляет портальный ореол самостоятельным эффектом, не вмешиваясь в доступность перехода.
static func circle(
	owner: String, canvas: CanvasItem, center: Vector2, radius: float, color: Color
) -> void:
	if _enabled(canvas, owner, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		canvas.draw_circle(center, radius, color)


## Сохраняет исходную трапецию окна в мировых координатах и прежний цвет.
static func polygon(
	owner: String, canvas: CanvasItem, points: PackedVector2Array, color: Color
) -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	if _enabled(canvas, owner, bounds):
		canvas.draw_colored_polygon(points, color)
