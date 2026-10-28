extends "res://tools/assets/contracts/visual_resources_review.gd"

const SamplingSuite := preload("res://tests/suites/visual_sampling_suite.gd")

## Проверяет адресную фильтрацию в изолированных экземплярах без сохранений игрока.
func _initialize() -> void:
	SamplingSuite.new(self).run()
	print("SAMPLING TESTS: %d passed, %d failed" % [passed,failed]); quit(0 if failed==0 else 1)
