extends Node2D

var guarded := true

## Показывает только диагностический старый посев, не подключая его к штатной сцене.
func _draw() -> void:
	preload("res://scripts/presentation/village_decoration_rules.gd").draw_legacy(self,guarded)
