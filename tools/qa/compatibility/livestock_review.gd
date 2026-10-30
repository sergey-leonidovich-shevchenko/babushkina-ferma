extends SceneTree

const Game := preload("res://scripts/game.gd")
var passed := 0
var failed := 0

## Проверяет профильные фермерские сценарии до обязательного общего quality gate.
func _initialize() -> void:
	preload("res://tests/suites/livestock_suite.gd").new(self).run()
	preload("res://tests/suites/farm_life_suite.gd").new(self).test_animals_feed_then_produce()
	preload("res://tests/suites/village_clearance_suite.gd").new(self).run()
	print("LIVESTOCK REVIEW: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)

## Создаёт игровую модель с отключёнными стартовыми окнами и внешней записью настроек.
func make_game() -> Node:
	var game := Game.new(); game.audio_enabled=false; game._ready(); game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"
	return game

## Записывает результат конкретного проверяемого правила.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error("FAIL: "+label)
