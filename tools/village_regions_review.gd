extends SceneTree

const Game := preload("res://scripts/game.gd")
var passed:=0
var failed:=0

## Проверяет районы, расселение, прежние миссии, первую главу, пещерные проходы и языковой интерфейс.
func _initialize() -> void:
	preload("res://tests/suites/village_regions_suite.gd").new(self).run()
	preload("res://tests/suites/story_suite.gd").new(self).run()
	preload("res://tests/suites/story_relic_arena_suite.gd").new(self).run()
	preload("res://tests/suites/alchemy_suite.gd").new(self).run()
	preload("res://tests/suites/living_world_suite.gd").new(self).run()
	preload("res://tests/suites/first_chapter_suite.gd").new(self).run()
	preload("res://tests/suites/cave_labyrinth_suite.gd").new(self).run()
	var game:=make_game(); var report:Dictionary=game.UiLayoutAuditSystem.project_report(game)
	for issue in report.issues: expect(false,str(issue))
	game.free(); print("VILLAGE REGIONS REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Создаёт отдельную игровую модель без пользовательских слотов и окон начала игры.
func make_game() -> Node:
	var game:=Game.new(); game._ready(); game.language_screen=false; game.title_screen=false; game.LocaleSystem.set_locale("ru"); return game

## Считает поведенческие утверждения и печатает каждый отказ вместе с его причиной.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)

## Даёт настоящее клавиатурное нажатие для общего маршрутизатора.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var value:=InputEventKey.new(); value.keycode=keycode; value.physical_keycode=physical_keycode; value.pressed=pressed; return value

## Даёт настоящую кнопку геймпада для проверки перехода между двумя видами карты.
func joypad_button_event(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var value:=InputEventJoypadButton.new(); value.button_index=button; value.pressed=pressed; return value
