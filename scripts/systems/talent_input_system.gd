class_name TalentInputSystem
extends RefCounted

## Обрабатывает клавиатуру и геймпад дерева талантов, сохраняя навигацию независимой от главного игрового узла.
static func handle(game: Node, event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: game.skill_menu_selected = posmod(game.skill_menu_selected - 5, game.TalentSystem.TALENTS.size())
			JOY_BUTTON_DPAD_RIGHT: game.skill_menu_selected = posmod(game.skill_menu_selected + 5, game.TalentSystem.TALENTS.size())
			JOY_BUTTON_DPAD_UP: game.skill_menu_selected = posmod(game.skill_menu_selected - 1, game.TalentSystem.TALENTS.size())
			JOY_BUTTON_DPAD_DOWN: game.skill_menu_selected = posmod(game.skill_menu_selected + 1, game.TalentSystem.TALENTS.size())
			JOY_BUTTON_A: game.TalentSystem.unlock(game, game.TalentSystem.at(game.skill_menu_selected).id)
			JOY_BUTTON_X: game.TalentSystem.respec(game)
			JOY_BUTTON_Y, JOY_BUTTON_B, JOY_BUTTON_START: game.skill_menu_open = false
		game.queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE, KEY_K: game.skill_menu_open = false
		KEY_R: game.TalentSystem.respec(game)
		KEY_LEFT: game.skill_menu_selected = posmod(game.skill_menu_selected - 5, game.TalentSystem.TALENTS.size())
		KEY_RIGHT: game.skill_menu_selected = posmod(game.skill_menu_selected + 5, game.TalentSystem.TALENTS.size())
		KEY_UP: game.skill_menu_selected = posmod(game.skill_menu_selected - 1, game.TalentSystem.TALENTS.size())
		KEY_DOWN: game.skill_menu_selected = posmod(game.skill_menu_selected + 1, game.TalentSystem.TALENTS.size())
		KEY_ENTER, KEY_E: game.TalentSystem.unlock(game, game.TalentSystem.at(game.skill_menu_selected).id)
	game.queue_redraw()
