extends "res://tools/assets/contracts/visual_resources_review.gd"

const SizesSuite := preload("res://tests/suites/item_sizes_suite.gd")

## Проверяет роли и кеш двух размеров без пользовательского сохранения и нативного прогрева.
func _initialize() -> void:
	SizesSuite.new(self).run()
	print("ITEM SIZE TESTS: %d passed, %d failed" % [passed,failed]); quit(0 if failed==0 else 1)
