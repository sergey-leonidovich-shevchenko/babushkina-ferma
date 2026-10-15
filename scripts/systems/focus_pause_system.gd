extends RefCounted

const META := &"application_focus_pause"

## Возвращает только временную память фокуса, отдельную от ручной паузы и игрового слота.
static func state(game: Node) -> Dictionary:
	if not game.has_meta(META): game.set_meta(META,{"focused":true,"suspended":false})
	return game.get_meta(META)

## Обрабатывает настоящие уведомления платформы, сбрасывая удержание при уходе и возвращении.
static func handle_notification(game: Node, what: int) -> void:
	match what:
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT: state(game).focused=false
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN: state(game).focused=true
		MainLoop.NOTIFICATION_APPLICATION_PAUSED: state(game).suspended=true
		MainLoop.NOTIFICATION_APPLICATION_RESUMED: state(game).suspended=false
		_: return
	release_inputs(game)

## Отделяет автоматическую паузу от меню; настройка явно разрешает стендам фоновую симуляцию.
static func blocked(game: Node) -> bool:
	if not game.settings_state.pause_on_focus_loss: return false
	var value:=state(game)
	if not value.focused or value.suspended: return true
	return game.is_inside_tree() and DisplayServer.get_name()!="headless" and (not DisplayServer.window_is_focused() or DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED)

## Сохраняет служебные кадры, не позволяя потерянному отпусканию кнопки возобновить действие.
static func update(game: Node) -> void:
	if blocked(game): release_inputs(game)

## Сбрасывает клавиши, атаку, блок и физическое удержание стройки, сохраняя начатую боевую фазу и оплаченную работу.
static func release_inputs(game: Node) -> void:
	game.clear_movement_keys(); game.state.player.blocking=false
	if game.has_meta("basement_ui"):
		var ui:Dictionary=game.get_meta("basement_ui"); ui.holding=0; ui.touch_id=-1
