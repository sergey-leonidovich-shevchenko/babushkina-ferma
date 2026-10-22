class_name TalentInputSystem
extends RefCounted

## Обрабатывает клавиатуру и геймпад дерева талантов, сохраняя навигацию независимой от главного игрового узла.
static func handle(game: Node, event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		var previous_selected: int = game.skill_menu_selected
		var was_open: bool = game.skill_menu_open
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: game.skill_menu_selected = posmod(game.skill_menu_selected - 5, game.TalentSystem.TALENTS.size())
			JOY_BUTTON_DPAD_RIGHT: game.skill_menu_selected = posmod(game.skill_menu_selected + 5, game.TalentSystem.TALENTS.size())
			JOY_BUTTON_DPAD_UP: game.skill_menu_selected = posmod(game.skill_menu_selected - 1, game.TalentSystem.TALENTS.size())
			JOY_BUTTON_DPAD_DOWN: game.skill_menu_selected = posmod(game.skill_menu_selected + 1, game.TalentSystem.TALENTS.size())
			JOY_BUTTON_A: game.UiFeedbackSystem.press(game, game.TalentRenderer.node_rect(game.skill_menu_selected)); game.TalentSystem.unlock(game, game.TalentSystem.at(game.skill_menu_selected).id)
			JOY_BUTTON_X: game.UiFeedbackSystem.press(game, game.TalentRenderer.RESPEC_BUTTON); game.TalentSystem.respec(game)
			JOY_BUTTON_LEFT_SHOULDER: game.CompanionSystem.cycle_command(game)
			JOY_BUTTON_Y, JOY_BUTTON_B, JOY_BUTTON_START: game.skill_menu_open = false
		sync_feedback(game, previous_selected, was_open); game.queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var previous_selected: int = game.skill_menu_selected
	var was_open: bool = game.skill_menu_open
	match event.keycode:
		KEY_ESCAPE, KEY_K: game.skill_menu_open = false
		KEY_C: game.CompanionSystem.cycle_command(game)
		KEY_R: game.UiFeedbackSystem.press(game, game.TalentRenderer.RESPEC_BUTTON); game.TalentSystem.respec(game)
		KEY_LEFT: game.skill_menu_selected = posmod(game.skill_menu_selected - 5, game.TalentSystem.TALENTS.size())
		KEY_RIGHT: game.skill_menu_selected = posmod(game.skill_menu_selected + 5, game.TalentSystem.TALENTS.size())
		KEY_UP: game.skill_menu_selected = posmod(game.skill_menu_selected - 1, game.TalentSystem.TALENTS.size())
		KEY_DOWN: game.skill_menu_selected = posmod(game.skill_menu_selected + 1, game.TalentSystem.TALENTS.size())
		KEY_ENTER, KEY_E: game.UiFeedbackSystem.press(game, game.TalentRenderer.node_rect(game.skill_menu_selected)); game.TalentSystem.unlock(game, game.TalentSystem.at(game.skill_menu_selected).id)
	sync_feedback(game, previous_selected, was_open); game.queue_redraw()


## Синхронизирует фокус и возврат книги талантов после изменения выбора или закрытия окна.
static func sync_feedback(game: Node, previous_selected: int, was_open: bool) -> void:
	if was_open and not game.skill_menu_open:
		game.UiFeedbackSystem.back(game)
	elif previous_selected != game.skill_menu_selected:
		game.UiFeedbackSystem.focus(game, "talent:%d" % game.skill_menu_selected)
