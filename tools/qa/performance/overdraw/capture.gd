extends "res://tools/qa/performance/pass_cost/capture.gd"

const Background := preload("res://scripts/world_background.gd")


func _task_id() -> String:
	return "VPERF-004"


func _profiles() -> Array:
	return ["baseline", "trimmed"]


func _configure_profile() -> void:
	if omitted == "baseline":
		game.set_meta(Probe.FULL_COVERAGE, true)


## Проверяет реальную геометрию живого renderer вместе с состоянием остальных проходов.
func _conditions() -> Dictionary:
	var conditions := super._conditions()
	var background := game.get_node("WorldBackground") as Background
	conditions["deck_trim"] = (
		background != null
		and background.water_layer.trim_decks
		and background.water_surface.trim_decks
	)
	var owner := game.get_node_or_null(Wind.NAME) as Wind
	conditions["foliage_trim"] = owner != null and owner.batch.get("trim_padding") == true
	var crops: Dictionary = owner.batch.get("content", {}) if owner != null else {}
	conditions["foliage_types"] = crops.size()
	return conditions


func _pass_matches(conditions: Dictionary) -> bool:
	var trimmed := omitted == "trimmed"
	return (
		super._pass_matches(conditions)
		and conditions.get("deck_trim") == trimmed
		and conditions.get("foliage_trim") == trimmed
		and conditions.get("foliage_types") == (2 if trimmed else 0)
	)
