extends RefCounted

const System := preload("res://scripts/systems/qa_teleport_system.gd")
const Layout := preload("res://scripts/presentation/qa_teleport_renderer.gd")

## Перехватывает все события списка до игровых действий, включая отпускание кнопок и касания.
static func handle(game: Node, event: InputEvent) -> bool:
	if not System.active(game): return false
	var value := System.state(game)
	if event is InputEventKey and event.pressed:
		if value.searching:
			if event.keycode in [KEY_ESCAPE, KEY_ENTER]: value.searching = false
			elif event.keycode == KEY_BACKSPACE: value.query = String(value.query).left(-1); System.select(game,0)
			elif event.unicode >= 32 and not event.ctrl_pressed and not event.meta_pressed:
				value.query = (String(value.query)+char(event.unicode)).left(64); System.select(game,0)
		elif not event.echo:
			match event.keycode:
				KEY_ESCAPE: System.close(game)
				KEY_F: value.searching = true
				KEY_UP: System.select(game,value.selected-1)
				KEY_DOWN: System.select(game,value.selected+1)
				KEY_HOME: System.select(game,0)
				KEY_END: System.select(game,System.entries(game).size()-1)
				KEY_PAGEUP: System.select(game,value.selected-System.ROWS)
				KEY_PAGEDOWN: System.select(game,value.selected+System.ROWS)
				KEY_TAB: cycle(game,-1 if event.shift_pressed else 1)
				KEY_ENTER: confirm(game)
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B: System.close(game)
			JOY_BUTTON_A: confirm(game)
			JOY_BUTTON_DPAD_UP: System.select(game,value.selected-1)
			JOY_BUTTON_DPAD_DOWN: System.select(game,value.selected+1)
			JOY_BUTTON_LEFT_SHOULDER: cycle(game,-1)
			JOY_BUTTON_RIGHT_SHOULDER: cycle(game,1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: pointer(game,event.position)
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and Layout.LIST.has_point(event.position):
			System.select(game,value.selected+(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1))
	if event is InputEventScreenTouch and event.pressed: value.drag = 0.0; pointer(game,event.position)
	if event is InputEventScreenDrag and Layout.LIST.has_point(event.position):
		value.drag += event.relative.y
		if absf(value.drag) >= 37: System.select(game,value.selected+(-1 if value.drag>0 else 1)); value.drag = 0.0
	game.queue_redraw()
	return true

## Меняет раздел и сбрасывает положение списка, сохраняя введённый поисковый запрос.
static func cycle(game: Node, offset: int) -> void:
	var value := System.state(game)
	value.group = System.GROUPS[posmod(System.GROUPS.find(value.group)+offset,System.GROUPS.size())]
	value.searching = false; System.select(game,0)

## Выполняет перенос только отдельной командой подтверждения по непустому выбору.
static func confirm(game: Node) -> bool:
	var ids := System.entries(game); var value := System.state(game)
	return System.travel(game,ids[clampi(value.selected,0,ids.size()-1)]) if not ids.is_empty() else false

## Отличает безопасный осмотр строки от кнопки переноса для мыши и сенсорного экрана.
static func pointer(game: Node, point: Vector2) -> void:
	if Layout.CLOSE.has_point(point): System.close(game); return
	var value := System.state(game); value.searching = Layout.SEARCH.has_point(point)
	for index in System.GROUPS.size():
		if Layout.tab_rect(index).has_point(point): value.group = System.GROUPS[index]; System.select(game,0); return
	if Layout.USE.has_point(point): confirm(game); return
	for row in System.ROWS:
		if Layout.row_rect(row).has_point(point): System.select(game,value.scroll+row); return
