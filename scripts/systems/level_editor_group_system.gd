extends RefCounted

const PANEL := Rect2(918,342,224,232)
const HEADER := Rect2(930,354,200,28)
const ROWS_START := Vector2(930,392)
const ROW_HEIGHT := 38
const LAYERS := ["foreground","objects","ground","background"]


## Перехватывает панель слоёв и инструменты группового выбора поверх живого холста.
static func handle_mouse(game: Node, state: Dictionary, event: InputEventMouseButton) -> bool:
	if PANEL.has_point(event.position):
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT: _handle_layer_click(state,event.position)
		return true
	if game.LevelEditorSystem.PANEL.has_point(event.position): return false
	if String(state.tool)!="select" or event.button_index!=MOUSE_BUTTON_LEFT: return false
	if event.pressed: _begin_world_selection(game,state,event)
	else: _finish_world_selection(game,state)
	return true


## Перемещает выбранную группу либо обновляет рамку выделяемой области.
static func handle_motion(game: Node, state: Dictionary, event: InputEventMouseMotion) -> bool:
	if String(state.get("drag_kind",""))=="marquee": state.selection_end=event.position+Vector2(game.camera_offset); return true
	if String(state.get("drag_kind",""))!="group": return false
	var delta:Vector2=game.LevelEditorSystem.snap(state,event.position+Vector2(game.camera_offset)-Vector2(state.group_drag_anchor))
	for index in state.objects.size():
		var id:=int(state.objects[index].id)
		if state.group_drag_origins.has(id): state.objects[index].position=Vector2(state.group_drag_origins[id])+delta
	return true


## Обрабатывает выделить всё, копирование и вставку группы стандартными сочетаниями клавиш.
static func handle_key(game: Node, state: Dictionary, event: InputEventKey) -> bool:
	if event.keycode in [KEY_DELETE,KEY_BACKSPACE] and not state.selected_ids.is_empty(): delete_selection(game,state); return true
	if not (event.ctrl_pressed or event.meta_pressed): return false
	if event.keycode==KEY_A: select_layer(state,String(state.layer)); return true
	if event.keycode==KEY_C: copy_selection(state); return true
	if event.keycode==KEY_V: paste_selection(game,state); return true
	return false


## Удаляет всю выбранную группу одним отменяемым действием и очищает первичный индекс.
static func delete_selection(game: Node, state: Dictionary) -> void:
	game.LevelEditorSystem.push_history(state); var removed:int=state.selected_ids.size()
	for index in range(state.objects.size()-1,-1,-1):
		if int(state.objects[index].id) in state.selected_ids: state.objects.remove_at(index)
	state.selected_ids=[]; state.selected=-1; game.LevelEditorSystem.ValidationSystem.rebuild_autotile_masks(state); state.status="Удалено объектов: %d"%removed


## Выделяет все незаблокированные объекты текущего слоя.
static func select_layer(state: Dictionary, layer: String) -> void:
	if bool(state.layer_locked.get(layer,false)): state.status="Слой заблокирован"; return
	state.selected_ids=[]
	for object in state.objects:
		if String(object.layer)==layer and not bool(object.get("hidden",false)): state.selected_ids.append(int(object.id))
	state.selected=_primary_index(state); state.status="Выбрано на слое: %d"%state.selected_ids.size()


## Копирует выбранные объекты во внутренний буфер без изменения их id и координат оригинала.
static func copy_selection(state: Dictionary) -> void:
	state.group_clipboard=[]
	for object in state.objects:
		if int(object.id) in state.selected_ids: state.group_clipboard.append(object.duplicate(true))
	state.status="Скопировано: %d"%state.group_clipboard.size()


## Вставляет буфер со смещением на клетку, выдаёт новые id и пропускает уникальных персонажей.
static func paste_selection(game: Node, state: Dictionary) -> void:
	if state.group_clipboard.is_empty(): state.status="Буфер группы пуст"; return
	game.LevelEditorSystem.push_history(state); state.selected_ids=[]; var skipped:=0
	for original in state.group_clipboard:
		if not String(original.get("unique_key","")).is_empty(): skipped+=1; continue
		var copy:Dictionary=original.duplicate(true); copy.id=int(state.next_id); state.next_id+=1; copy.position=Vector2(copy.position)+Vector2.ONE*int(state.grid); copy.name="%s копия"%copy.name; state.objects.append(copy); state.selected_ids.append(int(copy.id))
	state.selected=_primary_index(state); game.LevelEditorSystem.ValidationSystem.rebuild_autotile_masks(state); state.status="Вставлено: %d%s"%[state.selected_ids.size()," · уникальных пропущено %d"%skipped if skipped>0 else ""]


## Возвращает рамку активного выделения в мировых координатах независимо от направления жеста.
static func selection_rect(state: Dictionary) -> Rect2:
	var start:=Vector2(state.selection_start); var finish:=Vector2(state.selection_end); var minimum:=Vector2(minf(start.x,finish.x),minf(start.y,finish.y)); var maximum:=Vector2(maxf(start.x,finish.x),maxf(start.y,finish.y))
	return Rect2(minimum,maximum-minimum)


## Начинает перетаскивание выбранной группы или новую рамку по пустому месту.
static func _begin_world_selection(game: Node, state: Dictionary, event: InputEventMouseButton) -> void:
	var world:Vector2=event.position+Vector2(game.camera_offset); var index:int=game.LevelEditorSystem.object_at(state,world)
	if index<0:
		if not event.shift_pressed: state.selected_ids=[]; state.selected=-1
		state.drag_kind="marquee"; state.selection_start=world; state.selection_end=world; state.selection_additive=event.shift_pressed; return
	var id:=int(state.objects[index].id)
	if event.shift_pressed:
		if id in state.selected_ids: state.selected_ids.erase(id)
		else: state.selected_ids.append(id)
	elif id not in state.selected_ids: state.selected_ids=[id]
	state.selected=index
	if id not in state.selected_ids: state.drag_kind=""; return
	game.LevelEditorSystem.push_history(state); state.drag_kind="group"; state.group_drag_anchor=world; state.group_drag_origins={}
	for object in state.objects:
		if int(object.id) in state.selected_ids: state.group_drag_origins[int(object.id)]=Vector2(object.position)


## Завершает рамку или перемещение и пересчитывает связанные тайлы одним действием истории.
static func _finish_world_selection(game: Node, state: Dictionary) -> void:
	if String(state.drag_kind)=="marquee":
		var rect:=selection_rect(state)
		for object in state.objects:
			if not _selectable(state,object) or not rect.intersects(game.LevelEditorSystem.object_bounds(object),true): continue
			if int(object.id) not in state.selected_ids: state.selected_ids.append(int(object.id))
		state.selected=_primary_index(state); state.status="Выбрано рамкой: %d"%state.selected_ids.size()
	elif String(state.drag_kind)=="group":
		game.LevelEditorSystem.ValidationSystem.rebuild_autotile_masks(state); state.status="Перемещено объектов: %d"%state.selected_ids.size()
	state.drag_kind=""; state.group_drag_origins={}


## Переключает видимость или блокировку строки слоя по координате кнопки.
static func _handle_layer_click(state: Dictionary, point: Vector2) -> void:
	var row:=int((point.y-ROWS_START.y)/ROW_HEIGHT)
	if row<0 or row>=LAYERS.size(): return
	var layer:String=String(LAYERS[row])
	if point.x<1038: state.layer=layer; state.status="Активный слой: %s"%layer
	elif point.x<1082: state.layer_visibility[layer]=not bool(state.layer_visibility.get(layer,true)); state.status="Видимость %s"%layer
	else: state.layer_locked[layer]=not bool(state.layer_locked.get(layer,false)); state.status="Блокировка %s"%layer


## Проверяет видимость, блокировку и скрытое состояние объекта перед групповым выбором.
static func _selectable(state: Dictionary, object: Dictionary) -> bool:
	var layer:=String(object.layer)
	return bool(state.layer_visibility.get(layer,true)) and not bool(state.layer_locked.get(layer,false)) and not bool(object.get("hidden",false))


## Находит индекс первого выбранного id для совместимости с одиночной карточкой объекта.
static func _primary_index(state: Dictionary) -> int:
	for index in state.objects.size():
		if int(state.objects[index].id) in state.selected_ids: return index
	return -1
