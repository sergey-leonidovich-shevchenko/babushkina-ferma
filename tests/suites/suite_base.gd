extends RefCounted

const GameScript = preload("res://scripts/game.gd")

var context: SceneTree


## Сохраняет зависимости, переданные при создании объекта.
func _init(test_context: SceneTree) -> void:
	context = test_context


## Регистрирует успешную или проваленную проверку с понятным названием.
func expect(condition: bool, label: String) -> void:
	context.expect(condition, label)


## Создаёт изолированный экземпляр игры с отключёнными стартовыми экранами.
func make_game() -> Node:
	return context.make_game()


## Создаёт клавиатурное событие с заданными логической и физической клавишами.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	return context.key_event(keycode, physical_keycode, pressed)
