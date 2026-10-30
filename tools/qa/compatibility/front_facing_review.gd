extends "res://tools/qa/compatibility/house_furniture_review.gd"

## Проверяет ракурсы, строительные входы, мебель, ремёсла и сохранения без пользовательских слотов.
func _initialize() -> void:
	preload("res://tests/suites/front_facing_suite.gd").new(self).run()
	preload("res://tests/suites/house_furniture_suite.gd").new(self).run()
	preload("res://tests/suites/basement_suite.gd").new(self).run()
	preload("res://tests/suites/basement_content_suite.gd").new(self).run()
	preload("res://tests/suites/artisan_suite.gd").new(self).run()
	preload("res://tests/suites/kitchen_suite.gd").new(self).run()
	print("FRONT FACING REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
