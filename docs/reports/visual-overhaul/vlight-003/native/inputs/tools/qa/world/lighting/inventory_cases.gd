extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/lighting/inventory_game.gd")
const WorldSpace := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const POSITIONS: Dictionary[String, Vector2] = {
	"west-lamp": Vector2(768, 614), "east-lamp": Vector2(1728, 734), "home": Vector2(576, 500)
}


## Берёт существующую сцену; seed устанавливается до production bootstrap.
static func create_game(parent: Node) -> Observer:
	var scene := Points.create_game()
	scene.set_script(Observer)
	var game := scene as Observer
	game.world_loot_seed = Points.SEED
	parent.add_child(game)
	return game


## Примеры не перестраивают карту и используют проверенные ранее позиции фонарей и дома.
static func configure(game: Observer, group: String, minutes: int) -> void:
	var entries: Variant = Points.registry().get("points")
	if entries is not Array:
		push_error("lighting camera registry is missing")
		return
	var points: Array = entries
	if points.is_empty() or points[0] is not Dictionary:
		push_error("lighting camera registry is empty")
		return
	var source: Dictionary = points[0]
	var point := source.duplicate(true)
	point.location = "cottage_interior" if group == "home" else "overworld"
	point.player = Points.pair(POSITIONS[group])
	point.minutes = minutes
	point.day = 2
	Points.configure(game, point)
	game.FirstChapterSystem.state(game).bridge_repaired = true
	game.state.world.weather_day = game.day
	game.state.world.weather = "clear"
	game.dropped_items.clear()
	game.facing = Vector2.DOWN
	if group != "home":
		WorldSpace.set_reference_zoom(game, 1.2)
	game.update_camera()
	Pose.reset(game)
	# Инициализация погоды отделена от проверяемого draw и явно записана в конфигурации QA.
	game.WorldEventSystem.weather(game)


## Записывает настоящую камеру и масштаб вместе с часами, не выводя их из имени случая.
static func snapshot(game: Observer, id: String) -> Dictionary:
	var result := Points.snapshot(game, {"id": id})
	result.zoom = WorldSpace.zoom(game)
	return result


## Читает завершённый framebuffer только после очереди redraw и process_frame.
static func redraw(tree: SceneTree, games: Array[Observer], count: int) -> void:
	for index: int in count:
		for game: Observer in games:
			game.queue_redraw()
		await tree.process_frame
		await RenderingServer.frame_post_draw


## Отделяет оконное ожидание от остановленной игровой симуляции.
static func settle(tree: SceneTree, games: Array[Observer], milliseconds: int) -> void:
	tree.root.grab_focus()
	DisplayServer.window_move_to_foreground()
	var end := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < end:
		for game: Observer in games:
			game.queue_redraw()
		await tree.process_frame
