extends RefCounted

const OMITTED_PASS := &"overworld_render_probe_pass"
const FULL_COVERAGE := &"overworld_render_probe_full_coverage"
const FIXED_EFFECT_SECONDS := &"overworld_render_probe_effect_seconds"
const WATER := &"water"
const GRASS := &"grass"
const SHADOWS := &"shadows"
const UI := &"ui"


## Изолирует проход в одном экземпляре первой карты. Метка существует только в QA-сцене.
static func omits(game: Node, render_pass: StringName) -> bool:
	return (
		game != null
		and game.get_meta(OMITTED_PASS, &"") == render_pass
		and game.get("current_location") == "overworld"
	)


## Оставляет прежнюю геометрию в контрольной сцене с теми же материалами и настройками.
static func preserves_full_coverage(game: Node) -> bool:
	return game != null and game.get_meta(FULL_COVERAGE, false) == true


## Фиксирует фазу настенных эффектов в снимке QA. В игре используются прежние часы.
static func effect_seconds(game: Node) -> float:
	var value: Variant = game.get_meta(FIXED_EFFECT_SECONDS, -1.0)
	if value is float:
		@warning_ignore("unsafe_cast")
		var fixed := value as float
		if is_finite(fixed) and fixed >= 0.0:
			return fixed
	return Time.get_ticks_msec() / 1000.0
