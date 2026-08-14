extends RefCounted

const META_KEY := "fence_builder"
const CELL_SIZE := 24
const BUILDABLE_LOCATIONS := ["overworld","forest","rocky","ruins","cursed","glassworks"]
const SECTION_ITEM := "fence_kit"
const GATE_ITEM := "gate_kit"
const TOUCH_BUTTON := Rect2(1060,500,76,56)
const STYLES := [
	{"id":"rustic","names":["Дубовый","Rustic oak","Roble rústico","Rustikale Eiche","Chêne rustique","乡村橡木"]},
	{"id":"orchard","names":["Белый садовый","White orchard","Huerto blanco","Weißer Garten","Verger blanc","白色果园"]},
	{"id":"stone","names":["Каменный","Stone","Piedra","Stein","Pierre","石墙"]},
	{"id":"iron","names":["Кованый","Wrought iron","Hierro forjado","Schmiedeeisen","Fer forgé","锻铁"]},
	{"id":"hedge","names":["Живая изгородь","Living hedge","Seto vivo","Lebende Hecke","Haie vive","绿篱"]},
]


## Возвращает сохранённые постройки из расширения усадьбы и нормализует старые документы.
static func structures(game: Node) -> Array:
	var expansion: Dictionary = game.state.world.estate.get("expansion",{})
	if not expansion.has("fences") or not expansion.fences is Array: expansion.fences=[]
	game.state.world.estate.expansion=expansion
	return expansion.fences


## Возвращает временное состояние панели строительства, не попадающее в RPG-сохранение.
static func runtime(game: Node) -> Dictionary:
	if not game.has_meta(META_KEY): game.set_meta(META_KEY,{"active":false,"style":0,"piece":"section","orientation":0,"place_held":false,"repeat_left":0.0,"last_cell":Vector2i(-999,-999),"gamepad_chord_left":false})
	return game.get_meta(META_KEY)


## Проверяет, включён ли режим строительства ограды на текущей карте.
static func active(game: Node) -> bool:
	return bool(runtime(game).active)


## Возвращает локализованное название выбранного материала забора.
static func style_name(game: Node, style_index: int) -> String:
	var locale_index: int = maxi(0,game.LocaleSystem.LOCALES.find(game.LocaleSystem.current))
	return STYLES[clampi(style_index,0,STYLES.size()-1)].names[locale_index]


## Включает или завершает строительство только на разрешённых наружных локациях.
static func toggle(game: Node) -> bool:
	if game.current_location not in BUILDABLE_LOCATIONS: return false
	var value: Dictionary=runtime(game); value.active=not bool(value.active); value.place_held=false; value.last_cell=Vector2i(-999,-999); game.set_meta(META_KEY,value); game.clear_movement_keys()
	game.message=game.LocaleSystem.text("fence_builder_open") if value.active else game.LocaleSystem.text("fence_builder_closed")
	game.queue_redraw(); return true


## Обрабатывает клавиатуру, геймпад, мышь и касание в активном строительном режиме.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.keycode==KEY_Z and event.pressed and not event.echo:
		return toggle(game)
	if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_LEFT_SHOULDER:
		var chord: Dictionary=runtime(game); chord.gamepad_chord_left=event.pressed; game.set_meta(META_KEY,chord)
		if not event.pressed: return false
	if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_RIGHT_SHOULDER and event.pressed and bool(runtime(game).gamepad_chord_left): return toggle(game)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and TOUCH_BUTTON.has_point(event.position):
		return toggle(game)
	if event is InputEventScreenTouch and event.pressed and TOUCH_BUTTON.has_point(event.position):
		return toggle(game)
	if not active(game): return false
	var value: Dictionary=runtime(game)
	if event is InputEventKey:
		if event.keycode in [KEY_ENTER,KEY_E]:
			value.place_held=event.pressed; value.repeat_left=0.0
			if event.pressed and not event.echo: place(game)
			game.set_meta(META_KEY,value); return true
		if not event.pressed or event.echo: return event.keycode in [KEY_Q,KEY_G,KEY_R,KEY_X,KEY_ESCAPE]
		match event.keycode:
			KEY_Q: cycle_style(game,1)
			KEY_G: toggle_piece(game)
			KEY_R: rotate_gate(game)
			KEY_X,KEY_DELETE,KEY_BACKSPACE: remove_target(game)
			KEY_ESCAPE: value.active=false; value.place_held=false; game.set_meta(META_KEY,value); game.message=game.LocaleSystem.text("fence_builder_closed")
			_: return false
		game.queue_redraw(); return true
	if event is InputEventJoypadButton:
		if event.button_index==JOY_BUTTON_A:
			value.place_held=event.pressed; value.repeat_left=0.0; game.set_meta(META_KEY,value); if event.pressed: place(game); return true
		if not event.pressed: return false
		match event.button_index:
			JOY_BUTTON_X: remove_target(game)
			JOY_BUTTON_Y: toggle_piece(game)
			JOY_BUTTON_LEFT_SHOULDER: cycle_style(game,-1)
			JOY_BUTTON_RIGHT_SHOULDER: cycle_style(game,1)
			JOY_BUTTON_B: value.active=false; game.set_meta(META_KEY,value)
			_: return false
		game.queue_redraw(); return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: return place(game,event.position+game.camera_offset)
		if event.button_index==MOUSE_BUTTON_RIGHT: return remove_target(game,event.position+game.camera_offset)
	if event is InputEventScreenTouch and event.pressed: return place(game,event.position+game.camera_offset)
	return false


## Повторяет установку при удержании действия, позволяя быстро строить линии произвольной длины.
static func update(game: Node, delta: float) -> void:
	if not active(game): return
	if game.shop_open or game.inventory_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open or game.quest_log_open or game.skill_menu_open or game.world_map_open:
		var paused_value: Dictionary=runtime(game); paused_value.place_held=false; game.set_meta(META_KEY,paused_value); return
	var value: Dictionary=runtime(game)
	if not bool(value.place_held): return
	value.repeat_left=float(value.repeat_left)-delta
	if value.repeat_left<=0.0: place(game); value.repeat_left=0.16
	game.set_meta(META_KEY,value)


## Переключает один из пяти материалов и сбрасывает защиту от повторной клетки.
static func cycle_style(game: Node, step: int) -> void:
	var value: Dictionary=runtime(game); value.style=posmod(int(value.style)+step,STYLES.size()); value.last_cell=Vector2i(-999,-999); game.set_meta(META_KEY,value); game.message=style_name(game,value.style)


## Меняет обычную секцию на подходящую материалу калитку и обратно.
static func toggle_piece(game: Node) -> void:
	var value: Dictionary=runtime(game); value.piece="gate" if value.piece=="section" else "section"; value.last_cell=Vector2i(-999,-999); game.set_meta(META_KEY,value)


## Поворачивает двухклеточную калитку между горизонтальным и вертикальным направлением.
static func rotate_gate(game: Node) -> void:
	var value: Dictionary=runtime(game); value.orientation=1-int(value.orientation); value.last_cell=Vector2i(-999,-999); game.set_meta(META_KEY,value)


## Возвращает базовую клетку перед героем либо под переданным мировым указателем.
static func target_cell(game: Node, world_position: Vector2=Vector2.INF) -> Vector2i:
	var position: Vector2=world_position if world_position!=Vector2.INF else game.player+game.facing.normalized()*48.0
	return Vector2i(floori(position.x/CELL_SIZE),floori(position.y/CELL_SIZE))


## Возвращает центр базовой клетки 24×24 в мировых координатах.
static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell*CELL_SIZE)+Vector2(CELL_SIZE*0.5,CELL_SIZE*0.5)


## Возвращает две занятые клетки калитки либо единственную клетку обычной секции.
static func occupied_cells(structure: Dictionary) -> Array[Vector2i]:
	var data: Array=structure.get("cell",[0,0]); var origin:=Vector2i(int(data[0]),int(data[1])); var result: Array[Vector2i]=[origin]
	if structure.get("kind","section")=="gate": result.append(origin+(Vector2i.RIGHT if int(structure.get("orientation",0))==0 else Vector2i.DOWN))
	return result


## Находит индекс построенного объекта, занимающего заданную клетку текущей локации.
static func structure_at(game: Node, cell: Vector2i) -> int:
	var values:=structures(game)
	for index in values.size():
		var structure: Dictionary=values[index]
		if structure.get("location","")==game.current_location and cell in occupied_cells(structure): return index
	return -1


## Проверяет границы, дороги, воду, грядки, объекты и другие ограды до расходования набора.
static func placement_reason(game: Node, cell: Vector2i, piece: String, orientation: int) -> String:
	if game.current_location not in BUILDABLE_LOCATIONS: return "location"
	var cells: Array[Vector2i]=[cell]
	if piece=="gate": cells.append(cell+(Vector2i.RIGHT if orientation==0 else Vector2i.DOWN))
	for occupied in cells:
		var rect:=Rect2(Vector2(occupied*CELL_SIZE),Vector2(CELL_SIZE,CELL_SIZE)); var center:=rect.get_center()
		if rect.position.x<40 or rect.position.y<120 or rect.end.x>game.WORLD_SIZE.x-40 or rect.end.y>game.WORLD_SIZE.y-80: return "boundary"
		if structure_at(game,occupied)>=0: return "occupied"
		if game.current_location=="overworld" and (game.VillageLayoutSystem.is_road_or_path(center) or game.VillageLayoutSystem.is_on_bridge(center,8.0)): return "road"
		var navigation_reason: String=game.NavigationSystem.walkability_reason(game,center)
		if navigation_reason!="walkable": return navigation_reason
		for plot in game.state.world.world_plots.values():
			if plot.location==game.current_location and game.WorldFarmingSystem.cell_rect(plot.cell).intersects(rect): return "farm"
	return "ok"


## Устанавливает секцию или калитку, списывая один подходящий набор из рюкзака.
static func place(game: Node, world_position: Vector2=Vector2.INF) -> bool:
	var value: Dictionary=runtime(game); var cell:=target_cell(game,world_position)
	if cell==value.last_cell: return false
	var reason:=placement_reason(game,cell,value.piece,int(value.orientation))
	if reason!="ok": game.message=game.LocaleSystem.text("fence_cannot_build"); return false
	var item:=GATE_ITEM if value.piece=="gate" else SECTION_ITEM
	if game.inventory_item_count(item)<1: game.message=game.LocaleSystem.text("fence_no_items",[game.inventory_item_name(item)]); return false
	game.change_inventory_count(item,-1); structures(game).append({"location":game.current_location,"cell":[cell.x,cell.y],"kind":value.piece,"style":int(value.style),"orientation":int(value.orientation),"open":false})
	value.last_cell=cell; game.set_meta(META_KEY,value); game.message=game.LocaleSystem.text("fence_built"); game.play_sfx("craft"); game.notify_tutorial("fence_build"); if value.piece=="gate": game.notify_tutorial("fence_gate")
	game.queue_redraw(); return true


## Удаляет собственную ограду под целью и возвращает использованный строительный набор.
static func remove_target(game: Node, world_position: Vector2=Vector2.INF) -> bool:
	var cell:=target_cell(game,world_position); var index:=structure_at(game,cell)
	if index<0: return false
	var values:=structures(game); var item:=GATE_ITEM if values[index].kind=="gate" else SECTION_ITEM; values.remove_at(index); game.change_inventory_count(item,1); runtime(game).last_cell=Vector2i(-999,-999); game.message=game.LocaleSystem.text("fence_removed"); game.queue_redraw(); return true


## Вычисляет битовую маску соседей одного материала для автоматического соединения рисунка.
static func connection_mask(game: Node, structure: Dictionary) -> int:
	var origin: Vector2i=occupied_cells(structure)[0]; var style:=int(structure.get("style",0)); var mask:=0
	for entry in [[Vector2i.UP,1],[Vector2i.RIGHT,2],[Vector2i.DOWN,4],[Vector2i.LEFT,8]]:
		var index:=structure_at(game,origin+entry[0])
		if index>=0 and int(structures(game)[index].get("style",0))==style: mask|=entry[1]
	return mask


## Проверяет столкновение с секциями и только с закрытыми калитками текущей локации.
static func blocks_position(game: Node, position: Vector2, radius: float) -> bool:
	for structure in structures(game):
		if structure.location!=game.current_location or (structure.kind=="gate" and bool(structure.open)): continue
		for cell in occupied_cells(structure):
			if game.NavigationSystem.circle_intersects_rect(position,radius,Rect2(Vector2(cell*CELL_SIZE),Vector2(CELL_SIZE,CELL_SIZE))): return true
	return false


## Возвращает мировой центр секции или двухклеточной калитки.
static func structure_center(structure: Dictionary) -> Vector2:
	var cells:=occupied_cells(structure); return (cell_center(cells[0])+cell_center(cells[-1]))*0.5


## Находит ближайшую построенную калитку для обычного контекстного взаимодействия.
static func nearest_gate(game: Node, distance_limit: float=92.0) -> String:
	var nearest:=""; var best:=distance_limit
	for index in structures(game).size():
		var structure: Dictionary=structures(game)[index]
		if structure.location!=game.current_location or structure.kind!="gate": continue
		var distance: float=game.player.distance_to(structure_center(structure))
		if distance<best: best=distance; nearest="fence_gate:%d"%index
	return nearest


## Открывает или закрывает выбранную калитку и немедленно обновляет её коллизию.
static func toggle_gate(game: Node, index: int) -> bool:
	var values:=structures(game)
	if index<0 or index>=values.size() or values[index].kind!="gate": return false
	values[index].open=not bool(values[index].open); game.message=game.LocaleSystem.text("fence_gate_opened" if values[index].open else "fence_gate_closed"); game.play_sfx("craft"); game.notify_tutorial("fence_gate"); game.queue_redraw(); return true


## Готовит на первой локации контрольную витрину пяти материалов, соединений и калиток.
static func configure_preview(game: Node) -> void:
	game.language_screen=false; game.title_screen=false; game.current_location="overworld"; game.player=Vector2(1240,500); game.tutorial_visible=false; game.day=15
	var values: Array=structures(game); values.clear()
	for style in STYLES.size():
		var origin:=Vector2i(39,14+style*3)
		for offset in [0,1,2,5,6,7]: values.append({"location":"overworld","cell":[origin.x+offset,origin.y],"kind":"section","style":style,"orientation":0,"open":false})
		values.append({"location":"overworld","cell":[origin.x+3,origin.y],"kind":"gate","style":style,"orientation":0,"open":style%2==1})
		values.append({"location":"overworld","cell":[origin.x,origin.y+1],"kind":"section","style":style,"orientation":0,"open":false})
	game.change_inventory_count(SECTION_ITEM,40); game.change_inventory_count(GATE_ITEM,5)
