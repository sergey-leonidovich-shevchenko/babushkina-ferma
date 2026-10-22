extends RefCounted

const Apiary := preload("res://scripts/systems/apiary_system.gd")
const Render := preload("res://scripts/presentation/apiary_renderer.gd")

## Проверяет временное окно пасеки без создания сохраняемой памяти при каждом событии.
static func active(game: Node) -> bool:
	return bool(game.get_meta("apiary_ui",{}).get("open",false))

## Закрывает окно и очищает удержанные действия, не изменяя оплаченный улей и его запас.
static func close(game: Node) -> void:
	game.remove_meta("apiary_ui"); game.clear_movement_keys(); game.action_held=false; game.attack_held=false; game.queue_redraw()

## Выполняет основную кнопку только над проверенным рабочим экземпляром.
static func primary(game: Node) -> void:
	var item:=Apiary.selected(game)
	if item.is_empty(): return
	if item.level==0: Apiary.construct(game)
	elif not item.colonized: Apiary.populate(game)
	elif item.stock.values().any(func(count): return int(count)>0): Apiary.harvest(game)
	else: game.message=game.LocaleSystem.ui("apiary_primary_wait")

## Держит все устройства в одном модальном маршруте и не пропускает удары или движение под окном.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not active(game): return false
	if Apiary.selected(game).is_empty(): close(game); return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE,KEY_E]: close(game)
		elif event.keycode==KEY_ENTER: primary(game)
		elif event.keycode==KEY_U: Apiary.construct(game)
		elif event.keycode==KEY_DELETE: Apiary.dismantle(game)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_B: close(game)
		elif event.button_index==JOY_BUTTON_A: primary(game)
		elif event.button_index==JOY_BUTTON_Y: Apiary.construct(game)
		elif event.button_index==JOY_BUTTON_LEFT_STICK: Apiary.dismantle(game)
	elif (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		var point:Vector2=event.position
		if game.ItemWindowRenderer.close_button_rect(game).has_point(point): close(game)
		elif Render.PRIMARY.has_point(point): primary(game)
		elif Render.UPGRADE.has_point(point): Apiary.construct(game)
		elif Render.DISMANTLE.has_point(point): Apiary.dismantle(game)
	game.queue_redraw(); return true
