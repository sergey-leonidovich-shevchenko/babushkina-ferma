extends SceneTree

const Suite := preload("res://tests/suites/visual_resource_suite.gd")
var passed := 0
var failed := 0
const Game := preload("res://scripts/game.gd")

## Создаёт такой же изолированный игровой экземпляр, как полный набор тестов.
func make_game() -> Node:
	var game := Game.new(); game._ready()
	game.LocaleSystem.set_locale("ru"); game.language_screen=false; game.title_screen=false
	return game

## Запускает профильный контракт паспортов без загрузки сохранения игрока.
func _initialize() -> void:
	Suite.new(self).run()
	print("RESOURCE TESTS: %d passed, %d failed" % [passed,failed]); quit(0 if failed==0 else 1)

## Регистрирует каждое фактическое утверждение профильного контракта.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
