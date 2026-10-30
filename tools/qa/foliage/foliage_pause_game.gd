extends "res://scripts/game.gd"

var pause_review_tag := ""
var pause_review_color := Color.MAGENTA
var pause_review_draws: Array = []


## Наблюдает настоящий draw и добавляет маркер той же CanvasItem-командой, не меняя игровой state.
func _draw() -> void:
	var before := JSON.stringify(SaveSystem.snapshot(self), "", true, true)
	super._draw()
	var after := JSON.stringify(SaveSystem.snapshot(self), "", true, true)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, 1152, 6), pause_review_color)
	pause_review_draws.append({
		"tag": pause_review_tag,
		"frame": Engine.get_process_frames(),
		"seconds": preload("res://scripts/presentation/village_ground_clock.gd").seconds(self),
		"save_before_sha": before.sha256_text(),
		"save_after_sha": after.sha256_text(),
		"save_equal": before == after
	})
