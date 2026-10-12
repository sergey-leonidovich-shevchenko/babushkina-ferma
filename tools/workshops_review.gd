extends SceneTree

const Game := preload("res://scripts/game.gd")
var passed:=0
var failed:=0

## Запускает профильные производственные сценарии вместе с реестром и всеми языковыми окнами.
func _initialize() -> void:
	var game:=make_game(); var errors:PackedStringArray=PackedStringArray(game.ContentRegistry.validate())
	expect(errors.is_empty(),"workshop content references are valid: "+", ".join(errors))
	var report:Dictionary=game.UiLayoutAuditSystem.project_report(game)
	if int(report.failed)>0: print(JSON.stringify(report.issues))
	expect(int(report.failed)==0,"all new products and workshops pass six-language layout audit"); game.free()
	preload("res://tests/suites/workshop_suite.gd").new(self).run()
	preload("res://tests/suites/furnace_suite.gd").new(self).run()
	preload("res://tests/suites/research_suite.gd").new(self).run()
	print("WORKSHOPS REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Создаёт изолированную игровую модель без пользовательских слотов.
func make_game() -> Node:
	var game:=Game.new(); game.audio_enabled=false; game._ready(); game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"; return game

## Учитывает проверку наблюдаемого результата и выдаёт подробный отказ.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)

## Создаёт обычное событие клавиатуры для производственного меню.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=keycode; event.physical_keycode=physical_keycode; event.pressed=pressed; return event

## Создаёт обычное событие кнопки геймпада для производственного меню.
func joypad_button_event(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event:=InputEventJoypadButton.new(); event.button_index=button; event.pressed=pressed; return event
