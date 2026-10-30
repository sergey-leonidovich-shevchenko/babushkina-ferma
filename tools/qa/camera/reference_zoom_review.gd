extends SceneTree
const Suite := preload("res://tests/suites/reference_zoom_suite.gd")
const GameScript := preload("res://scripts/game.gd")
var passed := 0
var failed := 0

## Изолирует профиль тестов от пользовательских слотов и выполняет production-камеру без GPU-претензий.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VCAMERA-006-Tests-"+str(OS.get_process_id()))
	Suite.run(self)
	if "--regression" in OS.get_cmdline_user_args():
		preload("res://tests/suites/world_design_suite.gd").new(self).run()
		preload("res://tests/suites/tree_occlusion_suite.gd").new(self).run()
		preload("res://tests/suites/livestock_suite.gd").new(self).run()
		preload("res://tests/suites/living_world_suite.gd").new(self).run()
	print("REFERENCE ZOOM: ",passed," passed, ",failed," failed")
	var expected_count:=2225 if "--regression" in OS.get_cmdline_user_args() else 382
	quit(0 if failed==0 and passed==expected_count else 2)

## Регистрирует настоящее утверждение; отказ сохраняется как ошибка, а не меняет ожидаемые координаты.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)

## Создаёт ту же detached-игру, что полный test_game; координаты и стоимость GPU этим не подменяются.
func make_game() -> Node:
	var game:=GameScript.new(); game._ready(); game.LocaleSystem.set_locale("ru")
	game.language_screen=false; game.title_screen=false
	return game

## Сохраняет стандартный конструктор клавиатурных событий для адресной регрессии F10.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=keycode; event.physical_keycode=physical_keycode; event.pressed=pressed
	return event
