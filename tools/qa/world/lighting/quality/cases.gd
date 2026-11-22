extends RefCounted

const Fixture := preload("res://tools/qa/world/lighting/quality/game.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Existing := preload("res://tools/qa/world/lighting/inventory_cases.gd")
const Save := preload("res://scripts/systems/save_system.gd")
const WorldSpace := preload("res://scripts/systems/world_projection_system.gd")
const Context := preload("res://scripts/presentation/viewport_world_context.gd")
const Buildings := preload("res://scripts/systems/building_system.gd")
const Resources := preload("res://scripts/systems/resource_system.gd")
const Actors := preload("res://scripts/systems/enemy_animation_library.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const QUALITY_PATH := "res://scripts/presentation/lighting_quality.gd"
const ENTRIES: Array[Dictionary] = [
	{"id": "street-day", "room": "street", "minutes": 720},
	{"id": "street-dusk", "room": "street", "minutes": 1140},
	{"id": "street-night", "room": "street", "minutes": 1320},
	{"id": "home-day", "room": "home", "minutes": 720},
	{"id": "home-dusk", "room": "home", "minutes": 1140},
	{"id": "home-night", "room": "home", "minutes": 1320},
]


## Seed ставится после смены наблюдателя и до настоящего _ready обеих Git-версий.
static func create(parent: Node) -> Fixture:
	var scene := Points.create_game()
	scene.set_script(Fixture)
	var game := scene as Fixture
	game.world_loot_seed = Points.SEED
	parent.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	return game


## Типизированный список не зависит от вывода Array у условного выражения GDScript.
static func modes(baseline: bool) -> Array[String]:
	var result: Array[String] = ["standard"]
	if not baseline:
		result.append_array(["low", "off"])
	return result


## Переносит только настоящих противника и камень в QA; механики и исходные карты прежние.
static func configure(game: Fixture, entry: Dictionary) -> void:
	var minutes: int = entry.minutes
	Existing.configure(game, "home" if entry.room == "home" else "west-lamp", minutes)
	if entry.room == "street":
		game.player = Vector2(Buildings.BUILDINGS.cottage.door) + Vector2(96, 72)
	game.update_camera()
	game.settings_state.vsync_enabled = false
	var initial_enemies: Array = game.CombatSystem.default_enemies()
	var original_enemy: Dictionary = initial_enemies[2]
	var enemy := original_enemy.duplicate(true)
	enemy.location = game.current_location
	enemy.position = game.player + Vector2(140, 0)
	enemy.home = enemy.position
	enemy.action_target = enemy.position
	enemy.moving = false
	enemy.visual_time = 0.0
	game.enemy_nodes = [enemy]
	var initial_resources := Resources.default_nodes()
	var original_resource: Dictionary = initial_resources[0]
	var resource := original_resource.duplicate(true)
	resource.location = game.current_location
	resource.position = game.player + Vector2(-130, 0)
	game.resource_nodes = [resource]
	game.hazard_nodes.clear()
	game.hidden_target = ""
	game.bad_hud = false
	Pose.reset(game)


## Baseline не получает новый production-модуль; candidate вызывает настоящий публичный API.
static func mode(game: Fixture, value: String, baseline: bool) -> void:
	if baseline:
		if value != "standard" or ResourceLoader.exists(QUALITY_PATH):
			push_error("baseline must retain its genuine unmodified light implementation")
	else:
		var quality := load(QUALITY_PATH) as GDScript
		quality.call("set_profile", game, value)
	game.hidden_target = ""
	game.bad_hud = false
	game.hud_only = false
	var background := game.get_node("WorldBackground") as CanvasItem
	background.visible = true


## Сохраняет полный save, действительную камеру и seed независимо от названия кадра.
static func state(game: Fixture, baseline: bool) -> Dictionary:
	var selected := "standard"
	if not baseline:
		selected = str((load(QUALITY_PATH) as GDScript).call("profile", game))
	return {
		"save": Save.snapshot(game),
		"geometry": Existing.snapshot(game, "light-quality"),
		"owner": Context.read(game),
		"seed": game.world_loot_seed,
		"profile": selected,
		"entities": json_value({"enemies": game.enemy_nodes, "resources": game.resource_nodes}),
	}


## Сохраняет все поля настоящих сущностей, явно кодируя векторы вместо потери их типа в JSON.
static func json_value(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var result_dict: Dictionary = {}
		for key: Variant in value:
			result_dict[key] = json_value(value[key])
		return result_dict
	if value is Array:
		var result_array: Array = []
		for entry: Variant in value:
			result_array.append(json_value(entry))
		return result_array
	return value


## Выводит границы из production-геометрии, а не из нарисованного поверх картинки маркера.
static func targets(game: Fixture) -> Dictionary:
	var door := Buildings.door_rect("cottage")
	var enemy: Dictionary = game.enemy_nodes[0]
	var resource: Dictionary = game.resource_nodes[0]
	if game.current_location == "cottage_interior":
		var exit: Vector2 = Buildings.INTERIORS.cottage_interior.exit
		door = Rect2(exit - Vector2(35, 12), Vector2(70, 24))
	return {
		"enemy": Actors.actor_rect(enemy),
		"resource": Resources.destination_rect(resource),
		"door": door,
	}


## Мировая область проходит настоящую проекцию и оконное растяжение с округлением наружу.
static func native_rect(game: Fixture, world: Rect2) -> Array[int]:
	var logical := Rect2(
		WorldSpace.world_to_screen(game, world.position), world.size * WorldSpace.zoom(game)
	)
	var native := game.get_viewport().get_stretch_transform() * logical
	var left := floori(native.position.x)
	var top := floori(native.position.y)
	return [left, top, ceili(native.end.x) - left, ceili(native.end.y) - top]


## Снимок framebuffer делается только после фактического завершения production draw.
static func redraw(tree: SceneTree, game: Fixture, count: int = 3) -> void:
	for index: int in count:
		game.queue_redraw()
		await tree.process_frame
		await RenderingServer.frame_post_draw
