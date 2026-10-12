extends RefCounted

const Basement := preload("res://scripts/systems/basement_system.gd")
const Build := preload("res://scripts/systems/basement_construction_system.gd")
const Stations := preload("res://scripts/systems/basement_station_system.gd")
const Locale := preload("res://scripts/systems/basement_locale.gd")
const Camera := preload("res://scripts/systems/camera_system.gd")
const TABS := [Rect2(210,120,150,28),Rect2(366,120,150,28),Rect2(522,120,150,28)]
const ACTION := Rect2(714,500,216,40)
const HOLD := Rect2(934,506,200,48)
const PAGES := [Rect2(684,120,32,28),Rect2(724,120,32,28)]
const PLACE_BUTTONS := [Rect2(270,564,84,36),Rect2(360,564,84,36),Rect2(450,564,242,36),Rect2(698,564,184,36)]

## Даёт каталог видов либо список конкретных экземпляров выбранного раздела чертежа.
static func choices(game: Node) -> Array:
	return Basement.Data.STATIONS.keys() if int(Basement.ui(game).tab)==0 else Basement.state(game).objects

## Совмещает прокрутку видимых строк с клавиатурным выбором.
static func first(game: Node) -> int:
	return clampi(int(Basement.ui(game).selected)-3,0,maxi(0,choices(game).size()-8))

## Возвращает выбранный вид или экземпляр вместе с его точной стоимостью и стадией работ.
static func selected(game: Node) -> Dictionary:
	var value:=Basement.ui(game); var entries:=choices(game)
	if entries.is_empty(): return {}
	value.selected=clampi(int(value.selected),0,entries.size()-1)
	if int(value.tab)==0: return {"kind":entries[int(value.selected)],"level":1,"phase":"new","inputs":Basement.Data.STATIONS[entries[int(value.selected)]].inputs}
	return entries[int(value.selected)]

## Переводит выбранное действие в предварительное размещение, оплачиваемое улучшение либо явный демонтаж.
static func execute(game: Node) -> bool:
	var value:=Basement.ui(game); var item:=selected(game)
	if not bool(value.open) or game.current_location!=Basement.Data.LOCATION or game.player.distance_to(Basement.Data.BOARD)>60: return false
	if item.is_empty(): return false
	if int(value.tab)==0:
		value.open=false; value.placing=true; value.kind=item.kind; value.direction=0; value.x=12; value.y=12; value.pointer=Vector2.ZERO
		value.cache_key=""; game.clear_movement_keys(); game.notify_tutorial("basement_place"); follow_cursor(game); return true
	return Build.upgrade(game,int(item.id)) if int(value.tab)==1 else Build.dismantle(game,int(item.id))

## Создаёт предварительное основание из целых координат, не списывая материалы при движении мыши.
static func candidate(game: Node) -> Dictionary:
	var value:=Basement.ui(game)
	return {"kind":value.kind,"x":int(value.x),"y":int(value.y),"direction":int(value.direction)}

## Кеширует геометрию и связность по клетке и ревизии, исключая полный поиск пути на каждом кадре.
static func preview(game: Node) -> Dictionary:
	var value:=Basement.ui(game); var item:=candidate(game)
	var key:="%s:%d:%d:%d:%d"%[item.kind,item.x,item.y,item.direction,Basement.state(game).revision]
	if value.cache_key!=key:
		value.cache_key=key; value.preview={"object":item,"geometry":Basement.Layout.reason(Basement.state(game).objects,item,game.player)}
	value.preview.reason=value.preview.geometry
	if value.preview.reason.is_empty(): value.preview.reason=Build.cost_reason(game,{"inputs":Basement.Data.STATIONS[item.kind].inputs})
	return value.preview

## Передвигает обзор всей мастерской за выбранной клеткой, оставляя героя у чертежа.
static func follow_cursor(game: Node) -> void:
	var target:=Basement.Layout.rect(candidate(game)).get_center(); var field:=Camera.playfield_rect(game)
	game.camera_offset=Vector2(Camera._room_axis(target.x,Basement.Data.ROOM.position.x,Basement.Data.ROOM.end.x,field.position.x,field.end.x,1152),Camera._room_axis(target.y,Basement.Data.ROOM.position.y,Basement.Data.ROOM.end.y,field.position.y,field.end.y,648)).round()
	game.queue_redraw()

## Меняет направление и размер основания, не вращая готовый растровый рисунок на боку.
static func rotate(game: Node, offset: int) -> void:
	Basement.ui(game).direction=posmod(int(Basement.ui(game).direction)+offset,4); follow_cursor(game)

## Обрабатывает чертёж, размещение и удержание с клавиатуры, геймпада, мыши и касания.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if game.current_location!=Basement.Data.LOCATION or game.title_screen or game.language_screen: return false
	var value:=Basement.ui(game)
	if _release(game,event): return true
	if game.menu_state.pause_open or game.menu_state.settings_open or game.menu_state.defeat_open: return false
	if bool(value.placing): return _placing(game,event)
	if bool(value.open): return _menu(game,event)
	if game.crafting_open or game.forge_open or game.inventory_open or game.storage_open: return false
	var interaction:=Basement.nearest(game)
	if not interaction.begins_with("basement_station:"): return false
	var item:=Basement.object(game,int(interaction.get_slice(":",1)))
	if item.phase=="ready": return false
	var press:bool=(event is InputEventKey and event.pressed and not event.echo and game.InputSystem.matches(event,"use_item")) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A)
	if event is InputEventScreenTouch and event.pressed and HOLD.has_point(event.position): value.touch_id=event.index; press=true
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and HOLD.has_point(event.position): value.touch_id=-2; press=true
	return Stations.interact(game,int(item.id)) if press else false

## Снимает только соответствующее удержание даже тогда, когда открыта пауза или рюкзак.
static func _release(game: Node, event: InputEvent) -> bool:
	var value:=Basement.ui(game)
	var release:bool=(event is InputEventKey and not event.pressed and game.InputSystem.matches(event,"use_item")) or (event is InputEventJoypadButton and not event.pressed and event.button_index==JOY_BUTTON_A)
	release=release or (event is InputEventScreenTouch and not event.pressed and event.index==int(value.touch_id)) or (event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and int(value.touch_id)==-2)
	if not release or int(value.holding)==0: return false
	value.holding=0; value.touch_id=-1; return true

## Выбирает вкладку, строку или действие без оплаты одним нажатием имени станка.
static func _menu(game: Node, event: InputEvent) -> bool:
	var value:=Basement.ui(game); var offset:=0; var tab:=0; var accept:=false
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE,KEY_B: Basement.close(game)
			KEY_UP: offset=-1
			KEY_DOWN: offset=1
			KEY_TAB: tab=-1 if event.shift_pressed else 1
			KEY_ENTER,KEY_E: accept=not event.echo
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B: Basement.close(game)
			JOY_BUTTON_DPAD_UP: offset=-1
			JOY_BUTTON_DPAD_DOWN: offset=1
			JOY_BUTTON_LEFT_SHOULDER: tab=-1
			JOY_BUTTON_RIGHT_SHOULDER: tab=1
			JOY_BUTTON_A: accept=true
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: offset=-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1
	elif (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		for index in 2:
			if PAGES[index].has_point(event.position): value.selected=clampi(int(value.selected)+(-8 if index==0 else 8),0,maxi(0,choices(game).size()-1)); game.queue_redraw(); return true
		for index in 3:
			if TABS[index].has_point(event.position): value.tab=index; value.selected=0; game.queue_redraw(); return true
		if ACTION.has_point(event.position): accept=true
		elif Rect2(210,160,470,344).has_point(event.position): value.selected=first(game)+int((event.position.y-160)/43)
		elif Rect2(1010,60,60,60).has_point(event.position): Basement.close(game)
	if tab!=0: value.tab=posmod(int(value.tab)+tab,3); value.selected=0
	value.selected=clampi(int(value.selected)+offset,0,maxi(0,choices(game).size()-1))
	if accept: execute(game)
	game.queue_redraw(); return true

## Применяет свободное позиционирование и четыре поворота на всей площади, сохраняя отмену без списаний.
static func _placing(game: Node, event: InputEvent) -> bool:
	var value:=Basement.ui(game); var offset:=Vector2i.ZERO
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE,KEY_B: Basement.close(game)
			KEY_R: if not event.echo: rotate(game,1)
			KEY_Q: if not event.echo: rotate(game,-1)
			KEY_ENTER,KEY_E: if not event.echo: Build.build(game,candidate(game))
			KEY_LEFT,KEY_A: offset.x=-1
			KEY_RIGHT,KEY_D: offset.x=1
			KEY_UP,KEY_W: offset.y=-1
			KEY_DOWN,KEY_S: offset.y=1
		if event.shift_pressed: offset*=4
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B: Basement.close(game)
			JOY_BUTTON_A: Build.build(game,candidate(game))
			JOY_BUTTON_LEFT_SHOULDER: rotate(game,-1)
			JOY_BUTTON_RIGHT_SHOULDER: rotate(game,1)
			JOY_BUTTON_DPAD_LEFT: offset.x=-1
			JOY_BUTTON_DPAD_RIGHT: offset.x=1
			JOY_BUTTON_DPAD_UP: offset.y=-1
			JOY_BUTTON_DPAD_DOWN: offset.y=1
	elif event is InputEventMouseMotion or event is InputEventScreenDrag or event is InputEventScreenTouch or event is InputEventMouseButton:
		if (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			for index in 4:
				if not PLACE_BUTTONS[index].has_point(event.position): continue
				value.pointer=Vector2.ZERO
				if index<2: rotate(game,-1 if index==0 else 1)
				elif index==2: Build.build(game,candidate(game))
				else: Basement.close(game)
				return true
		if event.position.y<176 or event.position.y>=560: value.pointer=Vector2.ZERO; return true
		var selected_cell:=Basement.Layout.cell(event.position+game.camera_offset); value.x=selected_cell.x; value.y=selected_cell.y; value.pointer=event.position
		if (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed): Build.build(game,candidate(game))
	if offset!=Vector2i.ZERO:
		value.x+=offset.x; value.y+=offset.y; value.pointer=Vector2.ZERO; follow_cursor(game)
	game.queue_redraw(); return true

## Прокручивает обзор по краям экрана без продвижения игрового времени во время размещения.
static func update(game: Node, delta: float) -> void:
	if game.current_location!=Basement.Data.LOCATION or not bool(Basement.ui(game).placing): return
	var value:=Basement.ui(game); var pointer:Vector2=value.get("pointer",Vector2.ZERO)
	if pointer==Vector2.ZERO: return
	var motion:=Vector2(-1 if pointer.x<24 else (1 if pointer.x>1128 else 0),-1 if pointer.y<192 else (1 if pointer.y>544 else 0))
	if motion==Vector2.ZERO: return
	game.camera_offset+=motion*300*delta
	game.camera_offset.x=clampf(game.camera_offset.x,48,1200); game.camera_offset.y=clampf(game.camera_offset.y,-46,964)
	var position:=Basement.Layout.cell(pointer+game.camera_offset); value.x=position.x; value.y=position.y
