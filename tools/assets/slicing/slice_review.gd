extends "res://tools/qa/compatibility/livestock_review.gd"

## Проверяет реальные источники и нечётную контрольную сетку до полного игрового набора.
func _initialize() -> void:
	preload("res://tests/suites/atlas_source_geometry_suite.gd").new(self).run()
	print("SLICE REVIEW: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
