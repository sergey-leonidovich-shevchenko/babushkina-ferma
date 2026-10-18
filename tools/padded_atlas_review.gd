extends "res://tools/visual_resources_review.gd"

const PaddedSuite := preload("res://tests/suites/padded_atlas_suite.gd")

## Проверяет настоящие импортированные страницы и весь каталог без сохранений игрока.
func _initialize() -> void:
	PaddedSuite.new(self).run()
	print("PADDED TESTS: %d passed, %d failed" % [passed,failed]); quit(0 if failed==0 else 1)
