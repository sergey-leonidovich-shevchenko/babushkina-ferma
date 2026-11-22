# QA обращается к настоящему динамическому фасаду двух закреплённых Git-версий.
@warning_ignore_start(
	"unsafe_method_access", "unsafe_property_access", "untyped_declaration", "unsafe_call_argument"
)
extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Game := preload("res://tools/qa/world/rollback/game.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Wind := preload("res://scripts/presentation/foliage_wind.gd")
const FLAG := &"visual_overhaul_enabled"
const FLAGS := [
	"base_only",
	"painted_grass",
	"soft_ground_edges",
	"rectangular_roads",
	"joined_roads",
	"soft_plaza",
	"soft_garden",
	"color_patches",
	"separate_bridge_rails"
]
const CAMERAS := {
	"home": Vector2(432, 672),
	"garden": Vector2(456, 960),
	"animals": Vector2(936, 1128),
	"square": Vector2(1320, 744),
	"west-bank": Vector2(864, 360),
	"east-bank": Vector2(1776, 600),
}


## Создаёт main-сцену, а диагностический подкласс только считает настоящие кадры.
static func create(parent: Node) -> Game:
	var scene := Points.create_game()
	scene.set_script(Game)
	var game := scene as Game
	parent.add_child(game)
	Points.configure(game, Points.registry().points[0])
	game.remove_meta(&"camera_reference_zoom")
	game.settings_state.vsync_enabled = false
	game.WorkshopSystem.state(game, "pottery")
	game.state.world.estate.event = "market"
	return game


## Использует один и тот же transient-флаг и инвалидацию кеша в baseline и candidate.
## Baseline не получает скопированную реализацию нового production-переключателя.
static func toggle(game: Game, modern: bool) -> void:
	var path := "res://scripts/presentation/visual_version.gd"
	if ResourceLoader.exists(path):
		var version: Script = load(path)
		version.set_enabled(game, modern)
	else:
		game.set_meta(FLAG, modern)
		game.get_node("WorldBackground").refresh_terrain()
		game.queue_redraw()
	Wind.update(game)


## Оставляет симуляцию остановленной, но включает обычную отрисовку, атмосферу и интерфейс.
static func camera(game: Game, point: Vector2, minutes: float = 720.0) -> void:
	game.current_location = "overworld"
	game.player = point
	game.day = 1
	game.game_minutes = minutes
	game.sync_background_location()
	game.sync_background_environment()
	game.update_camera()
	Pose.reset(game)


## Читает эффективные значения настоящего terrain canvas и видимость выделенной воды.
static func state(game: Game) -> Dictionary:
	var background := game.get_node("WorldBackground")
	var effective := {}
	for key in FLAGS:
		effective[key] = background.terrain_canvas.get(key)
	var context := preload("res://scripts/presentation/viewport_world_context.gd").read(game)
	return {
		"save": game.SaveSystem.snapshot(game),
		"player": Points.pair(game.player),
		"camera": Points.pair(game.camera_offset),
		"location": game.current_location,
		"master":
		game.get_meta(FLAG, ProjectSettings.get_setting("rendering/visual_overhaul/enabled", true)),
		"master_metadata": game.has_meta(FLAG),
		"project_flag": ProjectSettings.get_setting("rendering/visual_overhaul/enabled", true),
		"terrain": effective,
		"water_layer": background.water_layer.visible,
		"terrain_ready": background.terrain_ready,
		"processing": game.is_physics_processing() or game.is_processing(),
		"reference_mode":
		preload("res://scripts/presentation/visual_reference_mode.gd").active(game),
		"owner": context,
		"game_id": game.get_instance_id(),
		"viewport_id": game.get_viewport().get_instance_id(),
		"background_id": background.get_instance_id(),
		"wind": Wind.statistics(game),
	}
