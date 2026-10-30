extends SceneTree

const Game := preload("res://scripts/game.gd")
var passed:=0
var failed:=0

## Выполняет профильные сценарии печи отдельно от большого обязательного набора.
func _initialize() -> void:
	var game:=make_game(); var errors:PackedStringArray=PackedStringArray(game.ContentRegistry.validate())
	expect(errors.is_empty(),"furnace content references are valid: "+", ".join(errors))
	var report:Dictionary=game.UiLayoutAuditSystem.project_report(game)
	if int(report.failed)>0: print(JSON.stringify(report.issues))
	expect(int(report.failed)==0,"furnace controls and all item windows pass six-locale typography audit"); game.free()
	preload("res://tests/suites/furnace_suite.gd").new(self).run()
	print("FURNACE REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Создаёт изолированную модель без записи пользовательских слотов.
func make_game() -> Node:
	var game:=Game.new(); game.audio_enabled=false; game._ready(); game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"; return game

## Регистрирует проверку конкретного наблюдаемого правила.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)

## Создаёт событие для обычного управления окном рецептов.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=keycode; event.physical_keycode=physical_keycode; event.pressed=pressed; return event
