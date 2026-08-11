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


## Создаёт событие оси с геймпада с заданной осью и значением.
func joypad_motion_event(axis: int, axis_value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


## Создаёт событие кнопки геймпада с заданным индексом и состоянием.
func joypad_button_event(button_index: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = pressed
	return event
