extends RefCounted

const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Render := preload("res://scripts/presentation/dev_cabinet_renderer.gd")

## Меняет выделение только в допустимых результатах текущего поиска.
static func move(game: Node, offset: int) -> void:
	var value:=Cabinet.state(game); var choices:=Cabinet.items(game)
	value.selected=clampi(int(value.selected)+offset,0,maxi(0,choices.size()-1)); value.notice=""; game.queue_redraw()

## Обновляет текстовый поиск, сбрасывая страницу и ограничивая память временного кэша.
static func query(game: Node, text: String) -> void:
	var value:=Cabinet.state(game); value.query=text.left(64); value.selected=0; value.notice=""; value.cache.clear(); game.queue_redraw()

## Фокусирует существующий предмет текущей страницы без выдачи вещей и без выхода из поиска.
static func focus_slot(game: Node, point: Vector2) -> bool:
	var value:=Cabinet.state(game)
	if value.searching: return false
	var choices:=Cabinet.items(game); var first:=Render.start(game)
	for visible in mini(Render.VISIBLE,choices.size()-first):
		if not Render.slot_rect(visible).has_point(point): continue
		var index:=first+visible
		if int(value.selected)==index: return false
		value.selected=index; value.notice=""; game.queue_redraw(); return true
	return false

## Передаёт указатель явным вкладкам, поиску, навигации и четырём кнопкам выдачи.
static func pointer(game: Node, point: Vector2) -> void:
	var value:=Cabinet.state(game)
	if Render.CLOSE.has_point(point): Cabinet.close(game); return
	value.searching=Render.SEARCH.has_point(point)
	if value.searching: return
	if preload("res://scripts/presentation/storage_actions_renderer.gd").pointer(game,point,true): return
	if Render.REFILL.has_point(point): Cabinet.refill(game); return
	for index in Cabinet.TABS.size():
		if Render.tab_rect(index).has_point(point): Cabinet.select_tab(game,index); return
	if Render.PREVIOUS.has_point(point): move(game,-Render.VISIBLE); return
	if Render.NEXT.has_point(point): move(game,Render.VISIBLE); return
	for index in Render.AMOUNTS.size():
		if Render.take_rect(index).has_point(point):
			var kind:=Cabinet.selected(game)
			if kind not in Cabinet.UNIQUE or index==0: Cabinet.take(game,kind,Render.AMOUNTS[index])
			return
	focus_slot(game,point)

## Принимает печать в поиске отдельно от игровых горячих клавиш и позволяет сначала снять фокус.
static func search_key(game: Node, event: InputEventKey) -> void:
	var value:=Cabinet.state(game)
	if event.keycode in [KEY_ESCAPE,KEY_ENTER]: value.searching=false
	elif event.keycode==KEY_BACKSPACE: query(game,"" if event.ctrl_pressed else String(value.query).left(maxi(0,String(value.query).length()-1)))
	elif event.keycode==KEY_DELETE: query(game,"")
	elif event.unicode>=32 and not event.ctrl_pressed and not event.meta_pressed: query(game,String(value.query)+String.chr(event.unicode))

## Обрабатывает выбор, вкладки, поиск и выдачу без проникновения нажатий в игровой мир.
static func keyboard(game: Node, event: InputEventKey) -> void:
	var value:=Cabinet.state(game)
	if value.searching: search_key(game,event); return
	if preload("res://scripts/systems/storage_actions_system.gd").handle_input(game,event,true): return
	match event.keycode:
		KEY_ESCAPE: Cabinet.close(game)
		KEY_F,KEY_SLASH: value.searching=true
		KEY_TAB,KEY_Q,KEY_E: Cabinet.select_tab(game,int(value.tab)+(-1 if event.keycode==KEY_Q or (event.keycode==KEY_TAB and event.shift_pressed) else 1))
		KEY_LEFT: move(game,-1)
		KEY_RIGHT: move(game,1)
		KEY_UP: move(game,-Render.COLUMNS)
		KEY_DOWN: move(game,Render.COLUMNS)
		KEY_PAGEUP: move(game,-Render.VISIBLE)
		KEY_PAGEDOWN: move(game,Render.VISIBLE)
		KEY_HOME: value.selected=0
		KEY_END: value.selected=maxi(0,Cabinet.items(game).size()-1)
		KEY_R: Cabinet.refill(game)
		KEY_ENTER: Cabinet.take(game,Cabinet.selected(game),999 if event.ctrl_pressed else (100 if event.shift_pressed else 1))

## Держит геймпад в одном слое и переключает аналоговый выбор один раз при пересечении порога.
static func controller(game: Node, event: InputEvent) -> void:
	if preload("res://scripts/systems/storage_actions_system.gd").handle_input(game,event,true): return
	var value:=Cabinet.state(game)
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B: Cabinet.close(game)
			JOY_BUTTON_A: Cabinet.take(game,Cabinet.selected(game),1)
			JOY_BUTTON_X: Cabinet.take(game,Cabinet.selected(game),100)
			JOY_BUTTON_Y: Cabinet.take(game,Cabinet.selected(game),999)
			JOY_BUTTON_LEFT_SHOULDER: Cabinet.select_tab(game,int(value.tab)-1)
			JOY_BUTTON_RIGHT_SHOULDER: Cabinet.select_tab(game,int(value.tab)+1)
			JOY_BUTTON_DPAD_LEFT: move(game,-1)
			JOY_BUTTON_DPAD_RIGHT: move(game,1)
			JOY_BUTTON_DPAD_UP: move(game,-Render.COLUMNS)
			JOY_BUTTON_DPAD_DOWN: move(game,Render.COLUMNS)
			JOY_BUTTON_LEFT_STICK: Cabinet.refill(game)
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var direction:=signi(int(event.axis_value*10)) if absf(event.axis_value)>=0.5 else 0
		if direction!=0 and int(value.axes.get(event.axis,0))!=direction: move(game,direction*(Render.COLUMNS if event.axis==JOY_AXIS_LEFT_Y else 1))
		value.axes[event.axis]=direction

## Перехватывает весь ввод открытого шкафа раньше рюкзака, боя и движения персонажа.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not Cabinet.active(game): return false
	if not Cabinet.at_cabinet(game): Cabinet.close(game); return true
	if event is InputEventMouseMotion: focus_slot(game,event.position); return true
	if event is InputEventKey and event.pressed and not event.echo: keyboard(game,event)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion: controller(game,event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: pointer(game,event.position)
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP: move(game,-Render.COLUMNS)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: move(game,Render.COLUMNS)
	elif event is InputEventScreenTouch and event.pressed: pointer(game,event.position)
	game.queue_redraw(); return true
