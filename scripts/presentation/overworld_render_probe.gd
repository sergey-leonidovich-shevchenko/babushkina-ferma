extends RefCounted

const OMITTED_PASS := &"overworld_render_probe_pass"
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
