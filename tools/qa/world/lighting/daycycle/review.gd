extends SceneTree

var passed := 0
var failed := 0


## Отдельный профиль не допускает доступа к обычным пользовательским слотам.
func _initialize() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Codex-VLIGHT-003-"):
		quit(2)
		return
	_run.call_deferred()


## Запускает ту же модельную suite, которая входит в полный Game.
func _run() -> void:
	preload("res://tests/suites/daylight_palette_suite.gd").new(self).run()
	print("DAYLIGHT REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


## Делегирует bootstrap штатному игровому тестовому контексту без его запуска.
func make_game() -> Node:
	var game := preload("res://scripts/game.gd").new()
	game._ready()
	preload("res://scripts/systems/locale_system.gd").set_locale("ru")
	game.language_screen = false
	game.title_screen = false
	return game


## Сохраняет явное нарушенное условие для полного журнала headless-профиля.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
