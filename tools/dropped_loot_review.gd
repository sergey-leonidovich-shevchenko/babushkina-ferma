extends SceneTree

const Game := preload("res://scripts/game.gd")
var passed:=0
var failed:=0

## Проверяет полный шкаф, прежний домашний сундук, кузницу, доступ в здания и локализованную геометрию интерфейса.
func _initialize() -> void:
	preload("res://tests/suites/dropped_loot_suite.gd").new(self).run()
	preload("res://tests/suites/core_suite.gd").new(self).run()
	preload("res://tests/suites/cave_labyrinth_suite.gd").new(self).run()
	preload("res://tests/suites/story_relic_arena_suite.gd").new(self).run()

	print("DROPPED LOOT REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Создаёт изолированную игровую модель без доступа к пользовательским слотам.
func make_game() -> Node:
	var game:=Game.new(); game._ready(); game.language_screen=false; game.title_screen=false; game.LocaleSystem.set_locale("ru"); return game

## Считает поведенческие утверждения и печатает причину каждого отказа.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)

## Создаёт обычное нажатие или отпускание для проверки реального удержания.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var value:=InputEventKey.new(); value.keycode=keycode; value.physical_keycode=physical_keycode; value.pressed=pressed; return value

## Создаёт обычную кнопку геймпада для производственных регрессий.
func joypad_button_event(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var value:=InputEventJoypadButton.new(); value.button_index=button; value.pressed=pressed; return value
