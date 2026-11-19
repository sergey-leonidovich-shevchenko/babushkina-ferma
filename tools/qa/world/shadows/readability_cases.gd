extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const WorldSpace := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Game := preload("res://scripts/game.gd")
const GROUPS: Array[String] = ["farm", "street", "grove", "home"]
const ITEMS: Array[String] = ["apple", "stone", "wood"]


## Проверяет JSON-границу до обращения к первой принятой точке камеры.
static func first_point() -> Dictionary:
	var values: Variant = Points.registry().get("points")
	if values is not Array:
		return {}
	var points: Array = values
	if points.is_empty() or points[0] is not Dictionary:
		return {}
	var point: Dictionary = points[0]
	return point.duplicate(true)


## Берёт существующий дом и улицу; постановка кадра не перестраивает мир и его коллизии.
static func configure(game: Game, group: String, minutes: int, no_loot: bool) -> Array[Dictionary]:
	var point := first_point()
	point.location = "cottage_interior" if group == "home" else "overworld"
	point.player = {
		"farm": Points.pair(game.workbench_position + Vector2(0, 86)),
		"street": [870, 471],
		"grove": [1848, 1140],
		"home": [576, 500]
	}[group]
	point.minutes = minutes
	Points.configure(game, point)
	game.FirstChapterSystem.state(game).bridge_repaired = true
	if group != "home":
		WorldSpace.set_reference_zoom(game, WorldSpace.REFERENCE_ZOOM)
	game.facing = Vector2.DOWN
	game.update_camera()
	Pose.reset(game)
	game.dropped_items.clear()
	var items: Array[Dictionary] = []
	for index: int in ITEMS.size():
		var position: Vector2 = game.player + Vector2((index - 1) * 54, 10)
		var item := {
			"kind": ITEMS[index],
			"count": 1,
			"position": position,
			"location": game.current_location,
			"pickup_blocked": true
		}
		if not no_loot:
			game.dropped_items.append(item)
		var stretch := game.get_viewport().get_stretch_transform()
		var a := stretch * WorldSpace.world_to_screen(game, position - Vector2(22, 22))
		var b := stretch * WorldSpace.world_to_screen(game, position + Vector2(22, 22))
		items.append(
			{
				"kind": ITEMS[index],
				"position": Points.pair(position),
				"rect": [a.x, a.y, b.x - a.x, b.y - a.y],
				"textured": game.item_texture(ITEMS[index]) != null
			}
		)
	return items


## Сохраняет реальные маленькие текстуры иконок; reader строит непрозрачную область из их alpha.
static func save_loot_sources(game: Game, folder: String) -> Dictionary:
	var result: Dictionary = {}
	for kind: String in ITEMS:
		var visual: Dictionary = game.VisualAssetSystem.item_draw_visual(kind, 44)
		var value: Variant = visual.get("texture")
		if value is not Texture2D:
			return {}
		var texture: Texture2D = value
		var image := texture.get_image()
		var name := "loot-source-" + kind + ".png"
		if image == null or image.save_png(folder.path_join(name)) != OK:
			return {}
		result[kind] = {"file": name, "size": Points.pair(image.get_size())}
	return result
