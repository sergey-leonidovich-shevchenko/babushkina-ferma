extends SceneTree

const Suite := preload("res://tests/suites/asset_boundary_suite.gd")
var passed := 0
var failed := 0

## Запускает профильный сценарий без сцены и без сохранений игрока.
func _initialize() -> void:
	Suite.new(self).run()
	print("PIPELINE TESTS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)

## Регистрирует результат каждой проверки импортной границы.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
