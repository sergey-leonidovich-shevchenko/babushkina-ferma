extends RefCounted


## Сохраняет исходный вызов mesh; выключатель действует только в отдельной QA-копии.
static func mesh(
	owner: String,
	canvas: CanvasItem,
	shape: Mesh,
	texture: Texture2D = null,
	transform: Transform2D = Transform2D.IDENTITY,
	modulate: Color = Color.WHITE
) -> void:
	var box := shape.get_aabb()
	var rect := (
		transform * Rect2(Vector2(box.position.x, box.position.y), Vector2(box.size.x, box.size.y))
	)
	_record(owner, rect)
	if not OS.get_cmdline_user_args().has("--without-contacts"):
		canvas.draw_mesh(shape, texture, transform, modulate)


## Оставляет прежнюю эллиптическую реализацию персонажей в её production-владельце.
static func ellipse(center: Vector2, radii: Vector2) -> bool:
	_record("directional", Rect2(center - radii, radii * 2.0))
	return not OS.get_cmdline_user_args().has("--without-contacts")


## Прибор пишет только геометрию вызова; снимки игры проверяют отсутствие побочных изменений.
static func _record(owner: String, bounds: Rect2) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var game := tree.current_scene
	if game != null and game.has_method("record_shadow_contact"):
		game.call("record_shadow_contact", owner, bounds)
