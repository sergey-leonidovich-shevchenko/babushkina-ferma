extends RefCounted

const OMITTED_PASS := &"overworld_render_probe_pass"
const FULL_COVERAGE := &"overworld_render_probe_full_coverage"
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
