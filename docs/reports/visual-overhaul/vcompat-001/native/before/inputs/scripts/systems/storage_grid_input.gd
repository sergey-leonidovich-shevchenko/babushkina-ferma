extends RefCounted

const Grid := preload("res://scripts/systems/storage_grid_system.gd")
const Layout := preload("res://scripts/presentation/storage_grid_layout.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Actions := preload("res://scripts/systems/storage_actions_system.gd")

## Сбрасывает только результаты и прокрутку шкафа после ввода поискового текста.
static func query(game: Node, text: String) -> void:
	var value:=Cabinet.state(game); value.query=text.left(64); value.selected=0; value.notice=""; value.cache.clear()
	Grid.state(game,true).rows[1]=0; Grid.select(game,true,1,0)

## Обрабатывает редактирование поиска раньше команд массового переноса и сортировки.
static func search_key(game: Node, event: InputEventKey) -> void:
	var value:=Cabinet.state(game)
	if event.keycode in [KEY_ESCAPE,KEY_ENTER]: value.searching=false
	elif event.keycode==KEY_BACKSPACE: query(game,"" if event.ctrl_pressed else String(value.query).left(maxi(0,String(value.query).length()-1)))
	elif event.keycode==KEY_DELETE: query(game,"")
	elif event.unicode>=32 and not event.ctrl_pressed and not event.meta_pressed: query(game,String(value.query)+String.chr(event.unicode))

## Закрывает только активное хранилище, не оставляя удержания мировых действий.
static func close(game: Node, cabinet: bool) -> void:
	if cabinet: Cabinet.close(game)
	else: game.storage_open=false; game.clear_movement_keys(); game.action_held=false; game.attack_held=false

## Разделяет явные кнопки, фокус сетки и перетаскивание полосы прокрутки.
static func pointer(game: Node, point: Vector2, cabinet: bool) -> void:
	if Layout.CLOSE.has_point(point): close(game,cabinet); return
	if cabinet:
		Cabinet.state(game).searching=Layout.SEARCH.has_point(point)
		if Cabinet.state(game).searching: return
		if Layout.REFILL.has_point(point): Cabinet.refill(game); return
		for index in Cabinet.TABS.size():
			if Rect2(40+index*134,96,128,34).has_point(point): Cabinet.select_tab(game,index); Grid.state(game,true).rows[1]=0; Grid.select(game,true,1,0); return
	if preload("res://scripts/presentation/storage_actions_renderer.gd").pointer(game,point,cabinet): return
	for index in 4:
		if Layout.transfer(index).has_point(point): Grid.transfer(game,cabinet,[1,10,100,999 if cabinet else -1][index]); return
	if not Grid.begin_drag(game,cabinet,point): Grid.focus(game,cabinet,point)

## Двигает фокус в сетке, а Tab сохраняет отдельный выбор противоположного инвентаря.
static func keyboard(game: Node, event: InputEventKey, cabinet: bool) -> void:
	if cabinet and Cabinet.state(game).searching: search_key(game,event); return
	if Actions.handle_input(game,event,cabinet): return
	var value:=Grid.state(game,cabinet); var side:int=value.side; var columns:=Layout.columns(side)
	match event.keycode:
		KEY_ESCAPE: close(game,cabinet)
		KEY_C:
			if not cabinet: close(game,false)
		KEY_TAB: Grid.switch_side(game,cabinet)
		KEY_F,KEY_SLASH:
			if cabinet: Cabinet.state(game).searching=true
		KEY_Q,KEY_E:
			if cabinet: Cabinet.select_tab(game,int(Cabinet.state(game).tab)+(-1 if event.keycode==KEY_Q else 1)); value.rows[1]=0; Grid.select(game,true,1,0)
		KEY_LEFT: Grid.move(game,cabinet,-1)
		KEY_RIGHT: Grid.move(game,cabinet,1)
		KEY_UP: Grid.move(game,cabinet,-columns)
		KEY_DOWN: Grid.move(game,cabinet,columns)
		KEY_PAGEUP: Grid.move(game,cabinet,-columns*Layout.ROWS)
		KEY_PAGEDOWN: Grid.move(game,cabinet,columns*Layout.ROWS)
		KEY_HOME: Grid.select(game,cabinet,side,0)
		KEY_END: Grid.select(game,cabinet,side,Grid.items(game,cabinet,side).size()-1)
		KEY_R:
			if cabinet: Cabinet.refill(game)
		KEY_ENTER,KEY_SPACE: Grid.transfer(game,cabinet,(999 if cabinet else -1) if event.ctrl_pressed else (100 if event.shift_pressed else 1))
		KEY_X: Grid.transfer(game,cabinet,100 if cabinet else -1)

## Использует ту же геометрию для геймпада и гасит повтор аналогового движения до отпускания стика.
static func controller(game: Node, event: InputEvent, cabinet: bool) -> void:
	if Actions.handle_input(game,event,cabinet): return
	var value:=Grid.state(game,cabinet); var columns:=Layout.columns(value.side)
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B: close(game,cabinet)
			JOY_BUTTON_A: Grid.transfer(game,cabinet,1)
			JOY_BUTTON_X: Grid.transfer(game,cabinet,100 if cabinet else -1)
			JOY_BUTTON_Y: Grid.transfer(game,cabinet,999 if cabinet else -1)
			JOY_BUTTON_LEFT_STICK: Grid.switch_side(game,cabinet)
			JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER:
				if cabinet: Cabinet.select_tab(game,int(Cabinet.state(game).tab)+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1)); value.rows[1]=0; Grid.select(game,true,1,0)
				else: Grid.switch_side(game,false)
			JOY_BUTTON_DPAD_LEFT: Grid.move(game,cabinet,-1)
			JOY_BUTTON_DPAD_RIGHT: Grid.move(game,cabinet,1)
			JOY_BUTTON_DPAD_UP: Grid.move(game,cabinet,-columns)
			JOY_BUTTON_DPAD_DOWN: Grid.move(game,cabinet,columns)
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var direction:=signi(int(event.axis_value*10)) if absf(event.axis_value)>=0.5 else 0
		if direction!=0 and int(value.axes.get(event.axis,0))!=direction: Grid.move(game,cabinet,direction*(columns if event.axis==JOY_AXIS_LEFT_Y else 1))
		value.axes[event.axis]=direction

## Перехватывает весь ввод окна, включая независимое колесо, бегунок и вертикальный свайп сетки.
static func handle(game: Node, event: InputEvent, cabinet: bool) -> void:
	var value:=Grid.state(game,cabinet)
	if event is InputEventKey and event.pressed and not event.echo: keyboard(game,event,cabinet)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion: controller(game,event,cabinet)
	elif event is InputEventMouseMotion:
		if int(value.drag)>=0: Grid.drag(game,cabinet,event.position)
		elif not cabinet or not Cabinet.state(game).searching: Grid.focus(game,cabinet,event.position)
	elif event is InputEventMouseButton:
		if not event.pressed: value.drag=-1
		elif event.button_index==MOUSE_BUTTON_LEFT: pointer(game,event.position,cabinet)
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var side:=Grid.side_at(event.position)
			if side>=0: Grid.scroll(game,cabinet,side,-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
	elif event is InputEventScreenTouch:
		if event.pressed: value.touch=Grid.side_at(event.position); value.touch_y=event.position.y; pointer(game,event.position,cabinet)
		else: value.drag=-1; value.touch=-1
	elif event is InputEventScreenDrag:
		if int(value.drag)>=0: Grid.drag(game,cabinet,event.position)
		elif int(value.touch)>=0:
			var rows:=int((float(value.touch_y)-event.position.y)/64)
			if rows!=0: Grid.scroll(game,cabinet,value.touch,rows); value.touch_y=float(value.touch_y)-rows*64
	game.queue_redraw()
