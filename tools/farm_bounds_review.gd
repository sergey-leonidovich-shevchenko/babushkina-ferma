extends "res://tools/livestock_review.gd"

## Проверяет границы фермы вместе с талантами, удобрениями и переносом старого двора.
func _initialize() -> void:
	preload("res://tests/suites/world_farming_suite.gd").new(self).run()
	preload("res://tests/suites/garden_crafting_suite.gd").new(self).run()
	preload("res://tests/suites/talent_suite.gd").new(self).run()
	preload("res://tests/suites/livestock_suite.gd").new(self).run()
	print("FARM BOUNDS REVIEW: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
