# Поля читаются на динамической границе фасада и проверенного числового Context.
@warning_ignore_start("unsafe_property_access", "unsafe_method_access", "unsafe_call_argument")
extends RefCounted

const META := &"weather_visual_clock"
const Context := preload("res://scripts/presentation/viewport_world_context.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const KEYS := ["game", "viewport", "background", "world", "seconds"]


## Читает только временную фазу этого мира; draw не создаёт часы и не пишет в save.
static func seconds(game: Node) -> float:
	var raw: Variant = game.get_meta(META, {})
	if not raw is Dictionary or not raw.is_read_only() or raw.size() != KEYS.size():
		return 0.0
	for key: String in KEYS:
		if not raw.has(key):
			return 0.0
	var owner := Context.read(game)
	if (
		owner.is_empty()
		or typeof(raw.game) != TYPE_INT
		or typeof(raw.viewport) != TYPE_INT
		or typeof(raw.background) != TYPE_INT
		or typeof(raw.world) != TYPE_STRING
		or typeof(raw.seconds) != TYPE_FLOAT
		or raw.game != owner.game
		or raw.viewport != owner.viewport
		or raw.background != owner.background
		or raw.world != game.current_location
		or not is_finite(float(raw.seconds))
		or raw.seconds < 0.0
	):
		return 0.0
	return float(raw.seconds)


## Вызывается один раз после движения тем же разрешённым delta, что визуальный кадр.
## Пауза и reduced motion не накапливают настенное время для будущего скачка.
static func advance(game: Node, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if (
		game.language_screen
		or game.GameLoop.modal_active(game)
		or game.GameLoop.gameplay_window_open(game)
		or game.LevelEditorSystem.active(game)
		or game.settings_state.reduced_motion
		or not Reference.effects_enabled(game)
	):
		return
	var owner := Context.ensure(game)
	if owner.is_empty():
		return
	var next := seconds(game) + delta
	if not is_finite(next):
		return
	var value := {
		"game": int(owner.game),
		"viewport": int(owner.viewport),
		"background": int(owner.background),
		"world": String(game.current_location),
		"seconds": next,
	}
	value.make_read_only()
	game.set_meta(META, value)


## Смена/загрузка комнаты и восстановление после поражения завершают прежний визит.
static func reset(game: Node) -> void:
	game.remove_meta(META)
