# QA читает фактический динамический фасад обеих Git-версий.
@warning_ignore_start(
	"unsafe_method_access", "unsafe_property_access", "untyped_declaration", "unsafe_call_argument"
)
extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Fixture := preload("res://tools/qa/world/weather/game.gd")
const CLOCK := "res://scripts/presentation/weather_visual_clock.gd"
const DAYS := {"clear": 1, "rain": 3, "snow": 23, "storm": 6}


## Создаёт настоящую main-сцену с одинаковым seed; старый renderer не заменяется оверлеем.
static func create(parent: Node, weather: String) -> Fixture:
	var scene := Points.create_game()
	scene.set_script(Fixture)
	var game := scene as Fixture
	game.world_loot_seed = Points.SEED
	parent.add_child(game)
	Points.configure(game, Points.registry().points[0])
	game.remove_meta(&"camera_reference_zoom")
	game.settings_state.reduced_motion = false
	game.settings_state.vsync_enabled = false
	game.player = Vector2(696, 696)
	game.day = int(DAYS[weather])
	game.game_minutes = 720.0
	game.state.world.weather_day = 0
	game.WorldEventSystem.weather(game)
	game.sync_background_environment()
	game.update_camera()
	return game


## Читает новый transient только там, где он действительно присутствует в Git-версии.
## Baseline не получает скопированный clock или подставное время.
static func phase(game: Fixture) -> float:
	if not ResourceLoader.exists(CLOCK):
		return -1.0
	var clock: Script = load(CLOCK)
	return float(clock.seconds(game))


## Сохраняет полный игровой снимок вместе с камерой, климатом и локальной фазой.
static func state(game: Fixture) -> Dictionary:
	return {
		"save": game.SaveSystem.snapshot(game),
		"world": game.current_location,
		"weather": game.WorldEventSystem.weather(game),
		"phase": phase(game),
		"camera": [game.camera_offset.x, game.camera_offset.y],
		"player": [game.player.x, game.player.y],
		"zoom": game.CameraSystem.WorldProjection.zoom(game),
		"paused": game.menu_state.pause_open,
		"reduced": game.settings_state.reduced_motion,
		"owner": preload("res://scripts/presentation/viewport_world_context.gd").read(game),
	}


## Подаёт лишь штатные callbacks; визуальное время не записывается тестом напрямую.
static func tick(game: Fixture, count: int = 1) -> void:
	for index: int in count:
		game._physics_process(0.02)


## Выключает только фон у изолированного наблюдателя, сохраняя production material/draw.
static func isolated(game: Fixture, enabled: bool) -> void:
	game.weather_only = enabled
	game.get_node("WorldBackground").visible = not enabled
	game.queue_redraw()
