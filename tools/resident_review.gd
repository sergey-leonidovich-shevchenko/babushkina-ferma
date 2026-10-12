extends "res://tools/livestock_review.gd"

## Проверяет рост, стопы, диалоги и редактор жителей перед общим набором регрессий.
func _initialize() -> void:
	preload("res://tests/suites/resident_visual_suite.gd").new(self).run()
	preload("res://tests/suites/grandmother_visual_suite.gd").new(self).run()
	preload("res://tests/suites/animation_suite.gd").new(self).test_every_human_atlas_uses_actual_left_and_right_rows()
	print("RESIDENT REVIEW: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
