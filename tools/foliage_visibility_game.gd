extends "res://scripts/game.gd"

const Review := preload("res://tests/helpers/foliage_visibility_scenario.gd")
var review_serial := 0
var review_isolated := false
var review_unculled := false
var review_draws := []


## Наблюдает настоящий production draw; отдельный слой сравнивает отсечение с теми же восемью слотами.
func _draw() -> void:
	var before := JSON.stringify(SaveSystem.snapshot(self), "", true, true)
	if not review_isolated:
		super._draw()
	else:
		Review.Wind.WorldProjection.apply(self)
		var owner: Node = get_node(Review.Wind.NAME)
		var previous: Array = owner.visible_rows
		if review_unculled: owner.visible_rows = range(8)
		for row in Review.Wind.placements():
			if not Review.Wind.draw(self, row.kind, row.position, Color(1, 1, 1, 0.82)):
				Review.Wind.Ambient.draw_cell(self, row.kind, row.position, Color(1, 1, 1, 0.82))
		owner.visible_rows = previous
	var after := JSON.stringify(SaveSystem.snapshot(self), "", true, true)
	draw_set_transform(Vector2.ZERO)
	# Six logical rows / sixteen independent bits survive Retina and prove the current callback was presented.
	for bit in 16:
		draw_rect(Rect2(bit * 72, 0, 72, 6), Color.WHITE if review_serial & (1 << bit) else Color.MAGENTA)
	review_draws.append({"serial": review_serial, "frame": Engine.get_process_frames(), "save_before": before.sha256_text(), "save_after": after.sha256_text(), "isolated": review_isolated, "unculled": review_unculled})
