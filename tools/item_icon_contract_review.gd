extends SceneTree

const Game := preload("res://scripts/game.gd")
var passed:=0
var failed:=0

## Запускает только регрессии общего контракта иконок без чтения слотов пользователя.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","MoonValleyIconContractReview")
	preload("res://tests/suites/item_icon_contract_suite.gd").new(self).run()
	print("ICON CONTRACT REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Создаёт отделённую игровую модель с загруженным реестром и локалью проверки.
func make_game() -> Node:
	var game:=Game.new(); game._ready(); game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"; return game

## Регистрирует проверку с текстом причины отказа для контроля журналов.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)
