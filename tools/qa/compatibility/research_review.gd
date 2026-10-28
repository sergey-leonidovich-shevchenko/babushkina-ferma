extends SceneTree

const Game := preload("res://scripts/game.gd")
var passed:=0
var failed:=0

## Запускает профильные сценарии изучения и разборки независимо от общего обязательного набора.
func _initialize() -> void:
	var game:=make_game(); var errors:PackedStringArray=PackedStringArray(game.ContentRegistry.validate())
	expect(errors.is_empty(),"research content references are valid: "+", ".join(errors))
	var report:Dictionary=game.UiLayoutAuditSystem.project_report(game)
	if int(report.failed)>0: print(JSON.stringify(report.issues))
	expect(int(report.failed)==0,"new research and recovery content passes six-language layout audit"); game.free()
	preload("res://tests/suites/research_suite.gd").new(self).run()
	print("RESEARCH REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Создаёт отдельную игровую модель без загрузки и перезаписи пользовательских слотов.
func make_game() -> Node:
	var game:=Game.new(); game.audio_enabled=false; game._ready(); game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"; return game

## Регистрирует утверждение о видимом поведении и сохраняет сообщение при отказе.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)

## Создаёт обычное клавиатурное событие для предметного окна.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=keycode; event.physical_keycode=physical_keycode; event.pressed=pressed; return event

## Создаёт обычное событие кнопки геймпада для предметного окна.
func joypad_button_event(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event:=InputEventJoypadButton.new(); event.button_index=button; event.pressed=pressed; return event
