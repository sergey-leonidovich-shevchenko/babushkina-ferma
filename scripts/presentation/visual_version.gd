extends RefCounted

const FLAG := &"visual_overhaul_enabled"
const SETTING := "rendering/visual_overhaul/enabled"


## Разрешает новую графику только по настоящему bool; остальные карты сохраняют свои прежние пути.
static func enabled(canvas: Node) -> bool:
	var owner := canvas
	while owner != null:
		var location: Variant = owner.get("current_location")
		if location is String:
			if location != "overworld":
				return true
			var value: Variant = owner.get_meta(FLAG, ProjectSettings.get_setting(SETTING, true))
			return typeof(value) == TYPE_BOOL and value
		owner = owner.get_parent()
	return true


## Меняет только transient-флаг владельца, обновляя его кеш земли без записи слотов или настроек.
static func set_enabled(game: Node, value: Variant) -> void:
	game.set_meta(FLAG, typeof(value) == TYPE_BOOL and value)
	var background := game.get_node_or_null("WorldBackground")
	if background != null and background.has_method("refresh_terrain"):
		background.call("refresh_terrain")
		var background_canvas := background as CanvasItem
		if background_canvas != null:
			background_canvas.queue_redraw()
	var canvas := game as CanvasItem
	if canvas != null:
		canvas.queue_redraw()
