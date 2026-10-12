extends "res://tools/livestock_review.gd"

## Проверяет полные позы инструментов и существующие боевые кадры до общего запуска тестов.
func _initialize() -> void:
	preload("res://tests/suites/hero_action_visual_suite.gd").new(self).run()
	preload("res://tests/suites/hero_combat_visual_suite.gd").new(self).run()
	print("HERO ACTION REVIEW: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
