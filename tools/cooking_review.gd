extends "res://tools/livestock_review.gd"

## Проверяет кухню и хозяйственные цепочки до обязательного полного quality gate.
func _initialize() -> void:
	preload("res://tests/suites/household_cooking_suite.gd").new(self).run()
	preload("res://tests/suites/potion_suite.gd").new(self).run()
	print("COOKING REVIEW: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
