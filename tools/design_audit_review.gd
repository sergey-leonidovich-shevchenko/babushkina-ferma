extends "res://tools/world_workbench_review.gd"

## Проверяет новые визуальные контракты и прежние реальные маршруты и производственные цепочки.
func _initialize() -> void:
	for suite in [preload("res://tests/suites/world_design_suite.gd"),preload("res://tests/suites/workshop_suite.gd"),preload("res://tests/suites/village_map_suite.gd"),preload("res://tests/suites/village_regions_suite.gd"),preload("res://tests/suites/village_clearance_suite.gd")]: suite.new(self).run()
	print("DESIGN AUDIT REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
