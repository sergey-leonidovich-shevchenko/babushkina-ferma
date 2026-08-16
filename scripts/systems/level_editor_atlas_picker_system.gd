extends RefCounted

const PANEL := Rect2(404,42,724,564)
const CLOSE_BUTTON := Rect2(1084,54,32,28)
const GRID_TAB := Rect2(430,84,150,32)
const CUSTOM_TAB := Rect2(588,84,150,32)
const SLICE_PREV := Rect2(750,84,36,32)
const SLICE_LABEL := Rect2(792,84,160,32)
const SLICE_NEXT := Rect2(958,84,36,32)
const GRID_AREA := Rect2(430,126,672,384)
const CUSTOM_AREA := Rect2(430,126,672,384)
const PAGE_PREV := Rect2(430,526,92,32)
const PAGE_LABEL := Rect2(528,526,476,32)
const PAGE_NEXT := Rect2(1010,526,92,32)
const GRID_COLUMNS := 8
const GRID_ROWS := 4
const GRID_CELL := Vector2(84,96)
const PAGE_SIZE := GRID_COLUMNS*GRID_ROWS
const SLICE_SIZES := [0,16,24,32,48,64,96,128,222,256]


## Открывает визуальный выбор кадра для текущего ресурса и показывает страницу активного индекса.
static func open(state: Dictionary) -> bool:
	var path:=String(state.get("selected_asset",""))
	if path.is_empty() or not ResourceLoader.exists(path): state.status="Сначала выбери спрайт"; return false
	state.atlas_picker_open=true; state.atlas_page=maxi(0,int(state.get("slice_index",0))/PAGE_SIZE); state.region_dragging=false; state.status="Выбери кадр или выдели произвольную область"
	return true


## Закрывает окно атласа, сохраняя выбранный кадр как активную кисть.
static func close(state: Dictionary) -> void:
	state.atlas_picker_open=false; state.region_dragging=false; state.status=source_label(state)


## Перехватывает мышь и клавиатуру модального выбора, не позволяя рисовать сквозь окно.
static func handle_input(state: Dictionary, event: InputEvent) -> bool:
	if not bool(state.get("atlas_picker_open",false)): return false
	var texture:=ResourceLoader.load(String(state.selected_asset)) as Texture2D
	if texture==null: close(state); state.status="Атлас не загрузился"; return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE,KEY_ENTER]: close(state)
		elif event.keycode==KEY_LEFT: change_page(state,texture,-1)
		elif event.keycode==KEY_RIGHT: change_page(state,texture,1)
		elif event.keycode==KEY_TAB: state.source_mode="custom" if String(state.get("source_mode","grid"))=="grid" else "grid"
		return true
	if event is InputEventMouseMotion:
		if bool(state.get("region_dragging",false)): update_custom_region(state,texture,event.position)
		return true
	if not event is InputEventMouseButton: return true
	if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: close(state); return true
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		change_page(state,texture,-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1); return true
	if event.button_index!=MOUSE_BUTTON_LEFT: return true
	if event.pressed: _handle_press(state,texture,event)
	elif bool(state.get("region_dragging",false)): update_custom_region(state,texture,event.position); state.region_dragging=false; state.status=source_label(state)
	return true


## Выполняет команду модального окна или начинает выделение произвольного прямоугольника.
static func _handle_press(state: Dictionary, texture: Texture2D, event: InputEventMouseButton) -> void:
	var point:=event.position
	if CLOSE_BUTTON.has_point(point): close(state); return
	if GRID_TAB.has_point(point): state.source_mode="grid"; if int(state.slice_size)<=0: state.slice_size=24; state.atlas_page=0; return
	if CUSTOM_TAB.has_point(point): state.source_mode="custom"; _ensure_custom_source(state,texture); return
	if SLICE_PREV.has_point(point): change_slice(state,-1); return
	if SLICE_NEXT.has_point(point): change_slice(state,1); return
	if PAGE_PREV.has_point(point): change_page(state,texture,-1); return
	if PAGE_NEXT.has_point(point): change_page(state,texture,1); return
	if String(state.get("source_mode","grid"))=="grid" and GRID_AREA.has_point(point):
		select_grid_frame(state,texture,point)
		if event.double_click: close(state)
	elif String(state.get("source_mode","grid"))=="custom" and texture_destination(texture).has_point(point):
		var pixel:=screen_to_texture(texture,point); state.region_drag_start=pixel; state.region_drag_end=pixel+Vector2.ONE; state.region_dragging=true; update_custom_region(state,texture,point)


## Переключает размер равномерной ячейки и сбрасывает страницу на первый корректный кадр.
static func change_slice(state: Dictionary, step: int) -> void:
	var current:=SLICE_SIZES.find(int(state.get("slice_size",0))); if current<0: current=0
	state.slice_size=SLICE_SIZES[posmod(current+step,SLICE_SIZES.size())]; state.slice_index=0; state.atlas_page=0; state.source_mode="grid"; state.custom_source=Rect2(); state.status=source_label(state)


## Листает кадры постранично и ограничивает страницу фактическим числом целых ячеек.
static func change_page(state: Dictionary, texture: Texture2D, step: int) -> void:
	var pages:=page_count(texture,state); state.atlas_page=clampi(int(state.get("atlas_page",0))+step,0,pages-1)


## Выбирает кадр по координате ячейки визуальной таблицы.
static func select_grid_frame(state: Dictionary, texture: Texture2D, point: Vector2) -> bool:
	var local:=point-GRID_AREA.position; var column:=clampi(int(local.x/GRID_CELL.x),0,GRID_COLUMNS-1); var row:=clampi(int(local.y/GRID_CELL.y),0,GRID_ROWS-1); var index:=int(state.get("atlas_page",0))*PAGE_SIZE+row*GRID_COLUMNS+column
	if index>=frame_count(texture,state): return false
	state.slice_index=index; state.source_mode="grid"; state.status=source_label(state); return true


## Обновляет произвольный source-rect по движению мыши и сохраняет минимум один пиксель.
static func update_custom_region(state: Dictionary, texture: Texture2D, point: Vector2) -> void:
	state.region_drag_end=screen_to_texture(texture,point); var start:=Vector2(state.region_drag_start); var finish:=Vector2(state.region_drag_end); var minimum:=Vector2(floorf(minf(start.x,finish.x)),floorf(minf(start.y,finish.y))); var maximum:=Vector2(ceilf(maxf(start.x,finish.x)),ceilf(maxf(start.y,finish.y)))
	minimum.x=clampf(minimum.x,0,texture.get_width()-1); minimum.y=clampf(minimum.y,0,texture.get_height()-1); maximum.x=clampf(maximum.x,minimum.x+1,texture.get_width()); maximum.y=clampf(maximum.y,minimum.y+1,texture.get_height()); state.custom_source=Rect2(minimum,maximum-minimum); state.source_mode="custom"


## Возвращает область, реально используемую кистью: пользовательскую либо равномерный кадр.
static func selected_source(texture: Texture2D, state: Dictionary) -> Rect2:
	if String(state.get("source_mode","grid"))=="custom":
		_ensure_custom_source(state,texture); return Rect2(state.custom_source)
	var size:=int(state.get("slice_size",0))
	if size<=0: return Rect2()
	var columns:=maxi(1,int(texture.get_width())/size); var total:=frame_count(texture,state); var index:=posmod(int(state.get("slice_index",0)),total)
	return Rect2(Vector2((index%columns)*size,(index/columns)*size),Vector2(size,size))


## Считает только полностью помещающиеся кадры выбранного равномерного размера.
static func frame_count(texture: Texture2D, state: Dictionary) -> int:
	var size:=int(state.get("slice_size",0)); if size<=0: return 1
	return maxi(1,int(texture.get_width()/size)*int(texture.get_height()/size))


## Возвращает число страниц по 32 превью, включая единственную страницу цельного изображения.
static func page_count(texture: Texture2D, state: Dictionary) -> int:
	return maxi(1,ceili(float(frame_count(texture,state))/PAGE_SIZE))


## Вписывает полный исходник в безопасную область вкладки произвольной нарезки без искажения пропорций.
static func texture_destination(texture: Texture2D) -> Rect2:
	var texture_size:=texture.get_size(); var scale:=minf(CUSTOM_AREA.size.x/texture_size.x,CUSTOM_AREA.size.y/texture_size.y); var size:=texture_size*scale
	return Rect2(CUSTOM_AREA.position+(CUSTOM_AREA.size-size)*0.5,size)


## Переводит экранную координату окна обратно в точный пиксель исходной текстуры.
static func screen_to_texture(texture: Texture2D, point: Vector2) -> Vector2:
	var destination:=texture_destination(texture); var relative:=(point-destination.position)/destination.size
	return Vector2(clampf(relative.x,0,1)*texture.get_width(),clampf(relative.y,0,1)*texture.get_height())


## Создаёт начальное пользовательское выделение на весь исходник, если область ещё не задана.
static func _ensure_custom_source(state: Dictionary, texture: Texture2D) -> void:
	var source:=Rect2(state.get("custom_source",Rect2()))
	if source.size==Vector2.ZERO: state.custom_source=Rect2(Vector2.ZERO,texture.get_size())


## Формирует короткое описание активного кадра для панели и подсказок.
static func source_label(state: Dictionary) -> String:
	if String(state.get("source_mode","grid"))=="custom":
		var source:=Rect2(state.get("custom_source",Rect2())); return "ОБЛАСТЬ %.0f,%.0f · %.0f×%.0f"%[source.position.x,source.position.y,source.size.x,source.size.y]
	return "ЦЕЛИКОМ" if int(state.get("slice_size",0))<=0 else "КАДР %d px · #%d"%[int(state.slice_size),int(state.slice_index)+1]
