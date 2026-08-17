extends RefCounted

const AssetCatalogSystem := preload("res://scripts/systems/level_editor_asset_catalog_system.gd")
const ValidationSystem := preload("res://scripts/systems/level_editor_validation_system.gd")
const DocumentStore := preload("res://scripts/editor/level_editor_document_store.gd")
const PreferencesStore := preload("res://scripts/editor/level_editor_preferences_store.gd")
const ToolSystem := preload("res://scripts/systems/level_editor_tool_system.gd")
const AtlasPickerSystem := preload("res://scripts/systems/level_editor_atlas_picker_system.gd")
const GroupSystem := preload("res://scripts/systems/level_editor_group_system.gd")
const RuntimeAuthoringSystem := preload("res://scripts/systems/level_editor_runtime_authoring_system.gd")
const PreviewSystem := preload("res://scripts/systems/level_editor_preview_system.gd")
const META_KEY := "level_editor"
const GRID_SIZES := [12, 24, 48, 96]
const LAYERS := ["background", "ground", "objects", "foreground"]
const CATEGORIES := ["terrain", "buildings", "vegetation", "decor", "characters", "enemies", "items", "farming", "fishing", "ui", "other"]
const CATEGORY_NAMES := {"terrain":"ЗЕМЛЯ","buildings":"ДОМА","vegetation":"РАСТЕНИЯ","decor":"ДЕКОР","characters":"ПЕРСОНАЖИ","enemies":"ВРАГИ","items":"ПРЕДМЕТЫ","farming":"ФЕРМА","fishing":"ВОДА/РЫБАЛКА","ui":"ИНТЕРФЕЙС","other":"ПРОЧЕЕ"}
const PANEL := Rect2(10,10,420,628)
const CLOSE_BUTTON := Rect2(390,20,28,28)
const CATEGORY_PREV := Rect2(22,78,32,28)
const SEARCH_BUTTON := Rect2(58,78,246,28)
const CATEGORY_NEXT := Rect2(310,78,32,28)
const FAVORITES_BUTTON := Rect2(348,78,70,28)
const ASSET_ROWS := Rect2(22,116,396,178)
const ASSET_ROW_HEIGHT := 43
const VISIBLE_ASSETS := 4
const SELECT_TOOL_BUTTON := Rect2(22,326,76,32)
const PAINT_TOOL_BUTTON := Rect2(102,326,76,32)
const FILL_TOOL_BUTTON := Rect2(182,326,76,32)
const PICKER_TOOL_BUTTON := Rect2(262,326,76,32)
const ERASE_TOOL_BUTTON := Rect2(342,326,76,32)
const NEW_BUTTON := Rect2(22,383,70,32)
const SAVE_BUTTON := Rect2(96,383,70,32)
const LOAD_BUTTON := Rect2(170,383,70,32)
const EXPORT_BUTTON := Rect2(244,383,84,32)
const IMPORT_BUTTON := Rect2(332,383,86,32)
const PUBLISH_BUTTON := Rect2(22,419,194,32)
const VALIDATE_BUTTON := Rect2(222,419,196,32)
const GRID_BUTTON := Rect2(22,466,128,32)
const SLICE_BUTTON := Rect2(154,466,128,32)
const LAYER_BUTTON := Rect2(286,466,132,32)
const COLLISION_BUTTON := Rect2(22,513,146,32)
const LEVEL_NAME_BUTTON := Rect2(172,513,120,32)
const ROLE_BUTTON := Rect2(296,513,122,32)
const OBJECT_NAME_BUTTON := Rect2(22,549,194,32)
const OBJECT_NOTE_BUTTON := Rect2(222,549,196,32)

static var _catalog: Array[Dictionary] = []


## Создаёт полное временное состояние конструктора, которое не попадает в обычное сохранение игры.
static func default_state(game: Node) -> Dictionary:
	return {"active":false,"base_location":game.current_location,"level_name":"%s_custom" % game.current_location,"level_notes":"","objects":[],"selected":-1,"selected_ids":[],"group_clipboard":[],"group_drag_origins":{},"group_drag_anchor":Vector2.ZERO,"selection_start":Vector2.ZERO,"selection_end":Vector2.ZERO,"selection_additive":false,"layer_visibility":{"background":true,"ground":true,"objects":true,"foreground":true},"layer_locked":{"background":false,"ground":false,"objects":false,"foreground":false},"selected_asset":"","category":0,"scroll":0,"search":"","favorites":PreferencesStore.load_favorites(),"favorites_only":false,"grid":24,"snap":true,"slice_size":0,"slice_index":0,"source_mode":"grid","custom_source":Rect2(),"atlas_picker_open":false,"atlas_page":0,"region_dragging":false,"region_drag_start":Vector2.ZERO,"region_drag_end":Vector2.ZERO,"layer":"objects","collision":false,"collision_view":true,"tool":"select","drag_kind":"","drag_offset":Vector2.ZERO,"rectangle_start":Vector2i.ZERO,"rectangle_end":Vector2i.ZERO,"last_brush_cell":Vector2i(-2147483648,-2147483648),"stroke_cells":{},"stroke_history_pushed":false,"mouse":Vector2.ZERO,"history":[],"future":[],"status":"F12 — закрыть конструктор","validation":{},"text_mode":"","text_buffer":"","draft_cursor":-1,"panel_hidden":false,"capture_pending":0,"export_png":"","next_id":1}


## Проверяет, перехватывает ли конструктор симуляцию, ввод и интерфейс текущей игры.
static func active(game: Node) -> bool:
	return bool(game.get_meta(META_KEY, {}).get("active", false))


## Открывает редактор поверх живой локации или закрывает его без изменения runtime-карты.
static func toggle(game: Node) -> void:
	var state: Dictionary = game.get_meta(META_KEY, default_state(game))
	state.active = not bool(state.active)
	state.base_location = game.current_location if state.objects.is_empty() else state.base_location
	var audit:=AssetCatalogSystem.audit(catalog())
	state.status = "Каталог %d · дома %d/%d · листы %d · к нарезке %d" % [audit.placeable,audit.buildings,audit.expected_buildings,audit.sliced,audit.excluded_composites.size()] if state.active else "Конструктор закрыт"
	state.panel_hidden = false
	game.set_meta(META_KEY,state)
	game.clear_movement_keys()
	if game.DebugOverlaySystem.active(game):
		var debug: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY); debug.open = false; game.set_meta(game.DebugOverlaySystem.META_KEY,debug)
	game.queue_redraw()


## Рекурсивно строит ленивый каталог всех растровых игровых ресурсов и распределяет их по группам.
static func catalog() -> Array[Dictionary]:
	if not _catalog.is_empty(): return _catalog
	_catalog = AssetCatalogSystem.scan("res://assets/game")
	return _catalog


## Определяет пользовательскую группу спрайта по стабильной структуре каталогов проекта.
static func category_for_path(path: String) -> String:
	return AssetCatalogSystem.category_for_path(path)


## Возвращает отфильтрованные элементы активной категории для панели ресурсов.
static func visible_catalog(state: Dictionary) -> Array[Dictionary]:
	var category: String = CATEGORIES[int(state.category)]
	return AssetCatalogSystem.filter(catalog(),category,String(state.get("search","")),bool(state.get("favorites_only",false)),state.get("favorites",[]))


## Обрабатывает F12, мышь, drag-and-drop, горячие клавиши и режим ввода подписей.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		toggle(game); return true
	if not active(game): return false
	var state: Dictionary = game.get_meta(META_KEY)
	if not String(state.text_mode).is_empty():
		_handle_text_input(game,state,event); return true
	if event is InputEventMouseMotion:
		state.mouse = event.position; if not AtlasPickerSystem.handle_input(state,event): _handle_motion(game,state,event); game.set_meta(META_KEY,state); game.queue_redraw(); return true
	if event is InputEventMouseButton:
		_handle_mouse(game,state,event); game.set_meta(META_KEY,state); game.queue_redraw(); return true
	if event is InputEventKey and event.pressed and not event.echo:
		if not AtlasPickerSystem.handle_input(state,event): _handle_key(game,state,event); game.set_meta(META_KEY,state); game.queue_redraw(); return true
	return true


## Изменяет текст подписи или названия, поддерживая Unicode, Backspace, Enter и отмену Escape.
static func _handle_text_input(game: Node, state: Dictionary, event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.keycode == KEY_ESCAPE:
		state.text_mode = ""; state.text_buffer = ""; state.status = "Ввод отменён"
	elif event.keycode == KEY_ENTER:
		_commit_text(state); state.status = "Текст сохранён"
	elif event.keycode == KEY_BACKSPACE:
		state.text_buffer = String(state.text_buffer).left(maxi(String(state.text_buffer).length()-1,0))
	elif event.unicode >= 32:
		state.text_buffer += char(event.unicode)
	game.set_meta(META_KEY,state); game.queue_redraw()


## Применяет введённый текст к уровню или выбранному объекту и завершает режим ввода.
static func _commit_text(state: Dictionary) -> void:
	if String(state.text_mode)=="catalog_search":
		state.search=String(state.text_buffer).strip_edges(); state.scroll=0; state.text_mode=""; state.text_buffer=""; state.status="Поиск: %s"%(state.search if not String(state.search).is_empty() else "выключен"); return
	push_history(state)
	match String(state.text_mode):
		"level_name": state.level_name = String(state.text_buffer).strip_edges()
		"level_notes": state.level_notes = String(state.text_buffer).strip_edges()
		"object_name":
			if valid_selection(state): state.objects[state.selected].name = String(state.text_buffer).strip_edges()
		"object_notes":
			if valid_selection(state): state.objects[state.selected].notes = String(state.text_buffer).strip_edges()
	state.text_mode = ""; state.text_buffer = ""


## Обрабатывает нажатие, отпускание, колёсико и размещение ресурсов на мировом холсте.
static func _handle_mouse(game: Node, state: Dictionary, event: InputEventMouseButton) -> void:
	state.mouse = event.position
	if AtlasPickerSystem.handle_input(state,event): return
	if GroupSystem.handle_mouse(game,state,event): return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		if PANEL.has_point(event.position):
			state.scroll = maxi(0,int(state.scroll)+( -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
		else:
			pan_camera(game,Vector2(0,-96 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 96))
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		state.drag_kind = ""; state.selected_asset = ""; state.selected = -1; state.tool = "select"; state.status = "Режим выбора"; return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if event.pressed:
		if PANEL.has_point(event.position): _handle_panel_click(game,state,event.position)
		else: _handle_world_press(game,state,event.position)
	elif state.drag_kind == "catalog_asset":
		if not PANEL.has_point(event.position):
			_begin_stroke(state); place_selected_asset(game,state,event.position,false)
		state.drag_kind = ""; state.stroke_history_pushed = false
	elif state.drag_kind in ["paint","erase"]:
		state.drag_kind = ""; state.stroke_history_pushed = false; state.stroke_cells = {}; state.last_brush_cell = Vector2i(-2147483648,-2147483648)
	elif state.drag_kind == "fill":
		_fill_rectangle(game,state); state.drag_kind=""; state.stroke_history_pushed=false; state.stroke_cells={}
	elif state.drag_kind == "object":
		state.drag_kind = ""; state.status = "Объект перемещён"


## Перемещает выбранный объект или обновляет позицию превью переносимого спрайта.
static func _handle_motion(game: Node, state: Dictionary, event: InputEventMouseMotion) -> void:
	if GroupSystem.handle_motion(game,state,event): return
	if state.drag_kind == "object" and valid_selection(state):
		var world: Vector2 = event.position + Vector2(game.camera_offset)
		state.objects[state.selected].position = snap(state,world+Vector2(state.drag_offset))
	elif state.drag_kind == "paint":
		paint_to(game,state,event.position)
	elif state.drag_kind == "erase":
		erase_at(game,state,event.position)
	elif state.drag_kind == "fill":
		state.rectangle_end=grid_cell(state,event.position+Vector2(game.camera_offset))


## Выполняет команду экранной панели или начинает перенос выбранного ресурса на холст.
static func _handle_panel_click(game: Node, state: Dictionary, point: Vector2) -> void:
	if CLOSE_BUTTON.has_point(point): toggle(game); return
	if CATEGORY_PREV.has_point(point): change_category(state,-1); return
	if CATEGORY_NEXT.has_point(point): change_category(state,1); return
	if SEARCH_BUTTON.has_point(point): begin_text(state,"catalog_search",String(state.get("search",""))); return
	if FAVORITES_BUTTON.has_point(point): state.favorites_only=not bool(state.favorites_only); state.scroll=0; state.status="Только избранное" if state.favorites_only else "Все ресурсы категории"; return
	if ASSET_ROWS.has_point(point):
		var row: int = int((point.y-ASSET_ROWS.position.y)/ASSET_ROW_HEIGHT)
		var entries: Array[Dictionary] = visible_catalog(state); var start:=clampi(int(state.scroll),0,maxi(entries.size()-VISIBLE_ASSETS,0)); var index: int = start+row
		if index < entries.size():
			if point.x>=ASSET_ROWS.end.x-34:
				var path:=String(entries[index].path); var added:bool=PreferencesStore.toggle_favorite(state.favorites,path); state.status=("В избранном: " if added else "Удалено из избранного: ")+String(entries[index].name)
			else: activate_asset(state,entries[index]); state.drag_kind = "catalog_asset"; state.status = "Кликни или веди по карте · B кисть"
		return
	if SELECT_TOOL_BUTTON.has_point(point): state.tool="select"; state.drag_kind=""; state.status="Выбор и перемещение · V"
	elif PAINT_TOOL_BUTTON.has_point(point): state.tool="paint"; state.status="Кисть · выбери спрайт и рисуй · B"
	elif FILL_TOOL_BUTTON.has_point(point): state.tool="fill"; state.drag_kind=""; state.status="Прямоугольник · протяни между углами · G"
	elif PICKER_TOOL_BUTTON.has_point(point): state.tool="picker"; state.drag_kind=""; state.status="Пипетка · кликни существующий объект · I"
	elif ERASE_TOOL_BUTTON.has_point(point): state.tool="erase"; state.drag_kind=""; state.status="Ластик · кликни или веди · E"
	elif NEW_BUTTON.has_point(point): new_draft(game,state)
	elif SAVE_BUTTON.has_point(point): save_draft(game,state,false)
	elif LOAD_BUTTON.has_point(point): load_next_draft(game,state)
	elif EXPORT_BUTTON.has_point(point): save_draft(game,state,true)
	elif IMPORT_BUTTON.has_point(point): import_current_level(game,state)
	elif PUBLISH_BUTTON.has_point(point): game.PublishedLevelSystem.publish_and_play(game,state)
	elif VALIDATE_BUTTON.has_point(point): validate_draft(state)
	elif GRID_BUTTON.has_point(point): state.grid = GRID_SIZES[(GRID_SIZES.find(int(state.grid))+1)%GRID_SIZES.size()]; state.status = "Сетка %d px" % state.grid
	elif SLICE_BUTTON.has_point(point): AtlasPickerSystem.open(state)
	elif LAYER_BUTTON.has_point(point): state.layer = LAYERS[(LAYERS.find(String(state.layer))+1)%LAYERS.size()]
	elif COLLISION_BUTTON.has_point(point): state.collision = not bool(state.collision)
	elif LEVEL_NAME_BUTTON.has_point(point): begin_text(state,"level_name",state.level_name)
	elif ROLE_BUTTON.has_point(point): RuntimeAuthoringSystem.cycle_role(game.LevelEditorSystem,state)
	elif OBJECT_NAME_BUTTON.has_point(point): begin_text(state,"object_name" if valid_selection(state) else "level_name",state.objects[state.selected].name if valid_selection(state) else state.level_name)
	elif OBJECT_NOTE_BUTTON.has_point(point): begin_text(state,"object_notes" if valid_selection(state) else "level_notes",state.objects[state.selected].notes if valid_selection(state) else state.level_notes)


## Выбирает верхний объект мира для перетаскивания либо рисует текущим спрайтом.
static func _handle_world_press(game: Node, state: Dictionary, screen_point: Vector2) -> void:
	var world: Vector2 = screen_point + Vector2(game.camera_offset)
	if String(state.tool) == "paint" and not String(state.selected_asset).is_empty():
		_begin_stroke(state); state.drag_kind = "paint"; paint_to(game,state,screen_point); return
	if String(state.tool) == "erase":
		_begin_stroke(state); state.drag_kind = "erase"; erase_at(game,state,screen_point); return
	if String(state.tool) == "fill" and not String(state.selected_asset).is_empty():
		_begin_stroke(state); state.rectangle_start=grid_cell(state,world); state.rectangle_end=state.rectangle_start; state.drag_kind="fill"; state.status="Протяни прямоугольник и отпусти"; return
	if String(state.tool) == "picker":
		var picked:=object_at(state,world)
		if picked>=0: ToolSystem.pick_object(state,state.objects[picked],CATEGORIES)
		else: state.status="Под курсором нет объекта"
		return
	var selected: int = object_at(state,world)
	if selected >= 0:
		push_history(state); state.selected = selected; state.drag_kind = "object"; state.drag_offset = Vector2(state.objects[selected].position)-world; return
	state.selected = -1


## Обрабатывает отмену, удаление, копирование, слои, трансформации, историю и перемещение камеры.
static func _handle_key(game: Node, state: Dictionary, event: InputEventKey) -> void:
	if GroupSystem.handle_key(game,state,event): return
	var command_pressed: bool = event.ctrl_pressed or event.meta_pressed
	if command_pressed and ((event.keycode == KEY_Z and event.shift_pressed) or event.keycode == KEY_Y): redo(state); return
	if command_pressed and event.keycode == KEY_Z: undo(state); return
	if RuntimeAuthoringSystem.handle_key(game,state,event): return
	match event.keycode:
		KEY_ESCAPE: state.selected_asset = ""; state.selected = -1; state.drag_kind = ""; state.tool = "select"
		KEY_B: state.tool = "paint"; state.status = "Кисть · кликни или веди"
		KEY_G: state.tool = "fill"; state.drag_kind=""; state.status = "Прямоугольник · протяни между углами"
		KEY_I: state.tool = "picker"; state.drag_kind=""; state.status = "Пипетка · кликни объект"
		KEY_F: state.favorites_only=not bool(state.favorites_only); state.scroll=0; state.status="Только избранное" if state.favorites_only else "Все ресурсы категории"
		KEY_SLASH: begin_text(state,"catalog_search",String(state.get("search","")))
		KEY_V: state.tool = "select"; state.drag_kind = ""; state.status = "Выбор и перемещение"
		KEY_E: state.tool = "erase"; state.drag_kind = ""; state.status = "Ластик · кликни или веди"
		KEY_DELETE,KEY_BACKSPACE: delete_selected(state)
		KEY_D: duplicate_selected(state)
		KEY_N: begin_text(state,"object_name" if valid_selection(state) else "level_name",state.objects[state.selected].name if valid_selection(state) else state.level_name)
		KEY_O: begin_text(state,"object_notes" if valid_selection(state) else "level_notes",state.objects[state.selected].notes if valid_selection(state) else state.level_notes)
		KEY_Q: transform_selected(state,"rotate")
		KEY_X: transform_selected(state,"flip_x")
		KEY_Y: transform_selected(state,"flip_y")
		KEY_BRACKETLEFT: transform_selected(state,"scale_down")
		KEY_BRACKETRIGHT: transform_selected(state,"scale_up")
		KEY_COMMA: state.slice_index = maxi(0,int(state.slice_index)-1)
		KEY_PERIOD: state.slice_index += 1
		KEY_PAGEUP: move_layer(state,1)
		KEY_PAGEDOWN: move_layer(state,-1)
		KEY_R: validate_draft(state)
		KEY_W,KEY_UP: pan_camera(game,Vector2(0,-int(state.grid)))
		KEY_S,KEY_DOWN: pan_camera(game,Vector2(0,int(state.grid)))
		KEY_A,KEY_LEFT: pan_camera(game,Vector2(-int(state.grid),0))
		KEY_RIGHT: pan_camera(game,Vector2(int(state.grid),0))
		_: pass


## Переключает категорию ресурсов по кольцу и возвращает список к первой строке.
static func change_category(state: Dictionary, step: int) -> void:
	state.category = posmod(int(state.category)+step,CATEGORIES.size()); state.scroll = 0; state.status = CATEGORY_NAMES[CATEGORIES[state.category]]


## Начинает безопасный пользовательский ввод для одного из текстовых полей конструктора.
static func begin_text(state: Dictionary, mode: String, current: String) -> void:
	state.text_mode = mode; state.text_buffer = current; state.status = "Ввод текста · Enter сохранить · Esc отменить"


## Включает кисть выбранного ресурса и применяет его безопасные настройки слоя и якоря.
static func activate_asset(state: Dictionary, entry: Dictionary) -> void:
	state.selected_asset = String(entry.path); state.tool = "paint"; state.slice_index = 0
	state.slice_size = int(entry.get("slice_size",0)); state.source_mode="grid"; state.custom_source=Rect2(); state.atlas_page=0; state.layer = String(entry.get("layer","objects")); state.collision = bool(entry.get("collision",false))


## Создаёт объект выбранного ресурса с текущими сеткой, срезом, слоем и коллизией.
static func place_selected_asset(game: Node, state: Dictionary, screen_point: Vector2, record_history: bool = true) -> bool:
	var path := String(state.selected_asset)
	if path.is_empty(): return false
	var entry := AssetCatalogSystem.find(catalog(),path)
	var unique_key:=String(entry.get("unique_key",""))
	if not unique_key.is_empty() and unique_is_placed(state,unique_key):
		state.status="Уникальный персонаж уже находится на уровне"; return false
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null: state.status = "Не удалось загрузить %s" % path; return false
	if record_history: push_history(state)
	var source := selected_source(texture,state)
	var profiled_size:=Vector2(entry.get("display_size",Vector2.ZERO))
	var size: Vector2 = profiled_size if profiled_size!=Vector2.ZERO else (source.size if source.size != Vector2.ZERO else texture.get_size())
	if String(state.get("source_mode","grid"))=="custom" and source.size!=Vector2.ZERO: size=source.size
	var world := screen_point + Vector2(game.camera_offset)
	var anchor := String(entry.get("anchor","center"))
	if anchor=="tile": size=Vector2.ONE*int(state.grid)
	var position := placement_position(state,world,anchor)
	if anchor == "tile": _remove_ground_at(state,position,String(state.layer))
	var object := {"id":int(state.next_id),"asset_path":path,"name":path.get_file().get_basename(),"notes":"","position":position,"size":size,"source":source,"anchor":anchor,"layer":state.layer,"collision":state.collision,"collision_size":size,"collision_offset":Vector2.ZERO,"runtime_role":"","rotation":0.0,"flip_x":false,"flip_y":false,"reference":false,"runtime_id":"","original_position":Vector2.ZERO,"hidden":false,"unique_key":unique_key,"catalog_category":String(entry.get("category","other")),"surface_kind":String(entry.get("surface_kind","")),"autotile_diagonal_mask":0,"transition_masks":{},"transition_corner_masks":{}}
	state.next_id = int(state.next_id)+1; state.objects.append(object); state.selected = state.objects.size()-1; state.selected_ids=[int(object.id)]; state.status = "Размещено: %s" % object.name
	ValidationSystem.rebuild_autotile_masks(state); state.validation={}
	return true


## Начинает единый мазок, чтобы вся непрерывная линия отменялась одной командой Ctrl+Z.
static func _begin_stroke(state: Dictionary) -> void:
	if not bool(state.stroke_history_pushed): push_history(state)
	state.stroke_history_pushed = true; state.stroke_cells = {}; state.last_brush_cell = Vector2i(-2147483648,-2147483648)


## Заполняет все пропущенные клетки между событиями мыши и не оставляет дыр при быстром движении.
static func paint_to(game: Node, state: Dictionary, screen_point: Vector2) -> void:
	var target := grid_cell(state,screen_point+Vector2(game.camera_offset))
	var first_cell := int(state.last_brush_cell.x) == -2147483648
	var start: Vector2i = target if first_cell else Vector2i(state.last_brush_cell)
	var cells := cells_between(start,target); if not first_cell and not cells.is_empty(): cells.pop_front()
	for cell in cells:
		var key := "%d:%d"%[cell.x,cell.y]
		if state.stroke_cells.has(key): continue
		state.stroke_cells[key]=true
		place_selected_asset(game,state,screen_for_cell(game,state,cell),false)
	state.last_brush_cell = target


## Заполняет выбранным ресурсом весь протянутый прямоугольник как одну операцию истории.
static func _fill_rectangle(game: Node, state: Dictionary) -> void:
	var cells:=ToolSystem.rectangle_cells(Vector2i(state.rectangle_start),Vector2i(state.rectangle_end))
	for cell in cells: place_selected_asset(game,state,screen_for_cell(game,state,cell),false)
	state.status="Прямоугольник: %d клеток"%cells.size(); ValidationSystem.rebuild_autotile_masks(state); state.validation={}


## Стирает верхний элемент в каждой пройденной клетке тем же непрерывным алгоритмом, что и кисть.
static func erase_at(game: Node, state: Dictionary, screen_point: Vector2) -> void:
	var target := grid_cell(state,screen_point+Vector2(game.camera_offset))
	var first_cell := int(state.last_brush_cell.x) == -2147483648; var start: Vector2i = target if first_cell else Vector2i(state.last_brush_cell)
	var cells := cells_between(start,target); if not first_cell and not cells.is_empty(): cells.pop_front()
	for cell in cells:
		var key := "%d:%d"%[cell.x,cell.y]
		if state.stroke_cells.has(key): continue
		state.stroke_cells[key]=true
		var world := Vector2(cell)*int(state.grid)+Vector2.ONE*int(state.grid)*0.5
		var index := object_at(state,world)
		if index >= 0: state.objects.remove_at(index); state.selected = -1
	ValidationSystem.rebuild_autotile_masks(state); state.validation={}; state.last_brush_cell = target; state.status = "Ластик"


## Возвращает все клетки дискретной линии Брезенхэма, включая начало и конец мазка.
static func cells_between(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := start; var delta := (finish-start).abs(); var step := Vector2i(1 if start.x<finish.x else -1,1 if start.y<finish.y else -1); var error := delta.x-delta.y
	while true:
		result.append(current)
		if current == finish: break
		var doubled := error*2
		if doubled > -delta.y: error -= delta.y; current.x += step.x
		if doubled < delta.x: error += delta.x; current.y += step.y
	return result


## Преобразует клетку мира обратно в экранную точку внутри клетки для общей функции размещения.
static func screen_for_cell(game: Node, state: Dictionary, cell: Vector2i) -> Vector2:
	return Vector2(cell)*int(state.grid)+Vector2.ONE*int(state.grid)*0.5-Vector2(game.camera_offset)


## Вычисляет индекс малой клетки с привязкой вниз, поэтому соседние тайлы касаются ровно границами.
static func grid_cell(state: Dictionary, world: Vector2) -> Vector2i:
	var grid := int(state.grid)
	return Vector2i(floori(world.x/grid),floori(world.y/grid))


## Выбирает координату якоря: левый верх для земли, низ для объектов и центр для предметов.
static func placement_position(state: Dictionary, world: Vector2, anchor: String) -> Vector2:
	if not bool(state.snap): return world.round()
	var grid := int(state.grid); var origin := Vector2(grid_cell(state,world))*grid
	if anchor == "tile": return origin
	if anchor == "bottom": return origin+Vector2(grid*0.5,grid)
	return origin+Vector2.ONE*grid*0.5


## Заменяет только тайл того же слоя в клетке, не затрагивая дерево, NPC или декор поверх него.
static func _remove_ground_at(state: Dictionary, position: Vector2, layer: String) -> void:
	for index in range(state.objects.size()-1,-1,-1):
		var object: Dictionary = state.objects[index]
		if String(object.get("anchor","center")) == "tile" and String(object.layer) == layer and Vector2(object.position).is_equal_approx(position):
			state.objects.remove_at(index)


## Вычисляет срез атласа для выбранного размера и безопасно зацикливает номер кадра.
static func selected_source(texture: Texture2D, state: Dictionary) -> Rect2:
	return AtlasPickerSystem.selected_source(texture,state)


## Возвращает подпись активного режима нарезки атласа и выбранного кадра.
static func slice_label(state: Dictionary) -> String:
	return AtlasPickerSystem.source_label(state)


## Привязывает позицию к выбранной сетке либо оставляет точные координаты при отключённой привязке.
static func snap(state: Dictionary, position: Vector2) -> Vector2:
	if not bool(state.snap): return position.round()
	var grid := int(state.grid)
	return Vector2(roundf(position.x/grid),roundf(position.y/grid))*grid


## Возвращает мировой прямоугольник спрайта по единому контракту якорей редактора.
static func object_bounds(object: Dictionary) -> Rect2:
	var size := Vector2(object.size)*object_scale(object); var position := Vector2(object.position)
	match String(object.get("anchor","center")):
		"tile": return Rect2(position,size)
		"bottom": return Rect2(position-Vector2(size.x*0.5,size.y),size)
		_: return Rect2(position-size*0.5,size)


## Возвращает индекс верхнего видимого объекта под мировой точкой с учётом масштаба.
static func object_at(state: Dictionary, world: Vector2) -> int:
	for index in range(state.objects.size()-1,-1,-1):
		var object: Dictionary = state.objects[index]
		if object.get("hidden",false) or not bool(state.layer_visibility.get(String(object.layer),true)) or bool(state.layer_locked.get(String(object.layer),false)): continue
		if object_bounds(object).has_point(world): return index
	return -1


## Проверяет, указывает ли индекс выбора на существующий объект черновика.
static func valid_selection(state: Dictionary) -> bool:
	return int(state.selected)>=0 and int(state.selected)<state.objects.size()


## Возвращает единый масштаб объекта с безопасным значением по умолчанию.
static func object_scale(object: Dictionary) -> float:
	return clampf(float(object.get("scale",1.0)),0.25,4.0)


## Удаляет выбранный объект с возможностью последующей отмены операции.
static func delete_selected(state: Dictionary) -> void:
	if not valid_selection(state): return
	push_history(state); state.objects.remove_at(state.selected); state.selected = mini(int(state.selected),state.objects.size()-1); state.status = "Объект удалён"


## Создаёт копию выбранного объекта со смещением на одну клетку текущей сетки.
static func duplicate_selected(state: Dictionary) -> void:
	if not valid_selection(state): return
	if not String(state.objects[state.selected].get("unique_key","")).is_empty(): state.status="Уникального персонажа нельзя дублировать"; return
	push_history(state); var copy: Dictionary = state.objects[state.selected].duplicate(true); copy.id = state.next_id; state.next_id += 1; copy.position = Vector2(copy.position)+Vector2(int(state.grid),int(state.grid)); copy.name = "%s копия" % copy.name; copy.runtime_role=""; state.objects.append(copy); state.selected = state.objects.size()-1; state.status = "Создана копия"


## Проверяет занятость уникального ключа среди видимых и скрытых объектов текущего черновика.
static func unique_is_placed(state: Dictionary, unique_key: String) -> bool:
	if unique_key.is_empty(): return false
	return state.objects.any(func(object: Dictionary): return String(object.get("unique_key",""))==unique_key)


## Изменяет поворот, отражение или масштаб выбранного объекта предсказуемым шагом.
static func transform_selected(state: Dictionary, operation: String) -> void:
	if not valid_selection(state): return
	push_history(state); var object: Dictionary = state.objects[state.selected]
	match operation:
		"rotate": object.rotation = fposmod(float(object.rotation)+PI*0.5,TAU)
		"flip_x": object.flip_x = not bool(object.flip_x)
		"flip_y": object.flip_y = not bool(object.flip_y)
		"scale_down": object.scale = maxf(0.25,object_scale(object)-0.25)
		"scale_up": object.scale = minf(4.0,object_scale(object)+0.25)
	state.objects[state.selected]=object; state.status="Трансформация применена"


## Перемещает объект по порядку слоёв и синхронизирует активный слой панели.
static func move_layer(state: Dictionary, step: int) -> void:
	if not valid_selection(state): return
	push_history(state); var object: Dictionary = state.objects[state.selected]; object.layer=LAYERS[posmod(LAYERS.find(String(object.layer))+step,LAYERS.size())]; state.objects[state.selected]=object; state.layer=object.layer


## Сдвигает камеру редактора внутри безопасных границ текущего мира.
static func pan_camera(game: Node, motion: Vector2) -> void:
	game.camera_offset.x=clampf(game.camera_offset.x+motion.x,0.0,game.WORLD_SIZE.x-1152.0); game.camera_offset.y=clampf(game.camera_offset.y+motion.y,0.0,game.WORLD_SIZE.y-648.0)
	var background:=game.get_node_or_null("WorldBackground"); if background: background.position=-game.camera_offset


## Сохраняет снимок объектов в стеке отмены и очищает повтор операций.
static func push_history(state: Dictionary) -> void:
	var history: Array=state.history; history.append({"objects":state.objects.duplicate(true),"level_name":state.level_name,"level_notes":state.level_notes,"next_id":state.next_id}); if history.size()>40: history.pop_front(); state.history=history; state.future=[]


## Возвращает предыдущую компоновку и переносит текущую в стек повтора.
static func undo(state: Dictionary) -> void:
	if state.history.is_empty(): state.status="Нечего отменять"; return
	var future: Array=state.future; future.append({"objects":state.objects.duplicate(true),"level_name":state.level_name,"level_notes":state.level_notes,"next_id":state.next_id}); state.future=future; _restore_history(state,state.history.pop_back()); state.selected=-1; state.selected_ids=[]; state.status="Отмена"


## Повторяет последнюю отменённую операцию без потери последующей истории.
static func redo(state: Dictionary) -> void:
	if state.future.is_empty(): state.status="Нечего повторять"; return
	var history: Array=state.history; history.append({"objects":state.objects.duplicate(true),"level_name":state.level_name,"level_notes":state.level_notes,"next_id":state.next_id}); state.history=history; _restore_history(state,state.future.pop_back()); state.selected=-1; state.selected_ids=[]; state.status="Повтор"


## Восстанавливает один внутренний снимок истории редактора.
static func _restore_history(state: Dictionary, snapshot: Dictionary) -> void:
	state.objects=snapshot.objects; state.level_name=snapshot.level_name; state.level_notes=snapshot.level_notes; state.next_id=snapshot.next_id


## Очищает холст, сохраняя текущую компоновку в истории отмены.
static func new_draft(game: Node, state: Dictionary) -> void:
	push_history(state); state.objects=[]; state.selected=-1; state.selected_ids=[]; state.base_location=game.current_location; state.level_name="%s_custom"%game.current_location; state.level_notes=""; state.next_id=1; state.status="Новый пустой черновик"


## Импортирует объекты живой локации как редактируемые референсы с исходными координатами.
static func import_current_level(game: Node, state: Dictionary) -> void:
	push_history(state); state.objects=[]; state.selected=-1; state.selected_ids=[]; state.base_location=game.current_location; state.level_name="%s_redesign"%game.current_location
	for candidate in game.DebugObjectInspectorSystem.candidates(game):
		if candidate.id=="player" or candidate.category in ["ДОБЫЧА","ПЕРЕХОД"]: continue
		state.objects.append({"id":int(state.next_id),"asset_path":"","name":candidate.name,"notes":"","position":candidate.position,"size":candidate.bounds.size,"source":Rect2(),"anchor":"center","layer":"objects","collision":not String(candidate.collision).begins_with("нет"),"collision_size":candidate.bounds.size,"collision_offset":Vector2.ZERO,"runtime_role":"","rotation":0.0,"flip_x":false,"flip_y":false,"reference":true,"runtime_id":candidate.id,"original_position":candidate.position,"hidden":false,"scale":1.0,"unique_key":runtime_unique_key(String(candidate.id)),"catalog_category":"reference","surface_kind":"","autotile_diagonal_mask":0,"transition_masks":{},"transition_corner_masks":{}}); state.next_id+=1
	state.status="Импортировано референсов: %d"%state.objects.size()


## Сопоставляет технический идентификатор живого NPC или напарника с ключом уникальности каталога.
static func runtime_unique_key(runtime_id: String) -> String:
	var normalized:=runtime_id.to_lower()
	if normalized.begins_with("npc:") or normalized.begins_with("companion:"): return normalized
	return ""


## Формирует JSON-совместимый документ со всеми дизайнерскими решениями и комментариями автора.
static func document(state: Dictionary) -> Dictionary:
	return DocumentStore.document(state)


## Запускает полный аудит карты и сохраняет подробный отчёт для панели конструктора.
static func validate_draft(state: Dictionary) -> Dictionary:
	return DocumentStore.validate_draft(state)


## Записывает черновик в пользовательскую папку или экспортирует JSON и запрашивает чистое PNG-превью.
static func save_draft(game: Node, state: Dictionary, export_to_project: bool) -> bool:
	return DocumentStore.save_draft(state, export_to_project)


## Возвращает безопасное имя файла из пользовательского названия уровня.
static func slugify(value: String) -> String:
	return DocumentStore.slugify(value)


## Собирает доступные файлы черновиков из пользовательской и проектной папок без дубликатов.
static func draft_files() -> Array[String]:
	return DocumentStore.draft_files()


## Загружает следующий сохранённый черновик по кругу для быстрого сравнения вариантов.
static func load_next_draft(game: Node, state: Dictionary) -> bool:
	return DocumentStore.load_next_draft(game, state)


## Читает и проверяет документ конструктора, восстанавливая его объекты и базовую локацию.
static func load_draft(game: Node, state: Dictionary, path: String) -> bool:
	return DocumentStore.load_draft(game, state, path)


## Собирает плотный демонстрационный фрагмент новой земли, дорог и воды для визуального QA редактора.
static func configure_preview(game: Node, state: Dictionary) -> void:
	PreviewSystem.configure(game,state,game.LevelEditorSystem,AssetCatalogSystem)


## Завершает отложенный захват чистого игрового кадра после скрытия панели редактора.
static func update_export_capture(game: Node) -> void:
	if not active(game): return
	var state:Dictionary=game.get_meta(META_KEY); var pending:=int(state.capture_pending)
	if pending<=0: return
	pending-=1; state.capture_pending=pending
	if pending==0:
		var image:=game.get_viewport().get_texture().get_image(); var error:=image.save_png(ProjectSettings.globalize_path(String(state.export_png))); state.panel_hidden=false; state.status="Экспорт готов: %s"%state.export_png if error==OK else "Ошибка PNG: %s"%error
	game.set_meta(META_KEY,state); game.queue_redraw()
