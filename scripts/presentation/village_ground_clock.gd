# Часы работают на динамической границе композиционного игрового узла и его систем.
@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return"
)
extends RefCounted

const META := &"village_live_ground_seconds"
const ViewportWorldContext := preload("res://scripts/presentation/viewport_world_context.gd")


## Читает временные визуальные часы, не создавая метаданные во время draw и не меняя слот.
static func seconds(game: Node) -> float:
	return float(game.get_meta(META, 0.0))


## Продвигает декор первой карты только вместе с разрешённой симуляцией; пауза не накапливает долг.
static func advance(game: Node, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or game.current_location != "overworld":
		return
	if ViewportWorldContext.ensure(game).is_empty():
		return
	if (
		game.language_screen
		or game.GameLoop.modal_active(game)
		or game.GameLoop.gameplay_window_open(game)
		or game.LevelEditorSystem.active(game)
	):
		return
	if (
		game.settings_state.reduced_motion
		or not preload("res://scripts/presentation/visual_reference_mode.gd").effects_enabled(game)
	):
		return
	game.set_meta(META, seconds(game) + delta)
