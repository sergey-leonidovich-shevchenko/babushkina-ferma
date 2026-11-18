extends "res://tools/qa/compatibility/dev_cabinet_review.gd"

const WaterSuite := preload("res://tests/suites/water_visual_compatibility_suite.gd")


## Ждёт входа корневого viewport в дерево перед созданием игровых сцен.
func _initialize() -> void:
	_run.call_deferred()


## Запускает парный сценарий через те же проверки, что и полный игровой набор.
func _run() -> void:
	WaterSuite.new(self).run()
	print("WATER VISUAL COMPATIBILITY: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
