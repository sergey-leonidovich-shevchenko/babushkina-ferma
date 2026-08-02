extends SceneTree

const GameScript = preload("res://scripts/game.gd")
const ArchitectureSuite = preload("res://tests/suites/architecture_suite.gd")
const CoreSuite = preload("res://tests/suites/core_suite.gd")
const GameplaySuite = preload("res://tests/suites/gameplay_suite.gd")
const WorldSuite = preload("res://tests/suites/world_suite.gd")
const BuildingsSuite = preload("res://tests/suites/buildings_suite.gd")
const ProgressionSuite = preload("res://tests/suites/progression_suite.gd")
const AnimationSuite = preload("res://tests/suites/animation_suite.gd")
const AudioSuite = preload("res://tests/suites/audio_suite.gd")
const InterfaceSuite = preload("res://tests/suites/interface_suite.gd")
var passed := 0
var failed := 0

## Запускает все наборы тестов и завершает процесс с кодом результата.
func _initialize() -> void:
	CoreSuite.new(self).run()
	GameplaySuite.new(self).run()
	WorldSuite.new(self).run()
	BuildingsSuite.new(self).run()
	ProgressionSuite.new(self).run()
	AnimationSuite.new(self).run()
	AudioSuite.new(self).run()
	InterfaceSuite.new(self).run()
	ArchitectureSuite.run(self)
	print("TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

## Создаёт изолированный экземпляр игры с отключёнными стартовыми экранами.
func make_game() -> Node:
	var game := GameScript.new()
	game._ready()
	game.language_screen = false
	game.title_screen = false
	return game

## Создаёт клавиатурное событие с заданными логической и физической клавишами.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	return event

## Регистрирует успешную или проваленную проверку с понятным названием.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)
