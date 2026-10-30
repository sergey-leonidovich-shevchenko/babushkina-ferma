extends SceneTree

const Game := preload("res://scripts/game.gd")
var passed:=0
var failed:=0

## Запускает профильные проверки алхимии до общего обязательного quality gate.
func _initialize() -> void:
	var game:=make_game()
	expect(game.ContentRegistry.validate().is_empty(),"expanded alchemy catalog has valid references")
	expect(game.ForageSystem.TYPES.size()==32,"twenty-four new wild herbs join eight historical types")
	var report:Dictionary=game.UiLayoutAuditSystem.project_report(game)
	if int(report.failed)>0: print(JSON.stringify(report.issues))
	expect(int(report.failed)==0,"alchemy names, effects and actual recipe rows pass full six-language layout audit")
	game.free(); preload("res://tests/suites/alchemy_suite.gd").new(self).run()
	print("ALCHEMY REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Создаёт чистую игровую модель без внешних настроек и пользовательских сохранений.
func make_game() -> Node:
	var game:=Game.new(); game.audio_enabled=false; game._ready(); game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"; return game

## Записывает результат конкретного правила без подавления ошибок компиляции.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)

## Создаёт событие клавиши для общего маршрутизатора ввода рецептов.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=keycode; event.physical_keycode=physical_keycode; event.pressed=pressed; return event
