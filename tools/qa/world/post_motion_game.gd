extends "res://tools/qa/world/render_order_game.gd"

## Стабилизирует лишь QA-рисунок, сохраняя настоящий production draw и снимки состояния.
func _draw()->void:
	var reduced:bool=settings_state.reduced_motion
	var had:bool=has_meta("visual_reference_hud");var prior:Variant=get_meta("visual_reference_hud") if had else null
	settings_state.reduced_motion=true;set_meta("visual_reference_hud",true)
	super._draw()
	settings_state.reduced_motion=reduced
	if had:set_meta("visual_reference_hud",prior)
	else:remove_meta("visual_reference_hud")
