extends RefCounted

const GameScript = preload("res://scripts/game.gd")

var context: SceneTree


func _init(test_context: SceneTree) -> void:
	context = test_context


func expect(condition: bool, label: String) -> void:
	context.expect(condition, label)


func make_game() -> Node:
	return context.make_game()


func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	return context.key_event(keycode, physical_keycode, pressed)
